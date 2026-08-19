import 'station.dart';
import 'trips.dart';
import '../value_objects/transfer_feasibility.dart';

class LiveConnection {
  final Trip connectingTrip;
  final Station interchangeStation;
  final DateTime currentTrainArrival;
  final DateTime connectingTrainDeparture;
  final Duration buffer;
  final TransferFeasibility feasibility;
  final String platform;

  const LiveConnection({
    required this.connectingTrip,
    required this.interchangeStation,
    required this.currentTrainArrival,
    required this.connectingTrainDeparture,
    required this.buffer,
    required this.feasibility,
    required this.platform,
  });

  factory LiveConnection.calculate({
    required Trip connectingTrip,
    required Station interchangeStation,
    required DateTime currentTrainArrival,
  }) {
    final departureTime = connectingTrip.departure?.scheduledTime ??
        currentTrainArrival.add(const Duration(minutes: 5));
    final buffer = departureTime.difference(currentTrainArrival);
    final feasibility = TransferFeasibility.fromBuffer(buffer);
    final platform = connectingTrip.departure?.platform.isNotEmpty == true
        ? connectingTrip.departure!.platform
        : 'TBD';

    return LiveConnection(
      connectingTrip: connectingTrip,
      interchangeStation: interchangeStation,
      currentTrainArrival: currentTrainArrival,
      connectingTrainDeparture: departureTime,
      buffer: buffer,
      feasibility: feasibility,
      platform: platform,
    );
  }

  int get bufferMinutes => buffer.inMinutes;
}
