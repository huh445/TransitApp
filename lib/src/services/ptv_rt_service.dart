import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../domain/entities/transit_route.dart';

class EnvService {
  static String? _userId;
  static String? _apiKey;
  static String _baseUrl = 'https://timetableapi.ptv.vic.gov.au';

  static String get userId => _userId ?? '';
  static String get apiKey => _apiKey ?? '';
  static String get baseUrl => _baseUrl;
  static bool get isConfigured => userId.isNotEmpty && apiKey.isNotEmpty;

  static void setCredentials({
    required String userId,
    required String apiKey,
    String? baseUrl,
  }) {
    _userId = userId;
    _apiKey = apiKey;
    if (baseUrl != null) _baseUrl = baseUrl;
  }

  static Future<void> loadEnv() async {
    final envString = await rootBundle.loadString('.env');
    final lines = const LineSplitter().convert(envString);
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final parts = trimmed.split('=');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final val = parts.sublist(1).join('=').trim();
        if (key == 'PTV_USER_ID') _userId = val;
        if (key == 'PTV_API_KEY') _apiKey = val;
        if (key == 'PTV_BASE_URL') _baseUrl = val;
      }
    }
  }
}

class PtvRealtimeService {
  final http.Client _client;

  PtvRealtimeService({http.Client? client}) : _client = client ?? http.Client();

  static String generateSignedUrl(String requestPath) {
    final devId = EnvService.userId;
    final key = EnvService.apiKey;
    final uriWithDevId = requestPath.contains('?')
        ? '$requestPath&devid=$devId'
        : '$requestPath?devid=$devId';

    final hmac = Hmac(sha1, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(uriWithDevId));
    final signature = digest.toString().toUpperCase();

    return '${EnvService.baseUrl}$uriWithDevId&signature=$signature';
  }

  Future<List<ServiceAlert>> fetchLiveDisruptions() async {
    final signedUrl = generateSignedUrl('/v3/disruptions');
    final response = await _client.get(Uri.parse(signedUrl));

    if (response.statusCode != 200) return [];

    final data = json.decode(response.body) as Map<String, dynamic>;
    final disruptionsObj = data['disruptions'] as Map<String, dynamic>?;
    if (disruptionsObj == null) return [];

    final alerts = <ServiceAlert>[];
    disruptionsObj.forEach((modeKey, list) {
      if (list is List) {
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final id = item['disruption_id']?.toString() ?? '';
            final title = item['title']?.toString() ?? 'PTV Service Alert';
            final desc = item['description']?.toString() ?? '';
            final routes = item['routes'] as List?;
            final lineCode = (routes != null && routes.isNotEmpty)
                ? (routes.first['route_short_name'] ??
                        routes.first['route_name'] ??
                        'PTV Network')
                    .toString()
                : 'PTV Network';

            alerts.add(
              ServiceAlert(
                id: id,
                title: title,
                description: desc,
                lineCode: lineCode,
                timestamp: DateTime.now(),
                severity: ServiceStatus.disrupted,
              ),
            );
          }
        }
      }
    });
    return alerts;
  }

  Future<Map<String, int>> fetchRealtimeDepartures({
    required int mode,
    required String stopId,
  }) async {
    final signedUrl = generateSignedUrl(
      '/v3/departures/route_type/$mode/stop/$stopId',
    );
    final response = await _client.get(Uri.parse(signedUrl));

    if (response.statusCode != 200) return {};

    final data = json.decode(response.body) as Map<String, dynamic>;
    final deps = data['departures'] as List?;
    if (deps == null) return {};

    final delaysByTrip = <String, int>{};
    for (final d in deps) {
      if (d is Map<String, dynamic>) {
        final runRef = d['run_ref']?.toString() ?? '';
        final schedTimeStr = d['scheduled_departure_utc']?.toString();
        final estTimeStr = d['estimated_departure_utc']?.toString();

        if (runRef.isNotEmpty && schedTimeStr != null && estTimeStr != null) {
          final sched = DateTime.tryParse(schedTimeStr);
          final est = DateTime.tryParse(estTimeStr);
          if (sched != null && est != null) {
            final delayMins = est.difference(sched).inMinutes;
            delaysByTrip[runRef] = delayMins;
          }
        }
      }
    }
    return delaysByTrip;
  }
}
