import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lead.dart';
import '../models/zones.dart';
import '../services/geo_service.dart';
import '../services/storage_service.dart';

/// GPS State Representation
class GeoState {
  final GeoCoordinates coordinates;
  final bool isGpsActive;
  final String statusLabel;
  final bool isLoading;

  const GeoState({
    required this.coordinates,
    required this.isGpsActive,
    required this.statusLabel,
    this.isLoading = false,
  });

  GeoState copyWith({
    GeoCoordinates? coordinates,
    bool? isGpsActive,
    String? statusLabel,
    bool? isLoading,
  }) {
    return GeoState(
      coordinates: coordinates ?? this.coordinates,
      isGpsActive: isGpsActive ?? this.isGpsActive,
      statusLabel: statusLabel ?? this.statusLabel,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// GPS State Notifier managing live geolocator location
class GeoNotifier extends StateNotifier<GeoState> {
  GeoNotifier()
      : super(GeoState(
          coordinates: GeoService.instance.currentCoordinates,
          isGpsActive: GeoService.instance.isGpsActive,
          statusLabel: GeoService.instance.gpsStatusLabel,
        )) {
    refreshGps();
  }

  Future<void> refreshGps() async {
    state = state.copyWith(isLoading: true);
    final coords = await GeoService.instance.acquireLiveGps(forceRefresh: true);
    state = GeoState(
      coordinates: coords,
      isGpsActive: GeoService.instance.isGpsActive,
      statusLabel: GeoService.instance.gpsStatusLabel,
      isLoading: false,
    );
  }
}

final geoProvider = StateNotifierProvider<GeoNotifier, GeoState>((ref) {
  return GeoNotifier();
});

/// Leads State Notifier bound reactively to Hive StorageService
class LeadsNotifier extends StateNotifier<List<Lead>> {
  LeadsNotifier() : super([]) {
    _loadFromStorage();
    // Reactively refresh when Hive revision updates
    StorageService.instance.revision.addListener(_onRevisionChanged);
  }

  void _onRevisionChanged() {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    state = StorageService.instance.getAllLeads();
  }

  Future<bool> addLead(Lead lead) async {
    final success = await StorageService.instance.addLead(lead);
    if (success) _loadFromStorage();
    return success;
  }

  Future<void> updateLead(Lead lead) async {
    await StorageService.instance.updateLead(lead);
    _loadFromStorage();
  }

  Future<void> updateLeadStatus(String leadId, String newStatus) async {
    await StorageService.instance.updateLeadStatus(leadId, newStatus);
    _loadFromStorage();
  }

  Future<void> deleteLead(String leadId) async {
    await StorageService.instance.deleteLead(leadId);
    _loadFromStorage();
  }

  Future<void> markContacted(String leadId) async {
    await StorageService.instance.markLeadContacted(leadId);
    _loadFromStorage();
  }

  void refresh() {
    _loadFromStorage();
  }

  @override
  void dispose() {
    StorageService.instance.revision.removeListener(_onRevisionChanged);
    super.dispose();
  }
}

final leadsProvider = StateNotifierProvider<LeadsNotifier, List<Lead>>((ref) {
  return LeadsNotifier();
});

/// Search Query State
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Selected Riyadh/KSA Cluster Category Filter
final selectedCategoryProvider =
    StateProvider<RiyadhClusterCategory>((ref) => RiyadhClusterCategory.all);

/// Live Proximity Sorting Flag ("Near Me First")
final isNearMeSortProvider = StateProvider<bool>((ref) => true);

/// Proximity-Sorted & Filtered Leads Provider
final proximitySortedLeadsProvider = Provider<List<Lead>>((ref) {
  final allLeads = ref.watch(leadsProvider);
  final geoState = ref.watch(geoProvider);
  final searchQuery = ref.watch(searchQueryProvider).trim().toLowerCase();
  final category = ref.watch(selectedCategoryProvider);
  final isNearMe = ref.watch(isNearMeSortProvider);

  // 1. Filter by category
  List<Lead> filtered = allLeads.where((lead) {
    return RiyadhZones.matchesCategory(lead.hub, category);
  }).toList();

  // 2. Filter by search query
  if (searchQuery.isNotEmpty) {
    filtered = filtered.where((lead) {
      final matchesCompany =
          lead.companyName.toLowerCase().contains(searchQuery);
      final matchesContact =
          lead.contactPerson.toLowerCase().contains(searchQuery);
      final matchesPhone = lead.saudiMobile.contains(searchQuery);
      final matchesHub = lead.hub.toLowerCase().contains(searchQuery);
      final matchesStaff = lead.staffingRequirements
          .any((req) => req.toLowerCase().contains(searchQuery));
      return matchesCompany ||
          matchesContact ||
          matchesPhone ||
          matchesHub ||
          matchesStaff;
    }).toList();
  }

  // 3. Proximity Sorting with Riyadh-First Priority
  if (isNearMe) {
    return GeoService.instance.sortLeadsByRiyadhProximity(
      filtered,
      geoState.coordinates,
    );
  } else {
    // Fallback sort: newest date first
    filtered.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return filtered;
  }
});
