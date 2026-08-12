import 'package:flutter/material.dart';

enum TransitType { metro, tram, regionalTrain, bus, ferry }

class PtvColors {
  static const Color metroTrain = Color(0xFF0072CE);
  static const Color yarraTram = Color(0xFF78BE20);
  static const Color vlinePurple = Color(0xFF8F1A95);
  static const Color ptvBus = Color(0xFFFF8200);
  static const Color ferryTeal = Color(0xFF00A3A6);
}

enum ServiceStatus { scheduled, onTime, delayed, disrupted }

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
  final String routeId;
  final String lineCode;
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

  TransitRoute copyWith({
    String? id,
    String? routeId,
    String? lineCode,
    String? name,
    TransitType? type,
    Color? badgeColor,
    List<Departure>? departures,
    bool? isFavorite,
  }) {
    return TransitRoute(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      lineCode: lineCode ?? this.lineCode,
      name: name ?? this.name,
      type: type ?? this.type,
      badgeColor: badgeColor ?? this.badgeColor,
      departures: departures ?? this.departures,
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
