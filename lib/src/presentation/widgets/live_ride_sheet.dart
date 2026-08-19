import 'package:flutter/material.dart';
import '../../domain/entities/live_connection.dart';
import '../../domain/entities/station.dart';
import '../../theme/app_theme.dart';
import '../state/transit_view_model.dart';

class LiveRideSheet extends StatelessWidget {
  final TransitViewModel viewModel;

  const LiveRideSheet({super.key, required this.viewModel});

  static void show(BuildContext context, TransitViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ListenableBuilder(
        listenable: viewModel,
        builder: (ctx, _) => LiveRideSheet(viewModel: viewModel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trip = viewModel.activeTrackedTrip;

    if (trip == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(child: Text('No active service being tracked')),
      );
    }

    final onBoardStation = viewModel.onBoardStation;
    final nextStation = viewModel.nextStopStation;
    final connectionsByStation = viewModel.upcomingConnections;
    final isLoadingConnections = viewModel.isLoadingConnections;

    final lineCode = trip.departure?.lineCode.isNotEmpty == true
        ? trip.departure!.lineCode
        : 'METRO';
    final destination = trip.destinationName;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor.withAlpha(60),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.statusGreen.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.statusGreen, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.statusGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'LIVE ON-BOARD',
                            style: TextStyle(
                              color: AppColors.statusGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryCyan,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        lineCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    viewModel.stopTracking();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.stop_circle_outlined, size: 18, color: AppColors.statusRose),
                  label: const Text('End Tracking', style: TextStyle(color: AppColors.statusRose, fontSize: 13)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Service to $destination',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                // Next Stop Callout Card
                if (nextStation != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryCyan.withAlpha(35),
                          AppColors.secondaryIndigo.withAlpha(25),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.primaryCyan.withAlpha(80),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryCyan.withAlpha(50),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.directions_railway_rounded,
                            color: AppColors.primaryCyan,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'APPROACHING NEXT STOP',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: AppColors.primaryCyan,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                nextStation.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              if (onBoardStation != null && onBoardStation.id != nextStation.id) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Departed: ${onBoardStation.name}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textTheme.bodySmall?.color?.withAlpha(160),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Connection Advisory Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'UPCOMING STOPS & CONNECTIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: theme.textTheme.bodySmall?.color?.withAlpha(160),
                      ),
                    ),
                    if (isLoadingConnections)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        onPressed: viewModel.refreshUpcomingConnections,
                        tooltip: 'Refresh Connections',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stops & Connection Cards List
                if (trip.stops.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('No intermediate stopping points available for this run.'),
                  )
                else
                  ...trip.stops.map((serviceStop) {
                    final station = serviceStop.station;
                    final connections = connectionsByStation[station.name] ?? [];

                    return _buildStopConnectionTile(
                      context: context,
                      theme: theme,
                      station: station,
                      platform: serviceStop.platform ?? '',
                      departureTime: serviceStop.departureTime,
                      connections: connections,
                      isNextStop: nextStation?.name == station.name,
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopConnectionTile({
    required BuildContext context,
    required ThemeData theme,
    required Station station,
    required String platform,
    required DateTime? departureTime,
    required List<LiveConnection> connections,
    required bool isNextStop,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isNextStop
              ? AppColors.primaryCyan
              : theme.dividerColor.withAlpha(35),
          width: isNextStop ? 1.5 : 1.0,
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isNextStop || connections.isNotEmpty,
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isNextStop
                  ? AppColors.primaryCyan.withAlpha(30)
                  : theme.dividerColor.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.train_rounded,
              color: isNextStop ? AppColors.primaryCyan : Colors.grey,
              size: 18,
            ),
          ),
          title: Text(
            station.name,
            style: TextStyle(
              fontWeight: isNextStop ? FontWeight.bold : FontWeight.w600,
              fontSize: 15,
              color: isNextStop ? AppColors.primaryCyan : null,
            ),
          ),
          subtitle: Row(
            children: [
              if (platform.isNotEmpty) ...[
                Text('Plat $platform', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
              ],
              if (departureTime != null)
                Text(
                  '${departureTime.hour.toString().padLeft(2, '0')}:${departureTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              const SizedBox(width: 8),
              if (connections.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.statusGreen.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${connections.length} Connections',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.statusGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          children: [
            if (connections.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No immediate train transfers at this stop.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    ...connections.map((conn) => _buildConnectionCard(theme, conn)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(ThemeData theme, LiveConnection conn) {
    final feasibility = conn.feasibility;
    final lineCode = conn.connectingTrip.departure?.lineCode.isNotEmpty == true
        ? conn.connectingTrip.departure!.lineCode
        : conn.connectingTrip.headsign;
    final depTime = conn.connectingTrainDeparture;
    final timeStr = '${depTime.hour.toString().padLeft(2, '0')}:${depTime.minute.toString().padLeft(2, '0')}';
    final bufferMins = conn.bufferMinutes;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: feasibility.color.withAlpha(60),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      lineCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'to ${conn.connectingTrip.destinationName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Text(
                timeStr,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Plat ${conn.platform}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              // Feasibility Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: feasibility.color.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: feasibility.color, width: 1.0),
                ),
                child: Row(
                  children: [
                    Icon(feasibility.icon, size: 12, color: feasibility.color),
                    const SizedBox(width: 4),
                    Text(
                      '${feasibility.label} ($bufferMins min)',
                      style: TextStyle(
                        color: feasibility.color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            feasibility.advisory,
            style: TextStyle(
              fontSize: 11,
              color: theme.textTheme.bodySmall?.color?.withAlpha(170),
            ),
          ),
        ],
      ),
    );
  }
}
