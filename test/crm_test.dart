import 'package:flutter_test/flutter_test.dart';
import 'package:tea_boy_crm/models/lead.dart';
import 'package:tea_boy_crm/models/zones.dart';
import 'package:tea_boy_crm/models/ai_analysis.dart';
import 'package:tea_boy_crm/services/dispatch_service.dart';
import 'package:tea_boy_crm/services/gemini_service.dart';
import 'package:tea_boy_crm/services/geo_service.dart';
import 'package:tea_boy_crm/services/scraper_service.dart';

void main() {
  group('Enterprise Saudi B2B CRM Core Unit Tests', () {
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
      expect(RiyadhZones.allZones.length, greaterThanOrEqualTo(16));

      final narjis = RiyadhZones.findZone('Al Narjis Commercial');
      expect(narjis, isNotNull);
      expect(narjis!.category, equals(RiyadhClusterCategory.hotspots));
      expect(narjis.isRiyadhPrimary, isTrue);

      final kafd = RiyadhZones.findZone('KAFD Phase 1 & 2');
      expect(kafd, isNotNull);
      expect(kafd!.category, equals(RiyadhClusterCategory.central));
      expect(kafd.isRiyadhPrimary, isTrue);

      // Western & Eastern Hub verification
      final jeddah = RiyadhZones.findZone('Jeddah Waterfront/Andalus');
      expect(jeddah, isNotNull);
      expect(jeddah!.region, equals(HubRegion.western));
      expect(jeddah.isSecondaryHub, isTrue);

      final khobar = RiyadhZones.findZone('Khobar Corniche/Logistics');
      expect(khobar, isNotNull);
      expect(khobar!.region, equals(HubRegion.eastern));
      expect(khobar.isSecondaryHub, isTrue);
    });

    test('Haversine Distance Formula & Proximity Matrix', () {
      // Distance between KAFD (24.7677, 46.6433) and Al Narjis (24.8427, 46.6667)
      final dist = GeoService.haversineDistance(
        24.7677,
        46.6433,
        24.8427,
        46.6667,
      );

      // Should be approx 8.6 km
      expect(dist, greaterThan(7.0));
      expect(dist, lessThan(11.0));

      // Same point distance should be 0
      final zeroDist = GeoService.haversineDistance(
        24.7677,
        46.6433,
        24.7677,
        46.6433,
      );
      expect(zeroDist, closeTo(0.0, 0.001));
    });

    test('Riyadh-First Priority & In-Bucket Dynamic Distance Sorting', () {
      final kafdLead = Lead.create(
        companyName: 'KAFD Bank RHQ',
        contactPerson: 'Manager',
        saudiMobile: '0501111111',
        hub: 'KAFD Phase 1 & 2', // approx 0 km from KAFD anchor
        staffingRequirements: ['Tea Boy'],
      );

      final narjisLead = Lead.create(
        companyName: 'Narjis Tech Consulting',
        contactPerson: 'Lead',
        saudiMobile: '0502222222',
        hub: 'Al Narjis Commercial', // approx 8.6 km from KAFD anchor
        staffingRequirements: ['Cleaners'],
      );

      final jeddahLead = Lead.create(
        companyName: 'Red Sea Maritime',
        contactPerson: 'Capt',
        saudiMobile: '0503333333',
        hub: 'Jeddah Waterfront/Andalus', // Western Hub (~850 km)
        staffingRequirements: ['Pantry Staff'],
      );

      final khobarLead = Lead.create(
        companyName: 'Khobar Oilfield Services',
        contactPerson: 'Eng',
        saudiMobile: '0504444444',
        hub: 'Khobar Corniche/Logistics', // Eastern Hub (~400 km)
        staffingRequirements: ['Tea Boy'],
      );

      final leads = [jeddahLead, narjisLead, khobarLead, kafdLead];

      // Sort from KAFD anchor position (24.7677, 46.6433)
      final sorted = GeoService.instance.sortLeadsByRiyadhProximity(
        leads,
        const GeoCoordinates(24.7677, 46.6433),
      );

      // 1. Primary Bucket (Riyadh) MUST strictly precede Secondary Bucket (Western/Eastern)
      expect(sorted[0].hub, equals('KAFD Phase 1 & 2'));
      expect(sorted[1].hub, equals('Al Narjis Commercial'));

      // 2. In-bucket dynamic sorting for Secondary Bucket:
      // Khobar (~400 km) is closer to Riyadh than Jeddah (~850 km)
      expect(sorted[2].hub, equals('Khobar Corniche/Logistics'));
      expect(sorted[3].hub, equals('Jeddah Waterfront/Andalus'));
    });

    test('Zero-Bug Dual RFC Dispatcher Parameter Encoding', () {
      const sampleText = 'VIP Tea Boy Service\nPrice: 4,200 SAR/mo';
      final encoded = DispatchService.encodeParam(sampleText);

      // Must NOT contain unencoded '+' signs
      expect(encoded.contains('+'), isFalse);
      // Spaces must be %20
      expect(encoded.contains('%20'), isTrue);
      // Newlines must be %0A
      expect(encoded.contains('%0A'), isTrue);
    });

    test('Wrong-Number Guard Trigger Detection', () {
      expect(GeminiService.detectWrongContact('غلطان بالرقم يا خوي'), isTrue);
      expect(GeminiService.detectWrongContact('الرقم خطأ'), isTrue);
      expect(GeminiService.detectWrongContact('لست الأستاذ فهد'), isTrue);
      expect(
          GeminiService.detectWrongContact('wrong number, please remove'), isTrue);
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

    test('Lead Model State, Email Generation, and Status Shift Machine', () {
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
      expect(lead.estimatedMonthlyValue, equals(8000.0));
      expect(lead.email, contains('@roshnfronttechhq.sa'));
      expect(lead.corporateEmailSubject, contains('Roshn Front Tech HQ'));

      final contacted = lead.copyWith(
        status: 'contacted',
        contactedAt: DateTime.now().toIso8601String(),
      );
      expect(contacted.isNew, isFalse);
      expect(contacted.isContacted, isTrue);
      expect(contacted.contactedAt, isNotNull);
    });

    test('Strict Saudi Mobile Filter Discards Landlines, Unified, and Non-Mobiles', () {
      // Valid mobile numbers -> strictly +9665xxxxxxxx
      expect(ScraperService.normalizeSaudiMobile('0501234567'), equals('+966501234567'));
      expect(ScraperService.normalizeSaudiMobile('+966501234567'), equals('+966501234567'));
      expect(ScraperService.normalizeSaudiMobile('00966559876543'), equals('+966559876543'));
      expect(ScraperService.normalizeSaudiMobile('+966 53 100 0216'), equals('+966531000216'));

      // Discarded Landlines (011), Unified lines (9200, 800), and invalid
      expect(ScraperService.normalizeSaudiMobile('0114644844'), isNull);
      expect(ScraperService.normalizeSaudiMobile('0112738000'), isNull);
      expect(ScraperService.normalizeSaudiMobile('920012372'), isNull);
      expect(ScraperService.normalizeSaudiMobile('920024460'), isNull);
      expect(ScraperService.normalizeSaudiMobile('8001234567'), isNull);
      expect(ScraperService.normalizeSaudiMobile(''), isNull);
      expect(ScraperService.normalizeSaudiMobile(null), isNull);
    });

    test('Bulletproof SHA-256 Composite Deduplication Key', () {
      final hash1 = Lead.buildDeduplicationHash('+966581297003', 'ChIJJzoGECgDLz4Raw9i1BPA9T8');
      final hash2 = Lead.buildDeduplicationHash('0581297003', 'ChIJJzoGECgDLz4Raw9i1BPA9T8');
      
      // Must be a valid 64-char lowercase hex string
      expect(hash1.length, equals(64));
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(hash1), isTrue);

      // Must normalize phone identically
      expect(hash1, equals(hash2));

      // Different Place ID must yield different hash
      final hash3 = Lead.buildDeduplicationHash('+966581297003', 'ChIJK2fMfiwDLz4RFWnQIXYtzlw');
      expect(hash1, isNot(equals(hash3)));
    });

    test('Authentic Google Maps Place Metadata and Direct Playable Links', () {
      final lead = Lead.create(
        companyName: 'Business tower',
        contactPerson: 'Office / Procurement Director',
        saudiMobile: '0581297003',
        hub: 'Al Olaya',
        placeId: 'ChIJJzoGECgDLz4Raw9i1BPA9T8',
        address: 'Business tower, 7135, 2478, Al Olaya, Riyadh 12244',
        staffingRequirements: ['Tea Boy', 'Cleaners'],
      );

      expect(lead.placeId, equals('ChIJJzoGECgDLz4Raw9i1BPA9T8'));
      expect(lead.googleMapsUrl, equals('https://maps.google.com/?q=place_id:ChIJJzoGECgDLz4Raw9i1BPA9T8'));
      expect(lead.address, contains('Al Olaya'));
      expect(lead.id.length, equals(64)); // SHA-256 hash as primary id

      // Serialization round-trip
      final json = lead.toJson();
      expect(json['place_id'], equals('ChIJJzoGECgDLz4Raw9i1BPA9T8'));
      expect(json['google_maps_url'], equals('https://maps.google.com/?q=place_id:ChIJJzoGECgDLz4Raw9i1BPA9T8'));
      expect(json['hash_key'], equals(lead.id));

      final restored = Lead.fromJson(json);
      expect(restored.placeId, equals(lead.placeId));
      expect(restored.googleMapsUrl, equals(lead.googleMapsUrl));
      expect(restored.id, equals(lead.id));
    });
  });
}
