import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lead.dart';
import '../models/zones.dart';
import '../services/storage_service.dart';
import '../services/scraper_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/app_theme.dart';
import '../widgets/lead_card.dart';
import '../widgets/pipeline_kpi_header.dart';
import 'add_lead_screen.dart';
import 'lead_detail_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  RiyadhClusterCategory _selectedCategory = RiyadhClusterCategory.all;
  String _searchQuery = '';
  bool _sortNewestFirst = true;
  bool _isScraping = false;

  final TextEditingController _searchController = TextEditingController();

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

  Future<void> _runScraper() async {
    setState(() => _isScraping = true);

    final result = await ScraperService.instance
        .scrapeLeads(clusterCategory: _selectedCategory);

    setState(() => _isScraping = false);

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.hub_outlined, color: AppTheme.saudiEmerald),
              SizedBox(width: 8),
              Text(
                'Riyadh Hotspots Scraper',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slateNavy,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scraped corporate market listings for ${_selectedCategory.label}.',
                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              _buildResultRow(
                icon: Icons.search,
                label: 'Total Discovered',
                value: '${result.totalScraped}',
                color: AppTheme.slateNavy,
              ),
              const SizedBox(height: 8),
              _buildResultRow(
                icon: Icons.check_circle_outline,
                label: 'New Leads Added',
                value: '${result.newLeadsAdded}',
                color: AppTheme.saudiEmerald,
              ),
              const SizedBox(height: 8),
              _buildResultRow(
                icon: Icons.filter_alt_off_outlined,
                label: 'Duplicates Skipped',
                value: '${result.skippedDuplicates}',
                color: AppTheme.statusContacted,
              ),
              if (result.skippedBlacklisted > 0) ...[
                const SizedBox(height: 8),
                _buildResultRow(
                  icon: Icons.block,
                  label: 'Blacklisted Excluded',
                  value: '${result.skippedBlacklisted}',
                  color: AppTheme.statusDisqualified,
                ),
              ],
              if (result.addedCompanyNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Newly Added Corporate Offices:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ...result.addedCompanyNames.take(4).map(
                      (name) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• $name',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppTheme.saudiEmerald),
                        ),
                      ),
                    ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK',
                  style: TextStyle(
                      color: AppTheme.saudiEmerald,
                      fontWeight: FontWeight.w700)),
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
          child: Text(label, style: const TextStyle(fontSize: 13)),
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.assessment_outlined, color: AppTheme.saudiEmerald),
            SizedBox(width: 8),
            Text(
              'Pipeline Executive Briefing',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.slateNavy,
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
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderGrey),
              ),
              child: SelectableText(
                report,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppTheme.slateNavy,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Close', style: TextStyle(color: AppTheme.textMuted)),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pipeline Briefing copied to clipboard!'),
                    backgroundColor: AppTheme.saudiEmerald,
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
              await WhatsAppService.launchWhatsApp(phone: '', message: report);
            },
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Share WhatsApp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006C4F),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _exportLeadsCsv() async {
    final csv = StorageService.instance.exportToCsv();
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.table_chart, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                    'All leads exported to CSV and copied to clipboard! Ready to paste into Excel.'),
              ),
            ],
          ),
          backgroundColor: AppTheme.slateNavy,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  List<Lead> _filterLeads(List<Lead> allLeads, int tabIndex) {
    List<Lead> list;

    // Segmented Tab Filter
    switch (tabIndex) {
      case 0: // 🟢 New (Unreached)
        list = allLeads.where((l) => l.isNew).toList();
        break;
      case 1: // 🟡 Contacted / Pending
        list = allLeads
            .where((l) => l.isContacted || l.isAnalyzed || l.isInterested)
            .toList();
        break;
      case 2: // 🔴 Disqualified / Archive
        list = allLeads.where((l) => l.isDisqualified || l.isClosed).toList();
        break;
      default:
        list = allLeads;
    }

    // Area Quick-Filter Category
    if (_selectedCategory != RiyadhClusterCategory.all) {
      list = list.where((l) {
        return RiyadhZones.matchesCategory(l.hub, _selectedCategory);
      }).toList();
    }

    // Search Query Filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((l) {
        return l.companyName.toLowerCase().contains(q) ||
            l.contactPerson.toLowerCase().contains(q) ||
            l.saudiMobile.contains(q) ||
            l.hub.toLowerCase().contains(q) ||
            l.notes.toLowerCase().contains(q);
      }).toList();
    }

    // Sort by dateAdded
    list.sort((a, b) {
      final cmp = a.dateAdded.compareTo(b.dateAdded);
      return _sortNewestFirst ? -cmp : cmp;
    });

    return list;
  }

  /// Sticky Top Bar String
  String _computeStickyTopBar(List<Lead> allLeads) {
    final today = DateTime.now().toIso8601String().split('T').first;
    final freshCount = allLeads.where((l) => l.dateAdded == today).length;

    // Determine Top Cluster
    final Map<String, int> clusterCounts = {};
    for (final l in allLeads) {
      clusterCounts[l.hub] = (clusterCounts[l.hub] ?? 0) + 1;
    }

    String topCluster = 'Al Narjis / Roshn';
    if (clusterCounts.isNotEmpty) {
      final sorted = clusterCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topHubName = sorted.first.key;
      if (topHubName.contains('Narjis') || topHubName.contains('Roshn')) {
        topCluster = 'Al Narjis / Roshn';
      } else {
        topCluster = topHubName;
      }
    }

    return "🟢 Today's Fresh Offices: $freshCount | Top Cluster: $topCluster";
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.royalGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.emoji_food_beverage,
                    color: AppTheme.slateNavy, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'TEA BOY B2B CRM',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5),
                  ),
                  Text(
                    'Riyadh Corporate Staffing',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.royalGoldLight),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Share Pipeline Report via WhatsApp',
              icon: const Icon(Icons.assessment_outlined),
              onPressed: _shareExecutivePipelineReport,
            ),
            IconButton(
              tooltip: 'Export Leads to CSV',
              icon: const Icon(Icons.table_chart_outlined),
              onPressed: _exportLeadsCsv,
            ),
            IconButton(
              tooltip: 'Run Scraper / Import',
              icon: _isScraping
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.cloud_download_outlined),
              onPressed: _isScraping ? null : _runScraper,
            ),
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
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
          child: ValueListenableBuilder<int>(
            valueListenable: StorageService.instance.revision,
            builder: (context, _, __) {
              final allLeads = StorageService.instance.getAllLeads();
              final stickyTopText = _computeStickyTopBar(allLeads);

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    children: [
                      // Sticky Top Bar: "🟢 Today's Fresh Offices: X | Top Cluster: Al Narjis / Roshn"
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt,
                                color: AppTheme.royalGold, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                stickyTopText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Executive Pipeline KPI Header
                      PipelineKpiHeader(leads: allLeads),

                      // Segmented Tabs: [🟢 New (Unreached), 🟡 Contacted / Pending, 🔴 Disqualified / Archive]
                      Container(
                        color: Colors.white,
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: AppTheme.saudiEmerald,
                          indicatorWeight: 3,
                          labelColor: AppTheme.saudiEmerald,
                          unselectedLabelColor: AppTheme.textMuted,
                          labelStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                          unselectedLabelStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                          tabs: _tabTitles.map((title) => Tab(text: title)).toList(),
                        ),
                      ),

                      // Area Quick-Filter Chips: [All, Hotspots (Narjis/Roshn), Central (KAFD/Olaya), North Hubs, Industrial/Logistics]
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: RiyadhClusterCategory.values.map((category) {
                            final isSel = category == _selectedCategory;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(category.label),
                                selected: isSel,
                                onSelected: (_) {
                                  setState(() => _selectedCategory = category);
                                },
                                selectedColor: AppTheme.saudiEmerald,
                                backgroundColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: isSel ? Colors.white : AppTheme.slateNavy,
                                  fontSize: 11,
                                  fontWeight: isSel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                                side: BorderSide(
                                  color: isSel
                                      ? AppTheme.saudiEmerald
                                      : AppTheme.borderGrey,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // Search & Sort Toggle Row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) {
                                  setState(() => _searchQuery = val);
                                },
                                decoration: InputDecoration(
                                  hintText:
                                      'Search offices, contacts, clusters...',
                                  hintStyle: const TextStyle(
                                      fontSize: 13, color: AppTheme.textMuted),
                                  prefixIcon: const Icon(Icons.search,
                                      size: 18, color: AppTheme.textMuted),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear,
                                              size: 16),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                        )
                                      : null,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                setState(
                                    () => _sortNewestFirst = !_sortNewestFirst);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.borderGrey),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _sortNewestFirst
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                      size: 14,
                                      color: AppTheme.saudiEmerald,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _sortNewestFirst ? 'Newest' : 'Oldest',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.slateNavy,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Tab Views with Real-Time Reactive Lead Lists
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [0, 1, 2].map((tabIndex) {
                            final filtered = _filterLeads(allLeads, tabIndex);

                            if (filtered.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.business_center_outlined,
                                        size: 48,
                                        color: AppTheme.textMuted
                                            .withOpacity(0.5)),
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
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Run the Riyadh Hotspots Scraper to ingest fresh offices',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textMuted),
                                    ),
                                    const SizedBox(height: 14),
                                    ElevatedButton.icon(
                                      onPressed: _runScraper,
                                      icon: const Icon(Icons.download, size: 16),
                                      label: const Text('Scrape Riyadh Hotspots'),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: filtered.length,
                              padding: const EdgeInsets.only(bottom: 80),
                              itemBuilder: (context, index) {
                                final lead = filtered[index];
                                return LeadCard(
                                  lead: lead,
                                  onStatusChanged: (newStatus) async {
                                    await StorageService.instance
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
              );
            },
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppTheme.saudiEmerald,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Add Lead',
              style: TextStyle(fontWeight: FontWeight.w700)),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddLeadScreen()),
            );
          },
        ),
      ),
    );
  }
}
