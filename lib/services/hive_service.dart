import 'package:hive_flutter/hive_flutter.dart';
import '../models/lead.dart';

class HiveService {
  static final HiveService instance = HiveService._internal();
  HiveService._internal();

  static const String _leadsBoxName = 'corporate_leads_box';
  static const String _settingsBoxName = 'crm_settings_box';

  Box<dynamic>? _leadsBox;
  Box<dynamic>? _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _leadsBox = await Hive.openBox<dynamic>(_leadsBoxName);
    _settingsBox = await Hive.openBox<dynamic>(_settingsBoxName);

    // Seed realistic Riyadh corporate leads if the box is empty
    if (_leadsBox!.isEmpty) {
      await seedInitialCorporateLeads();
    }
  }

  Box<dynamic> get leadsBox {
    if (_leadsBox == null || !_leadsBox!.isOpen) {
      throw StateError('Hive leads box is not initialized. Call init() first.');
    }
    return _leadsBox!;
  }

  Box<dynamic> get settingsBox {
    if (_settingsBox == null || !_settingsBox!.isOpen) {
      throw StateError('Hive settings box is not initialized. Call init() first.');
    }
    return _settingsBox!;
  }

  /// Deduplication check: check if composite key already exists
  bool leadExists(String companyName, String rawPhone) {
    final key = Lead.buildCompositeKey(companyName, rawPhone);
    return leadsBox.containsKey(key);
  }

  /// Add lead with strict deduplication: Never overwrite or duplicate existing leads
  Future<bool> addLead(Lead lead) async {
    final key = lead.id;
    if (leadsBox.containsKey(key)) {
      // Deduplication constraint: Lead already exists, abort without overwrite
      return false;
    }
    await leadsBox.put(key, lead.toJson());
    return true;
  }

  /// Update existing lead status, notes, or AI analysis
  Future<void> updateLead(Lead lead) async {
    await leadsBox.put(lead.id, lead.toJson());
  }

  /// Delete lead by composite key
  Future<void> deleteLead(String id) async {
    await leadsBox.delete(id);
  }

  /// Retrieve all leads mapped to Lead model instances
  List<Lead> getAllLeads() {
    final rawValues = leadsBox.values;
    final List<Lead> leads = [];
    for (final val in rawValues) {
      if (val is Map) {
        leads.add(Lead.fromJson(val));
      }
    }
    return leads;
  }

  /// Get lead by ID
  Lead? getLeadById(String id) {
    final val = leadsBox.get(id);
    if (val is Map) {
      return Lead.fromJson(val);
    }
    return null;
  }

  /// Add activity log to lead
  Future<void> addActivity(String leadId, LeadActivity activity) async {
    final lead = getLeadById(leadId);
    if (lead != null) {
      final updatedActivities = List<LeadActivity>.from(lead.activities)..insert(0, activity);
      final updated = lead.copyWith(activities: updatedActivities);
      await updateLead(updated);
    }
  }

  /// Update lead status directly
  Future<void> updateLeadStatus(String leadId, String newStatus) async {
    final lead = getLeadById(leadId);
    if (lead != null) {
      final updated = lead.copyWith(status: newStatus);
      await updateLead(updated);
    }
  }

  /// Update follow up date directly
  Future<void> setFollowUpDate(String leadId, String? followUpDate) async {
    final lead = getLeadById(leadId);
    if (lead != null) {
      final updated = lead.copyWith(followUpDate: followUpDate);
      await updateLead(updated);
    }
  }

  /// Export all leads as standard RFC 4180 CSV string
  String exportToCsv() {
    final leads = getAllLeads();
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('Company Name,Contact Person,Phone,Hub,Staffing Requirements,Status,Date Added,Follow Up Date,Deal Score,Monthly SAR Est,Notes');

    for (final l in leads) {
      final comp = '"${l.companyName.replaceAll('"', '""')}"';
      final contact = '"${l.contactPerson.replaceAll('"', '""')}"';
      final phone = '"${l.saudiMobile}"';
      final hub = '"${l.hub}"';
      final reqs = '"${l.staffingRequirements.join('; ')}"';
      final status = '"${l.status}"';
      final dateAdded = '"${l.dateAdded}"';
      final followUp = '"${l.followUpDate ?? ''}"';
      final score = l.aiAnalysis?.dealScore ?? 0;
      final estMonthly = l.estimatedMonthlyValue.toStringAsFixed(0);
      final notes = '"${l.notes.replaceAll('"', '""').replaceAll('\n', ' ')}"';

      buffer.writeln('$comp,$contact,$phone,$hub,$reqs,$status,$dateAdded,$followUp,$score,$estMonthly,$notes');
    }

    return buffer.toString();
  }

  /// Generate Executive Pipeline Daily Briefing string for 1-tap WhatsApp sharing
  String generatePipelineExecutiveBriefing() {
    final leads = getAllLeads();
    final total = leads.length;
    final hotDeals = leads.where((l) => (l.aiAnalysis?.dealScore ?? 0) >= 75).toList();
    final closed = leads.where((l) => l.status.toLowerCase() == 'closed').length;
    final followUpsDue = leads.where((l) => l.isFollowUpDue).toList();

    double totalMonthlyVal = 0.0;
    final Map<String, int> hubCounts = {};
    for (final l in leads) {
      if (l.status.toLowerCase() != 'disqualified') {
        totalMonthlyVal += l.estimatedMonthlyValue;
        hubCounts[l.hub] = (hubCounts[l.hub] ?? 0) + 1;
      }
    }

    final dateStr = DateTime.now().toIso8601String().split('T').first;

    final hubBreakdown = hubCounts.entries
        .map((e) => '• ${e.key}: ${e.value} leads')
        .join('\n');

    final followUpSection = followUpsDue.isNotEmpty
        ? '\n⚠️ *Follow-ups Due Today / Overdue:* ${followUpsDue.length}\n' +
            followUpsDue.take(4).map((l) => '  - ${l.companyName} (${l.contactPerson} - ${l.saudiMobile})').join('\n')
        : '\n✅ *Follow-ups:* All current calls up to date.';

    return '''
📊 *TEA BOY CRM - Daily Pipeline Briefing*
📍 *Riyadh Corporate Staffing & Hospitality*
📅 Date: $dateStr
━━━━━━━━━━━━━━━━━━━━
📈 *Active Pipeline:* $total Total Leads
🔥 *High-Priority Deals (AI ≥75%):* ${hotDeals.length}
🏆 *Closed Contracts:* $closed
💰 *Estimated Monthly Volume:* ${totalMonthlyVal.toStringAsFixed(0)} SAR / mo (+ 15% VAT)
$followUpSection

🏢 *Distribution by Corporate Hub:*
$hubBreakdown

⚡ Generated directly via TEA BOY Mobile CRM
''';
  }

  /// Get stored Gemini API key
  String? getApiKey() {
    return settingsBox.get('gemini_api_key')?.toString();
  }

  /// Save Gemini API key
  Future<void> saveApiKey(String key) async {
    await settingsBox.put('gemini_api_key', key.trim());
  }

  /// Reset & seed realistic Riyadh corporate staffing leads
  Future<void> seedInitialCorporateLeads() async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .split('T').first;
    final threeDaysAgo = DateTime.now()
        .subtract(const Duration(days: 3))
        .toIso8601String()
        .split('T').first;
    final lastWeek = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String()
        .split('T').first;

    final initialLeads = [
      Lead.create(
        companyName: 'Sanabil Venture Capital',
        contactPerson: 'Sultan Al-Otaibi',
        saudiMobile: '966501234567',
        hub: 'KAFD',
        staffingRequirements: ['Tea Boy', 'Pantry Staff'],
        status: 'Interested',
        notes: 'Requested VIP tea boy fluent in English & Arabic for executive floor.',
        dateAdded: today,
        followUpDate: today,
        activities: [
          LeadActivity(
            id: '1',
            type: 'Call',
            date: '$today 10:30',
            note: 'Spoke with Sultan Al-Otaibi. He requested official quotation for 1 Tea Boy and 1 Pantry Staff.',
          ),
          LeadActivity(
            id: '2',
            type: 'Quotation',
            date: '$today 11:15',
            note: 'Sent formal SAR quote (9,200 SAR/mo including 15% VAT). Awaiting board approval.',
          ),
        ],
      ),
      Lead.create(
        companyName: 'Riyadh Tech Accelerator',
        contactPerson: 'Fahad Al-Zahrani',
        saudiMobile: '966559876543',
        hub: 'Digital City',
        staffingRequirements: ['Cleaners', 'Tea Boy'],
        status: 'Contacted',
        notes: 'Needs 2 office cleaners and 1 tea boy for 3-floor incubator building.',
        dateAdded: today,
        followUpDate: yesterday,
        activities: [
          LeadActivity(
            id: '3',
            type: 'WhatsApp',
            date: '$today 09:15',
            note: 'Sent VIP Hospitality pitch via WhatsApp. Read with blue ticks.',
          ),
        ],
      ),
      Lead.create(
        companyName: 'Al-Rajhi Corporate Tower HQ',
        contactPerson: 'Abdullah Al-Dosari',
        saudiMobile: '966567890123',
        hub: 'King Fahd Rd',
        staffingRequirements: ['Cleaners', 'Pantry Staff'],
        status: 'New',
        notes: 'Looking for full-time cleaning crew (evening shift).',
        dateAdded: yesterday,
      ),
      Lead.create(
        companyName: 'KPMG Strategy Advisory',
        contactPerson: 'Mohammed Al-Ghamdi',
        saudiMobile: '966543210987',
        hub: 'Al Olaya',
        staffingRequirements: ['Tea Boy', 'Pantry Staff'],
        status: 'Closed',
        notes: 'Signed 1-year contract for 2 pantry coordinators and 2 tea boys.',
        dateAdded: threeDaysAgo,
        activities: [
          LeadActivity(
            id: '4',
            type: 'Visit',
            date: '$threeDaysAgo 14:00',
            note: 'In-person meeting at KPMG Tower, Floor 18. Finalized contract terms and uniform requirements.',
          ),
        ],
      ),
      Lead.create(
        companyName: 'Malqa Executive Clinics Group',
        contactPerson: 'Dr. Reem Al-Shehri',
        saudiMobile: '966531122334',
        hub: 'Al Malqa',
        staffingRequirements: ['Cleaners'],
        status: 'Contacted',
        notes: 'Strict medical-grade hygiene compliance required.',
        dateAdded: threeDaysAgo,
      ),
      Lead.create(
        companyName: 'Global Logistics Hub KSA',
        contactPerson: 'Turki Al-Subaie',
        saudiMobile: '966589988776',
        hub: 'Business Gate',
        staffingRequirements: ['Tea Boy', 'Cleaners'],
        status: 'New',
        notes: 'Modern warehouse headquarters near Airport road.',
        dateAdded: lastWeek,
      ),
    ];

    for (final lead in initialLeads) {
      await addLead(lead);
    }
  }
}
