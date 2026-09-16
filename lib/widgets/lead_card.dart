import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lead.dart';
import '../services/storage_service.dart';
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

  Future<void> _handleWhatsAppTrigger(BuildContext context) async {
    // 1. Light haptic feedback
    await HapticFeedback.lightImpact();

    // 2. Determine message copy (use AI personalized script if generated, otherwise VIP corporate pitch)
    final message = (lead.aiAnalysis?.followUpMessage.isNotEmpty ?? false)
        ? lead.aiAnalysis!.followUpMessage
        : WhatsAppService.generatePitchTemplate(
            companyName: lead.companyName,
            contactPerson: lead.contactPerson,
            hub: lead.hub,
            staffing: lead.staffingRequirements,
          );

    // 3. Copy script to clipboard
    await Clipboard.setData(ClipboardData(text: message));

    // 4. Instant Status-Shift State Machine:
    // If status is 'new', instantly demote to 'contacted', record contacted_at timestamp
    bool shifted = false;
    if (lead.isNew) {
      await StorageService.instance.markLeadContacted(lead.id);
      shifted = true;
      if (onStatusChanged != null) {
        onStatusChanged!('contacted');
      }
    }

    // 5. Launch native WhatsApp intent
    final launched = await WhatsAppService.launchWhatsApp(
      phone: lead.saudiMobile,
      message: message,
    );

    // 6. Brief confirmation SnackBar
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF006C4F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  shifted
                    ? 'Shifted to Contacted & WhatsApp launched for ${lead.companyName}'
                    : (launched
                        ? 'WhatsApp launched for ${lead.companyName}'
                        : 'Pitch copied to clipboard'),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisqualified = lead.isDisqualified;

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
              // Header: Company Name + Monthly SAR Value + Quick Status Menu
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
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDisqualified
                                      ? AppTheme.textMuted
                                      : AppTheme.textDark,
                                  decoration: isDisqualified
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDisqualified
                                    ? Colors.grey.shade100
                                    : const Color(0xFFE6F4EA),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${lead.estimatedMonthlyValue.toStringAsFixed(0)} SAR/mo',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDisqualified
                                      ? AppTheme.textMuted
                                      : AppTheme.saudiEmerald,
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
                                      color: const Color(0xFFF87171),
                                      width: 0.5),
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
                        await StorageService.instance
                            .updateLeadStatus(lead.id, newStatus);
                      }
                    },
                    itemBuilder: (context) => [
                      'new',
                      'contacted',
                      'analyzed',
                      'interested',
                      'closed',
                      'disqualified'
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

              const SizedBox(height: 10),

              // Contact Information & AI / Intent Score
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
                  if (lead.aiAnalysis != null)
                    AiScoreBadge(score: lead.aiAnalysis!.dealScore)
                  else
                    AiScoreBadge(score: lead.intentScore),
                ],
              ),

              const SizedBox(height: 8),

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

              if (lead.contactedAt != null && lead.contactedAt!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 12, color: AppTheme.statusContacted),
                    const SizedBox(width: 4),
                    Text(
                      'Contacted on ${lead.contactedAt!.split('T').first}',
                      style: const TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.statusContacted,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],

              const Divider(
                  height: 18, thickness: 0.8, color: AppTheme.borderGrey),

              // Bottom Action Row: Call, SAR Quote, Instant 1-Tap WhatsApp Trigger
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

                  // Call Phone
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

                  // Instant SAR Quotation Calculator
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

                  // 1-Tap Trigger WhatsApp Action
                  ElevatedButton.icon(
                    onPressed: () => _handleWhatsAppTrigger(context),
                    icon: const Icon(Icons.send_rounded, size: 14),
                    label: Text(lead.isNew ? 'Pitch' : 'WhatsApp'),
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
