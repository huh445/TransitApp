import 'package:flutter/material.dart';
import '../../domain/value_objects/transit_type.dart';

class ModeFilterBar extends StatelessWidget {
  final TransitType? selectedTypeFilter;
  final ValueChanged<TransitType?> onModeSelected;

  const ModeFilterBar({
    super.key,
    required this.selectedTypeFilter,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All Modes'),
            selected: selectedTypeFilter == null,
            onSelected: (selected) {
              if (selected) {
                onModeSelected(null);
              }
            },
          ),
          const SizedBox(width: 8),
          ...TransitType.values
              .where((type) => type != TransitType.ferry)
              .map((type) {
            final isSelected = selectedTypeFilter == type;
            final brandColor = type.ptvBrandColor;

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                avatar: Icon(
                  type.icon,
                  size: 18,
                  color: isSelected ? Colors.white : brandColor,
                ),
                label: Text(type.displayName),
                selected: isSelected,
                selectedColor: brandColor,
                onSelected: (selected) {
                  onModeSelected(selected ? type : null);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
