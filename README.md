# TEA BOY B2B CRM — Greater Riyadh Corporate Staffing

An enterprise-grade, private Android B2B Staffing CRM Application built in Flutter targeting corporate offices, regional headquarters (RHQ), consultancies, and co-working floors across Greater Riyadh for supplying dedicated cleaners, pantry staff, and tea boys.

---

## Technical Blueprint & Unified Architecture

### 1. High-Growth Riyadh Hotspots & 5X Expanded Radius (`lib/models/zones.dart`)
- **Hotspot Boom Strip**: Al Narjis Commercial, Al Yasmin, Al Khuzama, New Murabba corridor, King Salman Road Business Strip, Roshn Front Business Zone.
- **Core Corporate Hubs**: KAFD Phase 1 & 2, Al Olaya, King Fahd Rd, Digital City, Business Gate, Al Malqa Office Blocks.
- **Tech & Logistics Corridors**: Granada Business Park, Al Yarmouk, King Khalid Int'l Airport Logistics Zone.
- **Industrial HQs**: Al Sulay Industrial Zone, Riyadh Second Industrial City (Head Offices & Warehouses).
- **Target Sectors**: Newly fitted-out physical corporate offices, regional headquarters (RHQ), consultancies, and co-working floors needing on-site tea boys and cleaners.

### 2. Daily Automated Cloud Scraper Pipeline (`.github/workflows/daily_scraper.yml` & `scripts/scraper.py`)
- **Execution**: Daily automated cron job running at 03:00 UTC (06:00 AM Riyadh Time) with `workflow_dispatch` manual trigger.
- **Ingestion Conditions**:
  - Scrapes fresh commercial registrations and newly claimed listings from the last 24-72 hours.
  - Strict Deduplication: Uses composite primary key `(companyName_sanitizedPhone)`.
  - Cross-references against `blacklist_contacts` Hive box; skips blacklisted or already-contacted entities.
  - Appends structured fields: `id`, `company_name`, `contact_person`, `phone`, `zone_cluster`, `intent_score`, `date_added (YYYY-MM-DD)`, `status ('new')`.

### 3. Instant Status-Shift State Machine (`lib/services/storage_service.dart` & `lib/widgets/lead_card.dart`)
- **Status Lifecycle Levels**: `'new'` | `'contacted'` | `'analyzed'` | `'interested'` | `'closed'` | `'disqualified'`.
- **1-Tap WhatsApp Trigger**: Clicking the WhatsApp button:
  - Launches native WhatsApp intent with pre-drafted pitch.
  - Instantly demotes lead status from `'new'` to `'contacted'` without requiring manual confirmation.
  - Records `'contacted_at'` timestamp (`DateTime.now()`) and saves to Hive DB.
  - Triggers light haptic feedback and displays a brief confirmation SnackBar.
  - Removes the card immediately from the active `'New'` list view in real time via reactive `revision` notifier.

### 4. Wrong-Number Guard & Local Blacklist Engine (`lib/services/gemini_service.dart` & `storage_service.dart`)
- **Persistent Hive Box**: `'blacklist_contacts'`.
- **Trigger Detection**: Detects wrong number or misidentified recipient replies ("wrong number", "not [Name]", "غلطان", "الرقم خطأ", "لست الأستاذ", "لست المسؤول", "مو أنا", etc.).
- **Blacklist Protocol**:
  - Automatically marks lead status as `'disqualified'`.
  - Permanently stores the phone number in `'blacklist_contacts'` so it is never scraped or contacted again.
  - Generates zero-pitch polite apology exit message:
    `اعتذر منك بشدة على الإزعاج، سيتم تعديل الرقم وحذفه فوراً من سجلاتنا. أتمنى لك يوماً سعيداً.`
  - 1-tap "Send Apology & Archive" button with no further follow-up allowed.

### 5. AI Forecasting Engine (Gemini 1.5 Flash - `lib/services/gemini_service.dart`)
- **Auto-Trigger on Paste**: Automatically analyzes pasted client replies without requiring a manual "Submit" button.
- **Markdown Sanitization**: Strips backticks before JSON parsing.
- **Strict Schema Mode**:
  ```json
  {
    "sentiment": "Interested | Objection: Price | Objection: Vendor | Wrong Contact | Postponed",
    "is_wrong_contact": false,
    "pain_points": "string detailing client pain points",
    "recommended_action": "string with specific next step in Riyadh",
    "follow_up_message": "string (culturally refined Arabic WhatsApp pitch)",
    "next_follow_up_date": "YYYY-MM-DD",
    "deal_score": 85
  }
  ```
