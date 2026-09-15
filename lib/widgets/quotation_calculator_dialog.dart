import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../services/whatsapp_service.dart';
import '../theme/app_theme.dart';

class QuotationCalculatorDialog extends StatefulWidget {
  final Lead lead;

  const QuotationCalculatorDialog({super.key, required this.lead});

  @override
  State<QuotationCalculatorDialog> createState() =>
      _QuotationCalculatorDialogState();
}

class _QuotationCalculatorDialogState extends State<QuotationCalculatorDialog> {
  int _teaBoyCount = 1;
  int _pantryCount = 0;
  int _cleanerCount = 1;

  double _teaBoyRate = 4200.0;
  double _pantryRate = 3800.0;
  double _cleanerRate = 3200.0;

  String _selectedShift = 'صباحية (08:00 ص - 04:00 م)';

  static const List<String> _shifts = [
    'صباحية (08:00 ص - 04:00 م)',
    'مسائية (04:00 م - 12:00 ص)',
    'دوام كامل ممتد (12 ساعة)',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize based on lead requirements
    final reqs = widget.lead.staffingRequirements;
    _teaBoyCount = reqs.contains('Tea Boy') ? 1 : 0;
    _pantryCount = reqs.contains('Pantry Staff') ? 1 : 0;
    _cleanerCount = reqs.contains('Cleaners') ? 1 : 0;
    if (_teaBoyCount == 0 && _pantryCount == 0 && _cleanerCount == 0) {
      _teaBoyCount = 1;
    }
  }

  double get _subtotal =>
      (_teaBoyCount * _teaBoyRate) +
      (_pantryCount * _pantryRate) +
      (_cleanerCount * _cleanerRate);

  double get _vat => _subtotal * 0.15;
  double get _total => _subtotal + _vat;

  Widget _buildCounterRow({
    required String title,
    required IconData icon,
    required int count,
    required double rate,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.saudiEmerald),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slateNavy),
                ),
                Text(
                  '${rate.toStringAsFixed(0)} ر.س / شهرياً',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                size: 20, color: AppTheme.textMuted),
            onPressed: count > 0 ? () => onChanged(count - 1) : null,
          ),
          Text(
            '$count',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.slateNavy),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline,
                size: 20, color: AppTheme.saudiEmerald),
            onPressed: () => onChanged(count + 1),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.calculate_outlined,
                          color: AppTheme.royalGold, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'SAR Quotation Calculator',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.slateNavy),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                'Instant pricing proposal for ${widget.lead.companyName} (${widget.lead.hub})',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),

              // Staff count rows
              _buildCounterRow(
                title: 'Tea Boys (ضيافة مكتبية)',
                icon: Icons.emoji_food_beverage,
                count: _teaBoyCount,
                rate: _teaBoyRate,
                onChanged: (v) => setState(() => _teaBoyCount = v),
              ),
              _buildCounterRow(
                title: 'Pantry Staff (إشراف بوفيه)',
                icon: Icons.soup_kitchen,
                count: _pantryCount,
                rate: _pantryRate,
                onChanged: (v) => setState(() => _pantryCount = v),
              ),
              _buildCounterRow(
                title: 'Office Cleaners (نظافة مكتبية)',
                icon: Icons.cleaning_services,
                count: _cleanerCount,
                rate: _cleanerRate,
                onChanged: (v) => setState(() => _cleanerCount = v),
              ),

              const SizedBox(height: 10),

              // Shift selector
              const Text(
                'Shift / Working Hours',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _selectedShift,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                items: _shifts
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s, style: const TextStyle(fontSize: 12)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedShift = val);
                },
              ),

              const SizedBox(height: 14),

              // Total breakdown card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal (قبل الضريبة):',
                            style: TextStyle(fontSize: 12)),
                        Text('${_subtotal.toStringAsFixed(0)} SAR',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('VAT (ضريبة 15%):',
                            style: TextStyle(fontSize: 12)),
                        Text('${_vat.toStringAsFixed(0)} SAR',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Divider(height: 12, color: Color(0xFF86EFAC)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Monthly (الإجمالي):',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.saudiEmerald),
                        ),
                        Text(
                          '${_total.toStringAsFixed(0)} SAR',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.saudiEmerald),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 1-Tap Dispatch Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.saudiEmerald,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _total > 0
                      ? () {
                          final quotePitch =
                              WhatsAppService.generateItemizedQuotationPitch(
                            companyName: widget.lead.companyName,
                            contactPerson: widget.lead.contactPerson,
                            hub: widget.lead.hub,
                            teaBoyCount: _teaBoyCount,
                            pantryCount: _pantryCount,
                            cleanerCount: _cleanerCount,
                            teaBoyRate: _teaBoyRate,
                            pantryRate: _pantryRate,
                            cleanerRate: _cleanerRate,
                            shiftType: _selectedShift,
                          );

                          Navigator.pop(context);
                          WhatsAppService.copyScriptAndDispatch(
                            context: context,
                            phone: widget.lead.saudiMobile,
                            message: quotePitch,
                            companyName: widget.lead.companyName,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text(
                    'Copy Quote & Launch WhatsApp',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
