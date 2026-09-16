import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../models/lead.dart';
import '../models/zones.dart';

class GeoCoordinates {
  final double latitude;
  final double longitude;

  const GeoCoordinates(this.latitude, this.longitude);

  @override
  String toString() => '($latitude, $longitude)';
}

class GeoService {
  static final GeoService instance = GeoService._internal();
  GeoService._internal();

  // Fallback anchor: KAFD Phase 1 & 2 (Central Riyadh Corporate Epicenter)
  static const double fallbackLat = RiyadhZones.defaultLat;
  static const double fallbackLng = RiyadhZones.defaultLng;

  GeoCoordinates _lastKnownCoordinates =
      const GeoCoordinates(fallbackLat, fallbackLng);
  bool _isGpsActive = false;
  String _gpsStatusLabel = 'Acquiring GPS...';

  GeoCoordinates get currentCoordinates => _lastKnownCoordinates;
  bool get isGpsActive => _isGpsActive;
  String get gpsStatusLabel => _gpsStatusLabel;

  /// Haversine distance formula calculating straight-line distance in kilometers
  static double haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final double a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(math.max(0.0, a))); // 2 * R; R = 6371 km
  }

  /// Request GPS position with permission checks and graceful fallback
  Future<GeoCoordinates> acquireLiveGps({bool forceRefresh = false}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _isGpsActive = false;
        _gpsStatusLabel = 'Location Service Disabled (Using Riyadh Anchor)';
        return _lastKnownCoordinates;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _isGpsActive = false;
          _gpsStatusLabel = 'Permission Denied (Using Riyadh Anchor)';
          return _lastKnownCoordinates;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _isGpsActive = false;
        _gpsStatusLabel = 'Location Denied Forever (Using Riyadh Anchor)';
        return _lastKnownCoordinates;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 7),
      );

      _lastKnownCoordinates =
          GeoCoordinates(position.latitude, position.longitude);
      _isGpsActive = true;
      _gpsStatusLabel = '📍 GPS Active: KSA Proximity';
      return _lastKnownCoordinates;
    } catch (_) {
      // Graceful fallback for offline, desktop, or simulator environments
      _isGpsActive = false;
      _gpsStatusLabel = '📍 Riyadh Anchor Active (KAFD)';
      return _lastKnownCoordinates;
    }
  }

  /// Resolve coordinates for any lead (using lead's hub or defaults)
  static GeoCoordinates getCoordinatesForLead(Lead lead) {
    final zone = RiyadhZones.findZone(lead.hub);
    if (zone != null) {
      return GeoCoordinates(zone.latitude, zone.longitude);
    }
    return const GeoCoordinates(fallbackLat, fallbackLng);
  }

  /// Calculate distance from user position to lead
  double getDistanceToLead(Lead lead, [GeoCoordinates? userCoords]) {
    final user = userCoords ?? _lastKnownCoordinates;
    final leadCoords = getCoordinatesForLead(lead);
    return haversineDistance(
      user.latitude,
      user.longitude,
      leadCoords.latitude,
      leadCoords.longitude,
    );
  }

  /// Format distance badge string: e.g., '📍 1.2 km away • KAFD' or '📍 4.5 km • Al Narjis'
  String formatDistanceBadge(Lead lead, [GeoCoordinates? userCoords]) {
    final dist = getDistanceToLead(lead, userCoords);
    final shortHub = _simplifyHubName(lead.hub);

    if (dist < 1.0) {
      final meters = (dist * 1000).round();
      return '📍 ${meters}m away • $shortHub';
    } else {
      return '📍 ${dist.toStringAsFixed(1)} km away • $shortHub';
    }
  }

  static String _simplifyHubName(String hub) {
    final zone = RiyadhZones.findZone(hub);
    if (zone != null) {
      // Pick clean name
      if (zone.id == 'kafd') return 'KAFD';
      if (zone.id == 'al_narjis') return 'Al Narjis';
      if (zone.id == 'roshn_front') return 'Roshn Front';
      if (zone.id == 'king_salman_strip') return 'King Salman Rd';
      if (zone.id == 'al_malqa') return 'Al Malqa';
      if (zone.id == 'al_olaya') return 'Olaya';
      if (zone.id == 'digital_city') return 'Digital City';
      if (zone.id == 'business_gate') return 'Business Gate';
      if (zone.id == 'jeddah_waterfront') return 'Jeddah Waterfront';
      if (zone.id == 'khobar_corniche') return 'Khobar Corniche';
      if (zone.id == 'dammam_industrial') return 'Dammam Industrial';
      return zone.name;
    }
    return hub;
  }

  /// Sorting Hierarchy:
  /// Primary Bucket: Greater Riyadh Hubs (KAFD, Al Narjis, Roshn Front, King Salman Road, Al Malqa, Olaya)
  /// Secondary Bucket: Western & Eastern Hubs (Jeddah Waterfront/Andalus, Khobar Corniche/Logistics, Dammam Industrial)
  /// In-Bucket Dynamic Sorting: Sort strictly by shortest distance ("Near Me First")
  List<Lead> sortLeadsByRiyadhProximity(
    List<Lead> leads, [
    GeoCoordinates? userCoords,
  ]) {
    final user = userCoords ?? _lastKnownCoordinates;
    final List<Lead> copy = List<Lead>.from(leads);

    copy.sort((a, b) {
      final zoneA = RiyadhZones.findZone(a.hub);
      final zoneB = RiyadhZones.findZone(b.hub);

      final isRiyadhA = zoneA?.isRiyadhPrimary ?? true;
      final isRiyadhB = zoneB?.isRiyadhPrimary ?? true;

      // Primary Bucket (Greater Riyadh) strictly precedes Secondary Bucket
      if (isRiyadhA && !isRiyadhB) return -1;
      if (!isRiyadhA && isRiyadhB) return 1;

      // Secondary Bucket (Western & Eastern) precedes any undefined/other
      final isSecondaryA = zoneA?.isSecondaryHub ?? false;
      final isSecondaryB = zoneB?.isSecondaryHub ?? false;
      if (isSecondaryA && !isSecondaryB) return -1;
      if (!isSecondaryA && isSecondaryB) return 1;

      // In-Bucket Dynamic Sorting: Shortest straight-line distance first
      final distA = getDistanceToLead(a, user);
      final distB = getDistanceToLead(b, user);
      return distA.compareTo(distB);
    });

    return copy;
  }
}
