import 'package:flutter/material.dart';
import '../../domain/entities/station.dart';
import '../../domain/entities/transit_route.dart';
import '../../theme/app_theme.dart';

class DisruptionsScreen extends StatelessWidget {
  final List<ServiceAlert> alerts;
  final List<Station> favoriteStations;
  final Station selectedStation;
  final bool isLoading;
  final VoidCallback onRefresh;

  const DisruptionsScreen({
    super.key,
    required this.alerts,
    this.favoriteStations = const [],
    required this.selectedStation,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFavorites = favoriteStations.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Station Disruptions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: isLoading ? null : onRefresh,
            tooltip: 'Refresh Alerts',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        color: AppColors.primaryCyan,
        child: CustomScrollView(
          slivers: [
            // Favorites Context Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.dividerColor.withAlpha(40),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: AppColors.statusAmber,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasFavorites
                                ? 'MONITORING FAVORITE STATIONS'
                                : 'MONITORING CURRENT STATION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: theme.textTheme.bodySmall?.color?.withAlpha(160),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (hasFavorites)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: favoriteStations.map((st) {
                            return Chip(
                              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              avatar: const Icon(
                                Icons.train_rounded,
                                size: 14,
                                color: AppColors.primaryCyan,
                              ),
                              label: Text(
                                st.name,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: AppColors.primaryCyan.withAlpha(20),
                              side: BorderSide(
                                color: AppColors.primaryCyan.withAlpha(50),
                              ),
                            );
                          }).toList(),
                        )
                      else
                        Text(
                          'Showing alerts for ${selectedStation.name}. Star stations in search to monitor their disruptions here.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodyMedium?.color?.withAlpha(180),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            if (alerts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.statusGreen.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            size: 56,
                            color: AppColors.statusGreen,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'No Active Disruptions',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasFavorites
                              ? 'All lines serving your favorite stations are operating normally.'
                              : 'No active disruptions reported for ${selectedStation.name}.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final alert = alerts[index];
                      final status = alert.severity;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: status.color.withAlpha(28),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(18),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryCyan,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    alert.lineCode,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: status.color.withAlpha(28),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Text(
                                    status.label,
                                    style: TextStyle(
                                      color: status.color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              alert.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            if (alert.description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                alert.description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withAlpha(200),
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                    childCount: alerts.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
