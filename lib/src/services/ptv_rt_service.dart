import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../domain/entities/service.dart';
import '../domain/entities/transit_route.dart';
import '../domain/entities/station.dart';
import '../domain/entities/trips.dart';

class EnvService {
  static String _userId = const String.fromEnvironment('PTV_USER_ID', defaultValue: '3003979');
  static String _apiKey = const String.fromEnvironment('PTV_API_KEY', defaultValue: '75e01f6e-339a-4a01-ab13-b7524490ec83');
  static String _baseUrl = const String.fromEnvironment('PTV_BASE_URL', defaultValue: 'https://timetableapi.ptv.vic.gov.au');

  static String get userId => _userId;
  static String get apiKey => _apiKey;
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
    String? envString;
    try {
      envString = await rootBundle.loadString('.env');
    } catch (_) {
      try {
        envString = await rootBundle.loadString('assets/.env');
      } catch (_) {}
    }

    if (envString != null && envString.isNotEmpty) {
      final lines = const LineSplitter().convert(envString);
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final parts = trimmed.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final val = parts.sublist(1).join('=').trim();
          if (key == 'PTV_USER_ID' && val.isNotEmpty) _userId = val;
          if (key == 'PTV_API_KEY' && val.isNotEmpty) _apiKey = val;
          if (key == 'PTV_BASE_URL' && val.isNotEmpty) _baseUrl = val;
        }
      }
    }
  }
}

class PtvRealtimeService {
  final http.Client _client;
  final Map<String, String> _resolvedStopIdCache = {};

