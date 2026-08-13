import 'package:gtfs_bindings/schedule.dart' as gtfs;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transit_app/main.dart';
import 'package:transit_app/src/domain/entities/station.dart';
import 'package:transit_app/src/models/station.dart';
import 'package:transit_app/src/models/transit_route.dart';
import 'package:transit_app/src/models/trips.dart';
import 'package:transit_app/src/presentation/widgets/station_selector_card.dart';
import 'package:transit_app/src/services/gtfs_parser.dart';

class _EmptyGtfsRepository implements IGtfsRepository {
  @override
  Future<void> clearCache() async {}

  @override
  Future<gtfs.DirectoryDataset?> getDatasetForMode(
    PtvMode mode, {
    bool forceRefresh = false,
    GtfsProgressCallback? onProgress,
  }) async => null;

  @override
  Future<List<ServiceAlert>> getServiceAlerts() async => [
    ServiceAlert(
      id: 'alert_1',
      title: 'Belgrave Line Track Maintenance',
      description: 'Buses replace trains between Ringwood and Belgrave.',
      lineCode: 'BEL',
      timestamp: DateTime.now(),
      severity: ServiceStatus.disrupted,
    ),
  ];

  @override
  Future<List<Station>> getStopsForMode(
    PtvMode mode, {
    bool forceRefresh = false,
    GtfsProgressCallback? onProgress,
  }) async => [];

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

  testWidgets('Disruptions screen is reachable from bottom navigation tab', (tester) async {
    await tester.pumpWidget(TransitApp(repository: _EmptyGtfsRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Disruptions'));
    await tester.pumpAndSettle();

    expect(find.text('Network Disruptions'), findsOneWidget);
    expect(find.text('Belgrave Line Track Maintenance'), findsOneWidget);
  });

  testWidgets('Station selector handles empty station lists without asserting', (tester) async {
    const selectedStation = Station(
      id: 'vic:rail:STL',
      stopId: 'vic:rail:STL',
      name: 'Franklin St',
      code: 'vic:rail:STL',
      lat: 0,
      lon: 0,
      suburb: 'Melbourne',
      zone: 'Zone 1',
      routes: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StationSelectorCard(
            selectedStation: selectedStation,
            stations: const [],
            onStationSelected: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Franklin St'), findsOneWidget);
  });
}
