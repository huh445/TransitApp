import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../domain/entities/station.dart';

typedef GtfsProgressCallback = void Function(double progress, String status);

class MelbourneGtfsService {
  static const String stopsUrl =
      'https://raw.githubusercontent.com/huh4k/h4k-lib/refs/heads/main/stops.txt';

  static const Station defaultStation = Station(
    id: 'vic:rail:FSS',
    stopId: '1071',
    name: 'Flinders Street Station',
    code: 'FSS',
    lat: -37.8183,
    lon: 144.9671,
    suburb: 'Melbourne CBD',
    zone: 'Zone 1',
    isCityLoop: true,
    routes: [],
  );

  static Future<File?> getLocalStopsFile() async {
    try {
      Directory? baseDir;
      try {
        baseDir = await getApplicationSupportDirectory();
      } catch (_) {
        try {
          baseDir = await getApplicationDocumentsDirectory();
        } catch (_) {
          baseDir = await getTemporaryDirectory();
        }
      }
      final stopsDir = Directory(p.join(baseDir.path, 'ptv_gtfs'));
      if (!await stopsDir.exists()) {
        await stopsDir.create(recursive: true);
      }
      return File(p.join(stopsDir.path, 'stops.txt'));
    } catch (_) {
      return null;
    }
  }

  /// Downloads stops.txt with streaming download progress, saves it to local disk, and parses stations.
  static Future<List<Station>> loadOrDownloadStops({
    File? localFile,
    http.Client? client,
    GtfsProgressCallback? onProgress,
    bool forceRefresh = false,
  }) async {
    File? targetFile = localFile;
    targetFile ??= await getLocalStopsFile();

    // 1. Check if cached file on disk is valid
    if (!forceRefresh && targetFile != null && await targetFile.exists()) {
      try {
        final content = await targetFile.readAsString();
        if (content.trim().isNotEmpty) {
          final stations = parseStopsTxt(content);
          if (stations.length > 1) {
            onProgress?.call(1.0, 'Loaded Cached Stations: 100%');
            return stations;
          }
        }
      } catch (_) {}
    }

    // 2. Stream download from URL
    final httpClient = client ?? http.Client();
    onProgress?.call(0.05, 'Connecting to Stations Feed: 5%');

    try {
      final request = http.Request('GET', Uri.parse(stopsUrl));
      final streamedResponse = await httpClient.send(request);

      if (streamedResponse.statusCode == 200) {
        final contentLength = streamedResponse.contentLength ?? 0;
        final builder = BytesBuilder(copy: false);
        int downloaded = 0;

        await for (final chunk in streamedResponse.stream) {
          builder.add(chunk);
          downloaded += chunk.length;
          if (contentLength > 0 && onProgress != null) {
            final pVal = (downloaded / contentLength).clamp(0.05, 0.90);
            final pct = (pVal * 100).toInt();
            onProgress(pVal, 'Downloading Stations: $pct%');
          }
        }

        final bytes = builder.takeBytes();
        if (targetFile != null) {
          try {
            await targetFile.writeAsBytes(bytes);
          } catch (_) {}
        }

        onProgress?.call(0.95, 'Parsing Stations: 95%');
        final content = utf8.decode(bytes);
        final stations = parseStopsTxt(content);
        if (stations.length > 1) {
          onProgress?.call(1.0, 'Stations Ready: 100%');
          return stations;
        }
      }
    } catch (_) {}

    // 3. Fallback: Load pre-packaged asset 'assets/stops.txt'
    try {
      final assetContent = await rootBundle.loadString('assets/stops.txt');
      if (assetContent.trim().isNotEmpty) {
        final stations = parseStopsTxt(assetContent);
        if (stations.length > 1) {
          onProgress?.call(1.0, 'Loaded Stations: 100%');
          return stations;
        }
      }
    } catch (_) {}

    // 4. Fallback if cached file exists
    if (targetFile != null && await targetFile.exists()) {
      try {
        final content = await targetFile.readAsString();
        return parseStopsTxt(content);
      } catch (_) {}
    }

    return [defaultStation];
  }

