import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../services/hive_service.dart';
import '../services/scraper_service.dart';
import '../theme/app_theme.dart';
import '../widgets/hub_filter_bar.dart';
import '../widgets/lead_card.dart';
import 'add_lead_screen.dart';
import 'lead_detail_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedHub = 'All';
  String _selectedStatus = 'All';
  String _searchQuery = '';
  bool _sortNewestFirst = true;
  bool _isScraping = false;

  final TextEditingController _searchController = TextEditingController();

  static const List<String> _statuses = [
    'All',
    'New',
    'Contacted',
    'Interested',
    'Closed',
    'Disqualified',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {});
  }

  Future<void> _runScraper() async {
    setState(() => _isScraping = true);

    final result = await ScraperService.instance
        .scrapeLeads(targetHub: _selectedHub);

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
                'Riyadh Hub Scraper',
                style: TextStyle(
                  fontSize: 17,
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
                'Scraped market listings for ${_selectedHub == 'All' ? 'all Riyadh corporate hubs' : _selectedHub}.',
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
              if (result.addedCompanyNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Newly Added Companies:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ...result.addedCompanyNames.map(
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
              onPressed: () {
                Navigator.pop(ctx);
                _refresh();
              },
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

  List<Lead> _getFilteredLeads() {
    List<Lead> leads = HiveService.instance.getAllLeads();

    // Hub Filter
    if (_selectedHub != 'All') {
      leads = leads.where((l) => l.hub == _selectedHub).toList();
    }

    // Status Filter
    if (_selectedStatus != 'All') {
      leads = leads
          .where((l) => l.status.toLowerCase() == _selectedStatus.toLowerCase())
          .toList();
    }

    // Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      leads = leads.where((l) {
        return l.companyName.toLowerCase().contains(q) ||
            l.contactPerson.toLowerCase().contains(q) ||
            l.saudiMobile.contains(q) ||
            l.notes.toLowerCase().contains(q);
      }).toList();
    }

    // Sort by date_added
    leads.sort((a, b) {
      final cmp = a.dateAdded.compareTo(b.dateAdded);
      return _sortNewestFirst ? -cmp : cmp;
    });

    return leads;
  }

  @override
  Widget build(BuildContext context) {
    final leads = _getFilteredLeads();

    return Scaffold(
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
              _refresh();
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
            // Search Bar & Sort Toggle Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search companies, contacts...',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: AppTheme.textMuted),
                        prefixIcon: const Icon(Icons.search,
                            size: 18, color: AppTheme.textMuted),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
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
                      setState(() => _sortNewestFirst = !_sortNewestFirst);
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

            // Riyadh Hub Horizontal Filter Bar
            HubFilterBar(
              selectedHub: _selectedHub,
              onHubSelected: (hub) {
                setState(() => _selectedHub = hub);
              },
            ),

            const SizedBox(height: 6),

            // Horizontal Status Filter Chips
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _statuses.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final st = _statuses[i];
                  final isSelected = st == _selectedStatus;
                  return FilterChip(
                    label: Text(st),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedStatus = st),
                    selectedColor: AppTheme.slateNavy,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color:
                          isSelected ? AppTheme.slateNavy : AppTheme.borderGrey,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Lead List or Empty State
            Expanded(
              child: leads.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.apartment_outlined,
                              size: 48,
                              color: AppTheme.textMuted.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'No corporate leads found',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try running the Riyadh Hub Scraper or adjust filters',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _runScraper,
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Scrape Riyadh Market'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: leads.length,
                      padding: const EdgeInsets.only(bottom: 80),
                      itemBuilder: (context, index) {
                        final lead = leads[index];
                        return LeadCard(
                          lead: lead,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LeadDetailScreen(leadId: lead.id),
                              ),
                            );
                            _refresh();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
          ),
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
          _refresh();
        },
      ),
    );
  }
}
