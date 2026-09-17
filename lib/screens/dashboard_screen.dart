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
    '🟢 New (Unreached)',
    '🟡 Contacted / Pending',
    '🔴 Disqualified / Archive',
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
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
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
            const SizedBox(width: 10),
            const Text(
              'TEA BOY B2B CRM',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        actions: [
          // Live GPS Toggle & Refresh
          InkWell(
            onTap: () async {
              await HapticFeedback.selectionClick();
              await ref.read(geoProvider.notifier).refreshGps();
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.withAlphaFactor(
                  geoState.isGpsActive
                      ? AppTheme.mintEmerald
                      : AppTheme.electricCyan,
                  0.15,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.withAlphaFactor(
                    geoState.isGpsActive
                        ? AppTheme.mintEmerald
                        : AppTheme.electricCyan,
                    0.4,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    geoState.isGpsActive
                        ? Icons.gps_fixed
                        : Icons.location_searching,
                    size: 13,
                    color: geoState.isGpsActive
                        ? AppTheme.mintEmerald
                        : AppTheme.electricCyan,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    geoState.isGpsActive ? 'Live GPS' : 'Riyadh Hub',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: geoState.isGpsActive
                          ? AppTheme.mintEmerald
                          : AppTheme.electricCyan,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Executive Pipeline Briefing',
            icon: const Icon(Icons.assessment_outlined, size: 21),
            onPressed: _shareExecutivePipelineReport,
          ),
          IconButton(
            tooltip: 'Export Leads CSV',
            icon: const Icon(Icons.table_chart_outlined, size: 20),
            onPressed: _exportLeadsCsv,
          ),
          IconButton(
            tooltip: 'Manual Scraper (⚡ Ingest Leads)',
            icon: _isScraping
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: AppTheme.mintEmerald,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.bolt, color: AppTheme.mintEmerald, size: 22),
            onPressed: _isScraping ? null : _runScraper,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
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

                // Executive Quick Manual Scraper Action Bar
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.withAlphaFactor(
                        AppTheme.frostedCharcoalSlate, 0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          AppTheme.withAlphaFactor(AppTheme.mintEmerald, 0.4),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.withAlphaFactor(
                            AppTheme.mintEmerald, 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.withAlphaFactor(
                              AppTheme.mintEmerald, 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.bolt,
                            color: AppTheme.mintEmerald, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Manual Scraper',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.crispAlabaster,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.withAlphaFactor(
                                        AppTheme.electricCyan, 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppTheme.withAlphaFactor(
                                          AppTheme.electricCyan, 0.5),
                                      width: 0.6,
                                    ),
                                  ),
                                  child: Text(
                                    selectedCat.label,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.electricCyan,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Instant KSA corporate offices ingestion',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.mutedSilver),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.mintEmerald,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isScraping ? null : _runScraper,
                        icon: _isScraping
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download, size: 15),
                        label: Text(
                          _isScraping ? 'Scraping...' : 'Scrape Now',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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
                        padding: const EdgeInsets.only(bottom: 80),
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
