import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'new':
        return AppTheme.statusNew;
      case 'contacted':
        return AppTheme.statusContacted;
      case 'analyzed':
        return AppTheme.royalGold;
      case 'interested':
        return AppTheme.statusInterested;
      case 'closed':
        return AppTheme.statusClosed;
      case 'disqualified':
        return AppTheme.statusDisqualified;
      default:
        return AppTheme.textMuted;
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
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
