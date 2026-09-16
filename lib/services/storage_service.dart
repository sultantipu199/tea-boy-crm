import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/lead.dart';

class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  static const String leadsBoxName = 'corporate_leads_box';
  static const String blacklistContactsBoxName = 'blacklist_contacts';
  static const String settingsBoxName = 'crm_settings_box';

  Box<dynamic>? _leadsBox;
  Box<dynamic>? _blacklistBox;
  Box<dynamic>? _settingsBox;

  // Real-time revision notifier for reactive UI rebuilding
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<void> init() async {
    await Hive.initFlutter();
    _leadsBox = await Hive.openBox<dynamic>(leadsBoxName);
    _blacklistBox = await Hive.openBox<dynamic>(blacklistContactsBoxName);
    _settingsBox = await Hive.openBox<dynamic>(settingsBoxName);

    // Seed realistic Greater Riyadh corporate hotspot leads if database is empty
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

  Box<dynamic> get blacklistBox {
    if (_blacklistBox == null || !_blacklistBox!.isOpen) {
      throw StateError('Hive blacklist box is not initialized. Call init() first.');
    }
    return _blacklistBox!;
  }

  Box<dynamic> get settingsBox {
    if (_settingsBox == null || !_settingsBox!.isOpen) {
      throw StateError('Hive settings box is not initialized. Call init() first.');
    }
    return _settingsBox!;
  }

  void _notifyChange() {
    revision.value = revision.value + 1;
  }

  /// Strict phone normalization
  String sanitizePhone(String phone) => Lead.sanitizePhone(phone);

  /// Deduplication check: check if composite key already exists
  bool leadExists(String companyName, String rawPhone) {
    final key = Lead.buildCompositeKey(companyName, rawPhone);
    return leadsBox.containsKey(key);
  }

  /// Check if a phone number is permanently blacklisted
  bool isBlacklisted(String rawPhone) {
    final clean = sanitizePhone(rawPhone);
    return blacklistBox.containsKey(clean);
  }

  /// Add lead with strict deduplication and blacklist cross-reference
  Future<bool> addLead(Lead lead) async {
    final cleanPhone = sanitizePhone(lead.saudiMobile);
    if (isBlacklisted(cleanPhone)) {
      // Contact is blacklisted; discard
      return false;
    }

    final key = lead.id;
    if (leadsBox.containsKey(key)) {
      // Deduplication: Lead already exists, abort without overwrite
      return false;
    }

    await leadsBox.put(key, lead.toJson());
    _notifyChange();
    return true;
  }

  /// Update existing lead status, notes, or AI analysis
  Future<void> updateLead(Lead lead) async {
    await leadsBox.put(lead.id, lead.toJson());
    _notifyChange();
  }

  /// Delete lead by composite key
  Future<void> deleteLead(String id) async {
    await leadsBox.delete(id);
    _notifyChange();
  }

  /// Retrieve all leads mapped to Lead model instances
  List<Lead> getAllLeads() {
    final rawValues = leadsBox.values;
    final List<Lead> leads = [];
    for (final val in rawValues) {
      if (val is Map) {
        final lead = Lead.fromJson(val);
        // Exclude if blacklisted
        if (!isBlacklisted(lead.saudiMobile)) {
          leads.add(lead);
        }
      }
    }
    return leads;
  }

  /// Retrieve leads filtered by status ('new', 'contacted', 'analyzed', 'disqualified', etc.)
  List<Lead> getLeadsByStatus(String status) {
    final all = getAllLeads();
    final s = status.toLowerCase();
    return all.where((l) => l.status == s).toList();
  }

  /// Get lead by ID
  Lead? getLeadById(String id) {
    final val = leadsBox.get(id);
    if (val is Map) {
      return Lead.fromJson(val);
    }
    return null;
  }

  /// Instant Status-Shift State Machine:
  /// When WhatsApp button is tapped on a 'new' lead:
  /// Demote status to 'contacted', record contacted_at timestamp, notify listeners
  Future<Lead?> markLeadContacted(String leadId) async {
    final lead = getLeadById(leadId);
    if (lead == null) return null;

    final nowIso = DateTime.now().toIso8601String();
    final updated = lead.copyWith(
      status: 'contacted',
      contactedAt: nowIso,
    );

    // Also append an interaction activity log
    final now = DateTime.now();
    final dateStr =
        '${now.toIso8601String().split('T').first} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final activity = LeadActivity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'WhatsApp',
      date: dateStr,
      note: '1-Tap WhatsApp pitch dispatched to ${lead.contactPerson}. Status shifted to Contacted.',
    );

    final updatedActivities = List<LeadActivity>.from(updated.activities)
      ..insert(0, activity);

    final finalizedLead = updated.copyWith(activities: updatedActivities);
    await leadsBox.put(finalizedLead.id, finalizedLead.toJson());
    _notifyChange();
    return finalizedLead;
  }

  /// Wrong-Number Guard & Local Blacklist Engine:
  /// Permanently record phone number in 'blacklist_contacts' Hive box,
  /// flag lead status as 'disqualified', and exclude from future views/scrapers.
  Future<void> blacklistContact({
    required String rawPhone,
    required String reason,
    String? companyName,
    String? leadId,
  }) async {
    final cleanPhone = sanitizePhone(rawPhone);
    final nowIso = DateTime.now().toIso8601String();

    await blacklistBox.put(cleanPhone, {
      'phone': cleanPhone,
      'reason': reason,
      'company_name': companyName ?? '',
      'date_blacklisted': nowIso,
    });

    // If lead exists in leads box, update status to disqualified and mark isBlacklisted
    if (leadId != null) {
      final lead = getLeadById(leadId);
      if (lead != null) {
        final updated = lead.copyWith(
          status: 'disqualified',
          isBlacklisted: true,
          notes: lead.notes.isEmpty
              ? 'Blacklisted: $reason'
              : '${lead.notes} | Blacklisted: $reason',
        );
        await leadsBox.put(updated.id, updated.toJson());
      }
    } else {
      // Find matching lead by phone
      final all = getAllLeads();
      for (final l in all) {
        if (l.saudiMobile == cleanPhone) {
          final updated = l.copyWith(
            status: 'disqualified',
            isBlacklisted: true,
            notes: l.notes.isEmpty
                ? 'Blacklisted: $reason'
                : '${l.notes} | Blacklisted: $reason',
          );
          await leadsBox.put(updated.id, updated.toJson());
        }
      }
    }

    _notifyChange();
  }

  /// Remove contact from blacklist
  Future<void> removeFromBlacklist(String rawPhone) async {
    final clean = sanitizePhone(rawPhone);
    await blacklistBox.delete(clean);
    _notifyChange();
  }

  /// Retrieve all blacklisted numbers
  List<Map<String, dynamic>> getAllBlacklisted() {
    final list = <Map<String, dynamic>>[];
    for (final key in blacklistBox.keys) {
      final val = blacklistBox.get(key);
      if (val is Map) {
        list.add(Map<String, dynamic>.from(val));
      } else {
        list.add({'phone': key.toString(), 'reason': 'Manual Blacklist'});
      }
    }
    return list;
  }

  /// Add activity log to lead
  Future<void> addActivity(String leadId, LeadActivity activity) async {
    final lead = getLeadById(leadId);
    if (lead != null) {
      final updatedActivities = List<LeadActivity>.from(lead.activities)
        ..insert(0, activity);
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

  /// Update follow-up date directly
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
    buffer.writeln(
        'Company Name,Contact Person,Phone,Zone Cluster,Staffing Requirements,Status,Date Added,Contacted At,Follow Up Date,Deal Score,Monthly SAR Est,Notes');

    for (final l in leads) {
      final comp = '"' + l.companyName.replaceAll('"', '""') + '"';
      final contact = '"' + l.contactPerson.replaceAll('"', '""') + '"';
      final phone = '"' + l.saudiMobile + '"';
      final hub = '"' + l.hub + '"';
      final reqs = '"' + l.staffingRequirements.join('; ') + '"';
      final status = '"' + l.status + '"';
      final dateAdded = '"' + l.dateAdded + '"';
      final contactedAt = '"' + (l.contactedAt ?? '') + '"';
      final followUp = '"' + (l.followUpDate ?? '') + '"';
      final score = l.aiAnalysis?.dealScore ?? l.intentScore;
      final estMonthly = l.estimatedMonthlyValue.toStringAsFixed(0);
      final notes = '"' + l.notes.replaceAll('"', '""').replaceAll('\n', ' ') + '"';

      buffer.writeln(
          '$comp,$contact,$phone,$hub,$reqs,$status,$dateAdded,$contactedAt,$followUp,$score,$estMonthly,$notes');
    }

    return buffer.toString();
  }

  /// Generate Executive Pipeline Daily Briefing string for 1-tap WhatsApp sharing
  String generatePipelineExecutiveBriefing() {
    final leads = getAllLeads();
    final total = leads.length;
    final newLeads = leads.where((l) => l.isNew).length;
    final contacted = leads.where((l) => l.isContacted).length;
    final hotDeals = leads
        .where((l) => (l.aiAnalysis?.dealScore ?? l.intentScore) >= 75)
        .toList();
    final followUpsDue = leads.where((l) => l.isFollowUpDue).toList();

    double totalMonthlyVal = 0.0;
    final Map<String, int> hubCounts = {};
    for (final l in leads) {
      if (!l.isDisqualified) {
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
            followUpsDue
                .take(4)
                .map((l) =>
                    '  - ${l.companyName} (${l.contactPerson} - ${l.saudiMobile})')
                .join('\n')
        : '\n✅ *Follow-ups:* All callbacks up to date.';

    return '''
📊 *TEA BOY CRM - Riyadh Hotspots Pipeline Briefing*
📍 *Corporate Staffing (Cleaners, Pantry Staff, Tea Boys)*
📅 Date: $dateStr
━━━━━━━━━━━━━━━━━━━━
📈 *Active Pipeline:* $total Total Leads
🟢 *New (Unreached):* $newLeads
🟡 *Contacted / In Progress:* $contacted
🔥 *High-Priority Hotspots (Score ≥75%):* ${hotDeals.length}
💰 *Estimated Monthly Volume:* ${totalMonthlyVal.toStringAsFixed(0)} SAR / mo (+ 15% VAT)
$followUpSection

🏢 *Distribution by Riyadh Cluster:*
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

  /// Seed realistic Riyadh corporate offices across the 5X expanded radius
  Future<void> seedInitialCorporateLeads() async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .split('T')
        .first;
    final twoDaysAgo = DateTime.now()
        .subtract(const Duration(days: 2))
        .toIso8601String()
        .split('T')
        .first;

    final initialLeads = [
      Lead.create(
        companyName: 'Sanabil Venture Capital HQ',
        contactPerson: 'Sultan Al-Otaibi',
        saudiMobile: '966501234567',
        hub: 'KAFD Phase 1 & 2',
        staffingRequirements: ['Tea Boy', 'Pantry Staff'],
        status: 'new',
        notes: 'VIP boardroom tea boy fluent in English & Arabic requested for executive floor.',
        dateAdded: today,
        followUpDate: today,
        intentScore: 92,
      ),
      Lead.create(
        companyName: 'Roshn Front Tech Consultancy',
        contactPerson: 'Bandar Al-Amri',
        saudiMobile: '966580011223',
        hub: 'Roshn Front Business Zone',
        staffingRequirements: ['Tea Boy', 'Cleaners'],
        status: 'new',
        notes: 'Newly fitted out physical office requiring full-time hospitality staff.',
        dateAdded: today,
        intentScore: 88,
      ),
      Lead.create(
        companyName: 'Al Narjis Executive Advisory',
        contactPerson: 'Saad Al-Qurashi',
        saudiMobile: '966504433221',
        hub: 'Al Narjis Commercial',
        staffingRequirements: ['Tea Boy', 'Pantry Staff'],
        status: 'new',
        notes: 'New commercial strip branch opening next month. Needs uniform and dedicated staff.',
        dateAdded: today,
        intentScore: 90,
      ),
      Lead.create(
        companyName: 'King Salman Road Corporate Tower',
        contactPerson: 'Fahad Al-Zahrani',
        saudiMobile: '966559876543',
        hub: 'King Salman Road Business Strip',
        staffingRequirements: ['Cleaners', 'Tea Boy'],
        status: 'new',
        notes: 'Needs 2 office cleaners and 1 tea boy for corporate HQ floor.',
        dateAdded: yesterday,
        intentScore: 85,
      ),
      Lead.create(
        companyName: 'Digital City AI Labs',
        contactPerson: 'Hassan Al-Harbi',
        saudiMobile: '966567788990',
        hub: 'Digital City',
        staffingRequirements: ['Tea Boy', 'Cleaners'],
        status: 'contacted',
        contactedAt: '$yesterday 11:20:00',
        notes: 'Pitched VIP hospitality. Client reviewed quotation.',
        dateAdded: yesterday,
        followUpDate: today,
        intentScore: 82,
        activities: [
          LeadActivity(
            id: '101',
            type: 'WhatsApp',
            date: '$yesterday 11:20',
            note: '1-Tap WhatsApp pitch dispatched. Client replied inquiring about trial period.',
          ),
        ],
      ),
      Lead.create(
        companyName: 'Granada Telecom Park Regional HQ',
        contactPerson: 'Turki Al-Subaie',
        saudiMobile: '966589988776',
        hub: 'Granada Business Park',
        staffingRequirements: ['Pantry Staff', 'Cleaners'],
        status: 'contacted',
        contactedAt: '$twoDaysAgo 14:10:00',
        notes: 'Large floor area. In negotiations for 3 cleaners + 1 pantry coordinator.',
        dateAdded: twoDaysAgo,
        intentScore: 80,
      ),
      Lead.create(
        companyName: 'Al Sulay Logistics Distribution Hub',
        contactPerson: 'Mansour Al-Husseini',
        saudiMobile: '966532244556',
        hub: 'Al Sulay Industrial Zone',
        staffingRequirements: ['Cleaners'],
        status: 'new',
        notes: 'Central logistics office. Shift: morning 7 AM - 3 PM.',
        dateAdded: yesterday,
        intentScore: 75,
      ),
      Lead.create(
        companyName: 'KPMG Strategy Advisory Olaya',
        contactPerson: 'Mohammed Al-Ghamdi',
        saudiMobile: '966543210987',
        hub: 'Al Olaya',
        staffingRequirements: ['Tea Boy', 'Pantry Staff'],
        status: 'closed',
        notes: 'Signed 1-year contract for 2 pantry coordinators and 2 tea boys.',
        dateAdded: twoDaysAgo,
        intentScore: 95,
      ),
      Lead.create(
        companyName: 'Al Malqa Executive Clinics Group',
        contactPerson: 'Dr. Reem Al-Shehri',
        saudiMobile: '966531122334',
        hub: 'Al Malqa Office Blocks',
        staffingRequirements: ['Cleaners', 'Tea Boy'],
        status: 'new',
        notes: 'Strict medical-grade hygiene and VIP hospitality in private waiting lounge.',
        dateAdded: today,
        intentScore: 86,
      ),
    ];

    for (final lead in initialLeads) {
      await addLead(lead);
    }
  }
}
