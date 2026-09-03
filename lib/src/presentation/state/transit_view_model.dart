import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/live_connection.dart';
import '../../domain/entities/station.dart';
import '../../domain/entities/trips.dart';
import '../../domain/entities/transit_route.dart';
import '../../data/repositories/gtfs_repository.dart';
import '../../services/location_service.dart';
import '../../services/connection_advisor_service.dart';
import '../../services/melbourne_gtfs_service.dart';
import '../../services/ptv_rt_service.dart';
import '../../services/favorite_service.dart';

class TransitViewModel extends ChangeNotifier {
  final IGtfsRepository repository;
  final PtvRealtimeService ptvService;
  final FavoriteService favoriteService = FavoriteService();
  final LocationService locationService;
  late final ConnectionAdvisorService connectionAdvisor;
  bool _isDisposed = false;

  int _selectedNavIndex = 0;
  TransitType? _selectedTypeFilter;
  String _searchQuery = '';
  Station _selectedStation = MelbourneGtfsService.defaultStation;

  List<Trip> _trips = [];
  List<ServiceAlert> _alerts = [];
  List<Station> _stations = [MelbourneGtfsService.defaultStation];
  List<Station> _favoriteStations = [];
  List<Station> _recentStations = [];
  Set<String> _favoriteTrips = {};

  Position? _userPosition;
  bool _isLocating = false;

  // Active On-Board Ride Tracking & Connection Advisory State
  Trip? _activeTrackedTrip;
  Station? _onBoardStation;
  Station? _previousStopStation;
  Station? _nextStopStation;
  bool _isTrackingActive = false;
  bool _isLoadingConnections = false;
  Map<String, List<LiveConnection>> _upcomingConnections = {};

  bool _isLoading = true;
  double _loadingProgress = 0.0;
  String _loadingStatus = 'Initializing...';
  String? _errorMessage;
  int _loadRequestId = 0;
  late final Future<void> initFuture;

  TransitViewModel({
    required this.repository,
    PtvRealtimeService? ptvService,
    LocationService? locationService,
    ConnectionAdvisorService? connectionAdvisor,
  })  : ptvService = ptvService ?? PtvRealtimeService(),
        locationService = locationService ?? LocationService(),
        connectionAdvisor = connectionAdvisor ??
            ConnectionAdvisorService(
              ptvService: ptvService ?? PtvRealtimeService(),
              repository: repository,
            ) {
    initFuture = _init();
  }

