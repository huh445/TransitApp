import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:transit_app/src/data/datasources/gtfs_index_engine.dart';
import 'package:transit_app/src/domain/entities/transit_route.dart';

import 'package:transit_app/src/services/gtfs_parser.dart';
import 'package:transit_app/src/services/melbourne_gtfs_service.dart';

void main() {
  group('Melbourne GTFS Infrastructure Tests', () {
    test('Normalizes station names cleanly without raw railway station noise', () {
      expect(
        GtfsIndexEngine.normalizeStationName('Flinders Street Railway Station (Melbourne)'),
        equals('Flinders Street Station'),
      );
      expect(
        GtfsIndexEngine.normalizeStationName('Richmond Railway Station/Platform 1'),
        equals('Richmond Station'),
      );
      expect(
        GtfsIndexEngine.normalizeStationName('Southern Cross Railway Station'),
        equals('Southern Cross Station'),
      );
    });

    test('Filters out replacement bus stops from station index', () {
      expect(GtfsIndexEngine.isReplacementBusStop('Bus Replacement Stop'), isTrue);
      expect(GtfsIndexEngine.isReplacementBusStop('Temp Bus Stop'), isTrue);
      expect(GtfsIndexEngine.isReplacementBusStop('Flinders Street Station'), isFalse);
      expect(GtfsIndexEngine.isReplacementBusStop('Southern Cross Station'), isFalse);
    });

    test('Resolves PTV GTFS route types to domain modes correctly', () {
      expect(TransitRoute.fromGtfsRouteType(0), equals(TransitType.tram));
      expect(TransitRoute.fromGtfsRouteType(1), equals(TransitType.metro));
      expect(
        TransitRoute.fromGtfsRouteType(2),
        equals(TransitType.regionalTrain),
      );
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

    test(
      'Parses GTFS data into Trip objects from routes, trips, and stop_times',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('gtfs_test_');
        final now = DateTime.now();
        final firstDeparture = _gtfsTime(now.hour * 60 + now.minute + 5);
        final secondDeparture = _gtfsTime(now.hour * 60 + now.minute + 12);

        File('${tempDir.path}/routes.txt').writeAsStringSync(
          'route_id,agency_id,route_short_name,route_long_name,route_type\n'
          '2-BEL-F-mjp-1,2,BEL,Belgrave Line,1\n'
          '3-096-mjp-1,3,96,East Brunswick to St Kilda,0\n',
        );

        File('${tempDir.path}/trips.txt').writeAsStringSync(
          'route_id,service_id,trip_id,trip_headsign,direction_id\n'
          '2-BEL-F-mjp-1,weekday,trip_bel_1,Belgrave,0\n'
          '3-096-mjp-1,weekday,trip_96_1,St Kilda Beach,1\n',
        );

        File('${tempDir.path}/stop_times.txt').writeAsStringSync(
          'trip_id,arrival_time,departure_time,stop_id,stop_sequence\n'
          'trip_bel_1,$firstDeparture,$firstDeparture,19842,1\n'
          'trip_96_1,$secondDeparture,$secondDeparture,19842,1\n',
        );

        final trips = await PtvGtfsRepository.parseTripsFromDirectory(tempDir);

        expect(trips.length, equals(2));

        final headsigns = trips.map((t) => t.headsign).toSet();
        expect(headsigns, contains('Belgrave'));
        expect(headsigns, contains('St Kilda Beach'));

        final belgrave = trips.firstWhere((t) => t.headsign == 'Belgrave');
        expect(belgrave.routeId, equals('2-BEL-F-mjp-1'));

        final stKilda = trips.firstWhere((t) => t.headsign == 'St Kilda Beach');
        expect(stKilda.routeId, equals('3-096-mjp-1'));

        tempDir.deleteSync(recursive: true);
      },
    );

    test(
      'Generates departures successfully across at least 30 distinct Melbourne stations',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('gtfs_30_stations_');
        addTearDown(() => tempDir.delete(recursive: true));

        final now = DateTime.now();
        final date = _gtfsDate(now);
        final depTime = _gtfsTime(now.hour * 60 + now.minute + 15);

        final stations = const [
          'Flinders Street', 'Southern Cross', 'Melbourne Central', 'Parliament', 'Flagstaff',
          'Richmond', 'South Yarra', 'Caulfield', 'Footscray', 'Box Hill',
          'Dandenong', 'Frankston', 'Belgrave', 'Lilydale', 'Glen Waverley',
          'Ringwood', 'Camberwell', 'Essendon', 'Broadmeadows', 'Watergardens',
          'Sunbury', 'Werribee', 'Williamstown', 'Sandringham', 'Moorabbin',
          'Cheltenham', 'Mentone', 'Mordialloc', 'Geelong', 'Ballarat',
          'Bendigo', 'Traralgon',
        ];

        expect(stations.length, greaterThanOrEqualTo(30));

        final stopsBuffer = StringBuffer('stop_id,stop_name,stop_lat,stop_lon\n');
        final tripsBuffer = StringBuffer('route_id,service_id,trip_id,trip_headsign\n');
        final stopTimesBuffer = StringBuffer('trip_id,arrival_time,departure_time,stop_id,stop_sequence\n');

        File('${tempDir.path}/routes.txt').writeAsStringSync(
          'route_id,route_short_name,route_long_name,route_type\n'
          'route_metro,METRO,Melbourne Metro Line,1\n',
        );

        for (int i = 0; i < stations.length; i++) {
          final stopId = '${1000 + i}';
          final name = stations[i];
          stopsBuffer.writeln('$stopId,"$name Station",-37.8,144.9');

          final tripId = 'trip_$stopId';
          tripsBuffer.writeln('route_metro,weekday,$tripId,$name');
          stopTimesBuffer.writeln('$tripId,$depTime,$depTime,$stopId,1');
        }

        File('${tempDir.path}/stops.txt').writeAsStringSync(stopsBuffer.toString());
        File('${tempDir.path}/trips.txt').writeAsStringSync(tripsBuffer.toString());
        File('${tempDir.path}/stop_times.txt').writeAsStringSync(stopTimesBuffer.toString());
        File('${tempDir.path}/calendar.txt').writeAsStringSync(
          'service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\n'
          'weekday,1,1,1,1,1,1,1,$date,$date\n',
        );

        final parsedStops = await PtvGtfsRepository.parseStopsFromDirectory(tempDir);
        expect(parsedStops.length, equals(stations.length));

        for (final station in parsedStops) {
          final stationTrips = await PtvGtfsRepository.parseTripsFromDirectory(
            tempDir,
            targetStation: station,
          );
          expect(
            stationTrips.isNotEmpty,
            isTrue,
            reason: 'Departures should show up for ${station.name}',
          );
        }
      },
    );

    test('filters departures to services active today', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'gtfs_calendar_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final now = DateTime.now();
      final activeDays = List.filled(7, '0')..[now.weekday - 1] = '1';
      final date = _gtfsDate(now);
      final departure = _gtfsTime(now.hour * 60 + now.minute + 8);

      File('${tempDir.path}/calendar.txt').writeAsStringSync(
        'service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\n'
        'active,${activeDays.join(',')},$date,$date\n'
        'inactive,0,0,0,0,0,0,0,$date,$date\n',
      );
      File('${tempDir.path}/routes.txt').writeAsStringSync(
        'route_id,route_short_name,route_long_name,route_type\n'
        'route_1,T1,Test line,1\n',
      );
      File('${tempDir.path}/trips.txt').writeAsStringSync(
        'route_id,service_id,trip_id,trip_headsign\n'
        'route_1,active,active_trip,Active destination\n'
        'route_1,inactive,inactive_trip,Inactive destination\n',
      );
      File('${tempDir.path}/stop_times.txt').writeAsStringSync(
        'trip_id,arrival_time,departure_time,stop_id\n'
        'active_trip,$departure,$departure,19842\n'
        'inactive_trip,$departure,$departure,19842\n',
      );

      final trips = await PtvGtfsRepository.parseTripsFromDirectory(tempDir);

      expect(trips.map((trip) => trip.tripId), equals(['active_trip']));
      expect(trips.single.departure?.status, equals(ServiceStatus.scheduled));
    });
  });
}

String _gtfsTime(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:00';
}

String _gtfsDate(DateTime date) =>
    '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
