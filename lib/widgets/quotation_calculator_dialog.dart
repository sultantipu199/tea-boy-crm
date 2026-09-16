import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lead.dart';
import '../services/dispatch_service.dart';
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

  final double _teaBoyRate = 4200.0;
  final double _pantryRate = 3800.0;
  final double _cleanerRate = 3200.0;

  String _selectedShift = 'صباحية (08:00 ص - 04:00 م)';

  static const List<String> _shifts = [
    'صباحية (08:00 ص - 04:00 م)',
    'مسائية (04:00 م - 12:00 ص)',
    'دوام كامل ممتد (12 ساعة)',
  ];

  @override
  void initState() {
    super.initState();
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
        color: AppTheme.withAlphaFactor(AppTheme.frostedCharcoalSlate, 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cyberBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.electricCyan),
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
                    color: AppTheme.crispAlabaster,
                  ),
                ),
                Text(
                  '${rate.toStringAsFixed(0)} ر.س / شهرياً',
                  style: const TextStyle(fontSize: 11, color: AppTheme.mutedSilver),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                size: 20, color: AppTheme.mutedSilver),
            onPressed: count > 0 ? () => onChanged(count - 1) : null,
          ),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.crispAlabaster,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline,
                size: 20, color: AppTheme.electricCyan),
            onPressed: () => onChanged(count + 1),
          ),
        ],
      ),
    );
  }

  String _buildQuoteText() {
    return WhatsAppService.generateItemizedQuotationPitch(
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
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.obsidianVoid,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.cyberBorder),
      ),
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
                          color: AppTheme.crispAlabaster,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppTheme.mutedSilver),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                'Instant pricing proposal for ${widget.lead.companyName} (${widget.lead.hub})',
                style: const TextStyle(fontSize: 12, color: AppTheme.mutedSilver),
              ),
              const SizedBox(height: 14),

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

              const Text(
                'Shift / Working Hours',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.crispAlabaster,
                ),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _selectedShift,
                isExpanded: true,
                dropdownColor: AppTheme.frostedCharcoalSlate,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.cyberBorder),
                  ),
                ),
                items: _shifts
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.crispAlabaster,
                            ),
                          ),
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
                  color: AppTheme.withAlphaFactor(AppTheme.frostedCharcoalSlate, 0.9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cyberBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal (قبل الضريبة):',
                            style: TextStyle(fontSize: 12, color: AppTheme.mutedSilver)),
                        Text('${_subtotal.toStringAsFixed(0)} SAR',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.crispAlabaster)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('VAT (ضريبة 15%):',
                            style: TextStyle(fontSize: 12, color: AppTheme.mutedSilver)),
                        Text('${_vat.toStringAsFixed(0)} SAR',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.crispAlabaster)),
                      ],
                    ),
                    const Divider(height: 12, color: AppTheme.cyberBorder),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Monthly (الإجمالي):',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.mintEmerald,
                          ),
                        ),
                        Text(
                          '${_total.toStringAsFixed(0)} SAR',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.mintEmerald,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Dual Dispatch Buttons: WhatsApp & RFC Email
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.mintEmerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _total > 0
                          ? () async {
                              final quote = _buildQuoteText();
                              Navigator.pop(context);
                              await Clipboard.setData(ClipboardData(text: quote));
                              await DispatchService.launchWhatsApp(
                                phone: widget.lead.saudiMobile,
                                message: quote,
                              );
                            }
                          : null,
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text(
                        'WhatsApp Quote',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.royalIris,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _total > 0
                          ? () async {
                              final quote = _buildQuoteText();
                              Navigator.pop(context);
                              await DispatchService.launchEmail(
                                email: widget.lead.email,
                                subject: 'Official Quote: ${widget.lead.companyName} Hospitality',
                                body: quote,
                              );
                            }
                          : null,
                      icon: const Icon(Icons.email_outlined, size: 16),
                      label: const Text(
                        'RFC Email Quote',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
