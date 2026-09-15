# TEA BOY B2B CRM — Riyadh Corporate Staffing

An enterprise-grade Android B2B Staffing CRM Application built in Flutter, specifically tailored for corporate offices and commercial towers across **Riyadh, Saudi Arabia** (**KAFD**, **Al Olaya**, **King Fahd Rd**, **Al Malqa**, **Digital City**, and **Business Gate**). 

The CRM manages the B2B pipeline for supplying specialized workplace staff:
- **Tea Boys** (VIP Hospitality & Arabic/English etiquette)
- **Pantry Staff** (Corporate kitchen management & supply replenishment)
- **Professional Office Cleaners** (Medical and enterprise-grade hygiene)

---

## Key Engineered Systems

### 1. Android OS & Gradle Hardening (Zero-Fail Build)
- **Target OS Compatibility**: Engineered and tested for Android 11 through Android 15.
- **Gradle 8.5+ Architecture**: Hardened namespace `com.teaboy.crm`, Java 17 compatibility.
- **Zero-Secret Release Signing**: `buildTypes { release { signingConfig signingConfigs.debug; minifyEnabled false; shrinkResources false } }` generates a cryptographically signed, installable APK out of the box in CI/CD without requiring manual GitHub Secrets.
- **Intent & Permission Hardening**: AndroidManifest includes `<uses-permission android:name="android.permission.INTERNET"/>`, `ACCESS_NETWORK_STATE`, and comprehensive `<queries>` for `com.whatsapp`, `com.whatsapp.w4b` (WhatsApp Business), and `https` URI schemes.
- **Window Resize Inset**: `windowSoftInputMode="adjustResize"` combined with Flutter `SafeArea` and `SingleChildScrollView` prevents soft keyboard clipping on any device screen ratio.

### 2. Enterprise Offline Storage & Deduplication (Hive Singleton)
- **Deduplication Constraint**: Primary key is a composite hash `companyName_sanitizedPhone` (normalized lowercase & whitespace-trimmed). Re-scraping the Riyadh market or importing bulk leads will check this key and **never duplicate or overwrite** existing client relationships.
- **Timestamp Tracking Constraint**: Every lead records `date_added` formatted as `YYYY-MM-DD`, enabling chronological pipeline sorting (newest/oldest) and date-filtered discovery.
- **Offline Reliability**: 100% functional without an active internet connection.

### 3. Resilient Multilingual WhatsApp Dispatcher
- **Saudi Mobile Sanitation**: Regex cleanser strictly normalizes phone inputs (`05xxxxxxxx`, `+9665xxxxxxxx`, spaced numbers) into standard `9665xxxxxxxx` format.
- **Multi-Scheme Invocation**: Tries primary native scheme `whatsapp://send?phone=...&text=...` with automatic fallback to `https://wa.me/9665xxxxxxxx?text=...`.
- **Unicode BiDi Isolation**: Embeds mixed Arabic/English text using directional tokens (`\u202A`, `\u202B`, `\u202C`, `\u200E`, `\u200F`), preventing visual scrambling of Arabic corporate greetings containing English acronyms (e.g. *KAFD*, *Tea Boy*, *VIP*).
- **1-Tap Dispatch**: Copies message to system clipboard, fires haptic feedback (`HapticFeedback.lightImpact()`), launches WhatsApp, and displays an animated confirmation SnackBar.

### 4. Resilient AI Deal Forecasting Engine (Gemini 1.5 Flash)
- **JSON Schema Mode**: Direct REST integration to `generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent` with `response_mime_type: "application/json"`.
- **Fault-Tolerant Retries**: 2-stage retry mechanism with exponential backoff on intermittent timeouts (15-second ceiling).
- **Markdown Sanitation**: Strips accidental code fences (````json ... ````) prior to JSON decoding.
- **Structured Deal Output**: Produces `sentiment`, `pain_points`, `recommended_action`, `follow_up_message` (custom bilingual pitch), `next_follow_up_date`, and `deal_score` (0-100%).
- **Heuristic Fallback**: If an API key is missing or offline, a local scoring engine executes deterministically, guaranteeing zero application crashes.

