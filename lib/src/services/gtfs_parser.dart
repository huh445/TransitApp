import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:gtfs_bindings/schedule.dart' as gtfs;
import 'package:gtfs_realtime_bindings/gtfs_realtime_bindings.dart' as gtfs_rt;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/station.dart';
import '../models/trips.dart';
import '../models/transit_route.dart';
import 'ptv_rt_service.dart';

enum PtvMode {
  regionalTrain('1'),
  metroTrain('2'),
  metroTram('3'),
  metroBus('4'),
  regionalCoach('5'),
  regionalBus('6');

  final String id;
  const PtvMode(this.id);
}

abstract interface class IGtfsRepository {
  Future<gtfs.DirectoryDataset?> getDatasetForMode(
    PtvMode mode, {
    bool forceRefresh = false,
  });
  Future<List<Trip>> getTripsForMode(
    PtvMode mode, {
    Station? station,
    bool forceRefresh = false,
  });
  Future<List<Station>> getStopsForMode(
    PtvMode mode, {
    bool forceRefresh = false,
  });
  Future<List<ServiceAlert>> getServiceAlerts();
  Future<void> clearCache();
}

class PtvGtfsRepository implements IGtfsRepository {
  final Uri masterZipUrl;
  final http.Client _client;
  final PtvRealtimeService _realtimeService;

  List<int>? _cachedMasterBytes;

  PtvGtfsRepository({
    required this.masterZipUrl,
    http.Client? client,
    PtvRealtimeService? realtimeService,
  })  : _client = client ?? http.Client(),
        _realtimeService =
            realtimeService ?? PtvRealtimeService(client: client);

  @override
  Future<gtfs.DirectoryDataset?> getDatasetForMode(
    PtvMode mode, {
    bool forceRefresh = false,
  }) async {
    final appSupportDir = await getApplicationSupportDirectory();
    final modeDir = Directory(
      p.join(appSupportDir.path, 'ptv_gtfs', mode.name),
    );
    final routesFile = File(p.join(modeDir.path, 'routes.txt'));

    if (!forceRefresh && await _hasFreshCache(routesFile)) {
      return gtfs.DirectoryDataset(directory: modeDir);
    }

    if (forceRefresh) _cachedMasterBytes = null;
    _cachedMasterBytes ??= await _fetchMasterZip();
    await _extractModeToDirectory(_cachedMasterBytes!, mode, modeDir);

    return gtfs.DirectoryDataset(directory: modeDir);
  }

  @override
  Future<List<Trip>> getTripsForMode(
    PtvMode mode, {
    Station? station,
    bool forceRefresh = false,
  }) async {
    final dataset = await getDatasetForMode(mode, forceRefresh: forceRefresh);
    if (dataset != null) {
      return parseTripsFromDirectory(
        dataset.directory,
        targetStation: station,
      );
    }
    return [];
  }

  @override
  Future<List<Station>> getStopsForMode(
    PtvMode mode, {
    bool forceRefresh = false,
  }) async {
    final dataset = await getDatasetForMode(mode, forceRefresh: forceRefresh);
    if (dataset != null) {
      return parseStopsFromDirectory(dataset.directory);
    }
    return [];
  }

  @override
  Future<List<ServiceAlert>> getServiceAlerts() async {
    return _realtimeService.fetchLiveDisruptions();
  }


  @override
  Future<void> clearCache() async {
    _cachedMasterBytes = null;
    final appSupportDir = await getApplicationSupportDirectory();
    final cacheDir = Directory(p.join(appSupportDir.path, 'ptv_gtfs'));
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }

