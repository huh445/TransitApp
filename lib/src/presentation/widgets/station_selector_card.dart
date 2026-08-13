import 'package:flutter/material.dart';
import '../../data/datasources/gtfs_index_engine.dart';
import '../../domain/entities/station.dart';
import '../../theme/app_theme.dart';

class StationSelectorCard extends StatelessWidget {
  final Station selectedStation;
  final List<Station> stations;
  final ValueChanged<Station> onStationSelected;

  const StationSelectorCard({
    super.key,
    required this.selectedStation,
    required this.stations,
    required this.onStationSelected,
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

    final selectedDropdownValue = combinedStations.firstWhere(
      (s) =>
          s.id == selectedStation.id ||
          s.stopId == selectedStation.stopId ||
          s.name.toLowerCase() == selectedStation.name.toLowerCase(),
      orElse: () => combinedStations.isNotEmpty ? combinedStations.first : selectedStation,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.dividerColor.withAlpha(50),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_rounded,
            color: AppColors.primaryCyan,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Station>(
                value: selectedDropdownValue,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                ),
                items: combinedStations.map((station) {
                  return DropdownMenuItem<Station>(
                    value: station,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            station.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (station.isCityLoop)
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
                    ),
                  );
                }).toList(),
                onChanged: (station) {
                  if (station != null) {
                    onStationSelected(station);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
