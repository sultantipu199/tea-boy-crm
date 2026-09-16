import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../theme/app_theme.dart';

class PipelineKpiHeader extends StatelessWidget {
  final List<Lead> leads;

  const PipelineKpiHeader({super.key, required this.leads});

  @override
  Widget build(BuildContext context) {
    final totalLeads = leads.length;
    final hotDeals =
        leads.where((l) => (l.aiAnalysis?.dealScore ?? l.intentScore) >= 75).length;
    final closedDeals = leads.where((l) => l.isClosed).length;

    // Estimate monthly pipeline volume
    double totalMonthlyVal = 0.0;
    for (final l in leads) {
      if (!l.isDisqualified) {
        totalMonthlyVal += l.estimatedMonthlyValue;
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Total Leads KPI
          Expanded(
            child: _buildKpiCard(
              title: 'Active Pipeline',
              value: '$totalLeads',
              subtitle: '$closedDeals Closed',
              icon: Icons.pie_chart_outline,
              accentColor: AppTheme.electricCyan,
            ),
          ),
          const SizedBox(width: 8),
          // Hot AI Deals KPI
          Expanded(
            child: _buildKpiCard(
              title: 'Hot Hubs',
              value: '$hotDeals',
              subtitle: 'Score ≥ 75%',
              icon: Icons.auto_awesome,
              accentColor: AppTheme.amberAccent,
            ),
          ),
          const SizedBox(width: 8),
          // Estimated SAR Pipeline KPI
          Expanded(
            child: _buildKpiCard(
              title: 'Monthly Volume',
              value: '${(totalMonthlyVal / 1000).toStringAsFixed(0)}k SAR',
              subtitle: 'Est. Contracts',
              icon: Icons.monetization_on_outlined,
              accentColor: AppTheme.mintEmerald,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.withAlphaFactor(AppTheme.frostedCharcoalSlate, 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cyberBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedSilver,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Icon(icon, size: 14, color: accentColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.mutedSilver,
            ),
          ),
        ],
      ),
    );
  }
}
