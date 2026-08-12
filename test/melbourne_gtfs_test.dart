import 'package:flutter_test/flutter_test.dart';
import 'package:transit_app/src/models/transit_route.dart';
import 'package:transit_app/src/services/melbourne_gtfs_service.dart';

void main() {
  group('Melbourne GTFS Infrastructure Tests', () {
    test('Resolves PTV GTFS route types to domain modes correctly', () {
      expect(TransitRoute.fromGtfsRouteType(0), equals(TransitType.tram));
      expect(TransitRoute.fromGtfsRouteType(1), equals(TransitType.metro));
      expect(TransitRoute.fromGtfsRouteType(2), equals(TransitType.regionalTrain));
      expect(TransitRoute.fromGtfsRouteType(3), equals(TransitType.bus));
      expect(TransitRoute.fromGtfsRouteType(4), equals(TransitType.ferry));
    });

    test('Provides official PTV brand colors for modes', () {
      expect(
        TransitRoute.ptvBrandColor(TransitType.metro),
        equals(PtvColors.metroTrain),
      );
      expect(
        TransitRoute.ptvBrandColor(TransitType.tram),
        equals(PtvColors.yarraTram),
      );
      expect(
        TransitRoute.ptvBrandColor(TransitType.regionalTrain),
        equals(PtvColors.vlinePurple),
      );
    });

    test('Loads Melbourne hub stations including City Loop stations', () {
      final hubs = MelbourneGtfsService.melbourneHubStations;
      expect(hubs.isNotEmpty, isTrue);

      final flinders = hubs.firstWhere((s) => s.code == 'FSS');
      expect(flinders.name, equals('Flinders Street Station'));
      expect(flinders.isCityLoop, isTrue);
      expect(flinders.zone, equals('Zone 1'));
    });

    test('Returns active Melbourne network routes and alerts', () {
      final routes = MelbourneGtfsService.getMelbourneRoutes();
      final alerts = MelbourneGtfsService.getMelbourneAlerts();

      expect(routes.length, greaterThanOrEqualTo(5));
      expect(alerts.isNotEmpty, isTrue);

      final metroRoute = routes.firstWhere((r) => r.type == TransitType.metro);
      expect(metroRoute.lineCode, contains('BEL'));
    });

    test('Calculates Melbourne GTFS Belgrave service duration', () {
      final service = MelbourneGtfsService.getBelgraveExpressService();

      expect(service.originStation.name, equals('Flinders Street Station'));
      expect(service.destinationStation.name, equals('Southern Cross Station'));
      expect(service.stops.length, equals(2));
      expect(service.totalDuration, equals(const Duration(minutes: 4)));
    });
  });
}
