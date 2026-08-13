import 'package:flutter/material.dart';
import '../../domain/entities/station.dart';
import '../../domain/entities/trips.dart';
import '../../domain/entities/transit_route.dart';
import '../../data/repositories/gtfs_repository.dart';
import '../../data/datasources/gtfs_index_engine.dart';
import '../../services/melbourne_gtfs_service.dart';
import '../../services/ptv_rt_service.dart';
import '../../services/favorite_service.dart';

class TransitViewModel extends ChangeNotifier {
  final IGtfsRepository repository;
  final PtvRealtimeService ptvService;
  final FavoriteService favoriteService = FavoriteService();
  bool _isDisposed = false;

  int _selectedNavIndex = 0;
  TransitType? _selectedTypeFilter;
  String _searchQuery = '';
  Station _selectedStation = MelbourneGtfsService.melbourneHubStations.first;

  List<Trip> _trips = [];
  List<ServiceAlert> _alerts = [];
  List<Station> _stations = MelbourneGtfsService.melbourneHubStations;
  List<Station> _favoriteStations = [];
  
  final Set<String> _favoriteTrips = {};
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  String _loadingStatus = 'Initializing...';
  String? _errorMessage;
  int _loadRequestId = 0;

  TransitViewModel({
    required this.repository,
    PtvRealtimeService? ptvService,
  }) : ptvService = ptvService ?? PtvRealtimeService() {
    _init();
  }

  Future<void> _init() async {
    _favoriteStations = await favoriteService.getFavorites();
    if (_favoriteStations.isNotEmpty) {
      _selectedStation = _favoriteStations.first;
    }
  }

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
  List<Station> get searchResults {
    if (_searchQuery.isEmpty) return [];
    final query = _searchQuery.toLowerCase();
    return stations.where((s) => s.name.toLowerCase().contains(query)).toList();
  }
  List<Station> get favoriteStations => _favoriteStations;
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
    loadData(station: _selectedStation);
  }

  void selectStation(Station station) {
    _selectedStation = station;
    notifyListeners();
    loadData(station: station);
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedTypeFilter = null;
    notifyListeners();
    loadData(station: _selectedStation);
  }

  void toggleFavoriteTrip(String tripId) {
    if (_favoriteTrips.contains(tripId)) {
      _favoriteTrips.remove(tripId);
    } else {
      _favoriteTrips.add(tripId);
    }
    notifyListeners();
  }

  bool isFavoriteTrip(String tripId) => _favoriteTrips.contains(tripId);

  Future<void> toggleFavoriteStation(Station station) async {
    if (_favoriteStations.any((s) => s.id == station.id)) {
      _favoriteStations.removeWhere((s) => s.id == station.id);
    } else {
      _favoriteStations.add(station);
    }
    await favoriteService.saveFavorites(_favoriteStations);
    notifyListeners();
  }

  bool isFavoriteStation(Station station) => _favoriteStations.any((s) => s.id == station.id);

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
          (departure?.routeName.toLowerCase().contains(query) ?? false);
      return matchesType && matchesQuery;
    }).toList();

    return filtered;
  }

  List<Trip> get displayedTrips {
    final filtered = filteredTrips;
    if (_selectedNavIndex == 1) {
      return filtered.where((t) => _favoriteTrips.contains(t.tripId)).toList();
    }
    return filtered;
  }

  Future<void> loadData({PtvMode? mode, Station? station}) async {
    final requestId = ++_loadRequestId;
    final modeToFetch = mode ?? selectedMode;
    _isLoading = true;
    _loadingProgress = 0.05;
    _loadingStatus = 'Loading Stations from GTFS...';
    _errorMessage = null;
    notifyListeners();

    void updateProgress(double progress, String status) {
      if (requestId == _loadRequestId && !_isDisposed) {
        _loadingProgress = progress;
        _loadingStatus = status;
        notifyListeners();
      }
    }

    try {
      // 1. Load GTFS Stations
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

      // 2. Load Realtime Departures from PTV API
      updateProgress(0.5, 'Fetching Live Departures from PTV API...');
      var fetchedAlerts = await ptvService.fetchLiveDisruptions();
      List<Trip> fetchedTrips = await ptvService.fetchDepartures(
        currentSelected.stopId,
        routeType: _selectedTypeFilter?.value ?? 0,
        maxResults: 15,
      );

      if (fetchedAlerts.isEmpty) {
        fetchedAlerts = await repository.getServiceAlerts();
      }

      if (requestId == _loadRequestId && !_isDisposed) {
        _trips = fetchedTrips;
        _alerts = fetchedAlerts;
        _stations = stationList;
        _selectedStation = currentSelected;
        _isLoading = false;
        _loadingProgress = 1.0;
        _loadingStatus = 'Complete';
        notifyListeners();
      }
    } catch (e) {
      if (requestId == _loadRequestId && !_isDisposed) {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
