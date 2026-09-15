import 'ai_analysis.dart';

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
  final String saudiMobile;
  final String hub; // KAFD, Al Olaya, King Fahd Rd, Al Malqa, Digital City, Business Gate
  final List<String> staffingRequirements; // Cleaners, Pantry Staff, Tea Boy
  String status; // New, Contacted, Interested, Closed, Disqualified
  String notes;
  final String dateAdded; // Formatted YYYY-MM-DD
  String? followUpDate; // Formatted YYYY-MM-DD
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
    this.followUpDate,
    this.activities = const [],
    this.aiAnalysis,
  });

  /// Normalize and sanitize Saudi mobile number to strictly 9665xxxxxxxx format
  static String sanitizePhone(String phone) {
    // Remove all non-digits
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
    String status = 'New',
    String notes = '',
    String? dateAdded,
    String? followUpDate,
    List<LeadActivity>? activities,
    AiAnalysis? aiAnalysis,
  }) {
    final key = buildCompositeKey(companyName, saudiMobile);
    final today = dateAdded ??
        DateTime.now().toIso8601String().split('T').first; // YYYY-MM-DD
    return Lead(
      id: key,
      companyName: companyName.trim(),
      contactPerson: contactPerson.trim(),
      saudiMobile: sanitizePhone(saudiMobile),
      hub: hub.trim(),
      staffingRequirements: staffingRequirements,
      status: status,
      notes: notes,
      dateAdded: today,
      followUpDate: followUpDate,
      activities: activities ?? [],
      aiAnalysis: aiAnalysis,
    );
  }

  factory Lead.fromJson(Map<dynamic, dynamic> map) {
    return Lead(
      id: map['id']?.toString() ?? '',
      companyName: map['company_name']?.toString() ?? '',
      contactPerson: map['contact_person']?.toString() ?? '',
      saudiMobile: map['saudi_mobile']?.toString() ?? '',
      hub: map['hub']?.toString() ?? 'KAFD',
      staffingRequirements: (map['staffing_requirements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['Tea Boy'],
      status: map['status']?.toString() ?? 'New',
      notes: map['notes']?.toString() ?? '',
      dateAdded: map['date_added']?.toString() ??
          DateTime.now().toIso8601String().split('T').first,
      followUpDate: map['follow_up_date']?.toString(),
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
      'hub': hub,
      'staffing_requirements': staffingRequirements,
      'status': status,
      'notes': notes,
      'date_added': dateAdded,
      'follow_up_date': followUpDate,
      'activities': activities.map((a) => a.toJson()).toList(),
      'ai_analysis': aiAnalysis?.toJson(),
    };
  }

  Lead copyWith({
    String? status,
    String? notes,
    String? followUpDate,
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
      status: status ?? this.status,
      notes: notes ?? this.notes,
      dateAdded: dateAdded,
      followUpDate: followUpDate ?? this.followUpDate,
      activities: activities ?? this.activities,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
    );
  }

  /// Whether a follow-up callback is due or overdue
  bool get isFollowUpDue {
    if (followUpDate == null || followUpDate!.isEmpty) return false;
    if (status.toLowerCase() == 'closed' || status.toLowerCase() == 'disqualified') {
      return false;
    }
    final today = DateTime.now().toIso8601String().split('T').first;
    return followUpDate!.compareTo(today) <= 0;
  }

  /// Whether a follow-up callback is scheduled precisely for today
  bool get isFollowUpToday {
    if (followUpDate == null || followUpDate!.isEmpty) return false;
    final today = DateTime.now().toIso8601String().split('T').first;
    return followUpDate == today;
  }

  /// Estimated Monthly Contract Value (SAR before VAT)
  double get estimatedMonthlyValue {
    double total = 0.0;
    for (final req in staffingRequirements) {
      if (req == 'Tea Boy') total += 4200.0;
      else if (req == 'Pantry Staff') total += 3800.0;
      else if (req == 'Cleaners') total += 3200.0;
      else total += 3500.0;
    }
    return total;
  }
}

