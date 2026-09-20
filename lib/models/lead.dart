import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'ai_analysis.dart';
import 'zones.dart';

class LeadActivity {
  final String id;
  final String type; // 'Call', 'WhatsApp', 'Email', 'Visit', 'Quotation', 'Note'
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
  final String id; // Composite Primary Key: companyName_sanitizedPhone or SHA-256 hash
  final String? hashKey; // SHA-256(normalized_phone + "_" + place_id)
  final String? placeId; // Authentic Google Place ID
  final String? address; // Real street address
  final String? googleMapsUrl; // https://maps.google.com/?q=place_id:PLACE_ID
  final String companyName;
  final String contactPerson;
  final String saudiMobile; // strictly 9665xxxxxxxx
  final String email; // Corporate procurement / HR email
  final String hub; // zone_cluster
  final double? lat;
  final double? lng;
  final List<String> staffingRequirements; // Cleaners, Pantry Staff, Tea Boy
  String status; // 'new' | 'contacted' | 'analyzed' | 'disqualified' | 'interested' | 'closed'
  String notes;
  final String dateAdded; // Formatted YYYY-MM-DD
  String? contactedAt; // ISO String or YYYY-MM-DD HH:mm:ss when WhatsApp / Email dispatched
  String? followUpDate; // Formatted YYYY-MM-DD
  int intentScore; // 0 - 100
  String? clientReply; // Stored pasted response from client
  bool isBlacklisted; // Permanent exclusion flag
  List<LeadActivity> activities;
  AiAnalysis? aiAnalysis;

  Lead({
    required this.id,
    this.hashKey,
    this.placeId,
    this.address,
    this.googleMapsUrl,
    required this.companyName,
    required this.contactPerson,
    required this.saudiMobile,
    required this.email,
    required this.hub,
    this.lat,
    this.lng,
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
      digits = '966${digits.substring(1)}';
    } else if (digits.startsWith('5') && digits.length == 9) {
      digits = '966$digits';
    } else if (!digits.startsWith('966') && digits.length == 9) {
      digits = '966$digits';
    }
    return digits;
  }

  /// Construct default corporate procurement email if not provided
  static String defaultCorporateEmail(String companyName) {
    final clean = companyName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final handle = clean.isNotEmpty ? clean : 'corporate';
    return 'procurement@$handle.sa';
  }

  /// Advanced company name normalization for fuzzy deduplication
  static String normalizeCompanyName(String name) {
    if (name.isEmpty) return '';
    String clean = name.trim().toLowerCase();
    // Remove Arabic prefixes like شركة, مؤسسة, مكتب, فرع
    clean = clean.replaceAll(RegExp(r'^(?:شركة|مؤسسة|مكتب|فرع)\s+'), '');
    // Remove Arabic corporate suffixes like المحدودة, القابضة, ش م م, مساهمة
    clean = clean.replaceAll(RegExp(r'\s+(?:المحدودة|القابضة|ش\.?م\.?م|مساهمة)$'), '');
    // Remove English corporate suffixes
    clean = clean.replaceAll(
        RegExp(r'\b(?:co|company|ltd|llc|inc|est|corporation|corp|branch|group)\b',
            caseSensitive: false),
        '');
    // Remove special punctuation, dashes, parentheses
    clean = clean.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    // Collapse multi-spaces
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean;
  }

  /// Construct composite primary key for deduplication
  static String buildCompositeKey(String companyName, String rawPhone) {
    final cleanCompany = normalizeCompanyName(companyName);
    final cleanPhone = sanitizePhone(rawPhone);
    return '${cleanCompany.isNotEmpty ? cleanCompany : companyName.trim().toLowerCase()}_$cleanPhone';
  }

  /// Bulletproof SHA-256 Deduplication Hash from normalized phone and Google Place ID
  static String buildDeduplicationHash(String phone, String placeId) {
    final clean = sanitizePhone(phone);
    final normPhone = clean.startsWith('+') ? clean : '+$clean';
    final rawKey = '${normPhone}_${placeId.trim()}';
    return sha256.convert(utf8.encode(rawKey)).toString();
  }

