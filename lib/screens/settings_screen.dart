import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../services/gemini_service.dart';
import '../services/hive_service.dart';
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

  @override
  void initState() {
    super.initState();
    final savedKey = HiveService.instance.getApiKey() ?? '';
    _apiKeyController.text = savedKey;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    await HiveService.instance.saveApiKey(key);
    GeminiService.customApiKey = key.isEmpty ? null : key;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(key.isEmpty
              ? 'API Key cleared. Reverting to local heuristic forecasting.'
              : 'Gemini API Key saved securely to on-device storage.'),
          backgroundColor: AppTheme.saudiEmerald,
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
        title: const Text('Seed Sample Riyadh Leads'),
        content: const Text(
          'This will populate the database with realistic Riyadh corporate office tower leads. Any existing records matching the composite keys will be preserved and not duplicated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Seed Leads'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HiveService.instance.seedInitialCorporateLeads();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample leads seeded successfully!'),
            backgroundColor: AppTheme.saudiEmerald,
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
        title: const Text('Clear All Leads'),
        content: const Text(
          'Warning: This will delete ALL stored corporate leads from local Hive storage. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusDisqualified,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HiveService.instance.leadsBox.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All leads cleared from local storage.'),
            backgroundColor: AppTheme.statusDisqualified,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allLeads = HiveService.instance.getAllLeads();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'CRM Settings & AI Engine',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gemini AI Configuration Card
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.auto_awesome, color: AppTheme.royalGold, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Gemini 1.5 Flash Configuration',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.slateNavy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enter your Google Gemini API key to enable live AI deal scoring and automated Arabic/English WhatsApp pitch generation. Zero GitHub Secrets required: this key is stored strictly on your device.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _apiKeyController,
                        obscureText: _obscureKey,
                        decoration: InputDecoration(
                          hintText: 'AIzaSy...',
                          prefixIcon: const Icon(Icons.key_outlined, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureKey ? Icons.visibility_off : Icons.visibility,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() => _obscureKey = !_obscureKey);
                            },
                          ),
                        ),
                      ),
                      if (_testResultStatus != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _testResultStatus!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _testResultStatus!.startsWith('Success')
                                ? AppTheme.saudiEmerald
                                : AppTheme.statusDisqualified,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isTestingKey ? null : _testApiKey,
                              icon: _isTestingKey
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.bolt, size: 16),
                              label: const Text('Test Key'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _saveApiKey,
                              icon: const Icon(Icons.save, size: 16),
                              label: const Text('Save Key'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Database & Storage Operations
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.storage_outlined, color: AppTheme.saudiEmerald, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Hive Offline CRM Storage',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.slateNavy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Stored Leads:', style: TextStyle(fontSize: 13)),
                          Text(
                            '${allLeads.length}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.saudiEmerald,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: AppTheme.borderGrey),
                      const Text(
                        'Deduplication & Timestamps Rules:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '• Unique Primary Key: (companyName_sanitizedPhone). Existing leads are never duplicated or overwritten upon re-scraping.\n• Timestamps: Each lead contains date_added (YYYY-MM-DD) for chronological tracking.',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _resetToSeedData,
                              icon: const Icon(Icons.replay, size: 16),
                              label: const Text('Seed Leads'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.statusDisqualified,
                                side: const BorderSide(color: AppTheme.statusDisqualified),
                              ),
                              onPressed: _clearAllLeads,
                              icon: const Icon(Icons.delete_sweep, size: 16),
                              label: const Text('Clear DB'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Enterprise Specs & Hardening Summary
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.verified_user_outlined, color: AppTheme.slateNavy, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Enterprise Architecture Specs',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.slateNavy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSpecRow('Target Market', 'Riyadh Corporate Sector (KAFD, Olaya, etc.)'),
                      _buildSpecRow('Staffing Specialization', 'Cleaners, Pantry Staff, Tea Boys'),
                      _buildSpecRow('Android Compatibility', 'Android 11 through Android 15'),
                      _buildSpecRow('Gradle & Build Hardening', 'Gradle 8.5 with Debug Keystore Signing in Release'),
                      _buildSpecRow('WhatsApp Dispatch', 'BiDi Isolated Native & Wa.me Fallback'),
                      _buildSpecRow('CI/CD Pipeline', 'GitHub Actions Automated Release APK Build'),
                      _buildSpecRow('GitHub Secrets', '0 Required (100% Self-Contained)'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: const TextStyle(color: AppTheme.saudiEmerald, fontWeight: FontWeight.bold)),
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
  }
}
