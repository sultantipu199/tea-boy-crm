import 'ai_analysis.dart';

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
      'ai_analysis': aiAnalysis?.toJson(),
    };
  }

  Lead copyWith({
    String? status,
    String? notes,
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
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
    );
  }
}
