import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lead.dart';
import '../models/ai_analysis.dart';
import '../services/gemini_service.dart';
import '../services/hive_service.dart';
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
  late TextEditingController _notesController;
  PitchAngle _selectedPitchAngle = PitchAngle.vipHospitality;

  static const List<String> _allStatuses = [
    'New',
    'Contacted',
    'Interested',
    'Closed',
    'Disqualified',
  ];

  @override
  void initState() {
    super.initState();
    _loadLead();
    _notesController = TextEditingController(text: _lead?.notes ?? '');
  }

  void _loadLead() {
    _lead = HiveService.instance.getLeadById(widget.leadId);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_lead == null) return;
    final updated = _lead!.copyWith(status: newStatus);
    await HiveService.instance.updateLead(updated);
    setState(() {
      _lead = updated;
    });
  }

  Future<void> _saveNotes() async {
    if (_lead == null) return;
    final updated = _lead!.copyWith(notes: _notesController.text.trim());
    await HiveService.instance.updateLead(updated);
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
    await HiveService.instance.setFollowUpDate(_lead!.id, date);
    final refreshed = HiveService.instance.getLeadById(_lead!.id);
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

  void _openLogActivityDialog() {
    String selectedType = 'Call';
    final noteController = TextEditingController();
    String? newStatus;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.edit_note, color: AppTheme.saudiEmerald),
              SizedBox(width: 8),
              Text(
                'Log Sales Interaction',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.slateNavy),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Activity Type:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: ['Call', 'WhatsApp', 'Visit', 'Quotation', 'Note'].map((type) {
                    final isSel = type == selectedType;
                    return ChoiceChip(
                      label: Text(type),
                      selected: isSel,
                      selectedColor: AppTheme.saudiEmerald,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : AppTheme.slateNavy,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setDialogState(() => selectedType = type),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('Interaction Summary / Outcome:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'e.g. Called GM Tariq. Agreed on 2 VIP tea boys for boardroom. Sent SAR quote.',
                    hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Update Status: ', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: newStatus ?? _lead?.status,
                      isDense: true,
                      underline: const SizedBox(),
                      items: _allStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (val) => setDialogState(() => newStatus = val),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (noteController.text.trim().isEmpty) return;
                final now = DateTime.now();
                final dateStr = '${now.toIso8601String().split('T').first} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                final activity = LeadActivity(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  type: selectedType,
                  date: dateStr,
                  note: noteController.text.trim(),
                );

                await HiveService.instance.addActivity(_lead!.id, activity);
                if (newStatus != null && newStatus != _lead!.status) {
                  await HiveService.instance.updateLeadStatus(_lead!.id, newStatus!);
                }

                final refreshed = HiveService.instance.getLeadById(_lead!.id);
                setState(() {
                  _lead = refreshed;
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.saudiEmerald, foregroundColor: Colors.white),
              child: const Text('Save Activity'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAiAnalysis() async {
    if (_lead == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final analysis = await GeminiService.instance.analyzeLead(lead: _lead!);
      final updated = _lead!.copyWith(aiAnalysis: analysis);
      await HiveService.instance.updateLead(updated);
      setState(() {
        _lead = updated;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI Deal Forecast & Pitch generated successfully!'),
            backgroundColor: AppTheme.saudiEmerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating forecast: $e'),
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
      await HiveService.instance.deleteLead(_lead!.id);
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
        body: const Center(child: Text('This lead does not exist in local storage.')),
      );
    }

    final lead = _lead!;

    return Scaffold(
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
              // Company Header Card
              _buildHeaderCard(lead),

              const SizedBox(height: 16),

              // Staffing Requirements & Status Card
              _buildRequirementsAndStatusCard(lead),

              const SizedBox(height: 16),

              // AI Forecasting Engine Section
              _buildAiSection(lead),

              const SizedBox(height: 16),

              // Pitch Dispatchers Card
              _buildPitchDispatchCard(lead),

              const SizedBox(height: 16),

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
    );
  }

  Widget _buildHeaderCard(Lead lead) {
    return Card(
      elevation: 1,
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
                    color: AppTheme.saudiEmerald.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.business, color: AppTheme.saudiEmerald, size: 24),
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
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: AppTheme.royalGold),
                          const SizedBox(width: 4),
                          Text(
                            lead.hub,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.slateSurface,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.calendar_today, size: 13, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Added: ${lead.dateAdded}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: AppTheme.borderGrey),
            // Contact Row
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lead.contactPerson.isNotEmpty ? lead.contactPerson : 'Key Decision Maker',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  WhatsAppService.formatForDisplay(lead.saudiMobile),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.saudiEmerald,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: AppTheme.saudiEmerald),
                    ),
                    onPressed: () =>
                        WhatsAppService.launchPhoneCall(lead.saudiMobile),
                    icon: const Icon(Icons.phone, size: 15, color: AppTheme.saudiEmerald),
                    label: const Text('Call',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.saudiEmerald)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: AppTheme.royalGold),
                    ),
                    onPressed: () => WhatsAppService.launchMaps(lead.hub),
                    icon: const Icon(Icons.map_outlined,
                        size: 15, color: AppTheme.royalGold),
                    label: const Text('Navigate',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.royalGold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      backgroundColor: AppTheme.slateNavy,
                    ),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => QuotationCalculatorDialog(lead: lead),
                    ),
                    icon: const Icon(Icons.calculate_outlined,
                        size: 15, color: Colors.white),
                    label: const Text('SAR Quote',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
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
              'Staffing Needs & Pipeline Stage',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.slateNavy,
              ),
            ),
            const SizedBox(height: 12),
            // Staffing Requirements Chips
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
                  label: Text(req, style: const TextStyle(fontWeight: FontWeight.w600)),
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: const BorderSide(color: AppTheme.borderGrey),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Current Status: ',
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
                  color: lead.isFollowUpDue ? Colors.red : AppTheme.saudiEmerald,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.followUpDate != null && lead.followUpDate!.isNotEmpty
                            ? 'Follow-up: ${lead.followUpDate}'
                            : 'No Follow-up Scheduled',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: lead.isFollowUpDue ? Colors.red : AppTheme.slateNavy,
                        ),
                      ),
                      Text(
                        lead.isFollowUpDue
                            ? '⚠️ Action required: Follow-up is due today or overdue!'
                            : 'Scheduled callback with client',
                        style: TextStyle(
                          fontSize: 11,
                          color: lead.isFollowUpDue ? Colors.red : AppTheme.textMuted,
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

  Widget _buildAiSection(Lead lead) {
    final ai = lead.aiAnalysis;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: ai != null ? AppTheme.royalGold.withOpacity(0.5) : AppTheme.borderGrey,
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
                    Icon(Icons.auto_awesome, color: AppTheme.royalGold, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Gemini 1.5 Flash Forecast',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.slateNavy,
                      ),
                    ),
                  ],
                ),
                if (ai != null) AiScoreBadge(score: ai.dealScore),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'AI analyzes Riyadh market hub, staffing tiers, and pain points to calculate conversion probability.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            if (ai != null) ...[
              // Sentiment & Follow Up Date
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.saudiEmerald.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Sentiment: ${ai.sentiment}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.saudiEmerald,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (ai.nextFollowUpDate.isNotEmpty)
                    Text(
                      'Target Date: ${ai.nextFollowUpDate}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Recommended Action
              Container(
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
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Pain Points
              if (ai.painPoints.isNotEmpty) ...[
                const Text(
                  'Identified Pain Points:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ...ai.painPoints.map(
                  (pt) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: AppTheme.statusDisqualified)),
                        Expanded(
                          child: Text(
                            pt,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ai != null ? AppTheme.slateNavy : AppTheme.saudiEmerald,
                ),
                onPressed: _isAnalyzing ? null : _runAiAnalysis,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(
                  _isAnalyzing
                      ? 'Analyzing with Gemini...'
                      : ai == null
                          ? 'Generate Deal Forecast & AI Pitch'
                          : 'Re-Analyze Deal Forecast',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPitchDispatchCard(Lead lead) {
    final ai = lead.aiAnalysis;
    final standardPitch = WhatsAppService.generatePitchTemplate(
      companyName: lead.companyName,
      contactPerson: lead.contactPerson,
      hub: lead.hub,
      staffing: lead.staffingRequirements,
    );

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
                  'Multilingual WhatsApp Dispatcher',
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
              'Pre-formatted Saudi enterprise copy with Unicode BiDi isolation to prevent Arabic/English layout mixing.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),

            // AI Personalized Pitch (if available)
            if (ai != null && ai.followUpMessage.isNotEmpty) ...[
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
                          'AI Tailored Script (Arabic/English):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.saudiEmerald,
                          ),
                        ),
                        Icon(Icons.auto_awesome, size: 14, color: AppTheme.royalGold),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      WhatsAppService.isolateBiDi(ai.followUpMessage),
                      style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.textDark),
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
                        icon: const Icon(Icons.send_rounded, size: 15),
                        label: const Text('1-Tap: Copy AI Pitch & Launch WhatsApp'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Targeted Multi-Angle Pitch Selector
            const Text(
              'Select Corporate Pitch Angle:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
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
                  label: const Text('🎁 1-Week Free Trial'),
                  selected: _selectedPitchAngle == PitchAngle.freeTrial,
                  onSelected: (_) =>
                      setState(() => _selectedPitchAngle = PitchAngle.freeTrial),
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
                    Text(
                      angledPitch,
                      style: const TextStyle(
                          fontSize: 12, height: 1.4, color: AppTheme.textDark),
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
                    Icon(Icons.history_toggle_off_outlined, color: AppTheme.saudiEmerald, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Activity Log & Interactions',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.slateNavy,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _openLogActivityDialog,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Log Action'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.saudiEmerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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
                  'No interactions logged yet. Tap "+ Log Action" after calling the client, visiting their office, or sending WhatsApp proposals.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lead.activities.length,
                separatorBuilder: (_, __) => const Divider(height: 16, color: AppTheme.borderGrey),
                itemBuilder: (context, i) {
                  final act = lead.activities[i];
                  IconData icon;
                  Color color;
                  switch (act.type) {
                    case 'Call':
                      icon = Icons.phone;
                      color = AppTheme.saudiEmerald;
                      break;
                    case 'WhatsApp':
                      icon = Icons.chat;
                      color = const Color(0xFF25D366);
                      break;
                    case 'Visit':
                      icon = Icons.location_city;
                      color = AppTheme.royalGold;
                      break;
                    case 'Quotation':
                      icon = Icons.receipt_long;
                      color = AppTheme.slateNavy;
                      break;
                    default:
                      icon = Icons.notes;
                      color = AppTheme.textMuted;
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 14, color: color),
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: color,
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
              'Sales Notes & Context',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.slateNavy,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Add private context, client preferences, shift hours...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
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
