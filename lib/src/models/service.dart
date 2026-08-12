import 'station.dart';

class ServiceStop {
  final Station station;
  final DateTime? arrivalTime;
  final DateTime? departureTime;
  final String? platform;
  final int stopSequence;

  const ServiceStop({
    required this.station,
    this.arrivalTime,
    this.departureTime,
    this.platform,
    this.stopSequence = 1,
  });
}

class Service {
  final String id;
  final String tripId;
  final String routeId;
  final String serviceNumber; // GTFS short_name or trip headsign
  final String headsign;
  final String? shapeId;
  final Station originStation;
  final Station destinationStation;
  final List<ServiceStop> stops;

  const Service({
    required this.id,
    required this.tripId,
    required this.routeId,
    required this.serviceNumber,
    required this.headsign,
    this.shapeId,
    required this.originStation,
    required this.destinationStation,
    required this.stops,
  });

  /// Departure time at origin station.
  DateTime? get originDepartureTime {
    if (stops.isEmpty) return null;
    return stops.first.departureTime ?? stops.first.arrivalTime;
  }

  /// Arrival time at final destination station.
  DateTime? get destinationArrivalTime {
    if (stops.isEmpty) return null;
    return stops.last.arrivalTime ?? stops.last.departureTime;
  }

  /// Total duration of service trip.
  Duration? get totalDuration {
    final start = originDepartureTime;
    final end = destinationArrivalTime;
    if (start != null && end != null) {
      return end.difference(start);
    }
    return null;
  }
}