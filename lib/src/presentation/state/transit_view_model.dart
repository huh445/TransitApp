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
  Set<String> _favoriteTrips = {};

  bool _isLoading = true;
  double _loadingProgress = 0.0;
  String _loadingStatus = 'Initializing...';
  String? _errorMessage;
  int _loadRequestId = 0;
  late final Future<void> initFuture;

  TransitViewModel({
    required this.repository,
    PtvRealtimeService? ptvService,
  }) : ptvService = ptvService ?? PtvRealtimeService() {
    initFuture = _init();
  }

  Future<void> _init() async {
    final favs = await favoriteService.getFavorites();
    final trips = await favoriteService.getFavoriteTrips();
    if (_favoriteStations.isEmpty && favs.isNotEmpty) {
      _favoriteStations = favs;
      _selectedStation = _favoriteStations.first;
    }
    if (_favoriteTrips.isEmpty && trips.isNotEmpty) {
      _favoriteTrips = trips;
    }
    notifyListeners();
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

  /// Disruptions filtered strictly to favorited stations (or current station if no favorites yet).
  List<ServiceAlert> get favoriteStationDisruptions {
    if (_favoriteStations.isEmpty) {
      final stName = _selectedStation.name.toLowerCase().replaceAll(' station', '').trim();
      return _alerts.where((alert) {
        final title = alert.title.toLowerCase();
        final desc = alert.description.toLowerCase();
        final line = alert.lineCode.toLowerCase();
        return title.contains(stName) || desc.contains(stName) || line.contains(stName);
      }).toList();
    }

    return _alerts.where((alert) {
      final title = alert.title.toLowerCase();
      final desc = alert.description.toLowerCase();
      final line = alert.lineCode.toLowerCase();

      return _favoriteStations.any((fav) {
        final favName = fav.name.toLowerCase().replaceAll(' station', '').trim();
        return title.contains(favName) || desc.contains(favName) || line.contains(favName);
      });
    }).toList();
  }

  List<Station> get stations =>
      _stations.isNotEmpty ? _stations : MelbourneGtfsService.melbourneHubStations;
  List<Station> get favoriteStations => _favoriteStations;
  Set<String> get favoriteTrips => _favoriteTrips;
  bool get isLoading => _isLoading;
  double get loadingProgress => _loadingProgress;
  String get loadingStatus => _loadingStatus;
  int get loadingPercentage => (_loadingProgress * 100).clamp(0, 100).toInt();
  String? get errorMessage => _errorMessage;

  List<Station> get searchResults {
    if (_searchQuery.isEmpty) return [];
    final query = _searchQuery.toLowerCase();
    return stations.where((s) => s.name.toLowerCase().contains(query)).toList();
  }

  PtvMode get selectedMode => PtvMode.metroTrain;

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

  Future<void> toggleFavoriteTrip(String tripId) async {
    await initFuture;
    if (_favoriteTrips.contains(tripId)) {
      _favoriteTrips.remove(tripId);
    } else {
      _favoriteTrips.add(tripId);
    }
    await favoriteService.saveFavoriteTrips(_favoriteTrips);
    notifyListeners();
  }

  bool isFavoriteTrip(String tripId) => _favoriteTrips.contains(tripId);

  Future<void> toggleFavoriteStation(Station station) async {
    await initFuture;
    if (_favoriteStations.any((s) => s.id == station.id || s.name == station.name)) {
      _favoriteStations.removeWhere((s) => s.id == station.id || s.name == station.name);
    } else {
      _favoriteStations.add(station);
    }
    await favoriteService.saveFavorites(_favoriteStations);
    notifyListeners();
  }

  bool isFavoriteStation(Station station) =>
      _favoriteStations.any((s) => s.id == station.id || s.name == station.name);

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
    _isLoading = true;
    _loadingProgress = 0.05;
    _loadingStatus = 'Downloading Metro Suburban Timetable: 5%';
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
      // 1. Load Metro Suburban GTFS Stations (Mode 2)
      final dynamicStops = await repository.getStopsForMode(
        PtvMode.metroTrain,
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
        orElse: () => stationList.isNotEmpty
            ? stationList.first
            : requestedStation,
      );

      // 2. Load Scheduled Trips from GTFS (Metro Suburban Rail)
      updateProgress(0.50, 'Parsing Suburban Timetables: 50%');
      final scheduledTrips = await repository.getTripsForMode(
        PtvMode.metroTrain,
        station: currentSelected,
        onProgress: updateProgress,
      );

      // 3. Load Real-time Departures (Next 1 hour window) and Disruptions from PTV API
      updateProgress(0.80, 'Fetching Live Realtime Departures: 80%');
      var fetchedAlerts = await ptvService.fetchLiveDisruptions();
      if (fetchedAlerts.isEmpty) {
        fetchedAlerts = await repository.getServiceAlerts();
      }

      List<Trip> livePtvTrips = [];
      try {
        livePtvTrips = await ptvService.fetchDepartures(
          currentSelected.stopId,
          station: currentSelected,
          routeType: 0, // Metro Train route type
          maxResults: 30,
        );
      } catch (_) {
        // Fallback to scheduled
      }

      final now = DateTime.now();
      final oneHourFromNow = now.add(const Duration(hours: 1));

      List<Trip> mergedTrips = [];
      if (livePtvTrips.isNotEmpty) {
        // Enhance live trips with stop sequences from scheduled dataset if available
        final scheduledByHeadsign = <String, Trip>{};
        for (final st in scheduledTrips) {
          scheduledByHeadsign[st.headsign.toLowerCase()] = st;
          scheduledByHeadsign[st.destination.toLowerCase()] = st;
        }

        mergedTrips = livePtvTrips.map((liveTrip) {
          final destKey = liveTrip.destinationName.toLowerCase();
          final match = scheduledByHeadsign[destKey];
          if (match != null && match.stops.isNotEmpty && liveTrip.stops.isEmpty) {
            return liveTrip.copyWith(stops: match.stops);
          }
          return liveTrip;
        }).toList();
      } else {
        // Filter scheduled trips within 1-hour window
        mergedTrips = scheduledTrips.where((t) {
          final sched = t.departure?.scheduledTime;
          if (sched == null) return false;
          return sched.isAfter(now.subtract(const Duration(minutes: 2))) &&
                 sched.isBefore(oneHourFromNow);
        }).toList();
      }

      // Sort by line (e.g. Mernda, Frankston, Belgrave, Lilydale) and departure time
      mergedTrips.sort((a, b) {
        final aLine = a.departure?.lineCode.isNotEmpty == true
            ? a.departure!.lineCode
            : a.destinationName;
        final bLine = b.departure?.lineCode.isNotEmpty == true
            ? b.departure!.lineCode
            : b.destinationName;
        final lineComparison = aLine.toLowerCase().compareTo(bLine.toLowerCase());
        if (lineComparison != 0) return lineComparison;

        final aTime = a.departure?.scheduledTime ?? now;
        final bTime = b.departure?.scheduledTime ?? now;
        return aTime.compareTo(bTime);
      });

      if (requestId == _loadRequestId && !_isDisposed) {
        _trips = mergedTrips;
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
        _errorMessage = 'Unable to refresh departures. Please check connection.';
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
