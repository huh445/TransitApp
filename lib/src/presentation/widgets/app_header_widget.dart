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
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryCyan,
                    AppColors.secondaryIndigo,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryCyan.withAlpha(100),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_transit_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Interchange',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    fontSize: 20,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isLoading
                            ? AppColors.statusAmber
                            : AppColors.statusGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: isLoading
                                ? AppColors.statusAmber.withAlpha(100)
                                : AppColors.statusGreen.withAlpha(100),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isLoading
                          ? '$loadingPercentage% • Syncing...'
                          : 'Real-Time Feed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isLoading
                            ? AppColors.primaryCyan
                            : AppColors.statusGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
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
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan.withAlpha(35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryCyan.withAlpha(80),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$loadingPercentage%',
                  style: const TextStyle(
                    color: AppColors.primaryCyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF1F2B47)
                    : const Color(0xFFEDF2F9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF2A3A56)
                      : const Color(0xFFD0DDE8),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: isLoading ? null : onRefresh,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryCyan,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        size: 22,
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

