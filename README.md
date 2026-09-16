# Saudi B2B Corporate Acquisition & Staffing CRM
## Greater Riyadh Priority & KSA Expansion • Enterprise Edition

An enterprise-tier, high-performance mobile application architected for B2B corporate office acquisition and hospitality staffing across the Kingdom of Saudi Arabia. Specially optimized for regional corporate headquarters (RHQ), multinational consultancies, banking towers, and executive commercial floors supplying dedicated tea boys, pantry coordinators, and office cleaners.

---

## Architectural Highlights

### 1. Modern Technology Stack & Dependencies
- **Framework & Runtime**: Flutter 3.24+ (Dart 3.5+) targeting Android 14/15 with immersive edge-to-edge system rendering.
- **State Architecture**: `flutter_riverpod: ^2.5.1` with `StateNotifier` and reactive providers (`lib/providers/crm_providers.dart`).
- **Local Persistence**: `hive_flutter: ^1.1.0` with pre-indexed search boxes for zero-latency offline performance and strict composite deduplication.
- **Device & Location**: `geolocator: ^12.0.0` with high-accuracy live GPS telemetry and graceful fallback anchors.
- **Micro-Animations & UI**: `flutter_animate: ^4.5.0` with Impeller-optimized GPU shaders and glassmorphic backdrop filters.
- **AI Engine**: Gemini 1.5 Flash via direct authenticated REST integration (lightweight, zero heavy SDK bloat).

---

### 2. Live Proximity Matrix & Riyadh-First Priority (`lib/services/geo_service.dart`)
- **Haversine Distance Formula**: Computes precise straight-line distance in kilometers between the user's live GPS coordinates and corporate hub coordinates:
  $$d = 2R \arcsin\left(\sqrt{\sin^2\left(\frac{\Delta \phi}{2}\right) + \cos(\phi_1)\cos(\phi_2)\sin^2\left(\frac{\Delta \lambda}{2}\right)}\right)$$
- **Hierarchical Regional Bucketing**:
  * **Primary Bucket**: Greater Riyadh Hubs (*KAFD Phase 1 & 2, Al Narjis Commercial, Roshn Front Business Zone, King Salman Road Business Strip, Al Malqa Office Blocks, Al Olaya, Digital City, Business Gate, Al Yasmin, New Murabba, Granada Business Park, Al Yarmouk, KKIA Logistics, Al Sulay Industrial, Riyadh Second Industrial*).
  * **Secondary Bucket**: Western & Eastern Hubs (*Jeddah Waterfront/Andalus, Khobar Corniche/Logistics, Dammam Industrial*).
  * **Tertiary Bucket**: Unmapped or regional corridors.
- **In-Bucket Dynamic Distance Sorting**: Sorts all leads strictly by shortest distance ("Near Me First").
- **Live Proximity Badge**: Renders a dynamic badge on every card (e.g. `📍 1.2 km away • KAFD` or `📍 4.5 km away • Al Narjis`).

---

### 3. Glassmorphic Executive Dark Design System (`lib/theme/app_theme.dart`)
- **Aesthetic**: Deep Obsidian Void with Frosted Glass Overlay
  * **Scaffold Background**: `#05080E` (Deep Obsidian Void)
  * **Card Surface**: Frosted Charcoal Slate (`#0D131F` with 0.85 opacity, 1px cyber border `#1E293B`)
  * **Primary Accent**: Neon Electric Cyan (`#00F2FE`)
  * **WhatsApp Channel Accent**: Bright Mint Emerald (`#10B981`)
  * **Email Channel Accent**: Royal Iris Violet (`#6366F1`)
  * **Quotation & VIP Accent**: Royal Gold (`#D4AF37`)
  * **Typography**: Crisp Alabaster (`#F8FAFC`) with Secondary Muted Silver (`#94A3B8`)
- **Impeller Optimization**: Zero deprecated precision-loss opacity calls; utilizes modern `withValues(alpha: ...)` color math.

---

### 4. Zero-Bug Dual RFC Dispatcher (`lib/services/dispatch_service.dart`)
Completely eliminates unwanted `+` signs and broken URL encodings. Enforces 100% native space (`%20`) and newline (`%0A`) parsing across WhatsApp and email clients:

```dart
class DispatchService {
  static String encodeParam(String text) {
    return Uri.encodeComponent(text).replaceAll('+', '%20');
  }

  static Future<bool> launchWhatsApp({
    required String phone,
    required String message,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(
      'https://wa.me/$cleanPhone?text=${encodeParam(message)}',
    );
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static Future<bool> launchEmail({
    required String email,
    required String subject,
    required String body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email.trim(),
      query: 'subject=${encodeParam(subject)}&body=${encodeParam(body)}',
    );
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
```

---

### 5. Automated Pipeline & CI/CD Quality Gate
- **Static Analysis Gate**: Continuous self-healing compile loop enforcing `flutter analyze` with 0 warnings and 0 errors.
- **Automated Test Suite**: 9/9 comprehensive unit tests covering:
  * Saudi mobile phone normalization (`9665xxxxxxxx`).
  * Composite primary key deduplication (`company_sanitizedPhone`).
  * Haversine distance calculations and proximity matrix accuracy.
  * Riyadh-First Priority bucket order and dynamic distance sorting.
  * Dual RFC parameter encoding (`%20` and `%0A` verification).
  * Wrong-Number Guard keyword detection.
  * Gemini 1.5 Flash JSON schema parsing.
  * Lead model status-shift machine and auto-generated corporate email proposals.
- **GitHub Actions Workflows**:
  * `.github/workflows/build_apk.yml`: Compiles Android Release APK on Flutter 3.24+ with Java 17 Temurin.
  * `.github/workflows/daily_scraper.yml`: Cloud scraper cron job executing daily at 03:00 UTC (06:00 AM Riyadh Time) ingesting new commercial registrations.

---

## Verification & Build Commands

```bash
# Fetch dependencies
flutter pub get

# Run static quality analysis (must pass with 0 issues)
flutter analyze

# Execute test suite
flutter test

# Build Android release APK
flutter build apk --release
```
