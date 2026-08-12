import 'package:flutter/material.dart';

enum TransitType {
  metro,         // Metro Trains (PTV GTFS route_type 1)
  tram,          // Yarra Trams (PTV GTFS route_type 0)
  regionalTrain, // V/Line (PTV GTFS route_type 2)
  bus,           // PTV Bus (PTV GTFS route_type 3)
  ferry,         // Port Phillip Ferries (PTV GTFS route_type 4)
}

class PtvColors {
  static const Color metroTrain = Color(0xFF0072CE);
  static const Color yarraTram = Color(0xFF78BE20);
  static const Color vlinePurple = Color(0xFF8F1A95);
  static const Color ptvBus = Color(0xFFFF8200);
  static const Color ferryTeal = Color(0xFF00A3A6);
}

enum ServiceStatus {
  onTime,
  delayed,
  disrupted,
}

class Departure {
  final String destination;
  final String platform;
  final DateTime scheduledTime;
  final int minutesAway;
  final ServiceStatus status;

  const Departure({
    required this.destination,
    required this.platform,
    required this.scheduledTime,
    required this.minutesAway,
    required this.status,
  });
}

class TransitRoute {
  final String id;
  final String routeId; // GTFS route_id
  final String lineCode; // e.g. "96", "BEL", "GEE"
  final String name;
  final TransitType type;
  final Color badgeColor;
  final List<Departure> departures;
  final bool isFavorite;

  const TransitRoute({
    required this.id,
    required this.routeId,
    required this.lineCode,
    required this.name,
    required this.type,
    required this.badgeColor,
    required this.departures,
    this.isFavorite = false,
  });

  /// Resolves standard PTV transit type from GTFS route_type integer.
  static TransitType fromGtfsRouteType(int routeType) {
    switch (routeType) {
      case 0:
        return TransitType.tram;
      case 1:
        return TransitType.metro;
      case 2:
        return TransitType.regionalTrain;
      case 3:
        return TransitType.bus;
      case 4:
        return TransitType.ferry;
      default:
        return TransitType.bus;
    }
  }

  /// Default brand color for PTV transit types.
  static Color ptvBrandColor(TransitType type) {
    switch (type) {
      case TransitType.metro:
        return PtvColors.metroTrain;
      case TransitType.tram:
        return PtvColors.yarraTram;
      case TransitType.regionalTrain:
        return PtvColors.vlinePurple;
      case TransitType.bus:
        return PtvColors.ptvBus;
      case TransitType.ferry:
        return PtvColors.ferryTeal;
    }
  }

  TransitRoute copyWith({bool? isFavorite}) {
    return TransitRoute(
      id: id,
      routeId: routeId,
      lineCode: lineCode,
      name: name,
      type: type,
      badgeColor: badgeColor,
      departures: departures,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class ServiceAlert {
  final String id;
  final String title;
  final String description;
  final String lineCode;
  final DateTime timestamp;
  final ServiceStatus severity;

  const ServiceAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.lineCode,
    required this.timestamp,
    required this.severity,
  });
}
