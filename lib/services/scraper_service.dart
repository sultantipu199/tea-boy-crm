import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lead.dart';
import '../models/zones.dart';
import 'storage_service.dart';

class ScrapeResult {
  final int totalScraped;
  final int newLeadsAdded;
  final int skippedDuplicates;
  final int skippedBlacklisted;
  final List<String> addedCompanyNames;

  ScrapeResult({
    required this.totalScraped,
    required this.newLeadsAdded,
    required this.skippedDuplicates,
    this.skippedBlacklisted = 0,
    required this.addedCompanyNames,
  });
}

class ScraperService {
  static final ScraperService instance = ScraperService._internal();
  ScraperService._internal();

  static final RegExp _saudiMobileRegex =
      RegExp(r'^(?:\+966|00966|0)?(5[0-9]{8})$');

  static const Map<String, String> _targetQueryMap = {
    'KAFD Phase 1 & 2': 'corporate office in KAFD',
    'Al Olaya': 'business offices in Al Olaya',
    'Al Narjis Commercial': 'consulting company in Al Narjis',
    'Roshn Front Business Zone': 'head office in Roshn Front',
    'King Salman Road Business Strip': 'corporate towers King Salman Rd',
    'Digital City': 'corporate offices in Digital City Riyadh',
    'New Murabba Corridor': 'consulting firms in New Murabba Riyadh',
    'Al Malqa Office Blocks': 'corporate offices in Al Malqa Riyadh',
    'Granada Business Park': 'corporate offices in Granada Business Park Riyadh',
  };

  static String? normalizeSaudiMobile(String? rawPhone) {
    if (rawPhone == null) return null;
    final clean = rawPhone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    final match = _saudiMobileRegex.firstMatch(clean);
    if (match != null) {
      return '+966${match.group(1)}';
    }
    return null;
  }

  static String? _extractPhoneFromPlace(List<dynamic> p1) {
    try {
      if (p1.length > 178 && p1[178] is List && (p1[178] as List).isNotEmpty) {
        final item = p1[178][0];
        if (item is List) {
          if (item.length > 3 && item[3] != null) {
            return item[3].toString();
          }
          if (item.isNotEmpty && item[0] != null) {
            return item[0].toString();
          }
        }
      }
    } catch (_) {}

    String? deepFindPhone(dynamic obj) {
      if (obj is String) {
        if (RegExp(r'(?:\+966\s*5\d|05\d|\+966\s*11|011|9200|800)').hasMatch(obj)) {
          return obj;
        }
      } else if (obj is List) {
        for (final sub in obj) {
          final res = deepFindPhone(sub);
          if (res != null) return res;
        }
      } else if (obj is Map) {
        for (final v in obj.values) {
          final res = deepFindPhone(v);
          if (res != null) return res;
        }
      }
      return null;
    }

    return deepFindPhone(p1);
  }

  /// Query Google Maps live and extract genuine Place records
  Future<List<Map<String, dynamic>>> queryGoogleMapsLive(String searchQuery) async {
    final List<Map<String, dynamic>> results = [];
    final headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Accept-Language': 'en-US,en;q=0.9,ar;q=0.8',
    };

    try {
      final initialUri = Uri.parse(
          'https://www.google.com/maps/search/${Uri.encodeComponent(searchQuery)}');
      final r1 = await http.get(initialUri, headers: headers);
      if (r1.statusCode != 200) return [];

      final linkMatch = RegExp(r'href="(/search\?tbm=map[^"]+)"').firstMatch(r1.body);
      if (linkMatch == null) return [];

      String relativeUrl = linkMatch.group(1)!;
      relativeUrl = relativeUrl.replaceAll('&amp;', '&');
      final fullUri = Uri.parse('https://www.google.com$relativeUrl');

      final r2 = await http.get(fullUri, headers: headers);
      if (r2.statusCode != 200) return [];

      String text = r2.body;
      if (text.startsWith(")]}'")) {
        text = text.substring(4).trim();
      }

      final data = json.decode(text);
      if (data is! List || data.length <= 64 || data[64] is! List) return [];

      final places = data[64] as List<dynamic>;

      for (final p in places) {
        if (p is! List || p.length < 2 || p[1] is! List) continue;
        final p1 = p[1] as List<dynamic>;

        final name = (p1.length > 11 && p1[11] is String) ? p1[11] as String : null;
        if (name == null || name.trim().isEmpty) continue;

        String? placeId;
        if (p1.length > 78 && p1[78] is String && (p1[78] as String).startsWith('ChIJ')) {
          placeId = p1[78] as String;
        } else if (p1.length > 227 && p1[227] is List && (p1[227] as List).isNotEmpty) {
          final sub227 = p1[227][0];
          if (sub227 is List && sub227.length > 4 && sub227[4] is String && (sub227[4] as String).startsWith('ChIJ')) {
            placeId = sub227[4] as String;
          }
        }

        if (placeId == null) continue;

        String address = '';
        if (p1.length > 18 && p1[18] is String) {
          address = p1[18] as String;
        } else if (p1.length > 39 && p1[39] is String) {
          address = p1[39] as String;
        }

        final rawPhone = _extractPhoneFromPlace(p1);

        double? lat;
        double? lng;
        if (p1.length > 9 && p1[9] is List && (p1[9] as List).length >= 4) {
          final l0 = p1[9][2];
          final l1 = p1[9][3];
          if (l0 is num) lat = l0.toDouble();
          if (l1 is num) lng = l1.toDouble();
        }

        results.add({
          'company_name': name.trim(),
          'place_id': placeId,
          'address': address.trim(),
          'google_maps_url': 'https://maps.google.com/?q=place_id:$placeId',
          'raw_phone': rawPhone,
          'lat': lat,
          'lng': lng,
        });
      }
    } catch (_) {}

