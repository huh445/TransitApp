import 'dart:io';
import 'package:path/path.dart' as p;
import '../../domain/entities/station.dart';

class GtfsIndexCache {
  final Map<String, Station> stops;
  final Map<String, String> parentStopIdMap;

  const GtfsIndexCache({
    required this.stops,
    required this.parentStopIdMap,
  });
}

class GtfsIndexEngine {
  static final Map<String, GtfsIndexCache> _indexCache = {};

  static final RegExp _newlineRegex = RegExp(r'\r?\n');
  static final RegExp _parentSuffixRegex = RegExp(r'[:#_\-]');
  static final RegExp _parensRegex = RegExp(r'\s*\([^)]*\)');
  static final RegExp _railwayStationRegex = RegExp(r'\s+Railway Station', caseSensitive: false);
  static final RegExp _stationStationRegex = RegExp(r'\s+Station Station', caseSensitive: false);

  static void clearCache() {
    _indexCache.clear();
  }

  static bool isReplacementBusStop(String rawName) {
    final lower = rawName.toLowerCase();
    return lower.contains('replacement bus') ||
        lower.contains('bus replacement') ||
        lower.contains('replacement stop') ||
        lower.contains('temp bus') ||
        lower.contains('temporary bus') ||
        lower.contains('bustech');
  }

  static String normalizeStationName(String rawName) {
    if (rawName.isEmpty) return 'Station';

    String name = rawName.trim();

    name = name.split('/')[0].trim();
    name = name.replaceAll(_parensRegex, '').trim();
    name = name.replaceAll(_railwayStationRegex, ' Station');
    name = name.replaceAll(_stationStationRegex, ' Station');

    return name;
  }

  static Future<GtfsIndexCache> getOrCreateIndex(Directory modeDir) async {
    final path = modeDir.path;
    final cached = _indexCache[path];
    if (cached != null) {
      return cached;
    }

    final parsed = await _parseStopsMap(modeDir);
    _indexCache[path] = parsed;
    return parsed;
  }

  static Future<GtfsIndexCache> _parseStopsMap(Directory modeDir) async {
    final stopsFile = File(p.join(modeDir.path, 'stops.txt'));
    if (!await stopsFile.exists()) {
      return const GtfsIndexCache(stops: {}, parentStopIdMap: {});
    }

    final content = await stopsFile.readAsString();
    if (content.trim().isEmpty) {
      return const GtfsIndexCache(stops: {}, parentStopIdMap: {});
    }

    final lines = content.split(_newlineRegex);
    if (lines.isEmpty) {
      return const GtfsIndexCache(stops: {}, parentStopIdMap: {});
    }

    final headerCols = _parseCsvRow(lines.first);
    final stopIdIdx = headerCols.indexOf('stop_id');
    final stopNameIdx = headerCols.indexOf('stop_name');
    final stopLatIdx = headerCols.indexOf('stop_lat');
    final stopLonIdx = headerCols.indexOf('stop_lon');
    final stopCodeIdx = headerCols.indexOf('stop_code');
    final zoneIdIdx = headerCols.indexOf('zone_id');
    final parentStationIdx = headerCols.indexOf('parent_station');

    final stationMap = <String, Station>{};
    final parentMap = <String, String>{};

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _parseCsvRow(line);
      if (stopIdIdx == -1 || cols.length <= stopIdIdx) continue;

      final stopId = cols[stopIdIdx];
      if (stopId.isEmpty) continue;

      final rawStopName = (stopNameIdx != -1 && cols.length > stopNameIdx)
          ? cols[stopNameIdx]
          : stopId;

      if (isReplacementBusStop(rawStopName)) {
        continue;
      }

      final cleanName = normalizeStationName(rawStopName);

      if (isReplacementBusStop(cleanName)) {
        continue;
      }

      final stopLat = (stopLatIdx != -1 && cols.length > stopLatIdx)
          ? double.tryParse(cols[stopLatIdx]) ?? 0.0
          : 0.0;
      final stopLon = (stopLonIdx != -1 && cols.length > stopLonIdx)
          ? double.tryParse(cols[stopLonIdx]) ?? 0.0
          : 0.0;
      final stopCode = (stopCodeIdx != -1 && cols.length > stopCodeIdx)
          ? cols[stopCodeIdx]
          : '';
      final zoneId = (zoneIdIdx != -1 && cols.length > zoneIdIdx)
          ? cols[zoneIdIdx]
          : '';

      final parentStationVal = (parentStationIdx != -1 && cols.length > parentStationIdx)
          ? cols[parentStationIdx].trim()
          : '';

      final parentId = parentStationVal.isNotEmpty
          ? parentStationVal
          : stopId.split(_parentSuffixRegex).first;

      parentMap[stopId] = parentId;

      final nameLower = cleanName.toLowerCase();
      final isCityLoop = nameLower.contains('central') ||
          nameLower.contains('flinders') ||
          nameLower.contains('parliament') ||
          nameLower.contains('flagstaff') ||
          nameLower.contains('southern cross');

      final stationObj = Station(
        id: parentId,
        stopId: parentId,
        name: cleanName,
        code: stopCode.isNotEmpty ? stopCode : parentId,
        lat: stopLat,
        lon: stopLon,
        suburb: 'Melbourne',
        zone: zoneId.isNotEmpty ? 'Zone $zoneId' : 'Zone 1',
        isCityLoop: isCityLoop,
        routes: const [],
      );

      stationMap[stopId] = stationObj;
      stationMap[parentId] = stationObj;
    }

    return GtfsIndexCache(stops: stationMap, parentStopIdMap: parentMap);
  }

  static List<String> _parseCsvRow(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        values.add(buffer.toString().trim().replaceAll('"', ''));
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    values.add(buffer.toString().trim().replaceAll('"', ''));
    return values;
  }
}
