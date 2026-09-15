import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../services/whatsapp_service.dart';
import '../theme/app_theme.dart';
import 'ai_score_badge.dart';
import 'status_badge.dart';

class LeadCard extends StatelessWidget {
  final Lead lead;
  final VoidCallback onTap;

  const LeadCard({
    super.key,
    required this.lead,
    required this.onTap,
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
              // Header: Company Name + Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.companyName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppTheme.royalGold,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              lead.hub,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.slateSurface,
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
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: lead.status),
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

              const Divider(height: 20, thickness: 0.8, color: AppTheme.borderGrey),

              // Bottom Action Row: 1-Tap "Copy Script & Launch WhatsApp"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
