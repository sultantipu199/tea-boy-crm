import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_analysis.dart';
import '../models/lead.dart';

class GeminiService {
  static final GeminiService instance = GeminiService._internal();
  GeminiService._internal();

  // User-configurable in-app API key (stored in Hive or memory, zero GitHub Secrets required)
  static String? customApiKey;

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  static const String apologyExitMessage =
      'اعتذر منك بشدة على الإزعاج، سيتم تعديل الرقم وحذفه فوراً من سجلاتنا. أتمنى لك يوماً سعيداً.';

  /// Wrong number trigger phrases in Arabic and English
  static const List<String> wrongNumberTriggers = [
    'wrong number',
    'not me',
    'who is this',
    'wrong person',
    'not interested and wrong number',
    'غلطان',
    'الرقم خطأ',
    'الرقم غلط',
    'لست الأستاذ',
    'لست الاستاذ',
    'لست المعني',
    'لست المسؤول',
    'مو أنا',
    'مو انا',
    'رقم خاطئ',
    'غلطان بالرقم',
    'مين انت',
    'لست صاحب الرقم',
  ];

  /// Fast local check for wrong contact keywords
  static bool detectWrongContact(String text) {
    final lower = text.trim().toLowerCase();
    for (final trigger in wrongNumberTriggers) {
      if (lower.contains(trigger.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Strip accidental markdown code-block wrappers e.g. ```json ... ``` or ``` ... ```
  static String sanitizeJsonResponse(String raw) {
    String cleaned = raw.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }

    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    return cleaned.trim();
  }

  /// Auto-trigger analysis when client reply is pasted
  Future<AiAnalysis> analyzeClientReply({
    required Lead lead,
    required String clientReply,
    String? apiKeyOverride,
  }) async {
    final replyTrimmed = clientReply.trim();

    // 1. Fast path: If client reply matches known wrong-contact trigger phrases
    if (detectWrongContact(replyTrimmed)) {
      return AiAnalysis(
        sentiment: 'Wrong Contact',
        isWrongContact: true,
        painPoints: 'Client indicates misidentified contact or wrong phone number.',
        recommendedAction:
            'Permanently blacklist number, archive lead, and dispatch zero-pitch apology.',
        followUpMessage: apologyExitMessage,
        nextFollowUpDate: '',
        dealScore: 0,
      );
    }

    final apiKey = apiKeyOverride ?? customApiKey;

    // 2. If no API key is provided, execute deterministic heuristic engine
    if (apiKey == null || apiKey.trim().isEmpty) {
      return _generateLocalReplyForecast(lead, replyTrimmed);
    }

    final url = Uri.parse('$_baseUrl?key=${apiKey.trim()}');

    final prompt = '''
You are an expert enterprise B2B sales forecasting AI specialized in corporate office staffing (Cleaners, Pantry Staff, Tea Boys) in Riyadh, Saudi Arabia.
A client replied to our corporate staffing outreach.

Company Name: ${lead.companyName}
Riyadh Hub / Cluster: ${lead.hub}
Contact Person: ${lead.contactPerson}
Staffing Requirements: ${lead.staffingRequirements.join(', ')}

Client's Reply Text:
"""
$replyTrimmed
"""

Analyze this reply carefully.
Return a valid JSON object strictly matching this schema:
{
  "sentiment": "Interested | Objection: Price | Objection: Vendor | Wrong Contact | Postponed",
  "is_wrong_contact": boolean,
  "pain_points": "string summarizing pain points or objections",
  "recommended_action": "string with specific next sales step in Riyadh",
  "follow_up_message": "string (polite, culturally refined Arabic WhatsApp reply directly addressing their message)",
  "next_follow_up_date": "YYYY-MM-DD",
  "deal_score": integer between 0 and 100
}
''';

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'temperature': 0.2,
        'maxOutputTokens': 800,
      }
    });

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decodedBody = jsonDecode(response.body);
        final candidates = decodedBody['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final contentParts =
              candidates[0]['content']?['parts'] as List<dynamic>?;
          if (contentParts != null && contentParts.isNotEmpty) {
            final rawText = contentParts[0]['text']?.toString() ?? '{}';
            final cleanedJson = sanitizeJsonResponse(rawText);
            final parsedMap = jsonDecode(cleanedJson) as Map<String, dynamic>;
            final analysis = AiAnalysis.fromJson(parsedMap);

            if (analysis.isWrongContact ||
                analysis.sentiment.toLowerCase().contains('wrong contact')) {
              return analysis.copyWith(
                isWrongContact: true,
                sentiment: 'Wrong Contact',
                dealScore: 0,
                followUpMessage: apologyExitMessage,
              );
            }
            return analysis;
          }
        }
      }
    } catch (_) {}

    return _generateLocalReplyForecast(lead, replyTrimmed);
  }

  /// Analyze initial lead deal potential & personalized pitch via Gemini 1.5 Flash
  Future<AiAnalysis> analyzeLead({
    required Lead lead,
    String? apiKeyOverride,
  }) async {
    final apiKey = apiKeyOverride ?? customApiKey;

    if (apiKey == null || apiKey.trim().isEmpty) {
      return _generateLocalHeuristicForecast(lead);
    }

    final url = Uri.parse('$_baseUrl?key=${apiKey.trim()}');

    final prompt = '''
You are an expert enterprise B2B sales strategist specialized in corporate office staffing (Professional Cleaners, Pantry Staff, and Tea Boys) in Riyadh, Saudi Arabia.
Analyze this corporate lead:
Company Name: ${lead.companyName}
Riyadh Business Hub / Cluster: ${lead.hub}
Contact Person: ${lead.contactPerson}
Staffing Requirements: ${lead.staffingRequirements.join(', ')}
Current Status: ${lead.status}
Lead Discovery Date: ${lead.dateAdded}
Existing Notes: ${lead.notes}

Return a valid JSON object strictly matching this schema:
{
  "sentiment": "Interested | Objection: Price | Objection: Vendor | Wrong Contact | Postponed",
  "is_wrong_contact": false,
  "pain_points": "string detailing corporate hospitality and hygiene pain points",
  "recommended_action": "string",
  "follow_up_message": "string (personalized Arabic WhatsApp pitch highlighting reliability, Saudi VIP corporate etiquette, and immediate replacement guarantee)",
  "next_follow_up_date": "YYYY-MM-DD",
  "deal_score": integer between 0 and 100
}
''';

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'temperature': 0.3,
        'maxOutputTokens': 800,
      }
    });

    const int maxAttempts = 2;
    int backoffSeconds = 2;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: requestBody,
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final decodedBody = jsonDecode(response.body);
          final candidates = decodedBody['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final contentParts =
                candidates[0]['content']?['parts'] as List<dynamic>?;
            if (contentParts != null && contentParts.isNotEmpty) {
              final rawText = contentParts[0]['text']?.toString() ?? '{}';
              final cleanedJson = sanitizeJsonResponse(rawText);
              final parsedMap = jsonDecode(cleanedJson) as Map<String, dynamic>;
              return AiAnalysis.fromJson(parsedMap);
            }
          }
        }
      } catch (e) {
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: backoffSeconds));
          backoffSeconds *= 2;
          continue;
        }
      }
    }

    return _generateLocalHeuristicForecast(lead);
  }

  /// Heuristic response analyzer for client replies when offline
  AiAnalysis _generateLocalReplyForecast(Lead lead, String reply) {
    final lower = reply.toLowerCase();

    if (detectWrongContact(lower)) {
      return AiAnalysis(
        sentiment: 'Wrong Contact',
        isWrongContact: true,
        painPoints: 'Client indicated number or recipient is incorrect.',
        recommendedAction: 'Disqualify, archive to blacklist, send courtesy apology.',
        followUpMessage: apologyExitMessage,
        nextFollowUpDate: '',
        dealScore: 0,
      );
    }

    // Price objection
    if (lower.contains('سعر') ||
        lower.contains('غالي') ||
        lower.contains('ميزانية') ||
        lower.contains('price') ||
        lower.contains('expensive') ||
        lower.contains('budget')) {
      final nextDate = DateTime.now().add(const Duration(days: 1));
      return AiAnalysis(
        sentiment: 'Objection: Price',
        isWrongContact: false,
        painPoints: 'Budget constraints or perceived high monthly rate.',
        recommendedAction:
            'Send custom tiered quotation with volume discount or 3-day free trial.',
        followUpMessage: '''
أهلاً سعادة الأستاذ ${lead.contactPerson.isNotEmpty ? lead.contactPerson : 'المحترم'}،
نقدر اهتمامكم بميزانية الشركة في ${lead.companyName}. يسعدنا تقديم باقة مخصصة بأسعار تفضيلية وعقود مرنة تناسب متطلباتكم، مع فترة تجربة مجانية بدون التزام. هل نرسل لكم جدول التسعير المخفض؟
''',
        nextFollowUpDate: nextDate.toIso8601String().split('T').first,
        dealScore: 68,
      );
    }

    // Existing vendor objection
    if (lower.contains('عقد') ||
        lower.contains('متعاقدين') ||
        lower.contains('شركة ثانية') ||
        lower.contains('عندنا') ||
        lower.contains('vendor') ||
        lower.contains('already have')) {
      final nextDate = DateTime.now().add(const Duration(days: 14));
      return AiAnalysis(
        sentiment: 'Objection: Vendor',
        isWrongContact: false,
        painPoints: 'Currently locked into existing service contract.',
        recommendedAction:
            'Offer backup standby service and schedule follow-up prior to their contract renewal.',
        followUpMessage: '''
أهلاً سعادة الأستاذ ${lead.contactPerson.isNotEmpty ? lead.contactPerson : 'المحترم'}،
نتمنى لكم التوفيق دائماً مع شريككم الحالي. يسعدنا تسجيلكم ضمن قائمة خدمة "البديل الفوري للطوارئ" دون أي رسوم اشتراك، للتدخل السريع حال حدوث أي نقص أو غياب في مقركم بـ ${lead.hub}. هل ترغبون بكتالوج الخدمات للرجوع إليه مستقبلاً؟
''',
        nextFollowUpDate: nextDate.toIso8601String().split('T').first,
        dealScore: 55,
      );
    }

    // Postponed / Busy
    if (lower.contains('لاحقا') ||
        lower.contains('بعدين') ||
        lower.contains('مشغول') ||
        lower.contains('تواصل الأسبوع') ||
        lower.contains('later') ||
        lower.contains('busy') ||
        lower.contains('next week')) {
      final nextDate = DateTime.now().add(const Duration(days: 5));
      return AiAnalysis(
        sentiment: 'Postponed',
        isWrongContact: false,
        painPoints: 'Decision maker occupied; timing not immediate.',
        recommendedAction: 'Set reminder for scheduled callback next week.',
        followUpMessage: '''
أهلاً سعادة الأستاذ ${lead.contactPerson.isNotEmpty ? lead.contactPerson : 'المحترم'}،
نقدر وقتكم وانشغالكم بكل تأكيد. سأعاود التواصل معكم بداية الأسبوع القادم في الوقت المناسب لكم بإذن الله. يومك سعيد ومبارك.
''',
        nextFollowUpDate: nextDate.toIso8601String().split('T').first,
        dealScore: 62,
      );
    }

    // Positive / Interested
    final nextDate = DateTime.now().add(const Duration(days: 1));
    return AiAnalysis(
      sentiment: 'Interested',
      isWrongContact: false,
      painPoints: 'Seeking professional, reliable office hospitality and hygiene standards.',
      recommendedAction:
          '1-tap dispatch official SAR quotation and schedule quick on-site meeting in ${lead.hub}.',
      followUpMessage: '''
أهلاً وسهلاً سعادة الأستاذ ${lead.contactPerson.isNotEmpty ? lead.contactPerson : 'المحترم'} (${lead.companyName})،
يسعدنا اهتمامكم. يسرنا تزويدكم بعرض السعر الرسمي وتحديد موعد زيارة لمقركم في ${lead.hub} لترتيب تفاصيل الكوادر المطلوبة (${lead.staffingRequirements.join(' و ')}). هل يناسبكم غداً الساعة 11:00 صباحاً؟
''',
      nextFollowUpDate: nextDate.toIso8601String().split('T').first,
      dealScore: 85,
    );
  }

  /// Deterministic heuristic initial forecast
  AiAnalysis _generateLocalHeuristicForecast(Lead lead) {
    int score = 70;

    final hubLower = lead.hub.toLowerCase();
    if (hubLower.contains('kafd') ||
        hubLower.contains('narjis') ||
        hubLower.contains('roshn') ||
        hubLower.contains('salman')) {
      score += 15;
    } else if (hubLower.contains('olaya') ||
        hubLower.contains('digital') ||
        hubLower.contains('malqa')) {
      score += 10;
    }

    if (lead.staffingRequirements.length >= 2) {
      score += 8;
    }

    if (score > 98) score = 98;

    final nextDate = DateTime.now().add(const Duration(days: 2));
    final nextFollowUpDate = nextDate.toIso8601String().split('T').first;

    return AiAnalysis(
      sentiment: score >= 80 ? 'Interested' : 'Interested',
      isWrongContact: false,
      painPoints:
          '• Unreliable independent staffing causing office hospitality disruption\n• High cost and visa overhead for individual direct hires\n• Need for bilingual staff trained in Saudi corporate protocol',
      recommendedAction:
          'Send 1-tap WhatsApp corporate pitch highlighting trained Tea Boys & immediate backup replacement guarantee in ${lead.hub}.',
      followUpMessage: '''
السلام عليكم ورحمة الله،
أهلاً وسهلاً سعادة الأستاذ ${lead.contactPerson.isNotEmpty ? lead.contactPerson : 'المسئول'} في ${lead.companyName} (${lead.hub})،
يسعدنا في مؤسسة TEA BOY للضيافة المعتمدة تزويد مكاتبكم بكوادر مدربة من (مقدمي الضيافة Tea Boys ومسؤولي النظافة المكتبية) بدوام كامل، زي رسمي موحد، وبديل فوري معتمد. هل ترغبون بجدولة زيارة تجريبية مجانية؟
''',
      nextFollowUpDate: nextFollowUpDate,
      dealScore: score,
    );
  }
}
