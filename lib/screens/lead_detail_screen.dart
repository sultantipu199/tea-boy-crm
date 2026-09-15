import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lead.dart';
import '../models/ai_analysis.dart';
import '../services/gemini_service.dart';
import '../services/hive_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_score_badge.dart';
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

              // Notes Card
              _buildNotesCard(),

              const SizedBox(height: 32),
            ],
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

            // Standard Staffing Pitch
            ExpansionTile(
              title: const Text(
                'View Standard Staffing Pitch',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              tilePadding: EdgeInsets.zero,
              children: [
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
                      Text(
                        standardPitch,
                        style: const TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            WhatsAppService.copyScriptAndDispatch(
                              context: context,
                              phone: lead.saudiMobile,
                              message: standardPitch,
                              companyName: lead.companyName,
                            );
                          },
                          icon: const Icon(Icons.copy_all, size: 15),
                          label: const Text('Copy Standard Script & Launch WhatsApp'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
              'Internal Account Notes',
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
