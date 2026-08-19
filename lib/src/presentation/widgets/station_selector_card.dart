import 'package:flutter/material.dart';
import '../../data/datasources/gtfs_index_engine.dart';
import '../../domain/entities/station.dart';
import '../../theme/app_theme.dart';
import 'station_search_sheet.dart';

class StationSelectorCard extends StatelessWidget {
  final Station selectedStation;
  final List<Station> stations;
  final List<Station> favoriteStations;
  final ValueChanged<Station> onStationSelected;
  final ValueChanged<Station>? onToggleFavorite;

  const StationSelectorCard({
    super.key,
    required this.selectedStation,
    required this.stations,
    this.favoriteStations = const [],
    required this.onStationSelected,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final uniqueById = <String, Station>{};
    final uniqueByName = <String, Station>{};

    for (final s in stations) {
      final cleanName = GtfsIndexEngine.normalizeStationName(s.name);
      final nameKey = cleanName.toLowerCase();
      final idKey = s.id;

      if (uniqueById.containsKey(idKey)) {
        final existing = uniqueById[idKey]!;
        if (s.isCityLoop && !existing.isCityLoop) {
          uniqueById[idKey] = existing.copyWith(isCityLoop: true);
        }
        continue;
      }

      if (uniqueByName.containsKey(nameKey)) {
        final existing = uniqueByName[nameKey]!;
        if (s.isCityLoop && !existing.isCityLoop) {
          uniqueByName[nameKey] = existing.copyWith(isCityLoop: true);
        }
        continue;
      }

      final stationObj = s.copyWith(name: cleanName);
      uniqueById[idKey] = stationObj;
      uniqueByName[nameKey] = stationObj;
    }

    final combinedStations = uniqueById.values.toList();

    final matchingStation = combinedStations.firstWhere(
      (s) =>
          s.id == selectedStation.id ||
          s.stopId == selectedStation.stopId ||
          s.name.toLowerCase() == selectedStation.name.toLowerCase(),
      orElse: () => combinedStations.isNotEmpty ? combinedStations.first : selectedStation,
    );

    final isFav = favoriteStations.any(
      (f) => f.id == matchingStation.id || f.name.toLowerCase() == matchingStation.name.toLowerCase(),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        StationSearchSheet.show(
          context,
          stations: combinedStations.isNotEmpty ? combinedStations : stations,
          selectedStation: matchingStation,
          favoriteStations: favoriteStations,
          onStationSelected: onStationSelected,
          onToggleFavorite: onToggleFavorite ?? (_) {},
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.dividerColor.withAlpha(45),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withAlpha(18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: AppColors.primaryCyan,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT STATION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: theme.textTheme.bodySmall?.color?.withAlpha(150),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          matchingStation.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (matchingStation.isCityLoop) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.melbourneMetro.withAlpha(45),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'City Loop',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.melbourneMetro,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (onToggleFavorite != null) ...[
              IconButton(
                icon: Icon(
                  isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFav ? AppColors.statusAmber : Colors.grey.withAlpha(120),
                ),
                onPressed: () => onToggleFavorite!(matchingStation),
                tooltip: isFav ? 'Unfavorite Station' : 'Favorite Station',
              ),
            ],
            const Icon(
              Icons.search_rounded,
              color: Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
