import 'package:flutter/material.dart';
import '../models/zones.dart';
import '../theme/app_theme.dart';

class HubFilterBar extends StatelessWidget {
  final String selectedHub;
  final Function(String hub) onHubSelected;

  static List<String> get hubs => ['All', ...RiyadhZones.allClusterNames];

  const HubFilterBar({
    super.key,
    required this.selectedHub,
    required this.onHubSelected,
  });

  @override
  Widget build(BuildContext context) {
    final list = hubs;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final hub = list[index];
          final isSelected = hub == selectedHub;
          final isRiyadh = RiyadhZones.isPrimaryRiyadhHub(hub);

          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected && hub != 'All') ...[
                  const Icon(Icons.location_on, size: 14, color: AppTheme.obsidianVoid),
                  const SizedBox(width: 4),
                ] else if (hub != 'All') ...[
                  Icon(
                    isRiyadh ? Icons.location_city : Icons.hub_outlined,
                    size: 13,
                    color: isRiyadh ? AppTheme.electricCyan : AppTheme.royalIris,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(hub),
              ],
            ),
            selected: isSelected,
            onSelected: (_) => onHubSelected(hub),
            selectedColor: AppTheme.electricCyan,
            backgroundColor: AppTheme.withAlphaFactor(AppTheme.frostedCharcoalSlate, 0.85),
            labelStyle: TextStyle(
              color: isSelected ? AppTheme.obsidianVoid : AppTheme.crispAlabaster,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
            side: BorderSide(
              color: isSelected ? AppTheme.electricCyan : AppTheme.cyberBorder,
              width: 1,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          );
        },
      ),
    );
  }
}
