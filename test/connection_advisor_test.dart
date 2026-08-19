import 'package:flutter_test/flutter_test.dart';
import 'package:transit_app/src/domain/entities/service.dart';
import 'package:transit_app/src/domain/entities/station.dart';
import 'package:transit_app/src/domain/entities/trips.dart';
import 'package:transit_app/src/domain/value_objects/transfer_feasibility.dart';
import 'package:transit_app/src/domain/value_objects/transit_type.dart';
import 'package:transit_app/src/services/connection_advisor_service.dart';
import 'package:transit_app/src/services/ptv_rt_service.dart';

class _MockPtvServiceForAdvisor extends PtvRealtimeService {
  final DateTime now;
  _MockPtvServiceForAdvisor(this.now);

  @override
  Future<List<Trip>> fetchDepartures(
    String stopId, {
    int routeType = 0,
    int maxResults = 30,
    Station? station,
  }) async {
    // Current train arrives at Richmond at now + 3 mins
    final richmondArrival = now.add(const Duration(minutes: 3));

    return [
      // 1 min buffer (tight)
      Trip(
        tripId: 'conn_belgrave',
        routeId: 'route_bel',
        serviceId: 'svc_1',
        headsign: 'Belgrave',
        departure: TripDeparture(
          scheduledTime: richmondArrival.add(const Duration(minutes: 1)),
          platform: '9',
          lineCode: 'BEL',
          routeName: 'Belgrave Line',
          destination: 'Belgrave',
          type: TransitType.metro,
        ),
      ),
      // 2 min buffer (possible)
      Trip(
        tripId: 'conn_lilydale',
        routeId: 'route_lil',
        serviceId: 'svc_1',
        headsign: 'Lilydale',
        departure: TripDeparture(
          scheduledTime: richmondArrival.add(const Duration(minutes: 2)),
          platform: '10',
          lineCode: 'LIL',
          routeName: 'Lilydale Line',
          destination: 'Lilydale',
          type: TransitType.metro,
        ),
      ),
      // 3 min buffer (easy)
      Trip(
        tripId: 'conn_glen_waverley',
        routeId: 'route_glw',
        serviceId: 'svc_1',
        headsign: 'Glen Waverley',
        departure: TripDeparture(
          scheduledTime: richmondArrival.add(const Duration(minutes: 3)),
          platform: '8',
          lineCode: 'GLW',
          routeName: 'Glen Waverley Line',
          destination: 'Glen Waverley',
          type: TransitType.metro,
        ),
      ),
      // 5 min buffer (guaranteed)
      Trip(
        tripId: 'conn_pakenham',
        routeId: 'route_pkm',
        serviceId: 'svc_1',
        headsign: 'Pakenham',
        departure: TripDeparture(
          scheduledTime: richmondArrival.add(const Duration(minutes: 5)),
          platform: '5',
          lineCode: 'PKM',
          routeName: 'Pakenham Line',
          destination: 'Pakenham',
          type: TransitType.metro,
        ),
      ),
    ];
  }
}

void main() {
  group('ConnectionAdvisorService Tests', () {
    const stationFlinders = Station(
      id: '1071',
      stopId: '1071',
      name: 'Flinders Street Station',
      code: 'FSS',
      lat: -37.8183,
      lon: 144.9671,
      suburb: 'CBD',
      zone: 'Zone 1',
      routes: [],
    );

    const stationRichmond = Station(
      id: '1162',
      stopId: '1162',
      name: 'Richmond Station',
      code: 'RMD',
      lat: -37.8240,
      lon: 144.9896,
      suburb: 'Richmond',
      zone: 'Zone 1',
      routes: [],
    );

    test('Computes connection feasibility at upcoming stops with correct levels', () async {
      final now = DateTime.now();
      final richmondArrival = now.add(const Duration(minutes: 3));
      final advisor = ConnectionAdvisorService(
        ptvService: _MockPtvServiceForAdvisor(now),
      );

      final activeTrip = Trip(
        tripId: 'active_frankston',
        routeId: 'route_fkn',
        serviceId: 'svc_01',
        headsign: 'Frankston',
        stops: [
          ServiceStop(
            station: stationFlinders,
            departureTime: now,
            platform: '1',
            stopSequence: 1,
          ),
          ServiceStop(
            station: stationRichmond,
            departureTime: richmondArrival,
            platform: '4',
            stopSequence: 2,
          ),
        ],
        departure: TripDeparture(
          scheduledTime: now,
          platform: '1',
          lineCode: 'FKN',
          routeName: 'Frankston Line',
          destination: 'Frankston',
          type: TransitType.metro,
        ),
      );

      final connectionsMap = await advisor.computeUpcomingConnections(
        activeTrip: activeTrip,
        currentOrNextStation: stationFlinders,
        allStations: [stationFlinders, stationRichmond],
      );

      expect(connectionsMap.containsKey('Richmond Station'), isTrue);
      final richmondConns = connectionsMap['Richmond Station']!;
      expect(richmondConns.length, equals(4));

      // 1 min -> tight
      final belgraveConn = richmondConns.firstWhere((c) => c.connectingTrip.headsign == 'Belgrave');
      expect(belgraveConn.feasibility, equals(TransferFeasibility.tight));
      expect(belgraveConn.platform, equals('9'));

      // 2 min -> possible
      final lilydaleConn = richmondConns.firstWhere((c) => c.connectingTrip.headsign == 'Lilydale');
      expect(lilydaleConn.feasibility, equals(TransferFeasibility.possible));

      // 3 min -> easy
      final glwConn = richmondConns.firstWhere((c) => c.connectingTrip.headsign == 'Glen Waverley');
      expect(glwConn.feasibility, equals(TransferFeasibility.easy));

      // 5 min -> guaranteed
      final pkmConn = richmondConns.firstWhere((c) => c.connectingTrip.headsign == 'Pakenham');
      expect(pkmConn.feasibility, equals(TransferFeasibility.guaranteed));
    });
  });
}
