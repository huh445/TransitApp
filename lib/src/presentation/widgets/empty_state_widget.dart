import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final bool isSavedView;
  final VoidCallback onReset;

  const EmptyStateWidget({
    super.key,
    required this.isSavedView,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.directions_off_rounded,
            size: 52,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(
            isSavedView
                ? 'Save a departure to find it here'
                : 'No departures match your filter',
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: Icon(
              isSavedView
                  ? Icons.directions_transit_rounded
                  : Icons.refresh_rounded,
              size: 16,
            ),
            label: Text(
              isSavedView ? 'View departures' : 'Reset & Reload',
            ),
          ),
        ],
      ),
    );
  }
}