  static const Map<String, String> _defaultHeaders = {
    'Accept': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Linux; Android) TransitApp/1.0',
  };

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

  /// Dynamically resolves the official PTV API v3 numeric stop ID for a given station.
  Future<String> resolveStopIdForStation(Station station) async {
    final cleanName = station.name
        .toLowerCase()
        .replaceAll(' railway station', '')
        .replaceAll(' station', '')
        .trim();

    if (_resolvedStopIdCache.containsKey(cleanName)) {
      return _resolvedStopIdCache[cleanName]!;
    }

    // If stopId is already a valid PTV API numeric ID (3 to 5 digits), cache and return
    if (RegExp(r'^\d{3,5}$').hasMatch(station.stopId) &&
        !station.stopId.startsWith('19') &&
        !station.stopId.startsWith('20') &&
        !station.stopId.startsWith('22')) {
      _resolvedStopIdCache[cleanName] = station.stopId;
      return station.stopId;
    }

    if (!EnvService.isConfigured) return station.stopId;

    try {
      final searchResults = await searchStations(cleanName);
      if (searchResults.isNotEmpty) {
        // Find exact or closest match
        final exactMatch = searchResults.firstWhere(
          (s) => s.name.toLowerCase().replaceAll(' station', '').trim() == cleanName,
          orElse: () => searchResults.firstWhere(
            (s) => s.name.toLowerCase().contains(cleanName),
            orElse: () => searchResults.first,
          ),
        );
        _resolvedStopIdCache[cleanName] = exactMatch.stopId;
        return exactMatch.stopId;
      }
    } catch (_) {
      // Fallback
    }

    return station.stopId;
  }

  Future<List<ServiceAlert>> fetchLiveDisruptions() async {
    if (!EnvService.isConfigured) return [];

    final signedUrl = generateSignedUrl('/v3/disruptions');
    try {
      final response = await _client.get(
        Uri.parse(signedUrl),
        headers: _defaultHeaders,
      );
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
                          'Metro Network')
                      .toString()
                  : 'Metro Network';

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
    } catch (_) {
      return [];
    }
  }

  Future<List<Station>> searchStations(String query) async {
    if (query.trim().isEmpty || !EnvService.isConfigured) return [];

    final encodedQuery = Uri.encodeComponent(query.trim());
    final signedUrl = generateSignedUrl('/v3/search/$encodedQuery?route_types=0');

    try {
      final response = await _client.get(
        Uri.parse(signedUrl),
        headers: _defaultHeaders,
      );
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final stops = data['stops'] as List?;
      if (stops == null) return [];

      final stations = <Station>[];
      for (final stop in stops) {
        if (stop is Map<String, dynamic>) {
          final name = stop['stop_name']?.toString() ?? '';
          if (!name.toLowerCase().contains('replacement bus')) {
            stations.add(Station.fromPtv(stop));
          }
        }
      }
      return stations;
    } catch (_) {
      return [];
    }
  }

  Future<List<Trip>> fetchDepartures(
    String stopId, {
    int routeType = 0,
    int maxResults = 30,
    Station? station,
  }) async {
    if (!EnvService.isConfigured) return [];

    String numericStopId = stopId;
    if (station != null) {
      numericStopId = await resolveStopIdForStation(station);
    } else if (!RegExp(r'^\d{3,5}$').hasMatch(stopId)) {
      final tempStation = Station(
        id: stopId,
        stopId: stopId,
        name: stopId,
        code: stopId,
        lat: 0,
        lon: 0,
        suburb: '',
        zone: 'Zone 1',
        routes: const [],
      );
      numericStopId = await resolveStopIdForStation(tempStation);
    }

    final signedUrl = generateSignedUrl(
      '/v3/departures/route_type/$routeType/stop/$numericStopId?max_results=$maxResults&expand=all',
    );

    try {
      final response = await _client.get(
        Uri.parse(signedUrl),
        headers: _defaultHeaders,
      );
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final deps = data['departures'] as List?;
      final runs = data['runs'] as Map<String, dynamic>?;
      final routes = data['routes'] as Map<String, dynamic>?;

      if (deps == null || runs == null || routes == null) return [];

      final now = DateTime.now();
      final oneHourFromNow = now.add(const Duration(hours: 1));
      final trips = <Trip>[];

      for (final d in deps) {
        if (d is Map<String, dynamic>) {
          final runRef = d['run_ref']?.toString() ?? '';
          final routeId = d['route_id']?.toString() ?? '';

          final run = runs[runRef] as Map<String, dynamic>?;
          final route = routes[routeId] as Map<String, dynamic>?;

          if (run != null && route != null) {
            final trip = Trip.fromPtvDeparture(d, run, route);
            final sched = trip.departure?.scheduledTime;
            // Filter departures from current time (now - 2m) to 1 hour from now
            if (sched != null &&
                sched.isAfter(now.subtract(const Duration(minutes: 2))) &&
                sched.isBefore(oneHourFromNow)) {
              trips.add(trip);
            }
          }
        }
      }

      // Sort by line (e.g. Frankston, Mernda, Belgrave, Lilydale) and then by scheduled time
      trips.sort((a, b) {
        final aLine = a.departure?.lineCode.isNotEmpty == true
            ? a.departure!.lineCode
            : a.destinationName;
        final bLine = b.departure?.lineCode.isNotEmpty == true
            ? b.departure!.lineCode
            : b.destinationName;
        final lineComparison = aLine.toLowerCase().compareTo(bLine.toLowerCase());
        if (lineComparison != 0) return lineComparison;

        final aTime = a.departure?.scheduledTime ?? now;
        final bTime = b.departure?.scheduledTime ?? now;
        return aTime.compareTo(bTime);
      });

      return trips;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchPattern(String runRef, int routeType) async {
    if (!EnvService.isConfigured) return null;

    final signedUrl = generateSignedUrl(
      '/v3/pattern/run/$runRef/route_type/$routeType?expand=all',
    );

    try {
      final response = await _client.get(
        Uri.parse(signedUrl),
        headers: _defaultHeaders,
      );
      if (response.statusCode != 200) return null;
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Fetches intermediate stops and schedule times for a given run from PTV API.
  Future<List<ServiceStop>> fetchPatternStops(
    String runRef, {
    int routeType = 0,
  }) async {
    final pattern = await fetchPattern(runRef, routeType);
    if (pattern == null) return [];

    final deps = pattern['departures'] as List?;
    final stops = pattern['stops'] as Map<String, dynamic>?;
    if (deps == null || stops == null || deps.isEmpty) return [];

    final serviceStops = <ServiceStop>[];
    for (final d in deps) {
      if (d is Map<String, dynamic>) {
        final stopId = d['stop_id']?.toString() ?? '';
        final stopData = stops[stopId] as Map<String, dynamic>?;
        final stopName = stopData?['stop_name']?.toString() ?? 'Stop $stopId';

        final sched = d['scheduled_departure_utc']?.toString();
        final est = d['estimated_departure_utc']?.toString();
        final timeStr = est ?? sched;
        final time =
            timeStr != null ? DateTime.tryParse(timeStr)?.toLocal() : null;

        final stationObj = Station.fromPtv(
          stopData ?? {'stop_name': stopName, 'stop_id': stopId},
        );

        serviceStops.add(
          ServiceStop(
            station: stationObj,
            departureTime: time,
            platform: d['platform_number']?.toString() ?? '',
            stopSequence: d['departure_sequence'] as int? ?? 0,
          ),
        );
      }
    }

    serviceStops.sort((a, b) => a.stopSequence.compareTo(b.stopSequence));
    return serviceStops;
  }
}
