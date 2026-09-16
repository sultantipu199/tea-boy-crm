import 'ai_analysis.dart';
import 'zones.dart';

class LeadActivity {
  final String id;
  final String type; // 'Call', 'WhatsApp', 'Visit', 'Quotation', 'Note'
  final String date; // YYYY-MM-DD HH:mm
  final String note;

  LeadActivity({
    required this.id,
    required this.type,
    required this.date,
    required this.note,
  });

  factory LeadActivity.fromJson(Map<dynamic, dynamic> map) {
    return LeadActivity(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'Note',
      date: map['date']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'date': date,
      'note': note,
    };
  }
}

class Lead {
  final String id; // Composite Primary Key: companyName_sanitizedPhone
  final String companyName;
  final String contactPerson;
  final String saudiMobile; // strictly 9665xxxxxxxx
  final String hub; // zone_cluster
  final List<String> staffingRequirements; // Cleaners, Pantry Staff, Tea Boy
  String status; // 'new' | 'contacted' | 'analyzed' | 'disqualified' | 'interested' | 'closed'
  String notes;
  final String dateAdded; // Formatted YYYY-MM-DD
  String? contactedAt; // ISO String or YYYY-MM-DD HH:mm:ss when WhatsApp clicked
  String? followUpDate; // Formatted YYYY-MM-DD
  int intentScore; // 0 - 100
  String? clientReply; // Stored pasted response from client
  bool isBlacklisted; // Permanent exclusion flag
  List<LeadActivity> activities;
  AiAnalysis? aiAnalysis;

  Lead({
    required this.id,
    required this.companyName,
    required this.contactPerson,
    required this.saudiMobile,
    required this.hub,
    required this.staffingRequirements,
    required this.status,
    required this.notes,
    required this.dateAdded,
    this.contactedAt,
    this.followUpDate,
    this.intentScore = 70,
    this.clientReply,
    this.isBlacklisted = false,
    this.activities = const [],
    this.aiAnalysis,
  });

