import 'package:flutter_test/flutter_test.dart';
import 'package:transit_app/src/services/ptv_rt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PTV Realtime & Env Tests', () {
    test('EnvService provides user credentials', () {
      expect(EnvService.userId, equals('3003979'));
      expect(
        EnvService.apiKey,
        equals('75e01f6e-339a-4a01-ab13-b7524490ec83'),
      );
    });

    test('PtvRealtimeService generates HMAC signed URLs for PTV API v3', () {
      final signedUrl = PtvRealtimeService.generateSignedUrl('/v3/disruptions');

      expect(signedUrl, contains('https://timetableapi.ptv.vic.gov.au/v3/disruptions'));
      expect(signedUrl, contains('devid=3003979'));
      expect(signedUrl, contains('signature='));
    });
  });
}
