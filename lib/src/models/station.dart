import 'transit_route.dart';

class Station {
  final String id;
  final String stopId;
  final String name;
  final String code;
  final double lat;
  final double lon;
  final String suburb;
  final String zone; // e.g., 'Zone 1', 'Zone 1/2', 'Zone 2', 'Regional'
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
}
