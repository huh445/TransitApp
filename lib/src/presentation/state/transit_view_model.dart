import 'package:flutter/material.dart';
import '../../domain/entities/station.dart';
import '../../domain/entities/trips.dart';
import '../../domain/entities/transit_route.dart';
import '../../data/repositories/gtfs_repository.dart';
import '../../data/datasources/gtfs_index_engine.dart';
import '../../services/melbourne_gtfs_service.dart';

class TransitViewModel extends ChangeNotifier {
  final IGtfsRepository repository;
  bool _isDisposed = false;

  int _selectedNavIndex = 0;
  TransitType? _selectedTypeFilter;
  String _searchQuery = '';
  Station _selectedStation = MelbourneGtfsService.melbourneHubStations.first;

  List<Trip> _trips = [];
  List<ServiceAlert> _alerts = [];
  List<Station> _stations = MelbourneGtfsService.melbourneHubStations;
  final Set<String> _favoriteTrips = {};
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  String _loadingStatus = 'Initializing...';
  String? _errorMessage;
  int _loadRequestId = 0;

  TransitViewModel({required this.repository});

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  int get selectedNavIndex => _selectedNavIndex;
  TransitType? get selectedTypeFilter => _selectedTypeFilter;
  String get searchQuery => _searchQuery;
  Station get selectedStation => _selectedStation;
  List<Trip> get trips => _trips;
  List<ServiceAlert> get alerts => _alerts;
  List<Station> get stations =>
      _stations.isNotEmpty ? _stations : MelbourneGtfsService.melbourneHubStations;
  Set<String> get favoriteTrips => _favoriteTrips;
  bool get isLoading => _isLoading;
  double get loadingProgress => _loadingProgress;
  String get loadingStatus => _loadingStatus;
  int get loadingPercentage => (_loadingProgress * 100).clamp(0, 100).toInt();
  String? get errorMessage => _errorMessage;

  PtvMode get selectedMode => _selectedTypeFilter == null
      ? PtvMode.metroTrain
      : _mapTransitTypeToPtvMode(_selectedTypeFilter!);

  static PtvMode _mapTransitTypeToPtvMode(TransitType type) {
    switch (type) {
      case TransitType.metro:
        return PtvMode.metroTrain;
      case TransitType.tram:
        return PtvMode.metroTram;
      case TransitType.regionalTrain:
        return PtvMode.regionalTrain;
      case TransitType.bus:
        return PtvMode.metroBus;
      case TransitType.ferry:
        return PtvMode.regionalCoach;
    }
  }

  void selectNavIndex(int index) {
    if (_selectedNavIndex != index) {
      _selectedNavIndex = index;
      notifyListeners();
    }
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void selectModeFilter(TransitType? type) {
    _selectedTypeFilter = type;
    notifyListeners();
    loadMelbourneData(station: _selectedStation);
  }

  void selectStation(Station station) {
    _selectedStation = station;
    notifyListeners();
    loadMelbourneData(station: station);
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedTypeFilter = null;
    notifyListeners();
    loadMelbourneData(station: _selectedStation);
  }

  void toggleFavorite(String tripId) {
    if (_favoriteTrips.contains(tripId)) {
      _favoriteTrips.remove(tripId);
    } else {
      _favoriteTrips.add(tripId);
    }
    notifyListeners();
  }

  bool isFavorite(String tripId) => _favoriteTrips.contains(tripId);

  List<Trip> get filteredTrips {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _trips.where((trip) {
      final departure = trip.departure;
      final matchesType =
          _selectedTypeFilter == null || departure?.type == _selectedTypeFilter;
      final matchesQuery =
          query.isEmpty ||
          trip.destinationName.toLowerCase().contains(query) ||
          trip.destination.toLowerCase().contains(query) ||
          trip.headsign.toLowerCase().contains(query) ||
          (trip.shortName?.toLowerCase().contains(query) ?? false) ||
          (departure?.lineCode.toLowerCase().contains(query) ?? false) ||
          (departure?.routeName.toLowerCase().contains(query) ?? false) ||
          trip.stops.any((s) => s.station.name.toLowerCase().contains(query));
      return matchesType && matchesQuery;
    }).toList();

    filtered.sort((a, b) {
      final aTime = a.departure?.scheduledTime;
      final bTime = b.departure?.scheduledTime;
      if (aTime == null || bTime == null) return aTime == null ? 1 : -1;
      return aTime.compareTo(bTime);
    });

    return filtered;
  }

  List<Trip> get displayedTrips {
    final filtered = filteredTrips;
    if (_selectedNavIndex == 1) {
      return filtered.where((t) => _favoriteTrips.contains(t.tripId)).toList();
    }
    return filtered;
  }

  Future<void> loadMelbourneData({PtvMode? mode, Station? station}) async {
    final requestId = ++_loadRequestId;
    final modeToFetch = mode ?? selectedMode;
    _isLoading = true;
    _loadingProgress = 0.05;
    _loadingStatus = 'Connecting to PTV Feed... 5%';
    _errorMessage = null;
    notifyListeners();

    void updateProgress(double progress, String status) {
      if (requestId == _loadRequestId && !_isDisposed) {
        _loadingProgress = progress;
        _loadingStatus = status;
        notifyListeners();
      }
    }

    final dynamicStops = await repository.getStopsForMode(
      modeToFetch,
      onProgress: updateProgress,
    );
    final rawStations = [
      ...MelbourneGtfsService.melbourneHubStations,
      ...dynamicStops,
    ];

    final uniqueById = <String, Station>{};
    final uniqueByName = <String, Station>{};

    for (final s in rawStations) {
      final cleanName = GtfsIndexEngine.normalizeStationName(s.name);
      final nameKey = cleanName.toLowerCase();
      final idKey = s.id;

      if (uniqueById.containsKey(idKey)) {
        final existing = uniqueById[idKey]!;
        if (s.isCityLoop && !existing.isCityLoop) {
          uniqueById[idKey] = existing.copyWith(isCityLoop: true);
        }
        continue;
      }

      if (uniqueByName.containsKey(nameKey)) {
        final existing = uniqueByName[nameKey]!;
        if (s.isCityLoop && !existing.isCityLoop) {
          uniqueByName[nameKey] = existing.copyWith(isCityLoop: true);
        }
        continue;
      }

      final stationObj = s.copyWith(name: cleanName);
      uniqueById[idKey] = stationObj;
      uniqueByName[nameKey] = stationObj;
    }

    final stationList = uniqueById.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final requestedStation = station ?? _selectedStation;
    final currentSelected = stationList.firstWhere(
      (s) =>
          s.id == requestedStation.id ||
          s.stopId == requestedStation.stopId ||
          s.name.toLowerCase() == requestedStation.name.toLowerCase(),
      orElse: () => stationList.first,
    );

    final trips = await repository.getTripsForMode(
      modeToFetch,
      station: currentSelected,
      onProgress: updateProgress,
    );
    final alerts = await repository.getServiceAlerts();

    if (requestId == _loadRequestId && !_isDisposed) {
      _trips = trips;
      _alerts = alerts;
      _stations = stationList;
      _selectedStation = currentSelected;
      _isLoading = false;
      _loadingProgress = 1.0;
      _loadingStatus = 'Complete 100%';
      notifyListeners();
    }
  }
}
