import 'package:gtfs_bindings/schedule.dart' as gtfs;
import 'package:flutter_test/flutter_test.dart';
import 'package:transit_app/main.dart';
import 'package:transit_app/src/models/station.dart';
import 'package:transit_app/src/models/transit_route.dart';
import 'package:transit_app/src/models/trips.dart';
import 'package:transit_app/src/services/gtfs_parser.dart';

class _EmptyGtfsRepository implements IGtfsRepository {
  @override
  Future<void> clearCache() async {}

  @override
  Future<gtfs.DirectoryDataset?> getDatasetForMode(
    PtvMode mode, {
    bool forceRefresh = false,
  }) async => null;

  @override
  Future<List<ServiceAlert>> getServiceAlerts() async => [];

  @override
  Future<List<Station>> getStopsForMode(
    PtvMode mode, {
    bool forceRefresh = false,
  }) async => [];

  @override
  Future<List<Trip>> getTripsForMode(
    PtvMode mode, {
    Station? station,
    bool forceRefresh = false,
  }) async => [
    Trip(
      tripId: 'test-trip',
      routeId: 'test-route',
      serviceId: 'test-service',
      headsign: 'Test destination',
      departure: TripDeparture(
        scheduledTime: DateTime.now().add(const Duration(minutes: 10)),
        platform: '1',
        lineCode: 'T1',
        routeName: 'Test line',
        type: TransitType.metro,
      ),
    ),
  ];
}

void main() {
  testWidgets('TransitApp loads Melbourne Transit title and departures', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(TransitApp(repository: _EmptyGtfsRepository()));

    expect(find.text('Melbourne Transit'), findsOneWidget);
    expect(find.textContaining('Scheduled Departures'), findsOneWidget);
  });

  testWidgets('Saved departures are reachable from navigation', (tester) async {
    await tester.pumpWidget(TransitApp(repository: _EmptyGtfsRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save this departure'));
    await tester.pump();
    await tester.tap(find.text('Saved'));
    await tester.pump();

    expect(find.text('Saved Departures'), findsOneWidget);
    expect(find.text('Test destination'), findsOneWidget);
  });
}
