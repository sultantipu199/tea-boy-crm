import 'dart:math';
import '../models/lead.dart';
import 'hive_service.dart';

class ScrapeResult {
  final int totalScraped;
  final int newLeadsAdded;
  final int skippedDuplicates;
  final List<String> addedCompanyNames;

  ScrapeResult({
    required this.totalScraped,
    required this.newLeadsAdded,
    required this.skippedDuplicates,
    required this.addedCompanyNames,
  });
}

class ScraperService {
  static final ScraperService instance = ScraperService._internal();
  ScraperService._internal();

  // Curated corporate prospect pool representing corporate offices in Riyadh
  static final List<Map<String, dynamic>> _prospectPool = [
    {
      'company_name': 'Kingdom Holding Tower Management',
      'contact_person': 'Saad Al-Qurashi',
      'phone': '966504433221',
      'hub': 'Al Olaya',
      'staffing': ['Tea Boy', 'Cleaners'],
      'notes': 'Corporate headquarters on 35th floor. Inquiring for executive hospitality staff.',
    },
    {
      'company_name': 'Tadawul Group Financial Solutions',
      'contact_person': 'Ibrahim Al-Bawardi',
      'phone': '966551100998',
      'hub': 'KAFD',
      'staffing': ['Tea Boy', 'Pantry Staff'],
      'notes': 'High-traffic trading floor requiring constant pantry and tea boy support.',
    },
    {
      'company_name': 'Cloud Solutions Arabia',
      'contact_person': 'Hassan Al-Harbi',
      'phone': '966567788990',
      'hub': 'Digital City',
      'staffing': ['Cleaners'],
      'notes': 'Software development lab requiring daily morning sanitization.',
    },
    {
      'company_name': 'Riyadh Metro Consortium Corporate Office',
      'contact_person': 'Mansour Al-Husseini',
      'phone': '966532244556',
      'hub': 'King Fahd Rd',
      'staffing': ['Tea Boy', 'Pantry Staff', 'Cleaners'],
      'notes': 'Full facility management staff needed for 4 administrative levels.',
    },
    {
      'company_name': 'Al-Malqa Private Wealth Partners',
      'contact_person': 'Nasser Al-Mutairi',
      'phone': '966548899001',
      'hub': 'Al Malqa',
      'staffing': ['Tea Boy'],
      'notes': 'Family office seeking discreet, well-mannered tea boy.',
    },
    {
      'company_name': 'Aviation Services Group KSA',
      'contact_person': 'Bandar Al-Amri',
      'phone': '966580011223',
      'hub': 'Business Gate',
      'staffing': ['Cleaners', 'Pantry Staff'],
      'notes': 'Administrative hub opposite KKIA, 2 shifts required.',
    },
    {
      'company_name': 'Fintech Saudi Incubator',
      'contact_person': 'Sara Al-Omran',
      'phone': '966509988112',
      'hub': 'KAFD',
      'staffing': ['Tea Boy', 'Pantry Staff'],
      'notes': 'Co-working hub for 50+ startup teams.',
    },
    {
      'company_name': 'Olaya Towers Legal Consultants',
      'contact_person': 'Majed Al-Tuwaijri',
      'phone': '966556677889',
      'hub': 'Al Olaya',
      'staffing': ['Tea Boy', 'Cleaners'],
      'notes': 'Partner meeting suites needing tea service and cleanliness.',
    },
  ];

  /// Scrape / Import new leads for Riyadh hubs while strictly enforcing deduplication
  /// and stamping date_added in YYYY-MM-DD format.
  Future<ScrapeResult> scrapeLeads({String? targetHub}) async {
    final today = DateTime.now().toIso8601String().split('T').first;

    final poolToScrape = targetHub == null || targetHub == 'All'
        ? _prospectPool
        : _prospectPool.where((p) => p['hub'] == targetHub).toList();

    int totalScraped = poolToScrape.length;
    int newLeadsAdded = 0;
    int skippedDuplicates = 0;
    List<String> addedCompanies = [];

    for (final prospect in poolToScrape) {
      final companyName = prospect['company_name'] as String;
      final rawPhone = prospect['phone'] as String;

      // 1. Deduplication Constraint:
      // Composite Primary Key (companyName_sanitizedPhone)
      // Never overwrite or duplicate existing leads when re-scraping a month later.
      final alreadyExists =
          HiveService.instance.leadExists(companyName, rawPhone);

      if (alreadyExists) {
        skippedDuplicates++;
        continue;
      }

      // 2. Timestamps Constraint:
      // Add a 'date_added' field (formatted: YYYY-MM-DD)
      final newLead = Lead.create(
        companyName: companyName,
        contactPerson: prospect['contact_person'] as String,
        saudiMobile: rawPhone,
        hub: prospect['hub'] as String,
        staffingRequirements: List<String>.from(prospect['staffing'] as List),
        status: 'New',
        notes: prospect['notes'] as String,
        dateAdded: today,
      );

      final added = await HiveService.instance.addLead(newLead);
      if (added) {
        newLeadsAdded++;
        addedCompanies.add(companyName);
      } else {
        skippedDuplicates++;
      }
    }

    return ScrapeResult(
      totalScraped: totalScraped,
      newLeadsAdded: newLeadsAdded,
      skippedDuplicates: skippedDuplicates,
      addedCompanyNames: addedCompanies,
    );
  }
}
