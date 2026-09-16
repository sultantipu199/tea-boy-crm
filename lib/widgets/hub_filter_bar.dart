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

          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected && hub != 'All') ...[
                  const Icon(Icons.location_on, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                ],
                Text(hub),
              ],
            ),
            selected: isSelected,
            onSelected: (_) => onHubSelected(hub),
            selectedColor: AppTheme.saudiEmerald,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textDark,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
            side: BorderSide(
              color: isSelected ? AppTheme.saudiEmerald : AppTheme.borderGrey,
              width: 1,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          );
        },
      ),
    );
  }
}
