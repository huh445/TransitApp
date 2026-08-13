import 'package:flutter/material.dart';
import '../../domain/entities/trips.dart';
import '../../domain/entities/station.dart';
import '../../theme/app_theme.dart';

class TripDetailsSheet extends StatelessWidget {
  final Trip trip;
  final Station selectedStation;

  const TripDetailsSheet({
    super.key,
    required this.trip,
    required this.selectedStation,
  });

  static void show(BuildContext context, {required Trip trip, required Station selectedStation}) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.45,
          builder: (context, scrollController) {
            return TripDetailsSheet(
              trip: trip,
              selectedStation: selectedStation,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final departure = trip.departure;
    final badgeColor = departure == null
        ? AppColors.melbourneBus
        : departure.type.ptvBrandColor;
    final lineCode = departure?.lineCode ?? trip.shortName ?? trip.routeId;
    final scheduledTime = departure?.scheduledTime;
    final timeStr = scheduledTime != null
        ? '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}'
        : '--:--';

    final stops = trip.stops;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withAlpha(80),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  lineCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'To ${trip.destinationName}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (departure?.routeName.isNotEmpty ?? false)
                      Text(
                        departure!.routeName,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withAlpha(150),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerColor.withAlpha(40),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDetailItem(
                  icon: Icons.schedule_rounded,
                  label: 'Departure',
                  value: timeStr,
                  color: AppColors.primaryCyan,
                ),
                _buildDetailItem(
                  icon: Icons.directions_railway_rounded,
                  label: 'Platform',
                  value: departure?.platform.isNotEmpty == true
                      ? 'Plat ${departure!.platform}'
                      : 'TBA',
                  color: AppColors.secondaryIndigo,
                ),
                _buildDetailItem(
                  icon: Icons.flag_rounded,
                  label: 'Terminus',
                  value: trip.destinationName,
                  color: badgeColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Route Stop Sequence (${stops.length} stops)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),

          if (stops.isEmpty) ...[
            _buildTimelineItem(
              title: selectedStation.name,
              subtitle: 'Origin Station • Departs $timeStr',
              isFirst: true,
              isLast: false,
              color: AppColors.primaryCyan,
            ),
            _buildTimelineItem(
              title: trip.destinationName,
              subtitle: 'Terminating Station',
              isFirst: false,
              isLast: true,
              color: badgeColor,
            ),
          ] else ...[
            for (int i = 0; i < stops.length; i++) ...[
              () {
                final stop = stops[i];
                final isFirst = i == 0;
                final isLast = i == stops.length - 1;
                final t = stop.departureTime ?? stop.arrivalTime;
                final tStr = t != null
                    ? '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
                    : '';
                final sub = isFirst
                    ? 'Origin Station • Departs $tStr'
                    : (isLast
                          ? 'Terminus Station • Arrives $tStr'
                          : 'Stop ${i + 1} • $tStr');

                return _buildTimelineItem(
                  title: stop.station.name,
                  subtitle: sub,
                  isFirst: isFirst,
                  isLast: isLast,
                  color: isFirst
                      ? AppColors.primaryCyan
                      : (isLast ? badgeColor : Colors.grey),
                );
              }(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required String subtitle,
    required bool isFirst,
    required bool isLast,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: Colors.grey.withAlpha(80),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