  static Future<List<Trip>> parseTripsFromDirectory(
    Directory modeDir, {
    Station? targetStation,
  }) async {
    final now = DateTime.now();
    final activeServices = await _activeServiceDates(modeDir, now);
    final stopTimes = await _parseStopTimesList(
      modeDir,
      targetStation: targetStation,
    );
    if (stopTimes.isEmpty) return [];

    final targetTripIds = stopTimes.map((entry) => entry.tripId).toSet();
    final tripsById = await _parseTripsMap(
      modeDir,
      tripIds: targetTripIds,
      activeServices: activeServices,
    );
    if (tripsById.isEmpty) return [];

    final routeIds = tripsById.values.map((trip) => trip.routeId).toSet();
    final routesById = await _parseRoutesMap(modeDir, routeIds: routeIds);

    final scheduledTrips = <Trip>[];
    final cutoffTime = now.subtract(const Duration(minutes: 1));

    for (final stopTime in stopTimes) {
      final tripInfo = tripsById[stopTime.tripId];
      if (tripInfo == null) continue;

      final serviceDate = activeServices[tripInfo.serviceId] ?? now;
      final scheduledTime = _parseGtfsTime(stopTime.departureTime, serviceDate);
      if (scheduledTime.isBefore(cutoffTime)) continue;

      final routeInfo = routesById[tripInfo.routeId];
      final routeName = routeInfo?.longName ?? '';
      final lineCode = (routeInfo?.shortName.isNotEmpty == true)
          ? routeInfo!.shortName
          : tripInfo.routeId;

      final headsign = tripInfo.headsign.isNotEmpty
          ? tripInfo.headsign
          : (routeName.isNotEmpty ? routeName : 'Scheduled service');

      scheduledTrips.add(
        Trip(
          tripId: stopTime.tripId,
          routeId: tripInfo.routeId,
          serviceId: tripInfo.serviceId,
          headsign: headsign,
          shortName: routeInfo?.shortName,
          directionId: tripInfo.directionId,
          departure: TripDeparture(
            scheduledTime: scheduledTime,
            platform: stopTime.platform,
            lineCode: lineCode,
            routeName: routeName,
            type: routeInfo?.type ?? TransitType.bus,
          ),
        ),
      );
    }

    scheduledTrips.sort(
      (a, b) =>
          a.departure!.scheduledTime.compareTo(b.departure!.scheduledTime),
    );
    return scheduledTrips.take(100).toList();
  }

  static Future<List<Station>> parseStopsFromDirectory(
    Directory modeDir,
  ) async {
    final stopsFile = File(p.join(modeDir.path, 'stops.txt'));
    if (!await stopsFile.exists()) return [];

    final content = await stopsFile.readAsString();
    if (content.trim().isEmpty) return [];

    final lines = content.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) return [];

    final headerCols = _parseCsvRow(lines.first);
    final stopIdIdx = headerCols.indexOf('stop_id');
    final stopNameIdx = headerCols.indexOf('stop_name');
    final stopLatIdx = headerCols.indexOf('stop_lat');
    final stopLonIdx = headerCols.indexOf('stop_lon');
    final stopCodeIdx = headerCols.indexOf('stop_code');
    final zoneIdIdx = headerCols.indexOf('zone_id');

    final stationMap = <String, Station>{};

    for (int i = 1; i < lines.length && stationMap.length < 150; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _parseCsvRow(line);
      if (stopIdIdx == -1 || cols.length <= stopIdIdx) continue;

      final stopId = cols[stopIdIdx];
      if (stopId.isEmpty || stationMap.containsKey(stopId)) continue;

      final stopName = (stopNameIdx != -1 && cols.length > stopNameIdx)
          ? cols[stopNameIdx]
          : stopId;
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

      final nameLower = stopName.toLowerCase();
      final isCityLoop = nameLower.contains('central') ||
          nameLower.contains('flinders') ||
          nameLower.contains('parliament') ||
          nameLower.contains('flagstaff') ||
          nameLower.contains('southern cross');

      stationMap[stopId] = Station(
        id: stopId,
        stopId: stopId,
        name: stopName,
        code: stopCode.isNotEmpty ? stopCode : stopId,
        lat: stopLat,
        lon: stopLon,
        suburb: 'Melbourne',
        zone: zoneId.isNotEmpty ? 'Zone $zoneId' : 'Zone 1',
        isCityLoop: isCityLoop,
        routes: const [],
      );
    }

