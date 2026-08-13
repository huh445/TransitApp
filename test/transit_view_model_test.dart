import 'package:flutter_test/flutter_test.dart';
import 'package:gtfs_bindings/schedule.dart' as gtfs;
import 'package:transit_app/src/data/repositories/gtfs_repository.dart';
import 'package:transit_app/src/domain/entities/station.dart';
import 'package:transit_app/src/domain/entities/trips.dart';
import 'package:transit_app/src/domain/entities/transit_route.dart';
import 'package:transit_app/src/presentation/state/transit_view_model.dart';

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

void main() {
  group('TransitViewModel Tests', () {
    late TransitViewModel viewModel;

    setUp(() {
      viewModel = TransitViewModel(repository: _MockRepository());
    });

    test('Initializes with default state and loads trips with percentage progress', () async {
      expect(viewModel.isLoading, isTrue);
      await viewModel.loadMelbourneData();
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.loadingProgress, equals(1.0));
      expect(viewModel.loadingPercentage, equals(100));
      expect(viewModel.trips.length, equals(2));
      expect(viewModel.filteredTrips.length, equals(2));
    });

    test('Filters trips by search query', () async {
      await viewModel.loadMelbourneData();

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
      await viewModel.loadMelbourneData();

      expect(viewModel.isFavorite('trip_belgrave'), isFalse);
      viewModel.toggleFavorite('trip_belgrave');
      expect(viewModel.isFavorite('trip_belgrave'), isTrue);

      viewModel.selectNavIndex(1); // Saved view
      expect(viewModel.displayedTrips.length, equals(1));
      expect(viewModel.displayedTrips.single.tripId, equals('trip_belgrave'));
    });
  });
}
