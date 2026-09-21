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
  static const String processedLeadsBoxName = 'processed_leads';

  Box<dynamic>? _leadsBox;
  Box<dynamic>? _blacklistBox;
  Box<dynamic>? _settingsBox;
  Box<dynamic>? _processedLeadsBox;

  // Real-time revision notifier for reactive UI rebuilding
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  // In-Memory Fast Lookup Index for Absolute Deduplication
  final Set<String> _knownPhones = <String>{};
  final Set<String> _knownPlaceIds = <String>{};
  final Set<String> _knownCompanyNames = <String>{};
  final Set<String> _knownHashes = <String>{};

  void _indexLead(Lead lead, [String? hashKey]) {
    final cleanPhone = sanitizePhone(lead.saudiMobile);
    if (cleanPhone.isNotEmpty) _knownPhones.add(cleanPhone);

    final placeId = lead.placeId?.trim();
    if (placeId != null && placeId.isNotEmpty) _knownPlaceIds.add(placeId);

    final normName = Lead.normalizeCompanyName(lead.companyName);
    if (normName.isNotEmpty) _knownCompanyNames.add(normName);

    if (hashKey != null && hashKey.isNotEmpty) _knownHashes.add(hashKey);
    if (lead.hashKey != null && lead.hashKey!.isNotEmpty) {
      _knownHashes.add(lead.hashKey!);
    }
    if (lead.id.isNotEmpty) _knownHashes.add(lead.id);

    final compKey = Lead.buildCompositeKey(lead.companyName, cleanPhone);
    _knownHashes.add(compKey);
  }

  void _rebuildDedupIndex() {
    _knownPhones.clear();
    _knownPlaceIds.clear();
    _knownCompanyNames.clear();
    _knownHashes.clear();

    if (_leadsBox != null && _leadsBox!.isOpen) {
      for (final key in _leadsBox!.keys) {
        _knownHashes.add(key.toString());
        final val = _leadsBox!.get(key);
        if (val is Map) {
          try {
            final lead = Lead.fromJson(val);
            _indexLead(lead, key.toString());
          } catch (_) {}
        }
      }
    }

    if (_processedLeadsBox != null && _processedLeadsBox!.isOpen) {
      for (final key in _processedLeadsBox!.keys) {
        _knownHashes.add(key.toString());
        final val = _processedLeadsBox!.get(key);
        if (val is Map) {
          final p = val['phone']?.toString();
          if (p != null) {
            final cp = sanitizePhone(p);
            if (cp.isNotEmpty) _knownPhones.add(cp);
          }
          final pid = val['place_id']?.toString().trim();
          if (pid != null && pid.isNotEmpty) _knownPlaceIds.add(pid);
          final cname = val['company_name']?.toString();
          if (cname != null) {
            final n = Lead.normalizeCompanyName(cname);
            if (n.isNotEmpty) _knownCompanyNames.add(n);
          }
        }
      }
    }
  }

  /// Scans entire leads database, eliminates any duplicate leads across phone, placeId, or company name.
  /// Keeps the most complete/progressed lead, purges all redundant entries, and returns count of removed duplicates.
  Future<int> deduplicateDatabase() async {
    if (_leadsBox == null || !_leadsBox!.isOpen) return 0;

    final allKeys = _leadsBox!.keys.toList();
    if (allKeys.isEmpty) return 0;

    final seenPhones = <String, String>{}; // cleanPhone -> canonicalKey
    final seenPlaceIds = <String, String>{}; // placeId -> canonicalKey
    final seenNames = <String, String>{}; // normName -> canonicalKey
    final keysToDelete = <dynamic>{};

    for (final key in allKeys) {
      final val = _leadsBox!.get(key);
      if (val is! Map) {
        keysToDelete.add(key);
        continue;
      }

      Lead lead;
      try {
        lead = Lead.fromJson(val);
      } catch (_) {
        keysToDelete.add(key);
        continue;
      }

      final cleanPhone = sanitizePhone(lead.saudiMobile);
      final placeId = lead.placeId?.trim() ?? '';
      final normName = Lead.normalizeCompanyName(lead.companyName);

      String? existingKey;

      if (cleanPhone.isNotEmpty && seenPhones.containsKey(cleanPhone)) {
        existingKey = seenPhones[cleanPhone];
      } else if (placeId.isNotEmpty && seenPlaceIds.containsKey(placeId)) {
        existingKey = seenPlaceIds[placeId];
      } else if (normName.isNotEmpty && seenNames.containsKey(normName)) {
        existingKey = seenNames[normName];
      }

      if (existingKey != null) {
        // This is a duplicate! Determine which copy is superior
        final existingVal = _leadsBox!.get(existingKey);
        if (existingVal is Map) {
          try {
            final existingLead = Lead.fromJson(existingVal);
            final currentScore = _leadCompletenessScore(lead);
            final existingScore = _leadCompletenessScore(existingLead);

            if (currentScore > existingScore) {
              // Current lead is more complete, delete the previous key
              keysToDelete.add(existingKey);
              if (cleanPhone.isNotEmpty) seenPhones[cleanPhone] = key.toString();
              if (placeId.isNotEmpty) seenPlaceIds[placeId] = key.toString();
              if (normName.isNotEmpty) seenNames[normName] = key.toString();
              continue;
            }
          } catch (_) {}
        }
        keysToDelete.add(key);
      } else {
        if (cleanPhone.isNotEmpty) seenPhones[cleanPhone] = key.toString();
        if (placeId.isNotEmpty) seenPlaceIds[placeId] = key.toString();
        if (normName.isNotEmpty) seenNames[normName] = key.toString();
      }
    }

    for (final k in keysToDelete) {
      await _leadsBox!.delete(k);
    }

    _rebuildDedupIndex();

    if (keysToDelete.isNotEmpty) {
      _notifyChange();
    }
    return keysToDelete.length;
  }

  int _leadCompletenessScore(Lead lead) {
    int score = 0;
    if (lead.isContacted || lead.isInterested || lead.isAnalyzed) score += 50;
    if (lead.notes.isNotEmpty) score += 20;
    if (lead.aiAnalysis != null) score += 30;
    if (lead.activities.isNotEmpty) score += lead.activities.length * 10;
    if (lead.placeId != null && lead.placeId!.isNotEmpty) score += 15;
    if (lead.googleMapsUrl != null && lead.googleMapsUrl!.isNotEmpty) score += 10;
    return score;
  }

  Future<void> init() async {
    await Hive.initFlutter();
    _leadsBox = await Hive.openBox<dynamic>(leadsBoxName);
    _blacklistBox = await Hive.openBox<dynamic>(blacklistContactsBoxName);
    _settingsBox = await Hive.openBox<dynamic>(settingsBoxName);
    _processedLeadsBox = await Hive.openBox<dynamic>(processedLeadsBoxName);

    // 1. Automatically sanitize & purge any duplicates stored from legacy runs
    await deduplicateDatabase();

    // 2. Build live in-memory deduplication index
    _rebuildDedupIndex();

    // 3. Seed authentic Google Maps Riyadh corporate hotspot leads if database is empty
    if (_leadsBox!.isEmpty) {
      await seedInitialCorporateLeads();
      _rebuildDedupIndex();
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

  Box<dynamic> get processedLeadsBox {
    if (_processedLeadsBox == null || !_processedLeadsBox!.isOpen) {
      throw StateError('Hive processed leads box is not initialized. Call init() first.');
    }
    return _processedLeadsBox!;
  }

  void _notifyChange() {
    revision.value = revision.value + 1;
  }

  /// Strict phone normalization
  String sanitizePhone(String phone) => Lead.sanitizePhone(phone);

  /// Deduplication check: check if phone, placeId, normalized company name, or hash already exists
  bool leadExists(String companyName, String rawPhone, [String? placeId]) {
    final cleanPhone = sanitizePhone(rawPhone);
    if (cleanPhone.isNotEmpty && _knownPhones.contains(cleanPhone)) {
      return true;
    }

    if (placeId != null && placeId.trim().isNotEmpty) {
      final pid = placeId.trim();
      if (_knownPlaceIds.contains(pid)) {
        return true;
      }
      final hash = Lead.buildDeduplicationHash(cleanPhone, pid);
      if (_knownHashes.contains(hash) ||
          processedLeadsBox.containsKey(hash) ||
          leadsBox.containsKey(hash)) {
        return true;
      }
    }

    final normName = Lead.normalizeCompanyName(companyName);
    if (normName.isNotEmpty && _knownCompanyNames.contains(normName)) {
      return true;
    }

    final compKey = Lead.buildCompositeKey(companyName, cleanPhone);
    if (_knownHashes.contains(compKey) ||
        leadsBox.containsKey(compKey) ||
        processedLeadsBox.containsKey(compKey)) {
      return true;
    }

    // Direct fallback scan across leadsBox values
    if (_leadsBox != null && _leadsBox!.isOpen) {
      for (final val in _leadsBox!.values) {
        if (val is Map) {
          final existingPhone = sanitizePhone(
              val['saudi_mobile']?.toString() ?? val['phone']?.toString() ?? '');
          if (cleanPhone.isNotEmpty && existingPhone == cleanPhone) {
            return true;
          }
          final existingPlaceId = val['place_id']?.toString().trim();
          if (placeId != null &&
              placeId.trim().isNotEmpty &&
              existingPlaceId == placeId.trim()) {
            return true;
          }
          final existingName =
              Lead.normalizeCompanyName(val['company_name']?.toString() ?? '');
          if (normName.isNotEmpty && existingName == normName) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Check if hash_key exists in processed_leads
  bool isLeadProcessed(String hashKey) {
    return _knownHashes.contains(hashKey) ||
        processedLeadsBox.containsKey(hashKey) ||
        leadsBox.containsKey(hashKey);
  }

  /// Check if a phone number is permanently blacklisted
  bool isBlacklisted(String rawPhone) {
    final clean = sanitizePhone(rawPhone);
    return blacklistBox.containsKey(clean);
  }

  /// Add lead with strict triple-lock deduplication barrier and blacklist cross-reference
  Future<bool> addLead(Lead lead) async {
    final cleanPhone = sanitizePhone(lead.saudiMobile);
    if (isBlacklisted(cleanPhone)) {
      // Contact is blacklisted; discard
      return false;
    }

    // Pre-Ingestion Check 1: Comprehensive Multi-Field Deduplication
    if (leadExists(lead.companyName, cleanPhone, lead.placeId)) {
      return false;
    }

    final hashKey = lead.hashKey ??
        (lead.placeId != null && lead.placeId!.isNotEmpty
            ? Lead.buildDeduplicationHash(cleanPhone, lead.placeId!)
            : Lead.buildCompositeKey(lead.companyName, cleanPhone));

    // Pre-Ingestion Check 2: Hash & Key Verification
    if (_knownHashes.contains(hashKey) ||
        processedLeadsBox.containsKey(hashKey) ||
        leadsBox.containsKey(hashKey) ||
        leadsBox.containsKey(lead.id)) {
      return false;
    }

    await leadsBox.put(lead.id, lead.toJson());

    // Post-Ingestion: Append new hash_key and date_added to processed_leads permanent registry
    final today = lead.dateAdded.isNotEmpty
        ? lead.dateAdded
        : DateTime.now().toIso8601String().split('T').first;

    await processedLeadsBox.put(hashKey, {
      'hash_key': hashKey,
      'place_id': lead.placeId ?? '',
      'phone': lead.saudiMobile,
      'company_name': lead.companyName,
      'google_maps_url': lead.googleMapsUrl ?? '',
      'date_added': today,
    });

    // Update in-memory index immediately
    _indexLead(lead, hashKey);

    _notifyChange();
    return true;
  }

  /// Update existing lead status, notes, or AI analysis
  Future<void> updateLead(Lead lead) async {
    await leadsBox.put(lead.id, lead.toJson());
    _rebuildDedupIndex();
    _notifyChange();
  }

  /// Delete lead by composite key
  Future<void> deleteLead(String id) async {
    await leadsBox.delete(id);
    _rebuildDedupIndex();
    _notifyChange();
  }

  /// Retrieve all leads mapped to Lead model instances with defensive in-memory deduplication
  List<Lead> getAllLeads() {
    final rawValues = leadsBox.values;
    final List<Lead> leads = [];
    final seenPhones = <String>{};
    final seenPlaceIds = <String>{};
    final seenNames = <String>{};

    for (final val in rawValues) {
      if (val is Map) {
        final lead = Lead.fromJson(val);
        final cleanPhone = sanitizePhone(lead.saudiMobile);

        // Exclude if blacklisted
        if (isBlacklisted(cleanPhone)) {
          continue;
        }

        // Defensive In-Memory Deduplication: Prevent duplicate display on any screen
        if (cleanPhone.isNotEmpty && seenPhones.contains(cleanPhone)) {
          continue;
        }

        final placeId = lead.placeId?.trim();
        if (placeId != null && placeId.isNotEmpty && seenPlaceIds.contains(placeId)) {
          continue;
        }

        final normName = Lead.normalizeCompanyName(lead.companyName);
        if (normName.isNotEmpty && seenNames.contains(normName)) {
          continue;
        }

        if (cleanPhone.isNotEmpty) seenPhones.add(cleanPhone);
        if (placeId != null && placeId.isNotEmpty) seenPlaceIds.add(placeId);
        if (normName.isNotEmpty) seenNames.add(normName);

        leads.add(lead);
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

  /// Seed 100% genuine verified Google Maps records for Riyadh corporate hubs
  Future<void> seedInitialCorporateLeads() async {
    final today = DateTime.now().toIso8601String().split('T').first;

    final genuineLeads = [
      Lead.create(
        companyName: 'Business tower',
        contactPerson: 'Office / Procurement Director',
        saudiMobile: '+966581297003',
        hub: 'Al Olaya',
        placeId: 'ChIJJzoGECgDLz4Raw9i1BPA9T8',
        address: 'Business tower, 7135, 2478, Al Olaya, Riyadh 12244',
        googleMapsUrl: 'https://maps.google.com/?q=place_id:ChIJJzoGECgDLz4Raw9i1BPA9T8',
        staffingRequirements: ['Tea Boy', 'Pantry Staff', 'Cleaners'],
        status: 'new',
        notes: 'Verified Google Maps profile in Al Olaya. Place ID: ChIJJzoGECgDLz4Raw9i1BPA9T8.',
        dateAdded: today,
        intentScore: 89,
      ),
      Lead.create(
        companyName: 'Olaya Towers',
        contactPerson: 'Office / Procurement Director',
        saudiMobile: '+966556550847',
        hub: 'Al Olaya',
        placeId: 'ChIJK2fMfiwDLz4RFWnQIXYtzlw',
        address: 'Olaya Towers, Olaya St, Al Olaya, Riyadh 12213',
        googleMapsUrl: 'https://maps.google.com/?q=place_id:ChIJK2fMfiwDLz4RFWnQIXYtzlw',
        staffingRequirements: ['Tea Boy', 'Pantry Staff', 'Cleaners'],
        status: 'new',
        notes: 'Verified Google Maps profile in Al Olaya. Place ID: ChIJK2fMfiwDLz4RFWnQIXYtzlw.',
        dateAdded: today,
        intentScore: 89,
      ),
      Lead.create(
        companyName: 'مركز العليا للأعمال OBC',
        contactPerson: 'Office / Procurement Director',
        saudiMobile: '+966508613874',
        hub: 'Al Olaya',
        placeId: 'ChIJh3i8ZqsDLz4RxizD720bUJE',
        address: 'مركز العليا للأعمال OBC, Olaya St, Al Olaya, Riyadh 12244',
        googleMapsUrl: 'https://maps.google.com/?q=place_id:ChIJh3i8ZqsDLz4RxizD720bUJE',
        staffingRequirements: ['Tea Boy', 'Pantry Staff', 'Cleaners'],
        status: 'new',
        notes: 'Verified Google Maps profile in Al Olaya. Place ID: ChIJh3i8ZqsDLz4RxizD720bUJE.',
        dateAdded: today,
        intentScore: 89,
      ),
      Lead.create(
        companyName: 'RAM Systems Company Ltd',
        contactPerson: 'Office / Procurement Director',
        saudiMobile: '+966539380050',
        hub: 'Al Narjis Commercial',
        placeId: 'ChIJDdj9zyr_Lj4R1GLT-3rglk4',
        address: 'RAM Systems Company Ltd, Dist Office # 8, An Narjis, Riyadh 13324',
        googleMapsUrl: 'https://maps.google.com/?q=place_id:ChIJDdj9zyr_Lj4R1GLT-3rglk4',
        staffingRequirements: ['Tea Boy', 'Cleaners'],
        status: 'new',
        notes: 'Verified Google Maps profile in Al Narjis. Place ID: ChIJDdj9zyr_Lj4R1GLT-3rglk4.',
        dateAdded: today,
        intentScore: 90,
      ),
      Lead.create(
        companyName: 'Business Enablers Management Consultancy',
        contactPerson: 'Office / Procurement Director',
        saudiMobile: '+966502069867',
        hub: 'Al Narjis Commercial',
        placeId: 'ChIJq7MKN-j7Lj4RyPxvvJzh1GU',
        address: 'Business Enablers Management Consultancy, Othman Bin Affan Rd, An Narjis, Riyadh 13324',
        googleMapsUrl: 'https://maps.google.com/?q=place_id:ChIJq7MKN-j7Lj4RyPxvvJzh1GU',
        staffingRequirements: ['Tea Boy', 'Pantry Staff'],
        status: 'new',
        notes: 'Verified Google Maps profile in Al Narjis. Place ID: ChIJq7MKN-j7Lj4RyPxvvJzh1GU.',
        dateAdded: today,
        intentScore: 90,
      ),
      Lead.create(
        companyName: 'Roshn Front',
        contactPerson: 'Office / Procurement Director',
        saudiMobile: '+966553566068',
        hub: 'Roshn Front Business Zone',
        placeId: 'ChIJeXaTTtr7Lj4Rdt3S2Su-9lE',
        address: 'Roshn Front, Airport Road, Riyadh 13413',
        googleMapsUrl: 'https://maps.google.com/?q=place_id:ChIJeXaTTtr7Lj4Rdt3S2Su-9lE',
        staffingRequirements: ['Tea Boy', 'Pantry Staff', 'Cleaners'],
        status: 'new',
        notes: 'Verified Google Maps profile in Roshn Front. Place ID: ChIJeXaTTtr7Lj4Rdt3S2Su-9lE.',
        dateAdded: today,
        intentScore: 92,
      ),
      Lead.create(
        companyName: 'برج المغيب المكتبي',
        contactPerson: 'Office / Procurement Director',
        saudiMobile: '+966531000216',
        hub: 'King Salman Road Business Strip',
        placeId: 'ChIJQ6AZBoXjLj4R2ZqOmz2WPMg',
        address: 'برج المغيب المكتبي, King Salman Rd, Al Olaya, Riyadh 13321',
        googleMapsUrl: 'https://maps.google.com/?q=place_id:ChIJQ6AZBoXjLj4R2ZqOmz2WPMg',
        staffingRequirements: ['Cleaners', 'Tea Boy'],
        status: 'new',
        notes: 'Verified Google Maps profile on King Salman Rd. Place ID: ChIJQ6AZBoXjLj4R2ZqOmz2WPMg.',
        dateAdded: today,
        intentScore: 91,
      ),
      Lead.create(
        companyName: 'Hital Tower',
        contactPerson: 'Office / Procurement Director',
        saudiMobile: '+966500406660',
        hub: 'King Salman Road Business Strip',
        placeId: 'ChIJQ_i4LAvjLj4R6qMvY4JSPV4',
        address: 'Hital Tower, King Salman Rd, Riyadh 13524',
        googleMapsUrl: 'https://maps.google.com/?q=place_id:ChIJQ_i4LAvjLj4R6qMvY4JSPV4',
        staffingRequirements: ['Tea Boy', 'Pantry Staff', 'Cleaners'],
        status: 'new',
        notes: 'Verified Google Maps profile on King Salman Rd. Place ID: ChIJQ_i4LAvjLj4R6qMvY4JSPV4.',
        dateAdded: today,
        intentScore: 91,
      ),
      Lead.create(
        companyName: 'Analytix Arabia Management Consultants',
        contactPerson: 'Office / Procurement Director',
        saudiMobile: '+966554402052',
        hub: 'Al Narjis Commercial',
        placeId: 'ChIJnwBr5usFLz4R2WF1Stg5MBs',
        address: 'Analytix Arabia Management Consultants, Riyadh',
        googleMapsUrl: 'https://maps.google.com/?q=place_id:ChIJnwBr5usFLz4R2WF1Stg5MBs',
        staffingRequirements: ['Tea Boy', 'Cleaners'],
        status: 'new',
        notes: 'Verified Google Maps profile. Place ID: ChIJnwBr5usFLz4R2WF1Stg5MBs.',
        dateAdded: today,
        intentScore: 88,
      ),
      Lead.create(
        companyName: 'شركة تليد للاستشارات',
        contactPerson: 'Office / Procurement Director',
        saudiMobile: '+966505486611',
        hub: 'Al Narjis Commercial',
        placeId: 'ChIJe-it4sv9Lj4R4JzsjpNGcSw',
        address: 'شركة تليد للاستشارات, An Narjis, Riyadh',
        googleMapsUrl: 'https://maps.google.com/?q=place_id:ChIJe-it4sv9Lj4R4JzsjpNGcSw',
        staffingRequirements: ['Tea Boy', 'Pantry Staff'],
        status: 'new',
        notes: 'Verified Google Maps profile. Place ID: ChIJe-it4sv9Lj4R4JzsjpNGcSw.',
        dateAdded: today,
        intentScore: 90,
      ),
    ];

    for (final lead in genuineLeads) {
      await addLead(lead);
    }
  }
}
