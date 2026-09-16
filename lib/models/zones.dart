enum RiyadhClusterCategory {
  all('All'),
  hotspots('Hotspots (Narjis/Roshn)'),
  central('Central (KAFD/Olaya)'),
  northHubs('North Hubs'),
  industrialLogistics('Industrial/Logistics');

  final String label;
  const RiyadhClusterCategory(this.label);

  static RiyadhClusterCategory fromLabel(String label) {
    return RiyadhClusterCategory.values.firstWhere(
      (c) => c.label.toLowerCase() == label.toLowerCase(),
      orElse: () => RiyadhClusterCategory.all,
    );
  }
}

class RiyadhZone {
  final String id;
  final String name;
  final String arabicName;
  final RiyadhClusterCategory category;
  final String targetSector;
  final String mapsQuery;
  final int defaultIntentBoost;

  const RiyadhZone({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.category,
    required this.targetSector,
    required this.mapsQuery,
    this.defaultIntentBoost = 10,
  });
}

class RiyadhZones {
  static const List<RiyadhZone> allZones = [
    // 1. Hotspot Boom Strip
    RiyadhZone(
      id: 'al_narjis',
      name: 'Al Narjis Commercial',
      arabicName: 'النرجس التجاري',
      category: RiyadhClusterCategory.hotspots,
      targetSector: 'Newly fitted physical offices & consulting firms',
      mapsQuery: 'Al Narjis Commercial Riyadh',
      defaultIntentBoost: 25,
    ),
    RiyadhZone(
      id: 'roshn_front',
      name: 'Roshn Front Business Zone',
      arabicName: 'واجهة روشن للأعمال',
      category: RiyadhClusterCategory.hotspots,
      targetSector: 'Tech HQs & luxury corporate suites',
      mapsQuery: 'Roshn Front Business Zone Riyadh',
      defaultIntentBoost: 25,
    ),
    RiyadhZone(
      id: 'king_salman_strip',
      name: 'King Salman Road Business Strip',
      arabicName: 'شريط طريق الملك سلمان للأعمال',
      category: RiyadhClusterCategory.hotspots,
      targetSector: 'Regional headquarters & premium towers',
      mapsQuery: 'King Salman Road Riyadh corporate',
      defaultIntentBoost: 20,
    ),
    RiyadhZone(
      id: 'new_murabba',
      name: 'New Murabba Corridor',
      arabicName: 'ممر المربع الجديد',
      category: RiyadhClusterCategory.hotspots,
      targetSector: 'Mega-project contractor & consultant HQs',
      mapsQuery: 'New Murabba Riyadh',
      defaultIntentBoost: 20,
    ),
    RiyadhZone(
      id: 'al_yasmin',
      name: 'Al Yasmin',
      arabicName: 'الياسمين التجاري',
      category: RiyadhClusterCategory.hotspots,
      targetSector: 'Boutique agencies & financial advisory offices',
      mapsQuery: 'Al Yasmin Commercial District Riyadh',
      defaultIntentBoost: 15,
    ),
    RiyadhZone(
      id: 'al_khuzama',
      name: 'Al Khuzama',
      arabicName: 'الخزامى',
      category: RiyadhClusterCategory.hotspots,
      targetSector: 'Executive suites & private family offices',
      mapsQuery: 'Al Khuzama Riyadh',
      defaultIntentBoost: 15,
    ),

    // 2. Core Corporate Hubs
    RiyadhZone(
      id: 'kafd',
      name: 'KAFD Phase 1 & 2',
      arabicName: 'مركز الملك عبدالله المالي (كافد)',
      category: RiyadhClusterCategory.central,
      targetSector: 'Investment banks, RHQs & tier-1 consultancies',
      mapsQuery: 'King Abdullah Financial District KAFD Riyadh',
      defaultIntentBoost: 30,
    ),
    RiyadhZone(
      id: 'al_olaya',
      name: 'Al Olaya',
      arabicName: 'العليا التجارية',
      category: RiyadhClusterCategory.central,
      targetSector: 'Financial towers, law firms & multinational branches',
      mapsQuery: 'Al Olaya Corporate Towers Riyadh',
      defaultIntentBoost: 20,
    ),
    RiyadhZone(
      id: 'king_fahd_rd',
      name: 'King Fahd Rd',
      arabicName: 'طريق الملك فهد',
      category: RiyadhClusterCategory.central,
      targetSector: 'Major corporate skyscrapers & insurance HQs',
      mapsQuery: 'King Fahd Road Riyadh business',
      defaultIntentBoost: 20,
    ),
    RiyadhZone(
      id: 'digital_city',
      name: 'Digital City',
      arabicName: 'المدينة الرقمية',
      category: RiyadhClusterCategory.central,
      targetSector: 'Fintech, cybersecurity, IT & government contractors',
      mapsQuery: 'Digital City Riyadh',
      defaultIntentBoost: 25,
    ),
    RiyadhZone(
      id: 'business_gate',
      name: 'Business Gate',
      arabicName: 'بوابة الأعمال',
      category: RiyadhClusterCategory.central,
      targetSector: 'Aerospace, enterprise software & diplomatic contractors',
      mapsQuery: 'Business Gate Airport Road Riyadh',
      defaultIntentBoost: 20,
    ),
    RiyadhZone(
      id: 'al_malqa',
      name: 'Al Malqa Office Blocks',
      arabicName: 'مجمعات مكاتب الملقا',
      category: RiyadhClusterCategory.northHubs,
      targetSector: 'Executive clinics, private equity & fintech startups',
      mapsQuery: 'Al Malqa Riyadh corporate office blocks',
      defaultIntentBoost: 20,
    ),

    // 3. Tech & Logistics Corridors
    RiyadhZone(
      id: 'granada_business_park',
      name: 'Granada Business Park',
      arabicName: 'مجمع غرناطة للأعمال',
      category: RiyadhClusterCategory.northHubs,
      targetSector: 'Telecom giants, tech multinationals & shared service centers',
      mapsQuery: 'Granada Business Park Riyadh',
      defaultIntentBoost: 20,
    ),
    RiyadhZone(
      id: 'al_yarmouk',
      name: 'Al Yarmouk',
      arabicName: 'اليرموك التجاري',
      category: RiyadhClusterCategory.northHubs,
      targetSector: 'Commercial corporate services & supply chain offices',
      mapsQuery: 'Al Yarmouk Commercial Riyadh',
      defaultIntentBoost: 15,
    ),
    RiyadhZone(
      id: 'kkia_logistics',
      name: 'King Khalid Int\'l Airport Logistics Zone',
      arabicName: 'منطقة مطار الملك خالد اللوجستية',
      category: RiyadhClusterCategory.industrialLogistics,
      targetSector: 'Air freight, customs clearance & supply chain head offices',
      mapsQuery: 'King Khalid International Airport Logistics Zone Riyadh',
      defaultIntentBoost: 20,
    ),

    // 4. Industrial HQs
    RiyadhZone(
      id: 'al_sulay',
      name: 'Al Sulay Industrial Zone',
      arabicName: 'منطقة السلي الصناعية والتجارية',
      category: RiyadhClusterCategory.industrialLogistics,
      targetSector: 'Industrial corporate administration & central depots',
      mapsQuery: 'Al Sulay Industrial Zone Riyadh',
      defaultIntentBoost: 15,
    ),
    RiyadhZone(
      id: 'riyadh_second_industrial',
      name: 'Riyadh Second Industrial City',
      arabicName: 'المدينة الصناعية الثانية (المكاتب والمستودعات)',
      category: RiyadhClusterCategory.industrialLogistics,
      targetSector: 'Manufacturing HQs, pharma plants & engineering offices',
      mapsQuery: 'Second Industrial City Riyadh',
      defaultIntentBoost: 15,
    ),
  ];

