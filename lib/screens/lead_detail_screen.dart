import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lead.dart';
import '../services/dispatch_service.dart';
import '../services/gemini_service.dart';
import '../services/geo_service.dart';
import '../services/storage_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_score_badge.dart';
import '../widgets/quotation_calculator_dialog.dart';
import '../widgets/status_badge.dart';

class LeadDetailScreen extends StatefulWidget {
  final String leadId;

  const LeadDetailScreen({super.key, required this.leadId});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  late Lead? _lead;
  bool _isAnalyzing = false;
  bool _isReplyLocked = false;
  late TextEditingController _notesController;
  late TextEditingController _clientReplyController;
  Timer? _debounceTimer;
  PitchAngle _selectedPitchAngle = PitchAngle.vipHospitality;

  static const List<String> _allStatuses = [
    'new',
    'contacted',
    'analyzed',
    'interested',
    'closed',
    'disqualified',
  ];

  @override
  void initState() {
    super.initState();
    _loadLead();
    _notesController = TextEditingController(text: _lead?.notes ?? '');
    _clientReplyController =
        TextEditingController(text: _lead?.clientReply ?? '');
    // If analysis exists for reply, lock field
    if (_lead?.clientReply != null && _lead!.clientReply!.isNotEmpty) {
      _isReplyLocked = true;
    }
  }