  /// Normalize and sanitize Saudi mobile number to strictly 9665xxxxxxxx format
  static String sanitizePhone(String phone) {
    String digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('00966')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('05')) {
      digits = '966' + digits.substring(1);
    } else if (digits.startsWith('5') && digits.length == 9) {
      digits = '966' + digits;
    } else if (!digits.startsWith('966') && digits.length == 9) {
      digits = '966' + digits;
    }
    return digits;
  }

  /// Construct composite primary key for deduplication
  static String buildCompositeKey(String companyName, String rawPhone) {
    final cleanCompany = companyName.trim().toLowerCase();
    final cleanPhone = sanitizePhone(rawPhone);
    return '${cleanCompany}_$cleanPhone';
  }

  factory Lead.create({
    required String companyName,
    required String contactPerson,
    required String saudiMobile,
    required String hub,
    required List<String> staffingRequirements,
    String status = 'new',
    String notes = '',
    String? dateAdded,
    String? contactedAt,
    String? followUpDate,
    int? intentScore,
    String? clientReply,
    bool isBlacklisted = false,
    List<LeadActivity>? activities,
    AiAnalysis? aiAnalysis,
  }) {
    final key = buildCompositeKey(companyName, saudiMobile);
    final today = dateAdded ??
        DateTime.now().toIso8601String().split('T').first; // YYYY-MM-DD
    final zone = RiyadhZones.findZone(hub);
    final calculatedIntent = intentScore ?? (60 + (zone?.defaultIntentBoost ?? 10));

    return Lead(
      id: key,
      companyName: companyName.trim(),
      contactPerson: contactPerson.trim(),
      saudiMobile: sanitizePhone(saudiMobile),
      hub: hub.trim(),
      staffingRequirements: staffingRequirements.isNotEmpty
          ? staffingRequirements
          : ['Tea Boy'],
      status: status.toLowerCase(),
      notes: notes,
      dateAdded: today,
      contactedAt: contactedAt,
      followUpDate: followUpDate,
      intentScore: calculatedIntent.clamp(0, 100),
      clientReply: clientReply,
      isBlacklisted: isBlacklisted,
      activities: activities ?? [],
      aiAnalysis: aiAnalysis,
    );
  }

  factory Lead.fromJson(Map<dynamic, dynamic> map) {
    final rawStatus = (map['status']?.toString() ?? 'new').toLowerCase();
    final phone = map['saudi_mobile']?.toString() ??
        map['phone']?.toString() ??
        '';

    final hubName = map['zone_cluster']?.toString() ??
        map['hub']?.toString() ??
        'KAFD Phase 1 & 2';

    final intent = (map['intent_score'] is num)
        ? (map['intent_score'] as num).toInt()
        : int.tryParse(map['intent_score']?.toString() ?? '70') ?? 70;

    final isBlack = (map['is_blacklisted'] == true) ||
        (map['is_blacklisted']?.toString().toLowerCase() == 'true');

    return Lead(
      id: map['id']?.toString() ??
          buildCompositeKey(map['company_name']?.toString() ?? '', phone),
      companyName: map['company_name']?.toString() ?? '',
      contactPerson: map['contact_person']?.toString() ?? '',
      saudiMobile: sanitizePhone(phone),
      hub: hubName,
      staffingRequirements: (map['staffing_requirements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['Tea Boy'],
      status: rawStatus,
      notes: map['notes']?.toString() ?? '',
      dateAdded: map['date_added']?.toString() ??
          DateTime.now().toIso8601String().split('T').first,
      contactedAt: map['contacted_at']?.toString(),
      followUpDate: map['follow_up_date']?.toString(),
      intentScore: intent,
      clientReply: map['client_reply']?.toString(),
      isBlacklisted: isBlack,
      activities: (map['activities'] as List<dynamic>?)
              ?.map((e) => LeadActivity.fromJson(e as Map))
              .toList() ??
          [],
      aiAnalysis: map['ai_analysis'] != null
          ? AiAnalysis.fromJson(
              Map<String, dynamic>.from(map['ai_analysis'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_name': companyName,
      'contact_person': contactPerson,
      'saudi_mobile': saudiMobile,
      'phone': saudiMobile,
      'hub': hub,
      'zone_cluster': hub,
      'staffing_requirements': staffingRequirements,
      'status': status.toLowerCase(),
      'notes': notes,
      'date_added': dateAdded,
      'contacted_at': contactedAt,
      'follow_up_date': followUpDate,
      'intent_score': intentScore,
      'client_reply': clientReply,
      'is_blacklisted': isBlacklisted,
      'activities': activities.map((a) => a.toJson()).toList(),
      'ai_analysis': aiAnalysis?.toJson(),
    };
  }

  Lead copyWith({
    String? status,
    String? notes,
    String? contactedAt,
    String? followUpDate,
    int? intentScore,
    String? clientReply,
    bool? isBlacklisted,
    List<LeadActivity>? activities,
    AiAnalysis? aiAnalysis,
  }) {
    return Lead(
      id: id,
      companyName: companyName,
      contactPerson: contactPerson,
      saudiMobile: saudiMobile,
      hub: hub,
      staffingRequirements: staffingRequirements,
      status: (status ?? this.status).toLowerCase(),
      notes: notes ?? this.notes,
      dateAdded: dateAdded,
      contactedAt: contactedAt ?? this.contactedAt,
      followUpDate: followUpDate ?? this.followUpDate,
      intentScore: intentScore ?? this.intentScore,
      clientReply: clientReply ?? this.clientReply,
      isBlacklisted: isBlacklisted ?? this.isBlacklisted,
      activities: activities ?? this.activities,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
    );
  }

  /// Normalized status checks
  bool get isNew => status == 'new';
  bool get isContacted => status == 'contacted';
  bool get isAnalyzed => status == 'analyzed';
  bool get isDisqualified => status == 'disqualified';
  bool get isInterested => status == 'interested';
  bool get isClosed => status == 'closed';

  /// Check whether follow-up callback is due or overdue
  bool get isFollowUpDue {
    if (followUpDate == null || followUpDate!.isEmpty) return false;
    if (isClosed || isDisqualified) return false;
    final today = DateTime.now().toIso8601String().split('T').first;
    return followUpDate!.compareTo(today) <= 0;
  }

  /// Check whether follow-up callback is scheduled precisely for today
  bool get isFollowUpToday {
    if (followUpDate == null || followUpDate!.isEmpty) return false;
    final today = DateTime.now().toIso8601String().split('T').first;
    return followUpDate == today;
  }

  /// Estimated Monthly Contract Value (SAR before VAT)
  double get estimatedMonthlyValue {
    double total = 0.0;
    for (final req in staffingRequirements) {
      if (req == 'Tea Boy') {
        total += 4200.0;
      } else if (req == 'Pantry Staff') {
        total += 3800.0;
      } else if (req == 'Cleaners') {
        total += 3200.0;
      } else {
        total += 3500.0;
      }
    }
    return total;
  }
}
