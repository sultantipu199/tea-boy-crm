import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../services/hive_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/app_theme.dart';
import 'ai_score_badge.dart';
import 'quotation_calculator_dialog.dart';
import 'status_badge.dart';

class LeadCard extends StatelessWidget {
  final Lead lead;
  final VoidCallback onTap;
  final ValueChanged<String>? onStatusChanged;

  const LeadCard({
    super.key,
    required this.lead,
    required this.onTap,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Company Name + Status Badge + Quick Status Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lead.companyName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F4EA),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${lead.estimatedMonthlyValue.toStringAsFixed(0)} SAR/mo',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.saudiEmerald,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            InkWell(
                              onTap: () => WhatsAppService.launchMaps(lead.hub),
                              borderRadius: BorderRadius.circular(4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: AppTheme.royalGold,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    lead.hub,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.slateSurface,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              lead.dateAdded,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            if (lead.isFollowUpDue) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: const Color(0xFFF87171), width: 0.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.alarm,
                                        size: 10, color: Color(0xFFDC2626)),
                                    const SizedBox(width: 2),
                                    Text(
                                      lead.isFollowUpToday
                                          ? 'Follow-up Today'
                                          : 'Follow-up Due',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (lead.followUpDate != null &&
                                lead.followUpDate!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                'Due: ${lead.followUpDate}',
                                style: const TextStyle(
                                    fontSize: 10.5, color: AppTheme.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    initialValue: lead.status,
                    tooltip: 'Change Status',
                    onSelected: (newStatus) async {
                      if (onStatusChanged != null) {
                        onStatusChanged!(newStatus);
                      } else {
                        await HiveService.instance
                            .updateLeadStatus(lead.id, newStatus);
                      }
                    },
                    itemBuilder: (context) => [
                      'New',
                      'Contacted',
                      'Interested',
                      'Closed',
                      'Disqualified'
                    ].map((s) => PopupMenuItem(
                          value: s,
                          child: Row(
                            children: [
                              StatusBadge(status: s),
                              const SizedBox(width: 8),
                              if (s == lead.status)
                                const Icon(Icons.check,
                                    size: 16, color: AppTheme.saudiEmerald),
                            ],
                          ),
                        )).toList(),
                    child: StatusBadge(status: lead.status),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Contact Information & AI Score
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 15,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${lead.contactPerson} (${WhatsAppService.formatForDisplay(lead.saudiMobile)})',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (lead.aiAnalysis != null) ...[
                    AiScoreBadge(score: lead.aiAnalysis!.dealScore),
                  ],
                ],
              ),

              const SizedBox(height: 10),

              // Staffing Requirements Chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: lead.staffingRequirements.map((req) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderGrey),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          req == 'Tea Boy'
                              ? Icons.emoji_food_beverage
                              : req == 'Pantry Staff'
                                  ? Icons.soup_kitchen
                                  : Icons.cleaning_services,
                          size: 12,
                          color: AppTheme.saudiEmerald,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          req,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.slateNavy,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              const Divider(
                  height: 20, thickness: 0.8, color: AppTheme.borderGrey),

              // Bottom Action Row: Call, Quote Calculator, 1-Tap WhatsApp
              Row(
                children: [
                  if (lead.notes.isNotEmpty)
                    Expanded(
                      child: Text(
                        lead.notes,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 8),

                  // Call Phone Action
                  IconButton(
                    icon: const Icon(Icons.phone_outlined,
                        size: 18, color: AppTheme.saudiEmerald),
                    tooltip: 'Direct Phone Call',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () =>
                        WhatsAppService.launchPhoneCall(lead.saudiMobile),
                  ),
                  const SizedBox(width: 10),

                  // Instant Quote Calculator Action
                  IconButton(
                    icon: const Icon(Icons.calculate_outlined,
                        size: 20, color: AppTheme.royalGold),
                    tooltip: 'Instant SAR Quote',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => QuotationCalculatorDialog(lead: lead),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // WhatsApp Dispatch Action
                  ElevatedButton.icon(
                    onPressed: () {
                      final pitch = WhatsAppService.generatePitchTemplate(
                        companyName: lead.companyName,
                        contactPerson: lead.contactPerson,
                        hub: lead.hub,
                        staffing: lead.staffingRequirements,
                      );
                      WhatsAppService.copyScriptAndDispatch(
                        context: context,
                        phone: lead.saudiMobile,
                        message: pitch,
                        companyName: lead.companyName,
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 14),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006C4F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