  /// Parses CSV content of stops.txt into deduplicated Station objects.
  static List<Station> parseStopsTxt(String csvContent) {
    if (csvContent.trim().isEmpty) return [defaultStation];

    final lines = const LineSplitter().convert(csvContent);
    if (lines.isEmpty) return [defaultStation];

    final headerLine = lines.first.replaceAll('\uFEFF', ''); // Strip BOM
    final headers = _parseCsvRow(headerLine);

    final stopIdIdx = headers.indexOf('stop_id');
    final stopNameIdx = headers.indexOf('stop_name');
    final stopLatIdx = headers.indexOf('stop_lat');
    final stopLonIdx = headers.indexOf('stop_lon');
    final stopUrlIdx = headers.indexOf('stop_url');
    final parentStationIdx = headers.indexOf('parent_station');

    if (stopNameIdx == -1) return [defaultStation];

    final stopIdRegex = RegExp(r'/stop/(\d+)');
    final stationMap = <String, Station>{};

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _parseCsvRow(line);
      if (cols.length <= stopNameIdx) continue;

      final rawStopId = stopIdIdx != -1 && cols.length > stopIdIdx ? cols[stopIdIdx] : '';
      final rawName = cols[stopNameIdx];
      if (rawName.toLowerCase().contains('replacement bus')) continue;

      final cleanName = _normalizeStationName(rawName);
      final stopLat = (stopLatIdx != -1 && cols.length > stopLatIdx)
          ? double.tryParse(cols[stopLatIdx]) ?? 0.0
          : 0.0;
      final stopLon = (stopLonIdx != -1 && cols.length > stopLonIdx)
          ? double.tryParse(cols[stopLonIdx]) ?? 0.0
          : 0.0;

      final stopUrl = (stopUrlIdx != -1 && cols.length > stopUrlIdx) ? cols[stopUrlIdx] : '';
      final urlMatch = stopIdRegex.firstMatch(stopUrl);
      final ptvStopId = urlMatch != null ? urlMatch.group(1)! : rawStopId;

      final parentStationVal = (parentStationIdx != -1 && cols.length > parentStationIdx)
          ? cols[parentStationIdx].trim()
          : '';

      final parentKey = parentStationVal.isNotEmpty
          ? parentStationVal
          : cleanName.toLowerCase();

      final code = parentStationVal.contains(':')
          ? parentStationVal.split(':').last
          : (parentStationVal.isNotEmpty ? parentStationVal : ptvStopId);

      final nameLower = cleanName.toLowerCase();
      final isCityLoop = nameLower.contains('central') ||
          nameLower.contains('flinders') ||
          nameLower.contains('parliament') ||
          nameLower.contains('flagstaff') ||
          nameLower.contains('southern cross') ||
          ['FSS', 'SSS', 'MCE', 'PAR', 'FGS'].contains(code);

      if (!stationMap.containsKey(parentKey)) {
        stationMap[parentKey] = Station(
          id: parentStationVal.isNotEmpty ? parentStationVal : ptvStopId,
          stopId: ptvStopId,
          name: cleanName,
          code: code,
          lat: stopLat,
          lon: stopLon,
          suburb: 'Melbourne',
          zone: 'Zone 1',
          isCityLoop: isCityLoop,
          routes: const [],
        );
      }
    }

    if (stationMap.isEmpty) return [defaultStation];

    final stationList = stationMap.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return stationList;
  }

  static String _normalizeStationName(String raw) {
    var name = raw
        .replaceAll(RegExp(r'\s*Railway Station', caseSensitive: false), ' Station')
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .trim();
    if (!name.toLowerCase().endsWith(' station')) {
      name = '$name Station';
    }
    return name;
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
