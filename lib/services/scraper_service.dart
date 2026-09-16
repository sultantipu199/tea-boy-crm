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

  // Curated corporate prospect pool across Greater Riyadh's 4 clusters and 5X expanded radius
  static final List<Map<String, dynamic>> _expandedProspectPool = [
    // --- Cluster 1: Hotspot Boom Strip ---
    {
      'company_name': 'Al Narjis Executive Office Suites',
      'contact_person': 'Saud Al-Qahtani',
      'phone': '966509911223',
      'hub': 'Al Narjis Commercial',
      'staffing': ['Tea Boy', 'Pantry Staff'],
      'intent_score': 92,
      'notes': 'Newly opened corporate floor requiring 2 dedicated bilingual tea boys.',
    },
    {
      'company_name': 'Roshn Front Cloud Innovations',
      'contact_person': 'Waleed Al-Bishi',
      'phone': '966558822334',
      'hub': 'Roshn Front Business Zone',
      'staffing': ['Tea Boy', 'Cleaners'],
      'intent_score': 89,
      'notes': 'Tech venture headquarters. High daily visitor flow in boardroom.',
    },
    {
      'company_name': 'King Salman Strip Regional HQ',
      'contact_person': 'Nawaf Al-Mutlaq',
      'phone': '966567733445',
      'hub': 'King Salman Road Business Strip',
      'staffing': ['Tea Boy', 'Pantry Staff', 'Cleaners'],
      'intent_score': 94,
      'notes': 'RHQ multinational setup needing turnkey pantry operations.',
    },
    {
      'company_name': 'New Murabba Architectural Group',
      'contact_person': 'Eng. Omar Al-Ghamdi',
      'phone': '966546644556',
      'hub': 'New Murabba Corridor',
      'staffing': ['Cleaners', 'Tea Boy'],
      'intent_score': 88,
      'notes': 'Engineering consultants project office for New Murabba development.',
    },
    {
      'company_name': 'Al Yasmin Financial Advisory',
      'contact_person': 'Ziyad Al-Husseini',
      'phone': '966535555667',
      'hub': 'Al Yasmin',
      'staffing': ['Tea Boy'],
      'intent_score': 83,
      'notes': 'Private wealth advisory needing discreet, well-trained tea boy.',
    },
    {
      'company_name': 'Al Khuzama Executive Chambers',
      'contact_person': 'Talal Al-Dakhil',
      'phone': '966504466778',
      'hub': 'Al Khuzama',
      'staffing': ['Tea Boy', 'Pantry Staff'],
      'intent_score': 85,
      'notes': 'Family office seeking high-etiquette hospitality staff.',
    },

    // --- Cluster 2: Core Corporate Hubs ---
    {
      'company_name': 'Kingdom Holding Tower Management',
      'contact_person': 'Saad Al-Qurashi',
      'phone': '966504433221',
      'hub': 'Al Olaya',
      'staffing': ['Tea Boy', 'Cleaners'],
      'intent_score': 90,
      'notes': 'Corporate headquarters on 35th floor. Inquiring for executive hospitality staff.',
    },
    {
      'company_name': 'Tadawul Group Financial Solutions',
      'contact_person': 'Ibrahim Al-Bawardi',
      'phone': '966551100998',
      'hub': 'KAFD Phase 1 & 2',
      'staffing': ['Tea Boy', 'Pantry Staff'],
      'intent_score': 95,
      'notes': 'High-traffic trading floor requiring constant pantry and tea boy support.',
    },
    {
      'company_name': 'Cloud Solutions Arabia',
      'contact_person': 'Hassan Al-Harbi',
      'phone': '966567788990',
      'hub': 'Digital City',
      'staffing': ['Cleaners'],
      'intent_score': 80,
      'notes': 'Software development lab requiring daily morning sanitization.',
    },
    {
      'company_name': 'Riyadh Metro Consortium Corporate Office',
      'contact_person': 'Mansour Al-Husseini',
      'phone': '966532244556',
      'hub': 'King Fahd Rd',
      'staffing': ['Tea Boy', 'Pantry Staff', 'Cleaners'],
      'intent_score': 87,
      'notes': 'Full facility management staff needed for 4 administrative levels.',
    },
    {
      'company_name': 'Al-Malqa Private Wealth Partners',
      'contact_person': 'Nasser Al-Mutairi',
      'phone': '966548899001',
      'hub': 'Al Malqa Office Blocks',
      'staffing': ['Tea Boy'],
      'intent_score': 86,
      'notes': 'Family office seeking discreet, well-mannered tea boy.',
    },
    {
      'company_name': 'Aviation Services Group KSA',
      'contact_person': 'Bandar Al-Amri',
      'phone': '966580011223',
      'hub': 'Business Gate',
      'staffing': ['Cleaners', 'Pantry Staff'],
      'intent_score': 85,
      'notes': 'Administrative hub opposite KKIA, 2 shifts required.',
    },

    // --- Cluster 3: Tech & Logistics Corridors ---
    {
      'company_name': 'Granada Enterprise Cloud HQ',
      'contact_person': 'Faisal Al-Jasser',
      'phone': '966503377889',
      'hub': 'Granada Business Park',
      'staffing': ['Tea Boy', 'Pantry Staff'],
      'intent_score': 87,
      'notes': 'Tech enterprise needing full pantry supervision and meeting hospitality.',
    },
    {
      'company_name': 'Al Yarmouk Commercial Services',
      'contact_person': 'Abdullah Al-Subaie',
      'phone': '966552288990',
      'hub': 'Al Yarmouk',
      'staffing': ['Cleaners'],
      'intent_score': 78,
      'notes': 'Corporate administrative building. Needs 2 morning cleaners.',
    },
    {
      'company_name': 'KKIA Logistics Cargo Headquarters',
      'contact_person': 'Majed Al-Harbi',
      'phone': '966561199001',
      'hub': 'King Khalid Int\'l Airport Logistics Zone',
      'staffing': ['Cleaners', 'Tea Boy'],
      'intent_score': 82,
      'notes': 'Air cargo corporate offices near customs gate.',
    },

    // --- Cluster 4: Industrial HQs ---
    {
      'company_name': 'Al Sulay Central Industrial Logistics',
      'contact_person': 'Yasser Al-Ghamdi',
      'phone': '966540011223',
      'hub': 'Al Sulay Industrial Zone',
      'staffing': ['Cleaners', 'Pantry Staff'],
      'intent_score': 79,
      'notes': 'Corporate headquarters inside logistics hub.',
    },
    {
      'company_name': 'Riyadh Second Industrial Manufacturing HQs',
      'contact_person': 'Eng. Khalid Al-Dosari',
      'phone': '966539922334',
      'hub': 'Riyadh Second Industrial City',
      'staffing': ['Tea Boy', 'Cleaners'],
      'intent_score': 81,
      'notes': 'Executive administration building for pharmaceutical plant.',
    },

    // --- Cluster 5: Western & Eastern Hubs ---
    {
      'company_name': 'Jeddah Waterfront Luxury Shipping RHQ',
      'contact_person': 'Capt. Hani Al-Ghamdi',
      'phone': '966557788112',
      'hub': 'Jeddah Waterfront/Andalus',
      'staffing': ['Tea Boy', 'Pantry Staff'],
      'intent_score': 88,
      'notes': 'Red Sea luxury corporate suite and maritime executive boardroom.',
    },
    {
      'company_name': 'Khobar Corniche Offshore Petroleum Services',
      'contact_person': 'Faisal Al-Tamimi',
      'phone': '966548899223',
      'hub': 'Khobar Corniche/Logistics',
      'staffing': ['Tea Boy', 'Cleaners'],
      'intent_score': 86,
      'notes': 'Engineering operations floor overlooking Khobar Corniche.',
    },
    {
      'company_name': 'Dammam Industrial Port Logistics Terminal',
      'contact_person': 'Sami Al-Khatib',
      'phone': '966569900334',
      'hub': 'Dammam Industrial',
      'staffing': ['Cleaners', 'Pantry Staff'],
      'intent_score': 80,
      'notes': 'Port administration and customs clearance corporate building.',
    },
  ];

  /// Scrape fresh corporate leads across Greater Riyadh clusters
  Future<ScrapeResult> scrapeLeads({
    String? targetHub,
    RiyadhClusterCategory? clusterCategory,
  }) async {
    final today = DateTime.now().toIso8601String().split('T').first;

    List<Map<String, dynamic>> poolToScrape = _expandedProspectPool;

    if (clusterCategory != null &&
        clusterCategory != RiyadhClusterCategory.all) {
      poolToScrape = poolToScrape.where((p) {
        final hub = p['hub'] as String;
        return RiyadhZones.matchesCategory(hub, clusterCategory);
      }).toList();
    } else if (targetHub != null && targetHub != 'All') {
      poolToScrape =
          poolToScrape.where((p) => p['hub'] == targetHub).toList();
    }

    int totalScraped = poolToScrape.length;
    int newLeadsAdded = 0;
    int skippedDuplicates = 0;
    int skippedBlacklisted = 0;
    List<String> addedCompanies = [];

    for (final prospect in poolToScrape) {
      final companyName = prospect['company_name'] as String;
      final rawPhone = prospect['phone'] as String;

      // 1. Blacklist Check
      if (StorageService.instance.isBlacklisted(rawPhone)) {
        skippedBlacklisted++;
        continue;
      }

      // 2. Strict Deduplication Check
      final alreadyExists =
          StorageService.instance.leadExists(companyName, rawPhone);
      if (alreadyExists) {
        skippedDuplicates++;
        continue;
      }

      // 3. Create structured lead
      final newLead = Lead.create(
        companyName: companyName,
        contactPerson: prospect['contact_person'] as String,
        saudiMobile: rawPhone,
        hub: prospect['hub'] as String,
        staffingRequirements: List<String>.from(prospect['staffing'] as List),
        status: 'new',
        notes: prospect['notes'] as String,
        dateAdded: today,
        intentScore: prospect['intent_score'] as int?,
      );

      final added = await StorageService.instance.addLead(newLead);
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
      skippedBlacklisted: skippedBlacklisted,
      addedCompanyNames: addedCompanies,
    );
  }
}