  Future<void> _init() async {
    final favs = await favoriteService.getFavorites();
    final trips = await favoriteService.getFavoriteTrips();
    final recents = await favoriteService.getRecentStations();
    if (_favoriteStations.isEmpty && favs.isNotEmpty) {
      _favoriteStations = favs;
      _selectedStation = _favoriteStations.first;
    }
    if (_favoriteTrips.isEmpty && trips.isNotEmpty) {
      _favoriteTrips = trips;
    }
    if (recents.isNotEmpty) {
      _recentStations = recents;
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

  List<Station> get stations => _stations;
  List<Station> get favoriteStations => _favoriteStations;
  List<Station> get recentStations => _recentStations;
  Set<String> get favoriteTrips => _favoriteTrips;
  Position? get userPosition => _userPosition;
  bool get isLocating => _isLocating;
  bool get isLoading => _isLoading;
  double get loadingProgress => _loadingProgress;
  String get loadingStatus => _loadingStatus;
  int get loadingPercentage => (_loadingProgress * 100).clamp(0, 100).toInt();
  String? get errorMessage => _errorMessage;

  // Active Live Ride Tracking & Connections
  Trip? get activeTrackedTrip => _activeTrackedTrip;
  Station? get onBoardStation => _onBoardStation;
  Station? get currentStopStation => _onBoardStation;
  Station? get previousStopStation => _previousStopStation;
  Station? get nextStopStation => _nextStopStation;
  bool get isTrackingActive => _isTrackingActive;
  bool get isLoadingConnections => _isLoadingConnections;
  Map<String, List<LiveConnection>> get upcomingConnections => _upcomingConnections;

  Future<void> startTrackingTrip(Trip trip, {Station? initialStation}) async {
    Trip activeTrip = trip;

    // Automatically fetch real-time intermediate stops from PTV API if empty
    if (activeTrip.stops.isEmpty && activeTrip.tripId.isNotEmpty) {
      try {
        final patternStops = await ptvService.fetchPatternStops(
          activeTrip.tripId,
          routeType: activeTrip.departure?.type.value ?? 0,
        );
        if (patternStops.isNotEmpty) {
          activeTrip = activeTrip.copyWith(stops: patternStops);
        }
      } catch (_) {}
    }

    _activeTrackedTrip = activeTrip;
    _isTrackingActive = true;

    final currentSt = initialStation ?? _selectedStation;
    _onBoardStation = currentSt;

    final stops = activeTrip.stops;
    if (stops.isNotEmpty) {
      final curIdx = stops.indexWhere((s) {
        final sName = s.station.name.toLowerCase();
        final cName = currentSt.name.toLowerCase();
        return sName == cName ||
            sName.contains(cName) ||
            cName.contains(sName) ||
            (currentSt.id.isNotEmpty && s.station.id == currentSt.id) ||
            (currentSt.stopId.isNotEmpty && s.station.stopId == currentSt.stopId);
      });
      if (curIdx != -1) {
        _onBoardStation = stops[curIdx].station;
        _previousStopStation = curIdx > 0 ? stops[curIdx - 1].station : null;
        _nextStopStation = curIdx + 1 < stops.length ? stops[curIdx + 1].station : null;
      } else {
        _previousStopStation = null;
        _nextStopStation = stops.length > 1 ? stops[1].station : null;
      }
    } else {
      _previousStopStation = null;
      _nextStopStation = null;
    }

    notifyListeners();

    await locationService.startLocationTracking(
      onPositionChanged: handlePositionUpdate,
    );

    await refreshUpcomingConnections();
  }

  void stopTracking() {
    _activeTrackedTrip = null;
    _isTrackingActive = false;
    _onBoardStation = null;
    _previousStopStation = null;
    _nextStopStation = null;
    _upcomingConnections = {};
    locationService.stopLocationTracking();
    notifyListeners();
  }

  Future<void> refreshUpcomingConnections() async {
    if (_activeTrackedTrip == null) return;
    _isLoadingConnections = true;
    notifyListeners();

    try {
      final connections = await connectionAdvisor.computeUpcomingConnections(
        activeTrip: _activeTrackedTrip!,
        currentOrNextStation: _nextStopStation ?? _onBoardStation ?? _selectedStation,
        allStations: _stations,
      );
      _upcomingConnections = connections;
    } catch (_) {
      // Keep existing
    } finally {
      _isLoadingConnections = false;
      notifyListeners();
    }
  }

  void handlePositionUpdate(Position position) {
    if (!_isTrackingActive || _activeTrackedTrip == null) return;

    final closestStation = LocationService.findClosestStation(
      position.latitude,
      position.longitude,
      _stations,
      maxDistanceMeters: 1500,
    );

    if (closestStation != null) {
      final stops = _activeTrackedTrip!.stops;
      final curIdx = stops.indexWhere((s) {
        final sName = s.station.name.toLowerCase();
        final cName = closestStation.name.toLowerCase();
        return sName == cName ||
            sName.contains(cName) ||
            cName.contains(sName) ||
            (closestStation.id.isNotEmpty && s.station.id == closestStation.id) ||
            (closestStation.stopId.isNotEmpty && s.station.stopId == closestStation.stopId);
      });

      if (curIdx != -1) {
        _onBoardStation = stops[curIdx].station;
        _previousStopStation = curIdx > 0 ? stops[curIdx - 1].station : null;
        _nextStopStation = curIdx + 1 < stops.length ? stops[curIdx + 1].station : null;
      } else {
        _onBoardStation = closestStation;
      }
      notifyListeners();
    }
  }

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
    _saveRecent(station);
    notifyListeners();
    loadData(station: station);
  }

  /// Fetches departures for a given interchange [station] **without** changing
  /// the currently tracked trip or selected station. Used by LiveRideSheet to
  /// peek at departures at a connecting station while the on-board ride stays active.
  Future<List<Trip>> fetchTripsForStation(Station station) async {
    try {
      final livePtvTrips = await ptvService.fetchDepartures(
        station.stopId,
        station: station,
        routeType: 0,
        maxResults: 20,
      );
      if (livePtvTrips.isNotEmpty) return livePtvTrips;

      // Fallback: GTFS static timetable
      final scheduled = await repository.getTripsForMode(
        PtvMode.metroTrain,
        station: station,
      );
      final now = DateTime.now();
      return scheduled.where((t) {
        final sched = t.departure?.scheduledTime;
        if (sched == null) return false;
        return sched.isAfter(now.subtract(const Duration(minutes: 2))) &&
               sched.isBefore(now.add(const Duration(hours: 1)));
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveRecent(Station station) async {
    try {
      final updated = await favoriteService.saveRecentStation(station);
      _recentStations = updated;
      notifyListeners();
    } catch (_) {}
  }

  /// Locates the device GPS coordinates and selects the closest Melbourne station.
  Future<Station?> locateNearestStation() async {
    _isLocating = true;
    notifyListeners();
    try {
      final pos = await locationService.getCurrentPosition();
      if (pos != null) {
        _userPosition = pos;
        final nearest = LocationService.findClosestStation(
          pos.latitude,
          pos.longitude,
          _stations,
          maxDistanceMeters: 100000,
        );
        if (nearest != null) {
          selectStation(nearest);
          return nearest;
        }
      }
    } catch (_) {
    } finally {
      _isLocating = false;
      notifyListeners();
    }
    return null;
  }

  /// Refreshes the user's current GPS position.
  Future<void> refreshUserLocation() async {
    try {
      final pos = await locationService.getCurrentPosition();
      if (pos != null) {
        _userPosition = pos;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Checks if any current active service alert matches this trip's line, destination, or route.
  bool hasDisruptionForTrip(Trip trip) {
    if (_alerts.isEmpty) return false;
    final departure = trip.departure;
    final lineCode = (departure?.lineCode ?? trip.shortName ?? trip.routeId).toLowerCase().trim();
    final routeName = (departure?.routeName ?? '').toLowerCase().trim();
    final dest = trip.destinationName.toLowerCase().trim();

    return _alerts.any((alert) {
      final aLine = alert.lineCode.toLowerCase().trim();
      final aTitle = alert.title.toLowerCase().trim();
      final aDesc = alert.description.toLowerCase().trim();

      if (lineCode.isNotEmpty && (aLine.contains(lineCode) || lineCode.contains(aLine))) {
        return true;
      }
      if (routeName.isNotEmpty &&
          (aTitle.contains(routeName) || aDesc.contains(routeName) || aLine.contains(routeName))) {
        return true;
      }
      if (dest.isNotEmpty &&
          (aTitle.contains(dest) || aDesc.contains(dest))) {
        return true;
      }
      return false;
    });
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
      // 1. Load Metro Suburban GTFS Stations from stops.txt
      final dynamicStops = await repository.getStopsForMode(
        PtvMode.metroTrain,
        onProgress: updateProgress,
      );

      final stationList = dynamicStops.isNotEmpty
          ? dynamicStops
          : [MelbourneGtfsService.defaultStation];

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

      // Immediately register the full station list so station selector/search is populated
      if (requestId == _loadRequestId && !_isDisposed) {
        _stations = stationList;
        _selectedStation = currentSelected;
        notifyListeners();
      }

      // 2. Fetch Live Realtime Departures (Next 1 hour window) and Disruptions directly from PTV API
      updateProgress(0.60, 'Fetching Live Realtime Departures: 60%');
      var fetchedAlerts = <ServiceAlert>[];
      try {
        fetchedAlerts = await ptvService.fetchLiveDisruptions();
      } catch (_) {}
      if (fetchedAlerts.isEmpty) {
        try {
          fetchedAlerts = await repository.getServiceAlerts();
        } catch (_) {}
      }

      List<Trip> livePtvTrips = [];
      try {
        livePtvTrips = await ptvService.fetchDepartures(
          currentSelected.stopId,
          station: currentSelected,
          routeType: 0, // Metro Train route type
          maxResults: 30,
        );
      } catch (_) {}

      final now = DateTime.now();
      final oneHourFromNow = now.add(const Duration(hours: 1));

      List<Trip> mergedTrips = [];
      if (livePtvTrips.isNotEmpty) {
        mergedTrips = livePtvTrips;
      } else {
        // Fallback to static GTFS scheduled trips only if live PTV API returned empty
        updateProgress(0.85, 'Loading Scheduled Timetable Fallback...');
        try {
          final scheduledTrips = await repository.getTripsForMode(
            PtvMode.metroTrain,
            station: currentSelected,
            onProgress: updateProgress,
          );
          mergedTrips = scheduledTrips.where((t) {
            final sched = t.departure?.scheduledTime;
            if (sched == null) return false;
            return sched.isAfter(now.subtract(const Duration(minutes: 2))) &&
                   sched.isBefore(oneHourFromNow);
          }).toList();
        } catch (_) {}
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
        _errorMessage = e is GtfsNetworkException
            ? e.message
            : 'Unable to refresh departures. Please check connection.';
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
