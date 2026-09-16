import 'package:flutter_test/flutter_test.dart';
import 'package:tea_boy_crm/models/lead.dart';
import 'package:tea_boy_crm/models/zones.dart';
import 'package:tea_boy_crm/models/ai_analysis.dart';
import 'package:tea_boy_crm/services/gemini_service.dart';

void main() {
  group('Enterprise Riyadh CRM Core Unit Tests', () {
    test('Saudi Mobile Normalization to strictly 9665xxxxxxxx', () {
      expect(Lead.sanitizePhone('0501234567'), equals('966501234567'));
      expect(Lead.sanitizePhone('00966501234567'), equals('966501234567'));
      expect(Lead.sanitizePhone('+966 50 123 4567'), equals('966501234567'));
      expect(Lead.sanitizePhone('501234567'), equals('966501234567'));
      expect(Lead.sanitizePhone('966501234567'), equals('966501234567'));
    });

    test('Composite Primary Key Deduplication Key', () {
      final key1 = Lead.buildCompositeKey('Sanabil Capital', '0501234567');
      final key2 = Lead.buildCompositeKey('  sanabil capital ', '+966501234567');
      expect(key1, equals('sanabil capital_966501234567'));
      expect(key1, equals(key2));
    });

    test('Riyadh Hotspots & 5X Expanded Radius Clusters', () {
      expect(RiyadhZones.allZones.length, greaterThanOrEqualTo(14));

      final narjis = RiyadhZones.findZone('Al Narjis Commercial');
      expect(narjis, isNotNull);
      expect(narjis!.category, equals(RiyadhClusterCategory.hotspots));

      final kafd = RiyadhZones.findZone('KAFD Phase 1 & 2');
      expect(kafd, isNotNull);
      expect(kafd!.category, equals(RiyadhClusterCategory.central));

      final sulay = RiyadhZones.findZone('Al Sulay Industrial Zone');
      expect(sulay, isNotNull);
      expect(sulay!.category, equals(RiyadhClusterCategory.industrialLogistics));
    });

    test('Wrong-Number Guard Trigger Detection', () {
      expect(GeminiService.detectWrongContact('غلطان بالرقم يا خوي'), isTrue);
      expect(GeminiService.detectWrongContact('الرقم خطأ'), isTrue);
      expect(GeminiService.detectWrongContact('لست الأستاذ فهد'), isTrue);
      expect(GeminiService.detectWrongContact('wrong number, please remove'), isTrue);
      expect(GeminiService.detectWrongContact('السلام عليكم كم السعر؟'), isFalse);
    });

    test('AiAnalysis JSON Parsing with Schema Guard', () {
      final json = {
        'sentiment': 'Interested',
        'is_wrong_contact': false,
        'pain_points': 'High tea boy turnover and unreliable cleaners',
        'recommended_action': 'Send formal quotation for 2 VIP tea boys',
        'follow_up_message': 'السلام عليكم ورحمة الله',
        'next_follow_up_date': '2026-09-20',
        'deal_score': 88,
      };

      final analysis = AiAnalysis.fromJson(json);
      expect(analysis.sentiment, equals('Interested'));
      expect(analysis.isWrongContact, isFalse);
      expect(analysis.dealScore, equals(88));
      expect(analysis.painPoints, contains('turnover'));
    });

    test('Lead Model State and Status Shift Machine', () {
      final lead = Lead.create(
        companyName: 'Roshn Front Tech HQ',
        contactPerson: 'Saad Al-Qurashi',
        saudiMobile: '0558822334',
        hub: 'Roshn Front Business Zone',
        staffingRequirements: ['Tea Boy', 'Pantry Staff'],
        status: 'new',
      );

      expect(lead.isNew, isTrue);
      expect(lead.isContacted, isFalse);
      expect(lead.saudiMobile, equals('966558822334'));
      expect(lead.estimatedMonthlyValue, equals(8000.0)); // 4200 (Tea Boy) + 3800 (Pantry Staff)

      final contacted = lead.copyWith(
        status: 'contacted',
        contactedAt: DateTime.now().toIso8601String(),
      );
      expect(contacted.isNew, isFalse);
      expect(contacted.isContacted, isTrue);
      expect(contacted.contactedAt, isNotNull);
    });
  });
}
