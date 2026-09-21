import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lead.dart';
import '../models/zones.dart';
import '../providers/crm_providers.dart';
import '../services/dispatch_service.dart';
import '../services/scraper_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/lead_card.dart';
import '../widgets/pipeline_kpi_header.dart';
import 'add_lead_screen.dart';
import 'lead_detail_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isScraping = false;

  final List<String> _tabTitles = [
    '🟢 New',
    '🟡 In Progress',
    '🔴 Disqualified',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runScraper({int count = 15}) async {
    await HapticFeedback.mediumImpact();
    setState(() => _isScraping = true);

    final selectedCat = ref.read(selectedCategoryProvider);
    final result = await ScraperService.instance
        .scrapeLeads(clusterCategory: selectedCat, dynamicCount: count);

    // Refresh leads in Riverpod
    ref.read(leadsProvider.notifier).refresh();

    setState(() => _isScraping = false);
    await HapticFeedback.heavyImpact();

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.obsidianVoid,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.cyberBorder),
          ),
          title: Row(
            children: const [
              Icon(Icons.bolt, color: AppTheme.mintEmerald, size: 22),
              SizedBox(width: 8),
              Text(
                'Corporate Scraper Ingestion',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.crispAlabaster,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingested corporate listings for ${selectedCat.label}.',
                style: const TextStyle(fontSize: 13, color: AppTheme.mutedSilver),
              ),
              const SizedBox(height: 14),
              _buildResultRow(
                icon: Icons.search,
                label: 'Total Discovered',
                value: '${result.totalScraped}',
                color: AppTheme.crispAlabaster,
              ),
              const SizedBox(height: 8),
              _buildResultRow(
                icon: Icons.check_circle_outline,
                label: 'New Leads Added',
                value: '${result.newLeadsAdded}',
                color: AppTheme.mintEmerald,
              ),
              const SizedBox(height: 8),
              _buildResultRow(
                icon: Icons.filter_alt_off_outlined,
                label: 'Duplicates Skipped',
                value: '${result.skippedDuplicates}',
                color: AppTheme.amberAccent,
              ),
              if (result.skippedBlacklisted > 0) ...[
                const SizedBox(height: 8),
                _buildResultRow(
                  icon: Icons.block,
                  label: 'Blacklisted Excluded',
                  value: '${result.skippedBlacklisted}',
                  color: AppTheme.crimsonAccent,
                ),
              ],
              if (result.addedCompanyNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Newly Ingested Corporate Offices:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.crispAlabaster,
                  ),
                ),
                const SizedBox(height: 4),
                ...result.addedCompanyNames.take(4).map(
                      (name) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• $name',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.electricCyan,
                          ),
                        ),
                      ),
                    ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close',
                  style: TextStyle(
                      color: AppTheme.mutedSilver,
                      fontWeight: FontWeight.w600)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.electricCyan,
                foregroundColor: AppTheme.obsidianVoid,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _tabController.animateTo(0);
              },
              icon: const Icon(Icons.flash_on, size: 16),
              label: const Text('View New Leads',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildResultRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: AppTheme.mutedSilver)),
        ),
        Text(
          value,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  void _showLeadActionsSheet(BuildContext context, List<Lead> allLeads) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: BoxDecoration(
          color: AppTheme.obsidianVoid,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.cyberBorder),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.6),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.cyberBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.tune_rounded, color: AppTheme.electricCyan, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Lead Actions & Cleaner',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.crispAlabaster,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.withAlphaFactor(AppTheme.mintEmerald, 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.withAlphaFactor(AppTheme.mintEmerald, 0.4),
                    ),
                  ),
                  child: Text(
                    '${allLeads.length} Leads',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mintEmerald,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildActionTile(
              icon: Icons.cleaning_services_outlined,
              color: AppTheme.mintEmerald,
              title: 'Clean & Deduplicate Leads',
              subtitle: 'Scan database & purge duplicate records across company, phone & location',
              onTap: () async {
                Navigator.pop(ctx);
                final pruned = await StorageService.instance.deduplicateDatabase();
                ref.read(leadsProvider.notifier).refresh();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        pruned > 0
                            ? '🧹 Deduplication complete! Purged $pruned duplicate records.'
                            : '✅ Pipeline is 100% clean! Zero duplicate records found.',
                      ),
                      backgroundColor: AppTheme.mintEmerald,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            _buildActionTile(
              icon: Icons.delete_sweep_outlined,
              color: AppTheme.crimsonAccent,
              title: 'Clear All Leads',
              subtitle: 'Safely delete all stored leads to start with a fresh pipeline',
              onTap: () {
                Navigator.pop(ctx);
                _confirmAndClearAllLeads();
              },
            ),
            const SizedBox(height: 8),
            _buildActionTile(
              icon: Icons.replay_rounded,
              color: AppTheme.royalGold,
              title: 'Seed Sample Riyadh Leads',
              subtitle: 'Populate verified Riyadh office tower listings (KAFD, Olaya, etc.)',
              onTap: () async {
                Navigator.pop(ctx);
                await StorageService.instance.seedInitialCorporateLeads();
                ref.read(leadsProvider.notifier).refresh();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sample Riyadh corporate leads seeded successfully!'),
                      backgroundColor: AppTheme.mintEmerald,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            _buildActionTile(
              icon: Icons.settings_outlined,
              color: AppTheme.electricCyan,
              title: 'Open Full Settings & AI Engine',
              subtitle: 'Configure Gemini 1.5 API key, blacklist rules & system parameters',
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                ref.read(leadsProvider.notifier).refresh();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndClearAllLeads() async {
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
          'This will delete all stored corporate leads from your on-device storage. This action cannot be undone.\n\nAre you sure you want to proceed?',
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
            label: const Text('Clear Everything', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.instance.leadsBox.clear();
      StorageService.instance.revision.value++;
      ref.read(leadsProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All leads cleared from local storage.'),
            backgroundColor: AppTheme.crimsonAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.withAlphaFactor(AppTheme.frostedCharcoalSlate, 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cyberBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.withAlphaFactor(color, 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.crispAlabaster,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.mutedSilver,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppTheme.mutedSilver),
          ],
        ),
      ),
    );
  }

  void _shareExecutivePipelineReport() {
    final report = StorageService.instance.generatePipelineExecutiveBriefing();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.obsidianVoid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.cyberBorder),
        ),
        title: Row(
          children: const [
            Icon(Icons.assessment_outlined, color: AppTheme.electricCyan),
            SizedBox(width: 8),
            Text(
              'Pipeline Executive Briefing',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.crispAlabaster,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.withAlphaFactor(
                    AppTheme.frostedCharcoalSlate, 0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cyberBorder),
              ),
              child: SelectableText(
                report,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppTheme.crispAlabaster,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: AppTheme.mutedSilver)),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pipeline Briefing copied to clipboard!'),
                    backgroundColor: AppTheme.mintEmerald,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report));
              Navigator.pop(ctx);
              await DispatchService.launchWhatsApp(phone: '', message: report);
            },
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Share WhatsApp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mintEmerald,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _exportLeadsCsv() {
    final csvData = StorageService.instance.exportToCsv();
    Clipboard.setData(ClipboardData(text: csvData));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV copied to clipboard (ready for Excel/Sheets)'),
        backgroundColor: AppTheme.mintEmerald,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _computeStickyTopBar(List<Lead> leads, GeoState geoState) {
    final today = DateTime.now().toIso8601String().split('T').first;
    final todayCount = leads.where((l) => l.dateAdded == today).length;

    // Cluster count distribution
    final Map<String, int> clusterCounts = {};
    for (final l in leads) {
      clusterCounts[l.hub] = (clusterCounts[l.hub] ?? 0) + 1;
    }

    String topCluster = 'KAFD / Narjis';
    int maxCount = 0;
    clusterCounts.forEach((cluster, count) {
      if (count > maxCount) {
        maxCount = count;
        topCluster = cluster;
      }
    });

    final gpsTag = geoState.isGpsActive ? '📍 Live GPS' : '📍 Riyadh Anchor';
    return '$gpsTag | Today Fresh: $todayCount | Top Hub: $topCluster';
  }

  List<Lead> _filterLeadsByTab(List<Lead> leads, int tabIndex) {
    if (tabIndex == 0) {
      return leads.where((l) => l.isNew).toList();
    } else if (tabIndex == 1) {
      return leads
          .where((l) => l.isContacted || l.isAnalyzed || l.isInterested)
          .toList();
    } else {
      return leads.where((l) => l.isClosed || l.isDisqualified).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allLeads = ref.watch(leadsProvider);
    final sortedLeads = ref.watch(proximitySortedLeadsProvider);
    final geoState = ref.watch(geoProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);
    final isNearMe = ref.watch(isNearMeSortProvider);
    final stickyTopText = _computeStickyTopBar(allLeads, geoState);

    return Scaffold(
      backgroundColor: AppTheme.obsidianVoid,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.withAlphaFactor(AppTheme.electricCyan, 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.withAlphaFactor(AppTheme.electricCyan, 0.4),
                ),
              ),
              child: const Icon(Icons.coffee,
                  color: AppTheme.electricCyan, size: 18),
            ),
            const SizedBox(width: 8),
            const Text(
              'TEA BOY',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: AppTheme.crispAlabaster,
              ),
            ),
          ],
        ),
        actions: [
          // 1. Direct Lead Actions & Cleaner Button
          IconButton(
            tooltip: 'Lead Cleaner & Tools',
            icon: const Icon(Icons.cleaning_services_outlined,
                color: AppTheme.mintEmerald, size: 22),
            onPressed: () => _showLeadActionsSheet(context, allLeads),
          ),
          // 2. Direct Settings & AI Configuration Button
          IconButton(
            tooltip: 'Settings & AI Engine',
            icon: const Icon(Icons.settings_outlined,
                color: AppTheme.crispAlabaster, size: 22),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              ref.read(leadsProvider.notifier).refresh();
            },
          ),
          // 3. Overflow Menu for Executive Tools & Utilities
          PopupMenuButton<String>(
            tooltip: 'More Operations',
            icon: const Icon(Icons.more_vert, color: AppTheme.mutedSilver),
            color: AppTheme.frostedCharcoalSlate,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.cyberBorder),
            ),
            onSelected: (value) async {
              if (value == 'briefing') {
                _shareExecutivePipelineReport();
              } else if (value == 'export_csv') {
                _exportLeadsCsv();
              } else if (value == 'scrape') {
                if (!_isScraping) _runScraper();
              } else if (value == 'gps') {
                await HapticFeedback.selectionClick();
                await ref.read(geoProvider.notifier).refreshGps();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'gps',
                child: Row(
                  children: [
                    Icon(
                      geoState.isGpsActive ? Icons.gps_fixed : Icons.location_searching,
                      color: geoState.isGpsActive ? AppTheme.mintEmerald : AppTheme.electricCyan,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      geoState.isGpsActive ? 'Live GPS: Active' : 'Refresh Riyadh GPS',
                      style: const TextStyle(color: AppTheme.crispAlabaster, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'briefing',
                child: Row(
                  children: [
                    Icon(Icons.assessment_outlined, color: AppTheme.electricCyan, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Executive Briefing',
                      style: const TextStyle(color: AppTheme.crispAlabaster, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_outlined, color: AppTheme.royalGold, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Export Leads CSV',
                      style: const TextStyle(color: AppTheme.crispAlabaster, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'scrape',
                child: Row(
                  children: [
                    Icon(Icons.bolt, color: AppTheme.mintEmerald, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Run Web Scraper',
                      style: const TextStyle(color: AppTheme.crispAlabaster, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                // Top Live Proximity Banner
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.withAlphaFactor(
                        AppTheme.frostedCharcoalSlate, 0.95),
                    border: const Border(
                      bottom: BorderSide(
                          color: AppTheme.cyberBorderSubtle, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.radar,
                          color: AppTheme.electricCyan, size: 15),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          stickyTopText,
                          style: const TextStyle(
                            color: AppTheme.crispAlabaster,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          ref.read(isNearMeSortProvider.notifier).state =
                              !isNearMe;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.withAlphaFactor(
                              isNearMe
                                  ? AppTheme.electricCyan
                                  : AppTheme.mutedSilver,
                              0.15,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isNearMe
                                  ? AppTheme.electricCyan
                                  : AppTheme.mutedSilver,
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            isNearMe ? 'Near Me: ON' : 'Sort: Date',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isNearMe
                                  ? AppTheme.electricCyan
                                  : AppTheme.mutedSilver,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Pipeline KPI Header
                PipelineKpiHeader(leads: allLeads),

                // Segmented Tabs Bar
                Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.obsidianVoid,
                    border: Border(
                      bottom:
                          BorderSide(color: AppTheme.cyberBorder, width: 0.8),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppTheme.electricCyan,
                    indicatorWeight: 3,
                    labelColor: AppTheme.electricCyan,
                    unselectedLabelColor: AppTheme.mutedSilver,
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: _tabTitles.map((title) => Tab(text: title)).toList(),
                  ),
                ),

                // Cluster Filter Chips Row
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: RiyadhClusterCategory.values.map((category) {
                      final isSel = category == selectedCat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(category.label),
                          selected: isSel,
                          onSelected: (_) {
                            ref.read(selectedCategoryProvider.notifier).state =
                                category;
                          },
                          selectedColor: AppTheme.electricCyan,
                          backgroundColor: AppTheme.withAlphaFactor(
                              AppTheme.frostedCharcoalSlate, 0.85),
                          labelStyle: TextStyle(
                            color: isSel
                                ? AppTheme.obsidianVoid
                                : AppTheme.crispAlabaster,
                            fontSize: 11,
                            fontWeight:
                                isSel ? FontWeight.w700 : FontWeight.w500,
                          ),
                          side: BorderSide(
                            color: isSel
                                ? AppTheme.electricCyan
                                : AppTheme.cyberBorder,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Search Bar Row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(
                        color: AppTheme.crispAlabaster, fontSize: 13),
                    onChanged: (val) {
                      ref.read(searchQueryProvider.notifier).state = val;
                    },
                    decoration: InputDecoration(
                      hintText:
                          'Search offices, contacts, KAFD/Narjis/Jeddah...',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: AppTheme.mutedSilver),
                      prefixIcon: const Icon(Icons.search,
                          size: 18, color: AppTheme.electricCyan),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  size: 16, color: AppTheme.mutedSilver),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(searchQueryProvider.notifier).state =
                                    '';
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),

                // Tab Views with Real-Time Reactive Lead Lists
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [0, 1, 2].map((tabIndex) {
                      final tabLeads =
                          _filterLeadsByTab(sortedLeads, tabIndex);

                      if (tabLeads.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.business_center_outlined,
                                size: 48,
                                color: AppTheme.withAlphaFactor(
                                    AppTheme.mutedSilver, 0.4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                tabIndex == 0
                                    ? 'No new unreached leads'
                                    : tabIndex == 1
                                        ? 'No contacted leads in progress'
                                        : 'No archived leads',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.crispAlabaster,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Run the KSA Hotspots Scraper to ingest fresh corporate offices',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.mutedSilver),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                onPressed: _runScraper,
                                icon: const Icon(Icons.download, size: 16),
                                label: const Text('Ingest Corporate Hotspots'),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: tabLeads.length,
                        padding: const EdgeInsets.only(bottom: 110),
                        itemBuilder: (context, index) {
                          final lead = tabLeads[index];
                          return LeadCard(
                            lead: lead,
                            onStatusChanged: (newStatus) async {
                              await ref
                                  .read(leadsProvider.notifier)
                                  .updateLeadStatus(lead.id, newStatus);
                            },
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      LeadDetailScreen(leadId: lead.id),
                                ),
                              );
                              ref.read(leadsProvider.notifier).refresh();
                            },
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dedicated Manual Scraper Floating Action Button
          FloatingActionButton.extended(
            heroTag: 'fab_manual_scraper',
            backgroundColor: AppTheme.mintEmerald,
            foregroundColor: Colors.white,
            elevation: 4,
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
              _isScraping ? 'Scraping...' : 'Scrape Leads',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: _isScraping ? null : _runScraper,
          ),
          const SizedBox(width: 10),
          // Add Lead Floating Action Button
          FloatingActionButton.extended(
            heroTag: 'fab_add_lead',
            backgroundColor: AppTheme.electricCyan,
            foregroundColor: AppTheme.obsidianVoid,
            elevation: 4,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Lead',
                style: TextStyle(fontWeight: FontWeight.w800)),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddLeadScreen()),
              );
              ref.read(leadsProvider.notifier).refresh();
            },
          ),
        ],
      ),
    );
  }
}
