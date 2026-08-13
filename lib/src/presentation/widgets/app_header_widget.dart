import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppHeaderWidget extends StatelessWidget {
  final bool isLoading;
  final double loadingProgress;
  final int loadingPercentage;
  final String loadingStatus;
  final VoidCallback onRefresh;

  const AppHeaderWidget({
    super.key,
    required this.isLoading,
    this.loadingProgress = 0.0,
    this.loadingPercentage = 0,
    this.loadingStatus = '',
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.primaryCyan,
                    AppColors.secondaryIndigo,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryCyan.withAlpha(90),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_transit_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Melbourne Transit',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                    fontSize: 18,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isLoading
                            ? AppColors.statusAmber
                            : AppColors.statusGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLoading
                          ? '$loadingPercentage% • $loadingStatus'
                          : 'PTV Live Infrastructure',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isLoading
                            ? AppColors.primaryCyan
                            : Colors.grey,
                        fontSize: 12,
                        fontWeight:
                            isLoading ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            if (isLoading)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$loadingPercentage%',
                  style: const TextStyle(
                    color: AppColors.primaryCyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.dividerColor.withAlpha(40),
                ),
              ),
              child: IconButton(
                onPressed: isLoading ? null : onRefresh,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        size: 20,
                      ),
                tooltip: 'Refresh Feed',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