    final stationsList = stationMap.values.toList();
    stationsList.sort((a, b) => a.name.compareTo(b.name));
    return stationsList;
  }

  static Future<Map<String, DateTime>> _activeServiceDates(
    Directory modeDir,
    DateTime now,
  ) async {
    final serviceDate = DateTime(now.year, now.month, now.day);
    final activeServices = <String, DateTime>{};
    final calendarFile = File(p.join(modeDir.path, 'calendar.txt'));

    if (await calendarFile.exists()) {
      final lines = (await calendarFile.readAsString()).split(RegExp(r'\r?\n'));
      if (lines.isNotEmpty) {
        final headers = _parseCsvRow(lines.first);
        final serviceIdIdx = headers.indexOf('service_id');
        final startDateIdx = headers.indexOf('start_date');
        final endDateIdx = headers.indexOf('end_date');
        final weekdayIdx = headers.indexOf(_weekdayColumn(serviceDate.weekday));

        for (final line in lines.skip(1)) {
          final columns = _parseCsvRow(line);
          if (serviceIdIdx == -1 || columns.length <= serviceIdIdx) continue;
          if (weekdayIdx == -1 ||
              columns.length <= weekdayIdx ||
              columns[weekdayIdx] != '1') {
            continue;
          }

          final startDate = _dateAt(columns, startDateIdx);
          final endDate = _dateAt(columns, endDateIdx);
          if ((startDate == null || !serviceDate.isBefore(startDate)) &&
              (endDate == null || !serviceDate.isAfter(endDate))) {
            activeServices[columns[serviceIdIdx]] = serviceDate;
          }
        }
      }
    }

    final exceptionsFile = File(p.join(modeDir.path, 'calendar_dates.txt'));
    if (!await exceptionsFile.exists()) return activeServices;

    final lines = (await exceptionsFile.readAsString()).split(RegExp(r'\r?\n'));
    if (lines.isEmpty) return activeServices;

    final headers = _parseCsvRow(lines.first);
    final serviceIdIdx = headers.indexOf('service_id');
    final dateIdx = headers.indexOf('date');
    final exceptionTypeIdx = headers.indexOf('exception_type');

    for (final line in lines.skip(1)) {
      final columns = _parseCsvRow(line);
      if (serviceIdIdx == -1 || dateIdx == -1 || exceptionTypeIdx == -1) {
        continue;
      }
      if (columns.length <= serviceIdIdx ||
          columns.length <= dateIdx ||
          columns.length <= exceptionTypeIdx ||
          _dateAt(columns, dateIdx) != serviceDate) {
        continue;
      }

      final serviceId = columns[serviceIdIdx];
      if (columns[exceptionTypeIdx] == '1') {
        activeServices[serviceId] = serviceDate;
      } else if (columns[exceptionTypeIdx] == '2') {
        activeServices.remove(serviceId);
      }
    }

    return activeServices;
  }

  static String _weekdayColumn(int weekday) => const [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ][weekday - 1];

  static DateTime? _dateAt(List<String> columns, int index) {
    if (index == -1 || columns.length <= index || columns[index].length != 8) {
      return null;
    }

    final value = columns[index];
    final year = int.tryParse(value.substring(0, 4));
    final month = int.tryParse(value.substring(4, 6));
    final day = int.tryParse(value.substring(6, 8));
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  static Future<Map<String, _GtfsRouteInfo>> _parseRoutesMap(
    Directory modeDir, {
    Set<String>? routeIds,
  }) async {
    final routesFile = File(p.join(modeDir.path, 'routes.txt'));
    if (!await routesFile.exists()) return {};

    final map = <String, _GtfsRouteInfo>{};
    int? routeIdIdx;
    int? shortNameIdx;
    int? longNameIdx;
    int? routeTypeIdx;

    await _forEachCsvRow(routesFile, (headers, cols) {
      routeIdIdx ??= headers.indexOf('route_id');
      shortNameIdx ??= headers.indexOf('route_short_name');
      longNameIdx ??= headers.indexOf('route_long_name');
      routeTypeIdx ??= headers.indexOf('route_type');
      if (routeIdIdx == -1 || cols.length <= routeIdIdx!) return;

      final routeId = cols[routeIdIdx!];
      if (routeIds != null && !routeIds.contains(routeId)) return;
      final shortName = (shortNameIdx != -1 && cols.length > shortNameIdx!)
          ? cols[shortNameIdx!]
          : routeId;
      final longName = (longNameIdx != -1 && cols.length > longNameIdx!)
          ? cols[longNameIdx!]
          : shortName;
      final routeTypeInt = (routeTypeIdx != -1 && cols.length > routeTypeIdx!)
          ? int.tryParse(cols[routeTypeIdx!]) ?? 3
          : 3;

      final type = TransitRoute.fromGtfsRouteType(routeTypeInt);
      map[routeId] = _GtfsRouteInfo(
        shortName: shortName,
        longName: longName,
        type: type,
      );
    });

    return map;
  }

  static Future<Map<String, _GtfsTripInfo>> _parseTripsMap(
    Directory modeDir, {
    required Set<String> tripIds,
    required Map<String, DateTime> activeServices,
  }) async {
    final tripsFile = File(p.join(modeDir.path, 'trips.txt'));
    if (!await tripsFile.exists()) return {};

    final map = <String, _GtfsTripInfo>{};
    int? routeIdIdx;
    int? serviceIdIdx;
    int? tripIdIdx;
    int? headsignIdx;
    int? directionIdIdx;

    await _forEachCsvRow(tripsFile, (headers, cols) {
      routeIdIdx ??= headers.indexOf('route_id');
      serviceIdIdx ??= headers.indexOf('service_id');
      tripIdIdx ??= headers.indexOf('trip_id');
      headsignIdx ??= headers.indexOf('trip_headsign');
      directionIdIdx ??= headers.indexOf('direction_id');
      if (tripIdIdx == -1 || cols.length <= tripIdIdx!) return;

      final tripId = cols[tripIdIdx!];
      if (!tripIds.contains(tripId)) return;
      final routeId = (routeIdIdx != -1 && cols.length > routeIdIdx!)
          ? cols[routeIdIdx!]
          : '';
      final serviceId = (serviceIdIdx != -1 && cols.length > serviceIdIdx!)
          ? cols[serviceIdIdx!]
          : '';
      if (activeServices.isNotEmpty && !activeServices.containsKey(serviceId)) {
        return;
      }
      final headsign = (headsignIdx != -1 && cols.length > headsignIdx!)
          ? cols[headsignIdx!]
          : '';
      final directionId =
          (directionIdIdx != -1 && cols.length > directionIdIdx!)
          ? int.tryParse(cols[directionIdIdx!]) ?? 0
          : 0;

      map[tripId] = _GtfsTripInfo(
        routeId: routeId,
        serviceId: serviceId,
        headsign: headsign,
        directionId: directionId,
      );
    });

    return map;
  }

  static Future<List<_GtfsStopTimeEntry>> _parseStopTimesList(
    Directory modeDir, {
    Station? targetStation,
  }) async {
    final stopTimesFile = File(p.join(modeDir.path, 'stop_times.txt'));
    if (!await stopTimesFile.exists()) return [];

    final list = <_GtfsStopTimeEntry>[];
    int? tripIdIdx;
    int? arrivalTimeIdx;
    int? departureTimeIdx;
    int? stopIdIdx;
    int? platformIdx;

    await _forEachCsvRow(stopTimesFile, (headers, cols) {
      tripIdIdx ??= headers.indexOf('trip_id');
      arrivalTimeIdx ??= headers.indexOf('arrival_time');
      departureTimeIdx ??= headers.indexOf('departure_time');
      stopIdIdx ??= headers.indexOf('stop_id');
      platformIdx ??= headers.indexOf('platform_code');
      if (tripIdIdx == -1 || cols.length <= tripIdIdx!) return;

      final tripId = cols[tripIdIdx!];
      final stopId = (stopIdIdx != -1 && cols.length > stopIdIdx!)
          ? cols[stopIdIdx!]
          : '';

      if (targetStation != null &&
          targetStation.stopId.isNotEmpty &&
          stopId != targetStation.stopId &&
          stopId != targetStation.id) {
        return;
      }

      final depTimeStr =
          (departureTimeIdx != -1 && cols.length > departureTimeIdx!)
          ? cols[departureTimeIdx!]
          : ((arrivalTimeIdx != -1 && cols.length > arrivalTimeIdx!)
                ? cols[arrivalTimeIdx!]
                : '00:00:00');

      final platform = (platformIdx != -1 && cols.length > platformIdx!)
          ? cols[platformIdx!]
          : '';

      list.add(
        _GtfsStopTimeEntry(
          tripId: tripId,
          stopId: stopId,
          departureTime: depTimeStr,
          platform: platform,
        ),
      );
    });

    return list;
  }

  static Future<void> _forEachCsvRow(
    File file,
    void Function(List<String> headers, List<String> row) onRow,
  ) async {
    List<String>? headers;
    final lines = file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.isEmpty) continue;
      final row = _parseCsvRow(line);
      if (headers == null) {
        headers = row;
      } else {
        onRow(headers, row);
      }
    }
  }

  static DateTime _parseGtfsTime(String timeStr, DateTime serviceDate) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return serviceDate;

    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    final seconds = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;

    return DateTime(
      serviceDate.year,
      serviceDate.month,
      serviceDate.day,
    ).add(Duration(hours: hours, minutes: minutes, seconds: seconds));
  }

  static Future<bool> _hasFreshCache(File routesFile) async {
    if (!await routesFile.exists()) return false;
    final modified = await routesFile.lastModified();
    return DateTime.now().difference(modified) < const Duration(days: 7);
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

  Future<List<int>> _fetchMasterZip() async {
    final response = await _client
        .get(masterZipUrl)
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to download GTFS feed (HTTP ${response.statusCode})',
      );
    }
    return response.bodyBytes;
  }

  Future<void> _extractModeToDirectory(
    List<int> masterBytes,
    PtvMode mode,
    Directory targetDir,
  ) async {
    if (await targetDir.exists()) {
      await targetDir.delete(recursive: true);
    }
    await targetDir.create(recursive: true);

    final masterArchive = ZipDecoder().decodeBytes(masterBytes);

    for (final file in masterArchive) {
      if (!file.isFile) continue;

      final normName = file.name.replaceAll('\\', '/');

      final isTargetMode =
          normName.startsWith('${mode.id}/') ||
          normName.contains('/${mode.id}/') ||
          normName.endsWith('/${mode.id}.zip') ||
          normName == '${mode.id}.zip';

      if (!isTargetMode) continue;

      final bytes = _getArchiveFileBytes(file);

      if (normName.endsWith('.zip')) {
        try {
          final innerArchive = ZipDecoder().decodeBytes(bytes);
          for (final innerFile in innerArchive) {
            if (innerFile.isFile) {
              final innerBytes = _getArchiveFileBytes(innerFile);
              final outFile = File(
                p.join(targetDir.path, p.basename(innerFile.name)),
              );
              await outFile.create(recursive: true);
              await outFile.writeAsBytes(innerBytes);
            }
          }
        } catch (_) {}
      } else if (normName.endsWith('.txt')) {
        final outFile = File(p.join(targetDir.path, p.basename(normName)));
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(bytes);
      }
    }
  }

  static List<int> _getArchiveFileBytes(ArchiveFile file) {
    return file.content as List<int>;
  }

  static List<ServiceAlert> parseRealtimeServiceAlerts(List<int> bytes) {
    final feed = gtfs_rt.FeedMessage.fromBuffer(bytes);
    final alerts = <ServiceAlert>[];

    for (final entity in feed.entity) {
      if (entity.hasAlert()) {
        final alert = entity.alert;
        final headerText = alert.headerText.translation.isNotEmpty
            ? alert.headerText.translation.first.text
            : 'Melbourne Network Alert';
        final descriptionText = alert.descriptionText.translation.isNotEmpty
            ? alert.descriptionText.translation.first.text
            : '';

        final lineCode = alert.informedEntity.isNotEmpty
            ? alert.informedEntity.first.routeId
            : 'PTV Network';

        final timestampSeconds = alert.activePeriod.isNotEmpty
            ? alert.activePeriod.first.start.toInt()
            : (DateTime.now().millisecondsSinceEpoch ~/ 1000);

        alerts.add(
          ServiceAlert(
            id: entity.id,
            title: headerText,
            description: descriptionText,
            lineCode: lineCode,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              timestampSeconds * 1000,
            ),
            severity: ServiceStatus.disrupted,
          ),
        );
      }
    }

    return alerts;
  }
}

class _GtfsRouteInfo {
  final String shortName;
  final String longName;
  final TransitType type;

  const _GtfsRouteInfo({
    required this.shortName,
    required this.longName,
    required this.type,
  });
}

class _GtfsTripInfo {
  final String routeId;
  final String serviceId;
  final String headsign;
  final int directionId;

  const _GtfsTripInfo({
    required this.routeId,
    this.serviceId = '',
    required this.headsign,
    this.directionId = 0,
  });
}

class _GtfsStopTimeEntry {
  final String tripId;
  final String stopId;
  final String departureTime;
  final String platform;

  const _GtfsStopTimeEntry({
    required this.tripId,
    required this.stopId,
    required this.departureTime,
    required this.platform,
  });
}
