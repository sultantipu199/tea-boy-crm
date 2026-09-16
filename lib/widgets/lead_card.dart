import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/lead.dart';
import '../services/dispatch_service.dart';
import '../services/geo_service.dart';
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
    await HapticFeedback.lightImpact();

    // AI personalized script if generated, otherwise corporate pitch
    final message = (lead.aiAnalysis?.followUpMessage.isNotEmpty ?? false)
        ? lead.aiAnalysis!.followUpMessage
        : WhatsAppService.generatePitchTemplate(
            companyName: lead.companyName,
            contactPerson: lead.contactPerson,
            hub: lead.hub,
            staffing: lead.staffingRequirements,
          );

    await Clipboard.setData(ClipboardData(text: message));

    bool shifted = false;
    if (lead.isNew) {
      await StorageService.instance.markLeadContacted(lead.id);
      shifted = true;
      if (onStatusChanged != null) {
        onStatusChanged!('contacted');
      }
    }

    final launched = await DispatchService.launchWhatsApp(
      phone: lead.saudiMobile,
      message: message,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.mintEmerald,
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
                          : 'Pitch script copied to clipboard'),
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

  Future<void> _handleEmailTrigger(BuildContext context) async {
    await HapticFeedback.lightImpact();

    bool shifted = false;
    if (lead.isNew) {
      await StorageService.instance.markLeadContacted(lead.id);
      shifted = true;
      if (onStatusChanged != null) {
        onStatusChanged!('contacted');
      }
    }

    final launched = await DispatchService.launchEmail(
      email: lead.email,
      subject: lead.corporateEmailSubject,
      body: lead.corporateEmailBody,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.royalIris,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.mark_email_read_outlined,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  shifted
                      ? 'Shifted to Contacted & RFC Email opened for ${lead.companyName}'
                      : (launched
                          ? 'RFC Email dispatched to ${lead.email}'
                          : 'Email prepared for ${lead.companyName}'),
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
    final liveDistanceBadge = GeoService.instance.formatDistanceBadge(lead);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: AppTheme.glassBoxDecoration(
        surfaceColor: AppTheme.frostedCharcoalSlate,
        borderColor: isDisqualified
            ? AppTheme.cyberBorderSubtle
            : AppTheme.cyberBorder,
        opacity: 0.85,
        borderRadius: 14,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Proximity Badge Bar & Contract Value
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Live Proximity Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.withAlphaFactor(
                            AppTheme.electricCyan, 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.withAlphaFactor(
                              AppTheme.electricCyan, 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        liveDistanceBadge,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.electricCyan,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    // Monthly Value Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDisqualified
                            ? AppTheme.withAlphaFactor(
                                AppTheme.mutedSilver, 0.1)
                            : AppTheme.withAlphaFactor(
                                AppTheme.mintEmerald, 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDisqualified
                              ? AppTheme.withAlphaFactor(
                                  AppTheme.mutedSilver, 0.3)
                              : AppTheme.withAlphaFactor(
                                  AppTheme.mintEmerald, 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${lead.estimatedMonthlyValue.toStringAsFixed(0)} SAR/mo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDisqualified
                              ? AppTheme.mutedSilver
                              : AppTheme.mintEmerald,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Company Name & Quick Status Menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        lead.companyName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDisqualified
                              ? AppTheme.mutedSilver
                              : AppTheme.crispAlabaster,
                          decoration: isDisqualified
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      initialValue: lead.status,
                      tooltip: 'Change Status',
                      color: AppTheme.frostedCharcoalSlate,
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
                      ]
                          .map((s) => PopupMenuItem(
                                value: s,
                                child: Row(
                                  children: [
                                    StatusBadge(status: s),
                                    const SizedBox(width: 8),
                                    if (s == lead.status)
                                      const Icon(Icons.check,
                                          size: 16,
                                          color: AppTheme.electricCyan),
                                  ],
                                ),
                              ))
                          .toList(),
                      child: StatusBadge(status: lead.status),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Hub & Date Added Row
                Row(
                  children: [
                    InkWell(
                      onTap: () => DispatchService.launchMaps(
                        query: '${lead.hub} Saudi Arabia',
                      ),
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: AppTheme.royalGold,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            lead.hub,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.royalGold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 11,
                      color: AppTheme.mutedSilver,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      lead.dateAdded,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.mutedSilver,
                      ),
                    ),
                    if (lead.isFollowUpDue) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.withAlphaFactor(
                              AppTheme.crimsonAccent, 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppTheme.crimsonAccent,
                            width: 0.6,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.alarm,
                                size: 10, color: AppTheme.crimsonAccent),
                            const SizedBox(width: 2),
                            Text(
                              lead.isFollowUpToday
                                  ? 'Follow-up Today'
                                  : 'Follow-up Due',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.crimsonAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                // Contact Person & Phone & AI Badge
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 14,
                      color: AppTheme.mutedSilver,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${lead.contactPerson} (${WhatsAppService.formatForDisplay(lead.saudiMobile)})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.crispAlabaster,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.withAlphaFactor(
                            AppTheme.obsidianVoid, 0.7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppTheme.cyberBorder, width: 0.8),
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
                            color: AppTheme.electricCyan,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            req,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.crispAlabaster,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                if (lead.contactedAt != null &&
                    lead.contactedAt!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 12, color: AppTheme.amberAccent),
                      const SizedBox(width: 4),
                      Text(
                        'Contacted on ${lead.contactedAt!.split('T').first}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.amberAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],

                const Divider(
                  height: 18,
                  thickness: 0.8,
                  color: AppTheme.cyberBorder,
                ),

                // Bottom Action Row: Call, Quote, Email Channel, 1-Tap WhatsApp Channel
                Row(
                  children: [
                    if (lead.notes.isNotEmpty)
                      Expanded(
                        child: Text(
                          lead.notes,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.mutedSilver,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 6),

                    // Phone Call Action
                    IconButton(
                      icon: const Icon(Icons.phone_outlined,
                          size: 17, color: AppTheme.electricCyan),
                      tooltip: 'Direct Phone Call',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () =>
                          DispatchService.launchCall(lead.saudiMobile),
                    ),
                    const SizedBox(width: 8),

                    // Instant Quotation Calculator
                    IconButton(
                      icon: const Icon(Icons.calculate_outlined,
                          size: 19, color: AppTheme.royalGold),
                      tooltip: 'Instant SAR Quote',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) =>
                            QuotationCalculatorDialog(lead: lead),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 1-Tap RFC Email Channel (Royal Iris Violet #6366F1)
                    IconButton(
                      icon: const Icon(Icons.email_outlined,
                          size: 18, color: AppTheme.royalIris),
                      tooltip: '1-Tap RFC Corporate Email',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _handleEmailTrigger(context),
                    ),
                    const SizedBox(width: 10),

                    // 1-Tap WhatsApp Channel (Bright Mint Emerald #10B981)
                    ElevatedButton.icon(
                      onPressed: () => _handleWhatsAppTrigger(context),
                      icon: const Icon(Icons.send_rounded, size: 13),
                      label: Text(lead.isNew ? 'Pitch' : 'WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.mintEmerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
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
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.03, end: 0);
  }
}
