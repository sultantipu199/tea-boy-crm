import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AiScoreBadge extends StatelessWidget {
  final int score;

  const AiScoreBadge({super.key, required this.score});

  Color _getScoreColor() {
    if (score >= 80) return AppTheme.electricCyan;
    if (score >= 60) return AppTheme.amberAccent;
    return AppTheme.crimsonAccent;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getScoreColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.withAlphaFactor(color, 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.withAlphaFactor(color, 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$score%',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
