import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../services/hive_service.dart';
import '../services/whatsapp_service.dart';
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

  String _selectedHub = 'KAFD';
  final List<String> _selectedStaffing = ['Tea Boy'];
  String _dateAdded = DateTime.now().toIso8601String().split('T').first;
  bool _isSaving = false;
  String? _duplicateErrorMessage;

  static const List<String> _hubs = [
    'KAFD',
    'Al Olaya',
    'King Fahd Rd',
    'Al Malqa',
    'Digital City',
    'Business Gate',
  ];

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
            colorScheme: const ColorScheme.light(
              primary: AppTheme.saudiEmerald,
              onPrimary: Colors.white,
              onSurface: AppTheme.slateNavy,
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

    // 1. Deduplication constraint check
    final exists = HiveService.instance.leadExists(company, phone);
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
      status: 'New',
      notes: _notesController.text.trim(),
      dateAdded: _dateAdded,
    );

    final added = await HiveService.instance.addLead(newLead);

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
    return Scaffold(
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
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.statusDisqualified, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _duplicateErrorMessage!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.statusDisqualified,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Company Name
                const Text(
                  'Company Name *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slateNavy),
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slateNavy),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Standard Saudi format: 05xxxxxxxx or +9665xxxxxxxx (auto-sanitized)',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slateNavy),
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slateNavy),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slateNavy),
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
                        color: isSelected ? Colors.white : AppTheme.slateNavy,
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slateNavy),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderGrey),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 18, color: AppTheme.saudiEmerald),
                            const SizedBox(width: 10),
                            Text(
                              _dateAdded,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_drop_down, color: AppTheme.textMuted),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Initial Notes
                const Text(
                  'Initial Context / Notes',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slateNavy),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Head office floor 12, prefers morning shift, VIP tea service required',
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
    );
  }
}
