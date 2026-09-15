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

  /// Analyze lead deal potential and generate personalized pitch via Gemini 1.5 Flash
  Future<AiAnalysis> analyzeLead({
    required Lead lead,
    String? apiKeyOverride,
  }) async {
    final apiKey = apiKeyOverride ?? customApiKey;

    // If no API key is provided, execute local heuristic engine (guaranteeing zero runtime failure)
    if (apiKey == null || apiKey.trim().isEmpty) {
      return _generateLocalHeuristicForecast(lead);
    }

    final url = Uri.parse('$_baseUrl?key=${apiKey.trim()}');

    final prompt = '''
You are an expert enterprise B2B sales strategist specialized in corporate office staffing (Professional Cleaners, Pantry Staff, and Tea Boys) in Riyadh, Saudi Arabia.
Analyze this corporate lead:
Company Name: ${lead.companyName}
Riyadh Business Hub: ${lead.hub}
Contact Person: ${lead.contactPerson}
Staffing Requirements: ${lead.staffingRequirements.join(', ')}
Current Status: ${lead.status}
Lead Discovery Date: ${lead.dateAdded}
Existing Notes: ${lead.notes}

Return a valid JSON object strictly matching this schema:
{
  "sentiment": "Positive" | "Neutral" | "Hesitant" | "High Interest",
  "pain_points": ["string", "string"],
  "recommended_action": "string",
  "follow_up_message": "string (Arabic/English personalized WhatsApp pitch highlighting reliability, hygiene, and Saudi corporate etiquette)",
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

    // Automatic 2-attempt retry with exponential backoff on intermittent timeouts (15s ceiling)
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

    // Fallback if network or Gemini API fails
    return _generateLocalHeuristicForecast(lead);
  }

  /// High-value deterministic heuristic fallback engine
  AiAnalysis _generateLocalHeuristicForecast(Lead lead) {
    int score = 65;

    // Premium Riyadh business hubs boost deal probability
    if (lead.hub == 'KAFD' || lead.hub == 'Digital City') {
      score += 15;
    } else if (lead.hub == 'Al Olaya' || lead.hub == 'King Fahd Rd') {
      score += 10;
    }

    // Multi-staff requirements increase deal value
    if (lead.staffingRequirements.length >= 2) {
      score += 10;
    }

    if (score > 98) score = 98;

    final nextDate = DateTime.now().add(const Duration(days: 2));
    final nextFollowUpDate = nextDate.toIso8601String().split('T').first;

    return AiAnalysis(
      sentiment: score >= 80 ? 'High Interest' : 'Neutral',
      pain_points: [
        'Unreliable independent cleaners causing office disruption',
        'Lack of trained tea boys fluent in Saudi VIP corporate etiquette',
        'Administrative overhead of managing individual employee visas & leaves'
      ],
      recommended_action:
          'Send 1-tap WhatsApp corporate pitch highlighting trained Tea Boys & immediate backup replacement guarantee in ${lead.hub}.',
      follow_up_message: '''
السلام عليكم ورحمة الله،
أهلاً وسهلاً سعادة الأستاذ ${lead.contactPerson.isNotEmpty ? lead.contactPerson : 'المسئول'} في ${lead.companyName} (${lead.hub})،
يسعدنا في مؤسسة الضيافة الذكية تزويد مكاتبكم بكوادر مدربة من (مقدمي الضيافة Tea Boys ومسؤولي النظافة المكتبية) بدوام كامل، زي رسمي موحد، وبديل فوري معتمد. هل ترغبون بجدولة زيارة تجريبية مجانية؟
''',
      nextFollowUpDate: nextFollowUpDate,
      dealScore: score,
    );
  }
}