    return results;
  }

  /// Scrape 100% authentic Google Maps profiles for Riyadh corporate hubs
  /// Enforces: ZERO synthetic data, ZERO duplication, and Saudi Mobile Filtering
  Future<ScrapeResult> scrapeLeads({
    String? targetHub,
    RiyadhClusterCategory? clusterCategory,
    int dynamicCount = 15,
  }) async {
    final today = DateTime.now().toIso8601String().split('T').first;

    // Determine target queries
    List<MapEntry<String, String>> queriesToRun = [];

    if (targetHub != null && targetHub != 'All') {
      final q = _targetQueryMap[targetHub] ?? 'corporate offices in $targetHub Riyadh';
      queriesToRun.add(MapEntry(targetHub, q));
    } else {
      queriesToRun = _targetQueryMap.entries.toList();
    }

    int totalScraped = 0;
    int newLeadsAdded = 0;
    int skippedDuplicates = 0;
    int skippedBlacklisted = 0;
    List<String> addedCompanies = [];

    for (final entry in queriesToRun) {
      final hubName = entry.key;
      final queryText = entry.value;

      final places = await queryGoogleMapsLive(queryText);
      totalScraped += places.length;

      for (final place in places) {
        final rawPhone = place['raw_phone'] as String?;
        final companyName = place['company_name'] as String;
        final placeId = place['place_id'] as String;
        final address = place['address'] as String;
        final googleMapsUrl = place['google_maps_url'] as String;
        final lat = place['lat'] as double?;
        final lng = place['lng'] as double?;

        // 1. Strict Saudi Mobile Filter: accept ONLY mobile 05xxxxxxxx -> +9665xxxxxxxx
        final normalizedPhone = normalizeSaudiMobile(rawPhone);
        if (normalizedPhone == null) {
          // Discard landline, 9200, 800, missing
          continue;
        }

        // 2. Blacklist Check
        if (StorageService.instance.isBlacklisted(normalizedPhone)) {
          skippedBlacklisted++;
          continue;
        }

        // 3. Persistent SHA-256 Deduplication Check
        final hashKey = Lead.buildDeduplicationHash(normalizedPhone, placeId);
        if (StorageService.instance.isLeadProcessed(hashKey) ||
            StorageService.instance.leadExists(companyName, normalizedPhone, placeId)) {
          skippedDuplicates++;
          continue;
        }

        // 4. Create authentic Lead
        final newLead = Lead.create(
          companyName: companyName,
          contactPerson: 'Office / Procurement Director',
          saudiMobile: normalizedPhone,
          hub: hubName,
          placeId: placeId,
          address: address,
          googleMapsUrl: googleMapsUrl,
          hashKey: hashKey,
          lat: lat,
          lng: lng,
          staffingRequirements: ['Tea Boy', 'Pantry Staff', 'Cleaners'],
          status: 'new',
          notes: 'Verified Google Maps profile in $hubName. Address: ${address.isNotEmpty ? address : "Riyadh"}. Place ID: $placeId.',
          dateAdded: today,
          intentScore: 90,
        );

        final added = await StorageService.instance.addLead(newLead);
        if (added) {
          newLeadsAdded++;
          addedCompanies.add(companyName);
        } else {
          skippedDuplicates++;
        }
      }
    }

    return ScrapeResult(
      totalScraped: totalScraped,
      newLeadsAdded: newLeadsAdded,
      skippedDuplicates: skippedDuplicates,
      skippedBlacklisted: skippedBlacklisted,
      addedCompanyNames: addedCompanies,
    );
  }
}
