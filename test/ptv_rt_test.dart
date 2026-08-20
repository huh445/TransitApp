import 'package:flutter_test/flutter_test.dart';
import 'package:transit_app/src/domain/entities/station.dart';
import 'package:transit_app/src/services/ptv_rt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    EnvService.setCredentials(
      userId: 'test_dev_id',
      apiKey: 'test_api_key_hash',
    );
  });

  group('PTV Realtime & Env Tests', () {
    test('EnvService manages runtime credentials', () {
      expect(EnvService.userId, equals('test_dev_id'));
      expect(EnvService.apiKey, equals('test_api_key_hash'));
      expect(EnvService.isConfigured, isTrue);
    });

    test('PtvRealtimeService generates HMAC signed URLs for PTV API v3', () {
      final signedUrl = PtvRealtimeService.generateSignedUrl('/v3/disruptions');

      expect(signedUrl, contains('https://timetableapi.ptv.vic.gov.au/v3/disruptions'));
      expect(signedUrl, contains('devid=test_dev_id'));
      expect(signedUrl, contains('signature='));
    });

    test('PtvRealtimeService resolves stop ID accurately for Frankston and hubs', () async {
      final ptvService = PtvRealtimeService();
      const frankston = Station(
        id: 'st_frankston',
        stopId: '1073',
        name: 'Frankston Station',
        code: 'FKN',
        lat: -38.1432,
        lon: 145.1262,
        suburb: 'Frankston',
        zone: 'Zone 2',
        routes: [],
      );

      final resolvedId = await ptvService.resolveStopIdForStation(frankston);
      expect(resolvedId, equals('1073'));
    });
  });
}
