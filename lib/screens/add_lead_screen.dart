import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../models/zones.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class AddLeadScreen extends StatefulWidget {
  const AddLeadScreen({super.key});

  @override
  State<AddLeadScreen> createState() => _AddLeadScreenState();
}

class _AddLeadScreenState extends State<AddLeadScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedHub = RiyadhZones.allClusterNames.first;
  final List<String> _selectedStaffing = ['Tea Boy'];
  String _dateAdded = DateTime.now().toIso8601String().split('T').first;
  String? _followUpDate;
  bool _isSaving = false;
  String? _duplicateErrorMessage;

  static List<String> get _hubs => RiyadhZones.allClusterNames;

  static const List<String> _availableStaffing = [
    'Tea Boy',
    'Pantry Staff',
    'Cleaners',
  ];

  @override
  void dispose() {
    _companyController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _parseAndAutoFill(String raw) {
    // 1. Phone number detection: look for Saudi mobile formats
    final phoneRegex = RegExp(r'(?:\+?966|00966|0)?5\d{8}');
    final phoneMatch = phoneRegex.firstMatch(raw);
    if (phoneMatch != null) {
      _phoneController.text = phoneMatch.group(0)!;
    }

    // 2. Hub detection:
    final lower = raw.toLowerCase();
    if (lower.contains('kafd') || raw.contains('كافد') || lower.contains('financial district')) {
      _selectedHub = 'KAFD';
    } else if (lower.contains('olaya') || raw.contains('العليا')) {
      _selectedHub = 'Al Olaya';
    } else if (lower.contains('king fahd') || lower.contains('fahad') || raw.contains('الملك فهد')) {
      _selectedHub = 'King Fahd Rd';
    } else if (lower.contains('malqa') || raw.contains('الملقا')) {
      _selectedHub = 'Al Malqa';
    } else if (lower.contains('digital city') || raw.contains('الرقمية')) {
      _selectedHub = 'Digital City';
    } else if (lower.contains('business gate') || raw.contains('بوابة الأعمال')) {
      _selectedHub = 'Business Gate';
    }

    // 3. Staffing Requirements detection:
    final newStaffing = <String>[];
    if (lower.contains('tea') || lower.contains('boy') || raw.contains('شاي') || raw.contains('قهوجي') || raw.contains('ضيافة')) {
      newStaffing.add('Tea Boy');
    }
    if (lower.contains('pantry') || raw.contains('بوفيه') || raw.contains('مطبخ')) {
      newStaffing.add('Pantry Staff');
    }
    if (lower.contains('clean') || raw.contains('نظافة') || raw.contains('تنظيف')) {
      newStaffing.add('Cleaners');
    }
    if (newStaffing.isNotEmpty) {
      _selectedStaffing.clear();
      _selectedStaffing.addAll(newStaffing);
    }

    // 4. Contact person detection:
    final contactRegex = RegExp(
        r'(?:Engr?\.?|Mr\.?|Ms\.?|Dr\.?|المهندس|المهندسة|الأستاذ|الاستاذ|دكتور|عناية|Contact:?)\s*([^\n,،:0-9]{3,25})',
        caseSensitive: false);
    final contactMatch = contactRegex.firstMatch(raw);
    if (contactMatch != null) {
      _contactController.text = contactMatch.group(1)!.trim();
    }

    // 5. Company Name detection:
    final companyRegex = RegExp(
        r'(?:Company|Corp|Inc|شركة|مؤسسة|مكتب|Tower|برج)\s*([^\n,،:]{3,35})',
        caseSensitive: false);
    final companyMatch = companyRegex.firstMatch(raw);
    if (companyMatch != null) {
      _companyController.text = companyMatch.group(0)!.trim();
    } else if (_companyController.text.isEmpty) {
      final firstLine = raw
          .split('\n')
          .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
      if (firstLine.isNotEmpty && firstLine.length <= 40) {
        _companyController.text = firstLine.trim();
      }
    }

    // Copy context into notes if empty
    if (_notesController.text.isEmpty) {
      _notesController.text = 'Raw extracted text: ${raw.replaceAll('\n', ' ').trim()}';
    }

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Parsed & auto-filled lead info from text!'),
        backgroundColor: AppTheme.saudiEmerald,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openSmartPasteDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.obsidianVoid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.cyberBorder)),
        title: Row(
          children: const [
            Icon(Icons.auto_awesome, color: AppTheme.royalGold),
            SizedBox(width: 8),
            Text(
              'Smart Lead Extractor',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.crispAlabaster,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste any raw WhatsApp message, contact card, or email text. The regex engine auto-extracts Company, Contact, Saudi Phone, Hub, and Staffing needs!',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'e.g. Al Faisaliah Tower, Eng. Tariq Al-Otaibi 0551234567, needs 2 tea boys and 1 cleaner in Al Olaya...',
                  hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final raw = textController.text;
              if (raw.trim().isNotEmpty) {
                _parseAndAutoFill(raw);
              }
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.bolt, size: 16),
            label: const Text('Extract & Fill'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.saudiEmerald,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateAdded) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.electricCyan,
              onPrimary: AppTheme.obsidianVoid,
              surface: AppTheme.frostedCharcoalSlate,
              onSurface: AppTheme.crispAlabaster,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateAdded = picked.toIso8601String().split('T').first;
      });
    }
  }

  Future<void> _pickFollowUpDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.electricCyan,
              onPrimary: AppTheme.obsidianVoid,
              surface: AppTheme.frostedCharcoalSlate,
              onSurface: AppTheme.crispAlabaster,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _followUpDate = picked.toIso8601String().split('T').first;
      });
    }
  }

  Future<void> _submitForm() async {
    setState(() => _duplicateErrorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedStaffing.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one staffing requirement.'),
          backgroundColor: AppTheme.statusDisqualified,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final company = _companyController.text.trim();
    final phone = _phoneController.text.trim();

    // 0. Check Blacklist
    if (StorageService.instance.isBlacklisted(phone)) {
      setState(() {
        _duplicateErrorMessage =
            'Blacklist Guard: The number "${Lead.sanitizePhone(phone)}" is permanently archived in blacklist_contacts (Wrong Number / Excluded) and cannot be added.';
      });
      return;
    }

    // 1. Deduplication constraint check
    final exists = StorageService.instance.leadExists(company, phone);
    if (exists) {
      setState(() {
        _duplicateErrorMessage =
            'Duplicate Detected: A lead for "$company" with phone "${Lead.sanitizePhone(phone)}" already exists. Under strict CRM deduplication rules, existing leads are never duplicated or overwritten.';
      });
      return;
    }

    setState(() => _isSaving = true);

    final newLead = Lead.create(
      companyName: company,
      contactPerson: _contactController.text.trim().isEmpty
          ? 'Key Decision Maker'
          : _contactController.text.trim(),
      saudiMobile: phone,
      hub: _selectedHub,
      staffingRequirements: List.from(_selectedStaffing),
      status: 'new',
      notes: _notesController.text.trim(),
      dateAdded: _dateAdded,
      followUpDate: _followUpDate,
    );

    final added = await StorageService.instance.addLead(newLead);

    setState(() => _isSaving = false);

    if (added && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lead for "$company" saved successfully!'),
          backgroundColor: AppTheme.saudiEmerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      setState(() {
        _duplicateErrorMessage =
            'Failed to save lead: A record with matching credentials already exists.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'Add Corporate Lead',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Duplicate Error Banner
                if (_duplicateErrorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.withAlphaFactor(AppTheme.crimsonAccent, 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.withAlphaFactor(AppTheme.crimsonAccent, 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.crimsonAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _duplicateErrorMessage!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.crispAlabaster,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Smart Auto-Detect & Paste Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.frostedCharcoalSlate,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cyberBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 20, color: AppTheme.royalGold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Smart Text Auto-Detect',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.crispAlabaster),
                            ),
                            Text(
                              'Paste WhatsApp / SMS notes to auto-fill fields',
                              style: TextStyle(fontSize: 11, color: AppTheme.mutedSilver),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _openSmartPasteDialog,
                        icon: const Icon(Icons.bolt, size: 14),
                        label: const Text('Auto-Fill'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.mintEmerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Company Name
                const Text(
                  'Company Name *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.crispAlabaster),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _companyController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. KPMG Corporate Tower, Tadawul Group',
                    prefixIcon: Icon(Icons.business_outlined, size: 18),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter the corporate company name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Saudi Mobile Number
                const Text(
                  'Saudi Mobile Number *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.crispAlabaster),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Standard Saudi format: 05xxxxxxxx or +9665xxxxxxxx (auto-sanitized)',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.mutedSilver),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 0501234567 or 966559876543',
                    prefixIcon: Icon(Icons.phone_outlined, size: 18),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a mobile phone number';
                    }
                    final sanitized = Lead.sanitizePhone(val);
                    if (!sanitized.startsWith('9665') || sanitized.length != 12) {
                      return 'Must be a valid Saudi mobile number (starts with 05 / 9665, 9 digits after 966)';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Contact Person
                const Text(
                  'Contact Person / Title',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.crispAlabaster),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. HR Director, Facilities Manager, Sultan Al-Otaibi',
                    prefixIcon: Icon(Icons.person_outline, size: 18),
                  ),
                ),

                const SizedBox(height: 16),

                // Riyadh Business Hub
                const Text(
                  'Riyadh Business Hub *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.crispAlabaster),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _selectedHub,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on_outlined, size: 18, color: AppTheme.royalGold),
                  ),
                  items: _hubs.map((h) {
                    return DropdownMenuItem(value: h, child: Text(h));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedHub = val);
                  },
                ),

                const SizedBox(height: 16),

                // Staffing Requirements (Multi-select)
                const Text(
                  'Required Enterprise Staffing *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.crispAlabaster),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _availableStaffing.map((staff) {
                    final isSelected = _selectedStaffing.contains(staff);
                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            staff == 'Tea Boy'
                                ? Icons.emoji_food_beverage
                                : staff == 'Pantry Staff'
                                    ? Icons.soup_kitchen
                                    : Icons.cleaning_services,
                            size: 14,
                            color: isSelected ? Colors.white : AppTheme.saudiEmerald,
                          ),
                          const SizedBox(width: 5),
                          Text(staff),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: AppTheme.saudiEmerald,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.obsidianVoid : AppTheme.crispAlabaster,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedStaffing.add(staff);
                          } else {
                            _selectedStaffing.remove(staff);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Date Added (Timestamp Constraint)
                const Text(
                  'Lead Discovery Date (YYYY-MM-DD)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.crispAlabaster),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppTheme.frostedCharcoalSlate,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cyberBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 18, color: AppTheme.electricCyan),
                            const SizedBox(width: 10),
                            Text(
                              _dateAdded,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.crispAlabaster,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_drop_down, color: AppTheme.mutedSilver),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Initial Notes
                const Text(
                  'Initial Context / Notes',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.crispAlabaster),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Head office floor 12, prefers morning shift, VIP tea service required',
                  ),
                ),

                const SizedBox(height: 16),

                // Follow-up Callback Schedule
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Follow-Up Callback Reminder',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.crispAlabaster),
                    ),
                    if (_followUpDate != null)
                      InkWell(
                        onTap: () => setState(() => _followUpDate = null),
                        child: const Text('Clear', style: TextStyle(fontSize: 12, color: AppTheme.crimsonAccent)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickFollowUpDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.frostedCharcoalSlate,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _followUpDate != null ? AppTheme.mintEmerald : AppTheme.cyberBorder,
                        width: _followUpDate != null ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.alarm, size: 18,
                              color: _followUpDate != null ? AppTheme.mintEmerald : AppTheme.mutedSilver),
                            const SizedBox(width: 10),
                            Text(
                              _followUpDate ?? 'Optional: Schedule callback date',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: _followUpDate != null ? FontWeight.w700 : FontWeight.w400,
                                color: _followUpDate != null ? AppTheme.crispAlabaster : AppTheme.mutedSilver,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_drop_down, color: AppTheme.mutedSilver),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isSaving ? null : _submitForm,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _isSaving ? 'Saving Lead...' : 'Save Corporate Lead',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
          ),
        ),
      ),
    ),
    );
  }
}
