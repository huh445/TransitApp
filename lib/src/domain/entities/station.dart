import 'transit_route.dart';

class Station {
  final String id;
  final String stopId;
  final String name;
  final String code;
  final double lat;
  final double lon;
  final String suburb;
  final String zone;
  final bool isCityLoop;
  final List<TransitRoute> routes;

  const Station({
    required this.id,
    required this.stopId,
    required this.name,
    required this.code,
    required this.lat,
    required this.lon,
    required this.suburb,
    required this.zone,
    this.isCityLoop = false,
    required this.routes,
  });

  Station copyWith({
    String? id,
    String? stopId,
    String? name,
    String? code,
    double? lat,
    double? lon,
    String? suburb,
    String? zone,
    bool? isCityLoop,
    List<TransitRoute>? routes,
  }) {
    return Station(
      id: id ?? this.id,
      stopId: stopId ?? this.stopId,
      name: name ?? this.name,
      code: code ?? this.code,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      suburb: suburb ?? this.suburb,
      zone: zone ?? this.zone,
      isCityLoop: isCityLoop ?? this.isCityLoop,
      routes: routes ?? this.routes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stopId': stopId,
      'name': name,
      'code': code,
      'lat': lat,
      'lon': lon,
      'suburb': suburb,
      'zone': zone,
      'isCityLoop': isCityLoop,
    };
  }

  factory Station.fromMap(Map<String, dynamic> map) {
    return Station(
      id: map['id'] ?? '',
      stopId: map['stopId'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (map['lon'] as num?)?.toDouble() ?? 0.0,
      suburb: map['suburb'] ?? '',
      zone: map['zone'] ?? 'Zone 1',
      isCityLoop: map['isCityLoop'] ?? false,
      routes: const [],
    );
  }

  factory Station.fromPtv(Map<String, dynamic> map) {
    final name = map['stop_name']?.toString() ?? '';
    final stopId = map['stop_id']?.toString() ?? '';
    
    String cleanName = name;
    cleanName = cleanName.split('/')[0].trim();
    cleanName = cleanName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
    cleanName = cleanName.replaceAll(RegExp(r'\s+Railway Station', caseSensitive: false), ' Station');
    cleanName = cleanName.replaceAll(RegExp(r'\s+Station Station', caseSensitive: false), ' Station');
    if (cleanName.endsWith(' Station')) {
      cleanName = cleanName.substring(0, cleanName.length - 8).trim();
    }

    final nameLower = cleanName.toLowerCase();
    final isCityLoop = nameLower.contains('central') ||
        nameLower.contains('flinders') ||
        nameLower.contains('parliament') ||
        nameLower.contains('flagstaff') ||
        nameLower.contains('southern cross');

    return Station(
      id: stopId,
      stopId: stopId,
      name: cleanName.isNotEmpty ? cleanName : stopId,
      code: stopId,
      lat: (map['stop_latitude'] as num?)?.toDouble() ?? 0.0,
      lon: (map['stop_longitude'] as num?)?.toDouble() ?? 0.0,
      suburb: map['stop_suburb']?.toString() ?? 'Melbourne',
      zone: 'Zone 1',
      isCityLoop: isCityLoop,
      routes: const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Station && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Station(id: $id, name: $name, code: $code)';
}