### 5. Mobile-First Riyadh Hub CRM Dashboard
- **Design Aesthetic**: Riyadh Corporate Enterprise palette — Saudi Emerald (`#006C4F`), Royal Desert Gold (`#D4AF37`), Slate Navy (`#0F172A`), and Pristine Off-White cards.
- **Horizontal Hub Filter Bar**: Quick filter leads by Riyadh corporate clusters: `All`, `KAFD`, `Al Olaya`, `King Fahd Rd`, `Al Malqa`, `Digital City`, `Business Gate`.
- **Status Badges**: Color-coded lifecycle badges (`New`, `Contacted`, `Interested`, `Closed`, `Disqualified`).

### 6. Zero-Fail GitHub Actions CI/CD Pipeline
- Workflow located at `.github/workflows/build_apk.yml`.
- Runner: `ubuntu-latest`.
- Configured with Java 17 (Temurin), Flutter 3.22.x with caching, automated `chmod +x android/gradlew`, and release APK artifact publishing (7-day retention).
- **Zero GitHub Secrets needed**.

---

## Directory Structure

```
.
├── .github/
│   └── workflows/
│       └── build_apk.yml                     # Zero-secret GitHub Actions CI/CD pipeline
├── android/
│   ├── app/
│   │   ├── build.gradle                      # Gradle 8.5 config, namespace, debug signing
│   │   └── src/main/
│   │       ├── AndroidManifest.xml           # Permissions, <queries>, adjustResize
│   │       ├── kotlin/com/teaboy/crm/
│   │       │   └── MainActivity.kt           # FlutterActivity
│   │       └── res/                          # Launch backgrounds & styles
│   ├── gradle/wrapper/
│   │   ├── gradle-wrapper.properties         # Gradle 8.5 distribution URL
│   │   └── gradle-wrapper.jar                # Binary Gradle wrapper JAR
│   ├── build.gradle                          # Root Gradle build script
│   ├── settings.gradle                       # Plugin management & loaders
│   ├── gradle.properties                     # JVM arguments & AndroidX flags
│   ├── gradlew                               # Unix wrapper script
│   └── gradlew.bat                           # Windows wrapper script
├── lib/
│   ├── main.dart                             # App entry point & Hive initialization
│   ├── models/
│   │   ├── lead.dart                         # Lead model, composite primary key, date_added
│   │   └── ai_analysis.dart                  # Deal forecast & sentiment data structure
│   ├── services/
│   │   ├── hive_service.dart                 # Hive DB singleton & deduplication engine
│   │   ├── whatsapp_service.dart             # Multilingual WhatsApp dispatcher & BiDi engine
│   │   ├── gemini_service.dart               # Gemini 1.5 Flash REST client with backoff
│   │   └── scraper_service.dart              # Riyadh office lead scraper / generator
│   ├── theme/
│   │   └── app_theme.dart                    # Saudi corporate color system & typography
│   ├── widgets/
│   │   ├── hub_filter_bar.dart               # Horizontal Riyadh hub selector
│   │   ├── lead_card.dart                    # Interactive lead card with 1-tap dispatch
│   │   ├── status_badge.dart                 # Color-coded lifecycle status badge
│   │   └── ai_score_badge.dart               # Deal score visual badge
│   └── screens/
│       ├── dashboard_screen.dart             # Main CRM dashboard, search, filters, scraper
│       ├── lead_detail_screen.dart           # Lead detail, AI forecasting, pitch dispatcher
│       ├── add_lead_screen.dart              # Lead creation & deduplication validation
│       └── settings_screen.dart              # Gemini key configuration & database reset
├── pubspec.yaml                              # Flutter dependencies & metadata
└── .gitignore                                # Git ignore rules for Flutter & Android
```

---

## How to Run & Build

### Local Execution
```bash
flutter pub get
flutter run
```

### Build Signed Release APK
```bash
flutter build apk --release
```
The installable APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.
