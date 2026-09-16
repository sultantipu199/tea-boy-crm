enum HubRegion {
  riyadh,
  western,
  eastern,
  other,
}

enum RiyadhClusterCategory {
  all('All KSA Hubs'),
  hotspots('Hotspots (Narjis/Roshn)'),
  central('Central (KAFD/Olaya)'),
  northHubs('North Hubs'),
  industrialLogistics('Industrial/Logistics'),
  westernEastern('Western & Eastern Hubs');

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
  final HubRegion region;
  final String targetSector;
  final String mapsQuery;
  final double latitude;
  final double longitude;
  final int defaultIntentBoost;

  const RiyadhZone({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.category,
    this.region = HubRegion.riyadh,
    required this.targetSector,
    required this.mapsQuery,
    required this.latitude,
    required this.longitude,
    this.defaultIntentBoost = 10,
  });

  bool get isRiyadhPrimary => region == HubRegion.riyadh;
  bool get isSecondaryHub =>
      region == HubRegion.western || region == HubRegion.eastern;
}

class RiyadhZones {
  // Central Riyadh Anchor (KAFD) default fallback coordinates
  static const double defaultLat = 24.7677;
  static const double defaultLng = 46.6433;

  static const List<RiyadhZone> allZones = [
    // ----------------------------------------------------
    // PRIMARY BUCKET: Greater Riyadh Hubs
    // ----------------------------------------------------

    // 1. Hotspot Boom Strip
    RiyadhZone(
      id: 'al_narjis',
      name: 'Al Narjis Commercial',
      arabicName: 'النرجس التجاري',
      category: RiyadhClusterCategory.hotspots,
      region: HubRegion.riyadh,
      targetSector: 'Newly fitted physical offices & consulting firms',
      mapsQuery: 'Al Narjis Commercial Riyadh',
      latitude: 24.8427,
      longitude: 46.6667,
      defaultIntentBoost: 25,
    ),
    RiyadhZone(
      id: 'roshn_front',
      name: 'Roshn Front Business Zone',
      arabicName: 'واجهة روشن للأعمال',
      category: RiyadhClusterCategory.hotspots,
      region: HubRegion.riyadh,
      targetSector: 'Tech HQs & luxury corporate suites',
      mapsQuery: 'Roshn Front Business Zone Riyadh',
      latitude: 24.8322,
      longitude: 46.7314,
      defaultIntentBoost: 25,
    ),
    RiyadhZone(
      id: 'king_salman_strip',
      name: 'King Salman Road Business Strip',
      arabicName: 'شريط طريق الملك سلمان للأعمال',
      category: RiyadhClusterCategory.hotspots,
      region: HubRegion.riyadh,
      targetSector: 'Regional headquarters & premium towers',
      mapsQuery: 'King Salman Road Riyadh corporate',
      latitude: 24.8611,
      longitude: 46.6111,
      defaultIntentBoost: 20,
    ),
    RiyadhZone(
      id: 'new_murabba',
      name: 'New Murabba Corridor',
      arabicName: 'ممر المربع الجديد',
      category: RiyadhClusterCategory.hotspots,
      region: HubRegion.riyadh,
      targetSector: 'Mega-project contractor & consultant HQs',
      mapsQuery: 'New Murabba Riyadh',
      latitude: 24.7800,
      longitude: 46.6100,
      defaultIntentBoost: 20,
    ),
    RiyadhZone(
      id: 'al_yasmin',
      name: 'Al Yasmin',
      arabicName: 'الياسمين التجاري',
      category: RiyadhClusterCategory.hotspots,
      region: HubRegion.riyadh,
      targetSector: 'Boutique agencies & financial advisory offices',
      mapsQuery: 'Al Yasmin Commercial District Riyadh',
      latitude: 24.8211,
      longitude: 46.6480,
      defaultIntentBoost: 15,
    ),
    RiyadhZone(
      id: 'al_khuzama',
      name: 'Al Khuzama',
      arabicName: 'الخزامى',
      category: RiyadhClusterCategory.hotspots,
      region: HubRegion.riyadh,
      targetSector: 'Executive suites & private family offices',
      mapsQuery: 'Al Khuzama Riyadh',
      latitude: 24.6970,
      longitude: 46.6150,
      defaultIntentBoost: 15,
    ),

    // 2. Core Corporate Hubs
    RiyadhZone(
      id: 'kafd',
      name: 'KAFD Phase 1 & 2',
      arabicName: 'مركز الملك عبدالله المالي (كافد)',
      category: RiyadhClusterCategory.central,
      region: HubRegion.riyadh,
      targetSector: 'Investment banks, RHQs & tier-1 consultancies',
      mapsQuery: 'King Abdullah Financial District KAFD Riyadh',
      latitude: 24.7677,
      longitude: 46.6433,
      defaultIntentBoost: 30,
    ),
    RiyadhZone(
      id: 'al_olaya',
      name: 'Al Olaya',
      arabicName: 'العليا التجارية',
      category: RiyadhClusterCategory.central,
      region: HubRegion.riyadh,
      targetSector: 'Financial towers, law firms & multinational branches',
      mapsQuery: 'Al Olaya Corporate Towers Riyadh',
      latitude: 24.7003,
      longitude: 46.6853,
      defaultIntentBoost: 20,
    ),
    RiyadhZone(
      id: 'king_fahd_rd',
      name: 'King Fahd Rd',
      arabicName: 'طريق الملك فهد',
      category: RiyadhClusterCategory.central,
      region: HubRegion.riyadh,
      targetSector: 'Major corporate skyscrapers & insurance HQs',
      mapsQuery: 'King Fahd Road Riyadh business',
      latitude: 24.6980,
      longitude: 46.6820,
      defaultIntentBoost: 20,
    ),
    RiyadhZone(
      id: 'digital_city',
      name: 'Digital City',
      arabicName: 'المدينة الرقمية',
      category: RiyadhClusterCategory.central,
      region: HubRegion.riyadh,
      targetSector: 'Fintech, cybersecurity, IT & government contractors',
      mapsQuery: 'Digital City Riyadh',
      latitude: 24.7214,
      longitude: 46.6402,
      defaultIntentBoost: 25,
    ),
    RiyadhZone(
      id: 'business_gate',
      name: 'Business Gate',
      arabicName: 'بوابة الأعمال',
      category: RiyadhClusterCategory.central,
      region: HubRegion.riyadh,
      targetSector: 'Aerospace, enterprise software & diplomatic contractors',
      mapsQuery: 'Business Gate Airport Road Riyadh',
      latitude: 24.8115,
      longitude: 46.7210,
      defaultIntentBoost: 20,
    ),
    RiyadhZone(
      id: 'al_malqa',
      name: 'Al Malqa Office Blocks',
      arabicName: 'مجمعات مكاتب الملقا',
      category: RiyadhClusterCategory.northHubs,
      region: HubRegion.riyadh,
      targetSector: 'Executive clinics, private equity & fintech startups',
      mapsQuery: 'Al Malqa Riyadh corporate office blocks',
      latitude: 24.8090,
      longitude: 46.6022,
      defaultIntentBoost: 20,
    ),

    // 3. Tech & Logistics Corridors
    RiyadhZone(
      id: 'granada_business_park',
      name: 'Granada Business Park',
      arabicName: 'مجمع غرناطة للأعمال',
      category: RiyadhClusterCategory.northHubs,
      region: HubRegion.riyadh,
      targetSector:
          'Telecom giants, tech multinationals & shared service centers',
      mapsQuery: 'Granada Business Park Riyadh',
      latitude: 24.7876,
      longitude: 46.7267,
      defaultIntentBoost: 20,
    ),
    RiyadhZone(
      id: 'al_yarmouk',
      name: 'Al Yarmouk',
      arabicName: 'اليرموك التجاري',
      category: RiyadhClusterCategory.northHubs,
      region: HubRegion.riyadh,
      targetSector: 'Commercial corporate services & supply chain offices',
      mapsQuery: 'Al Yarmouk Commercial Riyadh',
      latitude: 24.8041,
      longitude: 46.7877,
      defaultIntentBoost: 15,
    ),
    RiyadhZone(
      id: 'kkia_logistics',
      name: 'King Khalid Int\'l Airport Logistics Zone',
      arabicName: 'منطقة مطار الملك خالد اللوجستية',
      category: RiyadhClusterCategory.industrialLogistics,
      region: HubRegion.riyadh,
      targetSector:
          'Air freight, customs clearance & supply chain head offices',
      mapsQuery: 'King Khalid International Airport Logistics Zone Riyadh',
      latitude: 24.9576,
      longitude: 46.6988,
      defaultIntentBoost: 20,
    ),

    // 4. Industrial HQs
    RiyadhZone(
      id: 'al_sulay',
      name: 'Al Sulay Industrial Zone',
      arabicName: 'منطقة السلي الصناعية والتجارية',
      category: RiyadhClusterCategory.industrialLogistics,
      region: HubRegion.riyadh,
      targetSector: 'Industrial corporate administration & central depots',
      mapsQuery: 'Al Sulay Industrial Zone Riyadh',
      latitude: 24.6475,
      longitude: 46.8200,
      defaultIntentBoost: 15,
    ),
    RiyadhZone(
      id: 'riyadh_second_industrial',
      name: 'Riyadh Second Industrial City',
      arabicName: 'المدينة الصناعية الثانية (المكاتب والمستودعات)',
      category: RiyadhClusterCategory.industrialLogistics,
      region: HubRegion.riyadh,
      targetSector: 'Manufacturing HQs, pharma plants & engineering offices',
      mapsQuery: 'Second Industrial City Riyadh',
      latitude: 24.5670,
      longitude: 46.8850,
      defaultIntentBoost: 15,
    ),

    // ----------------------------------------------------
    // SECONDARY BUCKET: Western & Eastern Hubs
    // ----------------------------------------------------
    RiyadhZone(
      id: 'jeddah_waterfront',
      name: 'Jeddah Waterfront/Andalus',
      arabicName: 'واجهة جدة البحرية / الأندلس',
      category: RiyadhClusterCategory.westernEastern,
      region: HubRegion.western,
      targetSector:
          'Maritime trade, luxury corporate hospitality & regional RHQ branches',
      mapsQuery: 'Jeddah Corniche Andalus Commercial Jeddah',
      latitude: 21.5433,
      longitude: 39.1728,
      defaultIntentBoost: 15,
    ),
    RiyadhZone(
      id: 'khobar_corniche',
      name: 'Khobar Corniche/Logistics',
      arabicName: 'كورنيش الخبر اللوجستي',
      category: RiyadhClusterCategory.westernEastern,
      region: HubRegion.eastern,
      targetSector:
          'Oil & gas services, maritime logistics & regional engineering HQs',
      mapsQuery: 'Khobar Corniche Commercial Khobar',
      latitude: 26.2886,
      longitude: 50.2106,
      defaultIntentBoost: 15,
    ),
    RiyadhZone(
      id: 'dammam_industrial',
      name: 'Dammam Industrial',
      arabicName: 'صناعية الدمام المركزية',
      category: RiyadhClusterCategory.westernEastern,
      region: HubRegion.eastern,
      targetSector:
          'Industrial supply chain, engineering fabrication & central depots',
      mapsQuery: 'Dammam Second Industrial City Dammam',
      latitude: 26.3927,
      longitude: 49.9777,
      defaultIntentBoost: 15,
    ),
  ];

  static List<String> get allClusterNames =>
      allZones.map((z) => z.name).toList();

  static List<RiyadhZone> get primaryRiyadhZones =>
      allZones.where((z) => z.region == HubRegion.riyadh).toList();

  static List<RiyadhZone> get secondaryKsaZones => allZones
      .where((z) =>
          z.region == HubRegion.western || z.region == HubRegion.eastern)
      .toList();

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
      // Western & Eastern Hub Matches
      if (clean.contains('jeddah') && zone.id == 'jeddah_waterfront') return zone;
      if (clean.contains('andalus') && zone.id == 'jeddah_waterfront') return zone;
      if (clean.contains('khobar') && zone.id == 'khobar_corniche') return zone;
      if (clean.contains('dammam') && zone.id == 'dammam_industrial') return zone;
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

  static bool isPrimaryRiyadhHub(String hub) {
    final zone = findZone(hub);
    if (zone == null) return true; // Default priority to Riyadh
    return zone.region == HubRegion.riyadh;
  }

  static bool isSecondaryHub(String hub) {
    final zone = findZone(hub);
    if (zone == null) return false;
    return zone.region == HubRegion.western ||
        zone.region == HubRegion.eastern;
  }
}