- **Field Locking**: Automatically locks input field after analysis; displays copyable follow-up script with a small edit icon to unlock if user explicitly needs to update.

### 6. Mobile UI Architecture (`lib/screens/dashboard_screen.dart`)
- **Sticky Top Bar**: `🟢 Today's Fresh Offices: X | Top Cluster: Al Narjis / Roshn`.
- **Segmented Tabs**:
  - `🟢 New (Unreached)`
  - `🟡 Contacted / Pending`
  - `🔴 Disqualified / Archive`
- **Area Quick-Filter Chips**: `[All, Hotspots (Narjis/Roshn), Central (KAFD/Olaya), North Hubs, Industrial/Logistics]`.
- **Android 14/15 Gesture Support**: `PopScope`, `SafeArea`, `SingleChildScrollView`, and `resizeToAvoidBottomInset: true`.

### 7. Zero-Fail Android Gradle & CI/CD Pipeline
- **`android/app/build.gradle`**:
  - Explicit namespace `com.teaboy.crm` compatible with Gradle 8+.
  - Release signed with debug keystore for seamless installation across Android 11 to 15 without parsing errors.
- **`android/app/src/main/AndroidManifest.xml`**:
  - Permissions: `INTERNET`, `ACCESS_NETWORK_STATE`.
  - Intent queries for `com.whatsapp`, `com.whatsapp.w4b`, and `https`.
- **GitHub Actions Workflow** (`.github/workflows/build_apk.yml`):
  - Runner: `ubuntu-latest` | Java 17 (Temurin) | Flutter 3.22.x with cache.
  - Automated unit test suite validation.
  - Release APK upload artifact with 7-day retention.
- **ZERO Manual GitHub Secrets Configuration**: 100% self-contained.

---

## Directory Structure

```
.
├── .github/
│   └── workflows/
│       ├── build_apk.yml                     # Zero-secret release APK CI/CD pipeline
│       └── daily_scraper.yml                 # Daily 03:00 UTC cloud scraper pipeline
├── android/
│   ├── app/
│   │   ├── build.gradle                      # Gradle 8.5 config, namespace, debug signing
│   │   └── src/main/
│   │       ├── AndroidManifest.xml           # Permissions, <queries>, adjustResize
│   │       ├── kotlin/com/teaboy/crm/
│   │       │   └── MainActivity.kt           # FlutterActivity
│   │       └── res/                          # Launch backgrounds & icons
│   └── ...
├── data/
│   └── scraped_leads.json                    # Daily ingested corporate office listings
├── lib/
│   ├── main.dart                             # App entry point & Hive storage bootstrap
│   ├── models/
│   │   ├── zones.dart                        # 5X expanded Riyadh clusters & categories
│   │   ├── lead.dart                         # Lead model, composite primary key, timestamps
│   │   └── ai_analysis.dart                  # Gemini 1.5 Flash structured forecast model
│   ├── services/
│   │   ├── storage_service.dart              # Offline Hive DB singleton, status state machine, blacklist
│   │   ├── hive_service.dart                 # Backward-compatible proxy to StorageService
│   │   ├── gemini_service.dart               # Gemini 1.5 Flash client & wrong-number detection
│   │   ├── scraper_service.dart              # In-app Greater Riyadh market scraper engine
│   │   └── whatsapp_service.dart             # Multilingual WhatsApp dispatcher & BiDi isolation
│   ├── theme/
│   │   └── app_theme.dart                    # Saudi Emerald, Royal Gold & Slate Navy theme
│   ├── widgets/
│   │   ├── lead_card.dart                    # 1-tap WhatsApp trigger & instant status shift
│   │   ├── pipeline_kpi_header.dart          # Executive KPI summary cards
│   │   ├── hub_filter_bar.dart               # Horizontal Riyadh cluster filter bar
│   │   ├── status_badge.dart                 # Lifecycle status pill badge
│   │   ├── ai_score_badge.dart               # Deal probability score indicator
│   │   └── quotation_calculator_dialog.dart  # Instant SAR formal price quotation with 15% VAT
│   └── screens/
│       ├── dashboard_screen.dart             # Sticky top bar, 3 segmented tabs, area quick-filters
│       ├── lead_detail_screen.dart           # AI forecasting, wrong-number guard, pitch selector
│       ├── add_lead_screen.dart              # Lead registration, smart auto-fill & blacklist check
│       └── settings_screen.dart              # API key config, blacklist manager & DB seeding
├── scripts/
│   └── scraper.py                            # Cloud scraper pipeline script for Greater Riyadh
├── test/
│   └── crm_test.dart                         # Core unit tests for models, zones, deduplication
├── pubspec.yaml                              # Flutter dependencies & metadata
└── README.md
```
