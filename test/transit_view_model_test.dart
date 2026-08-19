import 'package:flutter_test/flutter_test.dart';
import 'package:gtfs_bindings/schedule.dart' as gtfs;
import 'package:transit_app/src/data/repositories/gtfs_repository.dart';
import 'package:transit_app/src/domain/entities/station.dart';
import 'package:transit_app/src/domain/entities/trips.dart';
import 'package:transit_app/src/domain/entities/transit_route.dart';
import 'package:transit_app/src/presentation/state/transit_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transit_app/src/services/ptv_rt_service.dart';

class _MockRepository implements IGtfsRepository {
  @override
  Future<void> clearCache() async {}

  @override
  Future<gtfs.DirectoryDataset?> getDatasetForMode(
    PtvMode mode, {
    bool forceRefresh = false,
    GtfsProgressCallback? onProgress,
  }) async => null;

  @override
  Future<List<ServiceAlert>> getServiceAlerts() async => [];

  @override
  Future<List<Station>> getStopsForMode(
    PtvMode mode, {
    bool forceRefresh = false,
    GtfsProgressCallback? onProgress,
  }) async => [
    const Station(
      id: 'st_1',
      stopId: '101',
      name: 'Flinders Street',
      code: 'FSS',
      lat: 0.0,
      lon: 0.0,
      suburb: 'Melbourne',
      zone: 'Zone 1',
      routes: [],
    ),
  ];

  @override
  Future<List<Trip>> getTripsForMode(
    PtvMode mode, {
    Station? station,
    bool forceRefresh = false,
    GtfsProgressCallback? onProgress,
  }) async {
    onProgress?.call(1.0, 'Mock complete');
    return [
      Trip(
        tripId: 'trip_belgrave',
        routeId: 'route_bel',
        serviceId: 'svc_1',
        headsign: 'Belgrave',
        departure: TripDeparture(
          scheduledTime: DateTime.now().add(const Duration(minutes: 5)),
          platform: '1',
          lineCode: 'BEL',
          routeName: 'Belgrave Line',
          destination: 'Belgrave',
          type: TransitType.metro,
        ),
      ),
      Trip(
        tripId: 'trip_frankston',
        routeId: 'route_frk',
        serviceId: 'svc_1',
        headsign: 'Frankston',
        departure: TripDeparture(
          scheduledTime: DateTime.now().add(const Duration(minutes: 12)),
          platform: '2',
          lineCode: 'FRK',
          routeName: 'Frankston Line',
          destination: 'Frankston',
          type: TransitType.metro,
        ),
      ),
    ];
  }
}

class _MockPtvService extends PtvRealtimeService {
  @override
  Future<List<ServiceAlert>> fetchLiveDisruptions() async => [];

  @override
  Future<List<Trip>> fetchDepartures(String stopId, {int routeType = 0, int maxResults = 15, Station? station}) async {
    return [
      Trip(
        tripId: 'trip_belgrave',
        routeId: 'route_bel',
        serviceId: 'svc_1',
        headsign: 'Belgrave',
        departure: TripDeparture(
          scheduledTime: DateTime.now().add(const Duration(minutes: 5)),
          platform: '1',
          lineCode: 'BEL',
          routeName: 'Belgrave Line',
          destination: 'Belgrave',
          type: TransitType.metro,
        ),
      ),
      Trip(
        tripId: 'trip_frankston',
        routeId: 'route_frk',
        serviceId: 'svc_1',
        headsign: 'Frankston',
        departure: TripDeparture(
          scheduledTime: DateTime.now().add(const Duration(minutes: 12)),
          platform: '2',
          lineCode: 'FRK',
          routeName: 'Frankston Line',
          destination: 'Frankston',
          type: TransitType.metro,
        ),
      ),
    ];
  }
}

void main() {
  group('TransitViewModel Tests', () {
    late TransitViewModel viewModel;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      viewModel = TransitViewModel(
        repository: _MockRepository(),
        ptvService: _MockPtvService(),
      );
    });

    test('Initializes with default state and loads trips with percentage progress', () async {
      expect(viewModel.isLoading, isTrue);
      await viewModel.loadData();
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.loadingProgress, equals(1.0));
      expect(viewModel.loadingPercentage, equals(100));
      expect(viewModel.trips.length, equals(2));
      expect(viewModel.filteredTrips.length, equals(2));
    });

    test('Filters trips by search query', () async {
      await viewModel.loadData();

      viewModel.updateSearchQuery('Belgrave');
      expect(viewModel.filteredTrips.length, equals(1));
      expect(viewModel.filteredTrips.single.headsign, equals('Belgrave'));

      viewModel.updateSearchQuery('Frankston');
      expect(viewModel.filteredTrips.length, equals(1));
      expect(viewModel.filteredTrips.single.headsign, equals('Frankston'));

      viewModel.updateSearchQuery('');
      expect(viewModel.filteredTrips.length, equals(2));
    });

    test('Manages favorite trips state', () async {
      await viewModel.loadData();

      expect(viewModel.isFavoriteTrip('trip_belgrave'), isFalse);
      await viewModel.toggleFavoriteTrip('trip_belgrave');
      expect(viewModel.isFavoriteTrip('trip_belgrave'), isTrue);

      viewModel.selectNavIndex(1); // Saved view
      expect(viewModel.displayedTrips.length, equals(1));
      expect(viewModel.displayedTrips.single.tripId, equals('trip_belgrave'));
    });

    test('Manages favorite stations state', () async {
      const station = Station(
        id: 'st_richmond',
        stopId: '19845',
        name: 'Richmond Station',
        code: 'RMD',
        lat: -37.8240,
        lon: 144.9896,
        suburb: 'Richmond',
        zone: 'Zone 1',
        routes: [],
      );

      expect(viewModel.isFavoriteStation(station), isFalse);
      await viewModel.toggleFavoriteStation(station);
      expect(viewModel.isFavoriteStation(station), isTrue);
      expect(viewModel.favoriteStations.length, equals(1));

      await viewModel.toggleFavoriteStation(station);
      expect(viewModel.isFavoriteStation(station), isFalse);
      expect(viewModel.favoriteStations.isEmpty, isTrue);
    });

    test('Filters by transit mode correctly', () async {
      await viewModel.loadData();

      viewModel.selectModeFilter(TransitType.metro);
      expect(viewModel.selectedTypeFilter, equals(TransitType.metro));
      expect(viewModel.selectedMode, equals(PtvMode.metroTrain));

      viewModel.selectModeFilter(TransitType.tram);
      expect(viewModel.selectedTypeFilter, equals(TransitType.tram));
      expect(viewModel.selectedMode, equals(PtvMode.metroTrain));

      viewModel.resetFilters();
      expect(viewModel.selectedTypeFilter, isNull);
      expect(viewModel.selectedMode, equals(PtvMode.metroTrain));
    });
  });
}