  factory Lead.create({
    required String companyName,
    required String contactPerson,
    required String saudiMobile,
    String? email,
    required String hub,
    String? placeId,
    String? address,
    String? googleMapsUrl,
    String? hashKey,
    double? lat,
    double? lng,
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
    final key = hashKey ??
        (placeId != null && placeId.isNotEmpty
            ? buildDeduplicationHash(saudiMobile, placeId)
            : buildCompositeKey(companyName, saudiMobile));
    final today = dateAdded ??
        DateTime.now().toIso8601String().split('T').first; // YYYY-MM-DD
    final zone = RiyadhZones.findZone(hub);
    final calculatedIntent =
        intentScore ?? (60 + (zone?.defaultIntentBoost ?? 10));
    final resolvedEmail = (email != null && email.trim().isNotEmpty)
        ? email.trim()
        : defaultCorporateEmail(companyName);
    final resolvedMapsUrl = (googleMapsUrl != null && googleMapsUrl.isNotEmpty)
        ? googleMapsUrl
        : (placeId != null && placeId.isNotEmpty
            ? 'https://maps.google.com/?q=place_id:$placeId'
            : null);

    return Lead(
      id: key,
      hashKey: key,
      placeId: placeId,
      address: address,
      googleMapsUrl: resolvedMapsUrl,
      companyName: companyName.trim(),
      contactPerson: contactPerson.trim(),
      saudiMobile: sanitizePhone(saudiMobile),
      email: resolvedEmail,
      hub: hub.trim(),
      lat: lat ?? zone?.latitude,
      lng: lng ?? zone?.longitude,
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

    final compName = map['company_name']?.toString() ?? '';
    final existingEmail = map['email']?.toString();
    final resolvedEmail = (existingEmail != null && existingEmail.isNotEmpty)
        ? existingEmail
        : defaultCorporateEmail(compName);

    final placeIdVal = map['place_id']?.toString();
    final hashKeyVal = map['hash_key']?.toString() ?? map['id']?.toString();
    final gmapsUrl = map['google_maps_url']?.toString() ??
        (placeIdVal != null && placeIdVal.isNotEmpty
            ? 'https://maps.google.com/?q=place_id:$placeIdVal'
            : null);
    final addr = map['address']?.toString();

    double? parseCoord(dynamic val) {
      if (val is num) return val.toDouble();
      if (val != null) return double.tryParse(val.toString());
      return null;
    }

    return Lead(
      id: hashKeyVal ??
          (placeIdVal != null && placeIdVal.isNotEmpty
              ? buildDeduplicationHash(phone, placeIdVal)
              : buildCompositeKey(compName, phone)),
      hashKey: hashKeyVal,
      placeId: placeIdVal,
      address: addr,
      googleMapsUrl: gmapsUrl,
      companyName: compName,
      contactPerson: map['contact_person']?.toString() ?? '',
      saudiMobile: sanitizePhone(phone),
      email: resolvedEmail,
      hub: hubName,
      lat: parseCoord(map['lat']),
      lng: parseCoord(map['lng']),
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
      'hash_key': hashKey ?? id,
      'place_id': placeId,
      'address': address,
      'google_maps_url': googleMapsUrl,
      'company_name': companyName,
      'contact_person': contactPerson,
      'saudi_mobile': saudiMobile,
      'phone': saudiMobile,
      'email': email,
      'hub': hub,
      'zone_cluster': hub,
      'lat': lat,
      'lng': lng,
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
    String? companyName,
    String? contactPerson,
    String? saudiMobile,
    String? email,
    String? hub,
    String? placeId,
    String? address,
    String? googleMapsUrl,
    String? hashKey,
    double? lat,
    double? lng,
    List<String>? staffingRequirements,
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
      hashKey: hashKey ?? this.hashKey,
      placeId: placeId ?? this.placeId,
      address: address ?? this.address,
      googleMapsUrl: googleMapsUrl ?? this.googleMapsUrl,
      companyName: companyName ?? this.companyName,
      contactPerson: contactPerson ?? this.contactPerson,
      saudiMobile: saudiMobile ?? this.saudiMobile,
      email: email ?? this.email,
      hub: hub ?? this.hub,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      staffingRequirements: staffingRequirements ?? this.staffingRequirements,
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

  /// Executive Pitch Email Subject (RFC-compliant)
  String get corporateEmailSubject {
    return 'VIP Office Hospitality & Facility Staffing Proposal | $companyName';
  }

  /// Executive Pitch Email Body (RFC-compliant)
  String get corporateEmailBody {
    final staffList = staffingRequirements.join(', ');
    return '''السيد/السيدة: $contactPerson المحترم،
تحية طيبة وبعد،

يسرنا في شركة الشاي والأعمال (TEA BOY B2B) أن نقدم لكم عرض خدمات الضيافة المكتبية والكوادر التشغيلية المخصصة لمقركم الموقر في $hub ($companyName).

نحن نوفر كوادر مدربة بأعلى المعايير السعودية في مجالات:
• الكوادر المطلوبة: $staffList
• عقود مرنة معتمدة ومطابقة لمتطلبات وزارة الموارد البشرية ونظام العمل السعودي.
• زي موحد راقي، تدريب ضيافة بروتوكولية، وإشراف ميداني مستمر على مدار الساعة.

يسعدنا ترتيب موعد لمعاينة المقر أو بدء فترة تجريبية خلال هذا الأسبوع.

شاكرين ومقدرين حسن تعاونكم،
فريق تطوير الأعمال B2B | TEA BOY KSA
الرياض - المملكة العربية السعودية
هاتف: +966 50 123 4567''';
  }
}