  static List<String> get allClusterNames =>
      allZones.map((z) => z.name).toList();

  static RiyadhZone? findZone(String hubName) {
    final clean = hubName.trim().toLowerCase();
    for (final zone in allZones) {
      if (zone.name.toLowerCase() == clean ||
          zone.id.toLowerCase() == clean ||
          zone.arabicName.toLowerCase() == clean) {
        return zone;
      }
      if (clean.contains('narjis') && zone.id == 'al_narjis') return zone;
      if (clean.contains('roshn') && zone.id == 'roshn_front') return zone;
      if (clean.contains('kafd') && zone.id == 'kafd') return zone;
      if (clean.contains('olaya') && zone.id == 'al_olaya') return zone;
      if (clean.contains('fahd') && zone.id == 'king_fahd_rd') return zone;
      if (clean.contains('digital') && zone.id == 'digital_city') return zone;
      if (clean.contains('malqa') && zone.id == 'al_malqa') return zone;
      if (clean.contains('salman') && zone.id == 'king_salman_strip') return zone;
      if (clean.contains('murabba') && zone.id == 'new_murabba') return zone;
      if (clean.contains('granada') && zone.id == 'granada_business_park') return zone;
      if (clean.contains('yarmouk') && zone.id == 'al_yarmouk') return zone;
      if (clean.contains('sulay') && zone.id == 'al_sulay') return zone;
      if (clean.contains('second industrial') && zone.id == 'riyadh_second_industrial') return zone;
      if (clean.contains('airport') && zone.id == 'kkia_logistics') return zone;
      if (clean.contains('gate') && zone.id == 'business_gate') return zone;
      if (clean.contains('yasmin') && zone.id == 'al_yasmin') return zone;
      if (clean.contains('khuzama') && zone.id == 'al_khuzama') return zone;
    }
    return null;
  }

  static RiyadhClusterCategory categoryForHub(String hub) {
    final zone = findZone(hub);
    return zone?.category ?? RiyadhClusterCategory.central;
  }

  static bool matchesCategory(String hub, RiyadhClusterCategory category) {
    if (category == RiyadhClusterCategory.all) return true;
    final hubCategory = categoryForHub(hub);
    return hubCategory == category;
  }
}