  void _loadLead() {
    _lead = StorageService.instance.getLeadById(widget.leadId);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _notesController.dispose();
    _clientReplyController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_lead == null) return;
    final updated = _lead!.copyWith(status: newStatus);
    await StorageService.instance.updateLead(updated);
    setState(() {
      _lead = updated;
    });
  }

  Future<void> _saveNotes() async {
    if (_lead == null) return;
    final updated = _lead!.copyWith(notes: _notesController.text.trim());
    await StorageService.instance.updateLead(updated);
    setState(() {
      _lead = updated;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notes updated successfully'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _setFollowUp(String? date) async {
    if (_lead == null) return;
    await StorageService.instance.setFollowUpDate(_lead!.id, date);
    final refreshed = StorageService.instance.getLeadById(_lead!.id);
    setState(() {
      _lead = refreshed;
    });
  }

  Future<void> _pickFollowUpDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.saudiEmerald,
              onPrimary: Colors.white,
              onSurface: AppTheme.slateNavy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await _setFollowUp(picked.toIso8601String().split('T').first);
    }
  }

  /// Auto-trigger on client reply paste (no manual "Submit" button needed)
  void _onClientReplyChanged(String text) {
    if (_isReplyLocked) return;

    _debounceTimer?.cancel();
    final trimmed = text.trim();
    if (trimmed.length < 3) return;

    // Fast-detection for wrong-number phrases or auto-analyze after 650ms debounce
    _debounceTimer = Timer(const Duration(milliseconds: 650), () {
      _autoAnalyzeClientReply(trimmed);
    });
  }

  Future<void> _autoAnalyzeClientReply(String replyText) async {
    if (_lead == null || _isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final analysis = await GeminiService.instance.analyzeClientReply(
        lead: _lead!,
        clientReply: replyText,
      );

      final isWrong = analysis.isWrongContact ||
          analysis.sentiment.toLowerCase().contains('wrong contact');

      Lead updated;
      if (isWrong) {
        // Wrong-Number Guard: Mark disqualified, blacklist permanently
        await StorageService.instance.blacklistContact(
          rawPhone: _lead!.saudiMobile,
          reason: 'Client flagged wrong contact: "$replyText"',
          companyName: _lead!.companyName,
          leadId: _lead!.id,
        );

        updated = _lead!.copyWith(
          status: 'disqualified',
          isBlacklisted: true,
          clientReply: replyText,
          aiAnalysis: analysis,
        );
      } else {
        updated = _lead!.copyWith(
          status: 'analyzed',
          clientReply: replyText,
          followUpDate: analysis.nextFollowUpDate.isNotEmpty
              ? analysis.nextFollowUpDate
              : _lead!.followUpDate,
          aiAnalysis: analysis,
        );
      }

      await StorageService.instance.updateLead(updated);

      setState(() {
        _lead = updated;
        _isReplyLocked = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isWrong
                ? '⚠️ Wrong contact flagged: Lead disqualified & archived to blacklist.'
                : '✅ AI forecast generated: Sentiment categorized as "${analysis.sentiment}".'),
            backgroundColor: isWrong
                ? AppTheme.statusDisqualified
                : AppTheme.saudiEmerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing reply: $e'),
            backgroundColor: AppTheme.statusDisqualified,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  /// 1-Tap: Send Apology & Archive Action for Wrong-Number Contacts
  Future<void> _handleSendApologyAndArchive() async {
    if (_lead == null) return;
    await HapticFeedback.lightImpact();

    const apology = GeminiService.apologyExitMessage;
    await Clipboard.setData(const ClipboardData(text: apology));

    // Ensure permanently blacklisted
    await StorageService.instance.blacklistContact(
      rawPhone: _lead!.saudiMobile,
      reason: 'Wrong Number / Not the person',
      companyName: _lead!.companyName,
      leadId: _lead!.id,
    );

    // Launch WhatsApp with zero-pitch apology
    await WhatsAppService.launchWhatsApp(
      phone: _lead!.saudiMobile,
      message: apology,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Apology message sent & contact permanently archived in blacklist.'),
          backgroundColor: AppTheme.slateNavy,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _deleteLead() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Corporate Lead'),
        content: Text('Are you sure you want to delete ${_lead?.companyName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusDisqualified,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && _lead != null) {
      await StorageService.instance.deleteLead(_lead!.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lead == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lead Not Found')),
        body:
            const Center(child: Text('This lead does not exist in local storage.')),
      );
    }

    final lead = _lead!;
    final isWrong = lead.isBlacklisted ||
        lead.isDisqualified &&
            (lead.aiAnalysis?.isWrongContact ?? false);

    return PopScope(
      canPop: true,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(
            lead.companyName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Delete Lead',
              onPressed: _deleteLead,
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wrong Contact Alert Banner if flagged
                    if (isWrong) _buildWrongContactAlertBanner(),

                    // Company Header Card
                    _buildHeaderCard(lead),

                    const SizedBox(height: 16),

                    // Staffing Requirements & Status Card
                    _buildRequirementsAndStatusCard(lead),

                    const SizedBox(height: 16),

                    // AI Forecasting Engine & Client Reply Auto-Trigger Section
                    _buildAiForecastingSection(lead),

                    const SizedBox(height: 16),

                    // Multi-Angle Pitch Dispatchers (only if not blacklisted)
                    if (!isWrong) ...[
                      _buildPitchDispatchCard(lead),
                      const SizedBox(height: 16),
                    ],

                    // Activity Log Timeline Card
                    _buildActivityTimelineCard(lead),

                    const SizedBox(height: 16),

                    // Notes Card
                    _buildNotesCard(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWrongContactAlertBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.gpp_bad_rounded, color: Color(0xFFDC2626), size: 22),
              SizedBox(width: 8),
              Text(
                'Wrong-Number Guard Flagged',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB91C1C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'The client indicated a misidentified recipient or incorrect phone number. This contact is permanently stored in \'blacklist_contacts\' and will never be scraped or contacted again.',
            style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.3),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: const SelectableText(
              GeminiService.apologyExitMessage,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF991B1B),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleSendApologyAndArchive,
              icon: const Icon(Icons.send_rounded, size: 15),
              label: const Text('1-Tap: Send Apology & Archive (Zero Pitch)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(Lead lead) {
    final proximityBadge = GeoService.instance.formatDistanceBadge(lead);

    return Card(
      elevation: 1,
      color: AppTheme.withAlphaFactor(AppTheme.frostedCharcoalSlate, 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.cyberBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.withAlphaFactor(AppTheme.electricCyan, 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.withAlphaFactor(AppTheme.electricCyan, 0.3),
                    ),
                  ),
                  child: const Icon(Icons.business,
                      color: AppTheme.electricCyan, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.companyName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.crispAlabaster,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.withAlphaFactor(
                                  AppTheme.electricCyan, 0.12),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: AppTheme.withAlphaFactor(
                                    AppTheme.electricCyan, 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              proximityBadge,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.electricCyan,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 12, color: AppTheme.mutedSilver),
                              const SizedBox(width: 3),
                              Text(
                                'Added: ${lead.dateAdded}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.mutedSilver),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: AppTheme.cyberBorder),
            // Contact & Email Rows
            Row(
              children: [
                const Icon(Icons.person, size: 15, color: AppTheme.mutedSilver),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lead.contactPerson.isNotEmpty
                        ? lead.contactPerson
                        : 'Corporate Contact',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.crispAlabaster,
                    ),
                  ),
                ),
                Text(
                  WhatsAppService.formatForDisplay(lead.saudiMobile),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.electricCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.alternate_email,
                    size: 15, color: AppTheme.royalIris),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lead.email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.mutedSilver,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => DispatchService.launchEmail(
                    email: lead.email,
                    subject: lead.corporateEmailSubject,
                    body: lead.corporateEmailBody,
                  ),
                  child: const Text(
                    '1-Tap Email',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.royalIris,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Multi-channel Action Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: AppTheme.electricCyan),
                    ),
                    onPressed: () =>
                        DispatchService.launchCall(lead.saudiMobile),
                    icon: const Icon(Icons.phone,
                        size: 15, color: AppTheme.electricCyan),
                    label: const Text('Call',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.electricCyan)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: AppTheme.royalIris),
                    ),
                    onPressed: () => DispatchService.launchEmail(
                      email: lead.email,
                      subject: lead.corporateEmailSubject,
                      body: lead.corporateEmailBody,
                    ),
                    icon: const Icon(Icons.email_outlined,
                        size: 15, color: AppTheme.royalIris),
                    label: const Text('Email',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.royalIris)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: AppTheme.royalGold),
                    ),
                    onPressed: () => DispatchService.launchMaps(
                      query: '${lead.hub} Saudi Arabia',
                    ),
                    icon: const Icon(Icons.map_outlined,
                        size: 15, color: AppTheme.royalGold),
                    label: const Text('Navigate',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.royalGold)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      backgroundColor: AppTheme.frostedCharcoalSlate,
                      foregroundColor: AppTheme.crispAlabaster,
                    ),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => QuotationCalculatorDialog(lead: lead),
                    ),
                    icon: const Icon(Icons.calculate_outlined,
                        size: 15, color: AppTheme.royalGold),
                    label: const Text('SAR Quote',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.crispAlabaster)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementsAndStatusCard(Lead lead) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Staffing Needs & Pipeline Status',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.slateNavy,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: lead.staffingRequirements.map((req) {
                return Chip(
                  avatar: Icon(
                    req == 'Tea Boy'
                        ? Icons.emoji_food_beverage
                        : req == 'Pantry Staff'
                            ? Icons.soup_kitchen
                            : Icons.cleaning_services,
                    size: 14,
                    color: AppTheme.saudiEmerald,
                  ),
                  label: Text(req,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: const BorderSide(color: AppTheme.borderGrey),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Pipeline Status: ',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: lead.status,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(10),
                  items: _allStatuses.map((s) {
                    return DropdownMenuItem<String>(
                      value: s,
                      child: StatusBadge(status: s),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      _updateStatus(val);
                    }
                  },
                ),
              ],
            ),
            const Divider(height: 24, color: AppTheme.borderGrey),
            // Follow-up Callback Schedule
            Row(
              children: [
                Icon(
                  Icons.alarm,
                  size: 18,
                  color:
                      lead.isFollowUpDue ? Colors.red : AppTheme.saudiEmerald,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.followUpDate != null &&
                                lead.followUpDate!.isNotEmpty
                            ? 'Follow-up: ${lead.followUpDate}'
                            : 'No Follow-up Scheduled',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: lead.isFollowUpDue
                              ? Colors.red
                              : AppTheme.slateNavy,
                        ),
                      ),
                      Text(
                        lead.isFollowUpDue
                            ? '⚠️ Follow-up callback due today or overdue!'
                            : 'Scheduled callback with office manager',
                        style: TextStyle(
                          fontSize: 11,
                          color: lead.isFollowUpDue
                              ? Colors.red
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _pickFollowUpDate(),
                  child: Text(
                    lead.followUpDate == null ? 'Set Date' : 'Change',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (lead.followUpDate != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    tooltip: 'Clear Reminder',
                    onPressed: () => _setFollowUp(null),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// AI Forecasting Engine (Gemini 1.5 Flash) with Auto-Trigger on Paste
  Widget _buildAiForecastingSection(Lead lead) {
    final ai = lead.aiAnalysis;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: ai != null
              ? AppTheme.withAlphaFactor(AppTheme.royalGold, 0.5)
              : AppTheme.cyberBorder,
          width: ai != null ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.auto_awesome,
                        color: AppTheme.royalGold, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'AI Forecasting Engine (Gemini 1.5 Flash)',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.slateNavy,
                      ),
                    ),
                  ],
                ),
                if (ai != null) AiScoreBadge(score: ai.dealScore),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Paste client WhatsApp replies below. Automatically triggers sentiment analysis, objection handling & next steps without manual submit.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),

            // Paste Client Reply Field with Lock/Edit icon
            Container(
              decoration: BoxDecoration(
                color: _isReplyLocked
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isReplyLocked
                      ? AppTheme.borderGrey
                      : AppTheme.saudiEmerald,
                  width: _isReplyLocked ? 1 : 1.5,
                ),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isReplyLocked ? Icons.lock : Icons.content_paste,
                            size: 14,
                            color: _isReplyLocked
                                ? AppTheme.textMuted
                                : AppTheme.saudiEmerald,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isReplyLocked
                                ? 'Client Reply (Locked after Analysis)'
                                : 'Paste Client Reply to Auto-Analyze:',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _isReplyLocked
                                  ? AppTheme.textMuted
                                  : AppTheme.saudiEmerald,
                            ),
                          ),
                        ],
                      ),
                      if (_isReplyLocked)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          tooltip: 'Unlock to edit or re-paste',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() => _isReplyLocked = false);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _clientReplyController,
                    readOnly: _isReplyLocked,
                    maxLines: 3,
                    onChanged: _onClientReplyChanged,
                    decoration: InputDecoration(
                      hintText: _isReplyLocked
                          ? 'Analyzed client reply'
                          : 'Paste WhatsApp reply here e.g. "كم السعر؟", "عندنا شركة حاليا", "غلطان بالرقم"...',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                  if (_isAnalyzing) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.saudiEmerald,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Analyzing reply with Gemini 1.5 Flash...',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.saudiEmerald,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (ai != null) ...[
              const SizedBox(height: 14),
              // Sentiment Tag & Next Follow-Up Date
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ai.isWrongContact
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFE6F4EA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Sentiment: ${ai.sentiment}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ai.isWrongContact
                            ? const Color(0xFFDC2626)
                            : AppTheme.saudiEmerald,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (ai.nextFollowUpDate.isNotEmpty)
                    Text(
                      'Next Action: ${ai.nextFollowUpDate}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Recommended Action
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderGrey),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recommended Action:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.slateNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ai.recommendedAction,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppTheme.textDark),
                    ),
                  ],
                ),
              ),

              if (ai.painPoints.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pain Points & Objections:',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ai.painPoints,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF78350F)),
                      ),
                    ],
                  ),
                ),
              ],

              // Copyable Follow-up Script
              if (ai.followUpMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'Personalized Follow-up Script:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.saudiEmerald,
                            ),
                          ),
                          Icon(Icons.auto_awesome,
                              size: 14, color: AppTheme.royalGold),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        ai.followUpMessage,
                        style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006C4F),
                          ),
                          onPressed: () {
                            WhatsAppService.copyScriptAndDispatch(
                              context: context,
                              phone: lead.saudiMobile,
                              message: ai.followUpMessage,
                              companyName: lead.companyName,
                            );
                          },
                          icon: const Icon(Icons.send_rounded, size: 14),
                          label: const Text('1-Tap: Copy Script & Send WhatsApp'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPitchDispatchCard(Lead lead) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.send_rounded, color: Color(0xFF006C4F), size: 20),
                SizedBox(width: 8),
                Text(
                  'Corporate WhatsApp Pitches',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slateNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Select angle to load pre-drafted corporate pitch with Unicode BiDi isolation:',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('☕ VIP Tea Boy'),
                  selected: _selectedPitchAngle == PitchAngle.vipHospitality,
                  onSelected: (_) => setState(
                      () => _selectedPitchAngle = PitchAngle.vipHospitality),
                ),
                ChoiceChip(
                  label: const Text('🍽️ Pantry Logistics'),
                  selected: _selectedPitchAngle == PitchAngle.pantryLogistics,
                  onSelected: (_) => setState(
                      () => _selectedPitchAngle = PitchAngle.pantryLogistics),
                ),
                ChoiceChip(
                  label: const Text('✨ Night Cleaning'),
                  selected: _selectedPitchAngle == PitchAngle.nightCleaning,
                  onSelected: (_) => setState(
                      () => _selectedPitchAngle = PitchAngle.nightCleaning),
                ),
                ChoiceChip(
                  label: const Text('🎁 3-Day Free Trial'),
                  selected: _selectedPitchAngle == PitchAngle.freeTrial,
                  onSelected: (_) => setState(
                      () => _selectedPitchAngle = PitchAngle.freeTrial),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Builder(builder: (ctx) {
              final angledPitch = WhatsAppService.generateAngledPitch(
                angle: _selectedPitchAngle,
                companyName: lead.companyName,
                contactPerson: lead.contactPerson,
                hub: lead.hub,
                staffing: lead.staffingRequirements,
              );

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderGrey),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      angledPitch,
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.saudiEmerald,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () {
                              WhatsAppService.copyScriptAndDispatch(
                                context: context,
                                phone: lead.saudiMobile,
                                message: angledPitch,
                                companyName: lead.companyName,
                              );
                            },
                            icon: const Icon(Icons.send_rounded, size: 14),
                            label: const Text('1-Tap: Send This Pitch'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                          ),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) =>
                                QuotationCalculatorDialog(lead: lead),
                          ),
                          icon: const Icon(Icons.calculate_outlined, size: 16),
                          label: const Text('SAR Quote'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTimelineCard(Lead lead) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.history_toggle_off_outlined,
                        color: AppTheme.saudiEmerald, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Activity Log & History',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.slateNavy,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (lead.activities.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderGrey),
                ),
                child: const Text(
                  'No interactions logged yet. WhatsApp pitches and calls are automatically recorded.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lead.activities.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 16, color: AppTheme.borderGrey),
                itemBuilder: (context, i) {
                  final act = lead.activities[i];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.withAlphaFactor(AppTheme.mintEmerald, 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chat,
                            size: 14, color: Color(0xFF006C4F)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  act.type,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.slateNavy,
                                  ),
                                ),
                                Text(
                                  act.date,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              act.note,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.slateNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Private Context & Notes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.slateNavy,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'Add private client preferences, shift hours, VIP requirements...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _saveNotes,
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Save Notes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
