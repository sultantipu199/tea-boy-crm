import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'new':
        return AppTheme.electricCyan;
      case 'contacted':
        return AppTheme.amberAccent;
      case 'analyzed':
        return AppTheme.royalGold;
      case 'interested':
        return AppTheme.mintEmerald;
      case 'closed':
        return AppTheme.royalIris;
      case 'disqualified':
        return AppTheme.crimsonAccent;
      default:
        return AppTheme.mutedSilver;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final displayStatus = status.isEmpty
        ? 'New'
        : status[0].toUpperCase() + status.substring(1).toLowerCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.withAlphaFactor(color, 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.withAlphaFactor(color, 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.withAlphaFactor(color, 0.6),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            displayStatus,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
