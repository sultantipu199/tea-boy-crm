import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../models/zones.dart';
import '../services/gemini_service.dart';
import '../services/scraper_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isTestingKey = false;
  String? _testResultStatus;
  bool _obscureKey = true;
  bool _isScraping = false;
  RiyadhClusterCategory _selectedScraperCluster = RiyadhClusterCategory.all;

  @override
  void initState() {
    super.initState();
    final savedKey = StorageService.instance.getApiKey() ?? '';
    _apiKeyController.text = savedKey;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    await StorageService.instance.saveApiKey(key);
    GeminiService.customApiKey = key.isEmpty ? null : key;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(key.isEmpty
              ? 'API Key cleared. Reverting to local heuristic forecasting.'
              : 'Gemini API Key saved securely to on-device storage.'),
          backgroundColor: AppTheme.mintEmerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _testApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _testResultStatus = 'Please enter an API key first.';
      });
      return;
    }

    setState(() {
      _isTestingKey = true;
      _testResultStatus = null;
    });

    final testLead = Lead.create(
      companyName: 'Test Corporate Suite',
      contactPerson: 'Manager',
      saudiMobile: '0501234567',
      hub: 'KAFD',
      staffingRequirements: ['Tea Boy'],
    );

    try {
      final res = await GeminiService.instance.analyzeLead(
        lead: testLead,
        apiKeyOverride: key,
      );

      setState(() {
        _testResultStatus =
            'Success! Gemini 1.5 Flash responded (Score: ${res.dealScore}%, Sentiment: ${res.sentiment})';
      });
    } catch (e) {
      setState(() {
        _testResultStatus = 'Connection failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isTestingKey = false);
      }
    }
  }

  Future<void> _resetToSeedData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.obsidianVoid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.cyberBorder),
        ),
        title: Row(
          children: const [
            Icon(Icons.replay_rounded, color: AppTheme.royalGold, size: 22),
            SizedBox(width: 8),
            Text(
              'Seed Sample Riyadh Leads',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.crispAlabaster,
              ),
            ),
          ],
        ),
        content: const Text(
          'This will populate the database with realistic Riyadh corporate office tower leads. Any existing records matching the composite keys will be preserved and not duplicated.',
          style: TextStyle(fontSize: 13, color: AppTheme.mutedSilver, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.mutedSilver)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.royalGold,
              foregroundColor: AppTheme.obsidianVoid,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Seed Leads', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.instance.seedInitialCorporateLeads();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample leads seeded successfully!'),
            backgroundColor: AppTheme.mintEmerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {});
      }
    }
  }

  Future<void> _clearAllLeads() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.obsidianVoid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.cyberBorder),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.crimsonAccent, size: 24),
            SizedBox(width: 8),
            Text(
              'Clear All Leads?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.crispAlabaster,
              ),
            ),
          ],
        ),
        content: const Text(
          'Warning: This will delete ALL stored corporate leads from local Hive storage. This action cannot be undone.\n\nAre you sure you want to proceed?',
          style: TextStyle(fontSize: 13, color: AppTheme.mutedSilver, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.mutedSilver)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.crimsonAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final box = StorageService.instance.leadsBox;
      await box.clear();
      StorageService.instance.revision.value++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All leads cleared from local storage.'),
            backgroundColor: AppTheme.crimsonAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {});
      }
    }
  }

  Future<void> _runManualScrape() async {
    setState(() => _isScraping = true);
    final result = await ScraperService.instance.scrapeLeads(
      clusterCategory: _selectedScraperCluster,
      dynamicCount: 15,
    );
    StorageService.instance.revision.value++;
    setState(() => _isScraping = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Scraping completed: +${result.newLeadsAdded} fresh leads added (${result.skippedDuplicates} duplicates, ${result.skippedBlacklisted} blacklisted).',
          ),
          backgroundColor: AppTheme.mintEmerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allLeads = StorageService.instance.getAllLeads();
    final blacklisted = StorageService.instance.getAllBlacklisted();

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppTheme.obsidianVoid,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text(
            'CRM Settings & Database',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Lead Database & Cleaner Maintenance (Requested by User)
                    _buildFrostedSectionCard(
                      icon: Icons.storage_rounded,
                      iconColor: AppTheme.mintEmerald,
                      title: 'Lead Database & Storage',
                      badgeWidget: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.withAlphaFactor(AppTheme.mintEmerald, 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.withAlphaFactor(AppTheme.mintEmerald, 0.4),
                          ),
                        ),
                        child: Text(
                          '${allLeads.length} Leads Stored',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.mintEmerald,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'All corporate leads, statuses, and custom notes are persisted offline in encrypted local Hive storage. Zero data leaves your device unless explicitly shared.',
                            style: TextStyle(fontSize: 12, color: AppTheme.mutedSilver, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          // Clean & Deduplicate Full-Width Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.mintEmerald,
                                foregroundColor: AppTheme.obsidianVoid,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                final pruned = await StorageService.instance.deduplicateDatabase();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        pruned > 0
                                            ? '🧹 Deduplication complete! Purged $pruned duplicate records.'
                                            : '✅ Zero duplicates found! Pipeline is 100% clean.',
                                      ),
                                      backgroundColor: AppTheme.mintEmerald,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  setState(() {});
                                }
                              },
                              icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                              label: const Text(
                                '🧹 Clean & Deduplicate Database',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Seed & Clear Buttons Row
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.royalGold,
                                    side: const BorderSide(color: AppTheme.royalGold),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _resetToSeedData,
                                  icon: const Icon(Icons.replay_rounded, size: 16),
                                  label: const Text('Seed Sample Leads',
                                      style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.crimsonAccent,
                                    side: const BorderSide(color: AppTheme.crimsonAccent),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _clearAllLeads,
                                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                                  label: const Text('Clear All Leads',
                                      style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Section 2: Gemini 1.5 Flash AI Engine Configuration
                    _buildFrostedSectionCard(
                      icon: Icons.auto_awesome,
                      iconColor: AppTheme.royalGold,
                      title: 'Gemini 1.5 Flash AI Engine',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Enter your Google Gemini API key to enable live AI deal scoring, objection handling, and automated bilingual WhatsApp pitches. Stored securely on your device.',
                            style: TextStyle(fontSize: 12, color: AppTheme.mutedSilver, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _apiKeyController,
                            obscureText: _obscureKey,
                            style: const TextStyle(color: AppTheme.crispAlabaster, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Enter AIzaSy... API key',
                              prefixIcon: const Icon(Icons.key_outlined, size: 18, color: AppTheme.electricCyan),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureKey ? Icons.visibility_off : Icons.visibility,
                                  size: 18,
                                  color: AppTheme.mutedSilver,
                                ),
                                onPressed: () {
                                  setState(() => _obscureKey = !_obscureKey);
                                },
                              ),
                            ),
                          ),
                          if (_testResultStatus != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.withAlphaFactor(
                                  _testResultStatus!.startsWith('Success')
                                      ? AppTheme.mintEmerald
                                      : AppTheme.crimsonAccent,
                                  0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.withAlphaFactor(
                                    _testResultStatus!.startsWith('Success')
                                        ? AppTheme.mintEmerald
                                        : AppTheme.crimsonAccent,
                                    0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _testResultStatus!.startsWith('Success')
                                        ? Icons.check_circle_outline
                                        : Icons.error_outline,
                                    size: 16,
                                    color: _testResultStatus!.startsWith('Success')
                                        ? AppTheme.mintEmerald
                                        : AppTheme.crimsonAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _testResultStatus!,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: _testResultStatus!.startsWith('Success')
                                            ? AppTheme.mintEmerald
                                            : AppTheme.crimsonAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.electricCyan,
                                    side: const BorderSide(color: AppTheme.electricCyan),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _isTestingKey ? null : _testApiKey,
                                  icon: _isTestingKey
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.bolt, size: 16),
                                  label: const Text('Test Connection',
                                      style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.electricCyan,
                                    foregroundColor: AppTheme.obsidianVoid,
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _saveApiKey,
                                  icon: const Icon(Icons.save, size: 16),
                                  label: const Text('Save Key',
                                      style: TextStyle(fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Section 3: Manual Corporate Scraper Pipeline
                    _buildFrostedSectionCard(
                      icon: Icons.bolt,
                      iconColor: AppTheme.electricCyan,
                      title: 'Manual Corporate Scraper Pipeline',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Trigger real-time scraping across Greater Riyadh & KSA commercial clusters. Strictly deduplicates via multi-field SHA-256 and respects your blacklist.',
                            style: TextStyle(fontSize: 12, color: AppTheme.mutedSilver, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Target Cluster Scope:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.crispAlabaster,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: RiyadhClusterCategory.values.map((cat) {
                              final isSel = cat == _selectedScraperCluster;
                              return ChoiceChip(
                                label: Text(cat.label),
                                selected: isSel,
                                onSelected: (_) {
                                  setState(() => _selectedScraperCluster = cat);
                                },
                                selectedColor: AppTheme.electricCyan,
                                backgroundColor: AppTheme.withAlphaFactor(
                                    AppTheme.frostedCharcoalSlate, 0.9),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                  color: isSel ? AppTheme.obsidianVoid : AppTheme.crispAlabaster,
                                ),
                                side: BorderSide(
                                  color: isSel ? AppTheme.electricCyan : AppTheme.cyberBorder,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.saudiEmerald,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _isScraping ? null : _runManualScrape,
                              icon: _isScraping
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.bolt, size: 18),
                              label: Text(
                                _isScraping
                                    ? 'Scraping Corporate Listings...'
                                    : 'Run Manual Scraper Now',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Section 4: Wrong-Number Guard & Local Blacklist Box
                    _buildFrostedSectionCard(
                      icon: Icons.gpp_bad_outlined,
                      iconColor: AppTheme.crimsonAccent,
                      title: 'Wrong-Number Guard Blacklist',
                      badgeWidget: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.withAlphaFactor(AppTheme.crimsonAccent, 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.withAlphaFactor(AppTheme.crimsonAccent, 0.4),
                          ),
                        ),
                        child: Text(
                          '${blacklisted.length} Blacklisted',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.crimsonAccent,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Numbers flagged as wrong contact or non-decision makers are permanently excluded from scraping and outreach.',
                            style: TextStyle(fontSize: 12, color: AppTheme.mutedSilver, height: 1.4),
                          ),
                          if (blacklisted.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 160),
                              decoration: BoxDecoration(
                                color: AppTheme.withAlphaFactor(AppTheme.obsidianVoid, 0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.cyberBorder),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                itemCount: blacklisted.length,
                                separatorBuilder: (_, __) => const Divider(height: 8),
                                itemBuilder: (ctx, i) {
                                  final b = blacklisted[i];
                                  return Row(
                                    children: [
                                      const Icon(Icons.block, size: 14, color: AppTheme.crimsonAccent),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${b['phone']} - ${b['reason'] ?? 'Wrong Contact'}',
                                          style: const TextStyle(fontSize: 12, color: AppTheme.crispAlabaster),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.mutedSilver),
                                        tooltip: 'Remove from blacklist',
                                        onPressed: () async {
                                          await StorageService.instance.removeFromBlacklist(b['phone'].toString());
                                          setState(() {});
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Section 5: Enterprise Specs
                    _buildFrostedSectionCard(
                      icon: Icons.verified_user_outlined,
                      iconColor: AppTheme.electricCyan,
                      title: 'Enterprise Architecture Specs',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSpecRow('Target Market', 'Riyadh Corporate Sector (KAFD, Olaya, etc.)'),
                          _buildSpecRow('Staffing Specialization', 'Cleaners, Pantry Staff, Tea Boys'),
                          _buildSpecRow('Android Compatibility', 'Android 11 through Android 15+'),
                          _buildSpecRow('Gradle & Signing', 'Dual V1 (JAR) + V2/V3 (APK Signature Scheme)'),
                          _buildSpecRow('WhatsApp Dispatch', 'BiDi Isolated Native & Wa.me Fallback'),
                          _buildSpecRow('GitHub Secrets', '0 Required (100% Self-Contained)'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrostedSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? badgeWidget,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassBoxDecoration(
        surfaceColor: AppTheme.frostedCharcoalSlate,
        borderColor: AppTheme.cyberBorder,
        opacity: 0.88,
        borderRadius: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.crispAlabaster,
                    ),
                  ),
                ],
              ),
              if (badgeWidget != null) badgeWidget,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppTheme.electricCyan, fontWeight: FontWeight.bold)),
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.crispAlabaster,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: AppTheme.mutedSilver),
            ),
          ),
        ],
      ),
    );
  }
}
