import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../domain/entities/station.dart';
import '../data/datasources/gtfs_index_engine.dart';

typedef GtfsProgressCallback = void Function(double progress, String status);

class GtfsNetworkException implements Exception {
  final String message;
  const GtfsNetworkException(this.message);

  @override
  String toString() => message;
}

class MelbourneGtfsService {
  static const String stopsUrl =
      'https://raw.githubusercontent.com/huh4k/h4k-lib/main/stops.txt';

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

  static File _getEtagFile(File targetFile) {
    return File(p.join(targetFile.parent.path, 'stops.etag'));
  }

  static Future<List<Station>?> _loadCachedStations(File targetFile) async {
    // 1. Fast Path: Binary index
    final binFile = File(p.join(targetFile.parent.path, GtfsIndexEngine.binaryIndexFilename));
    if (await binFile.exists()) {
      try {
        final binCache = await GtfsIndexEngine.loadBinaryIndex(binFile);
        if (binCache != null && binCache.stops.isNotEmpty) {
          final rawStations = binCache.stops.values.toList();
          final uniqueByName = <String, Station>{};
          for (final s in rawStations) {
            final cleanName = GtfsIndexEngine.normalizeStationName(s.name);
            if (GtfsIndexEngine.isReplacementBusStop(cleanName)) continue;
            final key = cleanName.toLowerCase();
            if (!uniqueByName.containsKey(key)) {
              uniqueByName[key] = s.copyWith(name: cleanName);
            }
          }
          final stations = uniqueByName.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          if (stations.length > 1) {
            return stations;
          }
        }
      } catch (_) {}
    }

    // 2. Text CSV cache
    if (await targetFile.exists()) {
      try {
        final content = await targetFile.readAsString();
        if (content.trim().isNotEmpty) {
          final stations = parseStopsTxt(content);
          if (stations.isNotEmpty &&
              (stations.length > 1 || stations.first.id != defaultStation.id || content.contains('stop_id'))) {
            try {
              GtfsIndexEngine.getOrCreateIndex(targetFile.parent);
            } catch (_) {}
            return stations;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Streams stops.txt from remote repository, saves it to local disk, and parses stations.
  /// Uses HTTP ETag conditional headers (If-None-Match) to avoid downloading when repo is unchanged.
  /// Throws [GtfsNetworkException] if network is not connected and no local cache exists.
  static Future<List<Station>> loadOrDownloadStops({
    File? localFile,
    http.Client? client,
    GtfsProgressCallback? onProgress,
    bool forceRefresh = false,
  }) async {
    File? targetFile = localFile;
    targetFile ??= await getLocalStopsFile();

    final etagFile = targetFile != null ? _getEtagFile(targetFile) : null;
    String? savedEtag;
    if (etagFile != null && await etagFile.exists()) {
      try {
        savedEtag = (await etagFile.readAsString()).trim();
      } catch (_) {}
    }

    final hasLocalCache = targetFile != null && await targetFile.exists();

    final httpClient = client ?? http.Client();
    onProgress?.call(0.05, 'Checking Stations Feed: 5%');

    try {
      final request = http.Request('GET', Uri.parse(stopsUrl));
      if (!forceRefresh && savedEtag != null && savedEtag.isNotEmpty && hasLocalCache) {
        request.headers['If-None-Match'] = savedEtag;
      }

      final streamedResponse = await httpClient.send(request);

      if (streamedResponse.statusCode == 304) {
        // Repo is unchanged: load from local cache
        if (targetFile != null) {
          final cached = await _loadCachedStations(targetFile);
          if (cached != null && cached.isNotEmpty) {
            onProgress?.call(1.0, 'Stations Up-to-Date: 100%');
            return cached;
          }
        }
      }

      if (streamedResponse.statusCode == 200) {
        // Repo updated or first download: stream chunks to temp file and parse
        final stations = await _streamAndParseStops(
          streamedResponse: streamedResponse,
          targetFile: targetFile,
          etagFile: etagFile,
          onProgress: onProgress,
        );
        return stations;
      }

      throw GtfsNetworkException(
        'Failed to download stations (HTTP ${streamedResponse.statusCode}).',
      );
    } catch (e) {
      // If we already have cached data, fall back to offline cache
      if (targetFile != null) {
        final cached = await _loadCachedStations(targetFile);
        if (cached != null && cached.isNotEmpty) {
          onProgress?.call(1.0, 'Loaded Cached Stations (Offline): 100%');
          return cached;
        }
      }

      if (e is GtfsNetworkException) {
        rethrow;
      }
      throw const GtfsNetworkException(
        'Network not connected. Unable to download stations.',
      );
    }
  }

  static Future<List<Station>> _streamAndParseStops({
    required http.StreamedResponse streamedResponse,
    File? targetFile,
    File? etagFile,
    GtfsProgressCallback? onProgress,
  }) async {
    File? tempFile;
    IOSink? sink;
    StreamController<List<int>>? lineController;

    try {
      if (targetFile != null) {
        if (!await targetFile.parent.exists()) {
          await targetFile.parent.create(recursive: true);
        }
        tempFile = File('${targetFile.path}.tmp');
        sink = tempFile.openWrite();
      }

      lineController = StreamController<List<int>>();

      final parseFuture = parseStopsStream(
        lineController.stream.transform(utf8.decoder).transform(const LineSplitter()),
      );

      final contentLength = streamedResponse.contentLength ?? 0;
      int downloaded = 0;

      await for (final chunk in streamedResponse.stream) {
        sink?.add(chunk);
        lineController.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0 && onProgress != null) {
          final pVal = (downloaded / contentLength).clamp(0.05, 0.90);
          final pct = (pVal * 100).toInt();
          onProgress(pVal, 'Streaming Stations: $pct%');
        }
      }

      await lineController.close();
      if (sink != null) {
        await sink.flush();
        await sink.close();
        sink = null;
      }

      onProgress?.call(0.95, 'Parsing Stations: 95%');
      final stations = await parseFuture;

      if (stations.isEmpty || (stations.length == 1 && stations.first == defaultStation)) {
        throw const GtfsNetworkException('Downloaded station feed was empty or invalid.');
      }

      if (tempFile != null && targetFile != null) {
        try {
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          await tempFile.rename(targetFile.path);
        } catch (_) {
          await tempFile.copy(targetFile.path);
          await tempFile.delete();
        }

        final etag = streamedResponse.headers['etag'];
        if (etag != null && etag.trim().isNotEmpty && etagFile != null) {
          try {
            await etagFile.writeAsString(etag.trim());
          } catch (_) {}
        }

        try {
          GtfsIndexEngine.getOrCreateIndex(targetFile.parent);
        } catch (_) {}
      }

      onProgress?.call(1.0, 'Stations Ready: 100%');
      return stations;
    } catch (e) {
      await lineController?.close();
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Parses lines from a streaming GTFS stops CSV into deduplicated Station objects.
  static Future<List<Station>> parseStopsStream(Stream<String> lineStream) async {
    final stopIdRegex = RegExp(r'/stop/(\d+)');
    final stationMap = <String, Station>{};
    List<String>? headers;
    int stopIdIdx = -1;
    int stopNameIdx = -1;
    int stopLatIdx = -1;
    int stopLonIdx = -1;
    int stopUrlIdx = -1;
    int parentStationIdx = -1;

    await for (var line in lineStream) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (headers == null) {
        final headerLine = line.replaceAll('\uFEFF', '');
        headers = _parseCsvRow(headerLine);
        stopIdIdx = headers.indexOf('stop_id');
        stopNameIdx = headers.indexOf('stop_name');
        stopLatIdx = headers.indexOf('stop_lat');
        stopLonIdx = headers.indexOf('stop_lon');
        stopUrlIdx = headers.indexOf('stop_url');
        parentStationIdx = headers.indexOf('parent_station');
        if (stopNameIdx == -1) {
          return [defaultStation];
        }
        continue;
      }

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
