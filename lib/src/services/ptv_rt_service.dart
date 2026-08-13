import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../domain/entities/transit_route.dart';
import '../domain/entities/station.dart';
import '../domain/entities/trips.dart';
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

  Future<List<Station>> searchStations(String query) async {
    if (query.trim().isEmpty) return [];
    
    // Using route_types 0=Train, 1=Tram, 2=Bus, 3=Vline, 4=Night Bus
    final encodedQuery = Uri.encodeComponent(query.trim());
    final signedUrl = generateSignedUrl('/v3/search/$encodedQuery?route_types=0,1,2,3,4');
    
    try {
      final response = await _client.get(Uri.parse(signedUrl));
      if (response.statusCode != 200) return [];
      
      final data = json.decode(response.body) as Map<String, dynamic>;
      final stops = data['stops'] as List?;
      if (stops == null) return [];
      
      final stations = <Station>[];
      for (final stop in stops) {
        if (stop is Map<String, dynamic>) {
          // Exclude Replacement Bus stops
          final name = stop['stop_name']?.toString() ?? '';
          if (!name.toLowerCase().contains('replacement bus')) {
            stations.add(Station.fromPtv(stop));
          }
        }
      }
      return stations;
    } catch (e) {
      return [];
    }
  }

  Future<List<Trip>> fetchDepartures(String stopId, {int routeType = 0, int maxResults = 10}) async {
    final signedUrl = generateSignedUrl(
      '/v3/departures/route_type/$routeType/stop/$stopId?max_results=$maxResults&expand=all',
    );

    try {
      final response = await _client.get(Uri.parse(signedUrl));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final deps = data['departures'] as List?;
      final runs = data['runs'] as Map<String, dynamic>?;
      final routes = data['routes'] as Map<String, dynamic>?;

      if (deps == null || runs == null || routes == null) return [];

      final trips = <Trip>[];
      for (final d in deps) {
        if (d is Map<String, dynamic>) {
          final runRef = d['run_ref']?.toString() ?? '';
          final routeId = d['route_id']?.toString() ?? '';
          
          final run = runs[runRef] as Map<String, dynamic>?;
          final route = routes[routeId] as Map<String, dynamic>?;
          
          if (run != null && route != null) {
            trips.add(Trip.fromPtvDeparture(d, run, route));
          }
        }
      }
      
      // Sort by scheduled time
      trips.sort((a, b) {
        final aTime = a.departure?.scheduledTime ?? DateTime.now();
        final bTime = b.departure?.scheduledTime ?? DateTime.now();
        return aTime.compareTo(bTime);
      });
      
      return trips;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchPattern(String runRef, int routeType) async {
    final signedUrl = generateSignedUrl(
      '/v3/pattern/run/$runRef/route_type/$routeType?expand=all',
    );
    
    try {
      final response = await _client.get(Uri.parse(signedUrl));
      if (response.statusCode != 200) return null;
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}
