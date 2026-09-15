import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum PitchAngle {
  vipHospitality,
  pantryLogistics,
  nightCleaning,
  freeTrial,
  formalQuotation,
}

class WhatsAppService {
  static final WhatsAppService instance = WhatsAppService._internal();
  WhatsAppService._internal();

  /// Clean incoming phone numbers via regex to strictly enforce 9665xxxxxxxx format
  static String sanitizeSaudiMobile(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');

    if (cleaned.startsWith('00966')) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.startsWith('05')) {
      cleaned = '966' + cleaned.substring(1);
    } else if (cleaned.startsWith('5') && cleaned.length == 9) {
      cleaned = '966' + cleaned;
    } else if (!cleaned.startsWith('966') && cleaned.length == 9) {
      cleaned = '966' + cleaned;
    }
    return cleaned;
  }

  /// Format phone for visual display (e.g., +966 5X XXX XXXX)
  static String formatForDisplay(String phone) {
    final sanitized = sanitizeSaudiMobile(phone);
    if (sanitized.length == 12 && sanitized.startsWith('9665')) {
      return '+966 ${sanitized.substring(3, 5)} ${sanitized.substring(5, 8)} ${sanitized.substring(8)}';
    }
    return phone;
  }

  /// Direct phone dialer invocation
  static Future<bool> launchPhoneCall(String phone) async {
    final sanitized = sanitizeSaudiMobile(phone);
    final uri = Uri.parse('tel:+$sanitized');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (_) {}
    return false;
  }

  /// Launch Google Maps navigation to the specific Riyadh business hub
  static Future<bool> launchMaps(String hub) async {
    final Map<String, String> hubQueries = {
      'KAFD': 'King Abdullah Financial District Riyadh',
      'Al Olaya': 'Al Olaya Riyadh Saudi Arabia',
      'King Fahd Rd': 'King Fahd Road Riyadh',
      'Al Malqa': 'Al Malqa Riyadh',
      'Digital City': 'Digital City Riyadh',
      'Business Gate': 'Business Gate Airport Road Riyadh',
    };

    final query = hubQueries[hub] ?? '$hub Riyadh Saudi Arabia';
    final mapUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');

    try {
      if (await canLaunchUrl(mapUri)) {
        return await launchUrl(mapUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  /// Unicode BiDi isolation to ensure clean visual rendering of mixed Arabic/English pitch copy.
  static String isolateBiDi(String text, {bool isArabicDominant = true}) {
    if (isArabicDominant) {
      final englishSegmentRegex = RegExp(r'([A-Za-z0-9\+\-\:\/\.\s]{2,})');
      final isolated = text.replaceAllMapped(englishSegmentRegex, (match) {
        return '\u202A${match[1]}\u202C\u200F';
      });
      return '\u202B$isolated\u202C';
    } else {
      final arabicSegmentRegex = RegExp(r'([\u0600-\u06FF\s]+)');
      final isolated = text.replaceAllMapped(arabicSegmentRegex, (match) {
        return '\u202B${match[1]}\u202C\u200E';
      });
      return '\u202A$isolated\u202C';
    }
  }

  /// Launch WhatsApp with native URI scheme, falling back seamlessly to wa.me HTTPS
  static Future<bool> launchWhatsApp({
    required String phone,
    required String message,
  }) async {
    final sanitizedPhone = sanitizeSaudiMobile(phone);

    final nativeUri = Uri(
      scheme: 'whatsapp',
      host: 'send',
      queryParameters: {
        'phone': sanitizedPhone,
        'text': message,
      },
    );

    final webUri = Uri.parse(
      'https://wa.me/$sanitizedPhone?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    return false;
  }

  /// 1-tap "Copy Script & Launch WhatsApp" action with haptic feedback & confirmation SnackBar
  static Future<void> copyScriptAndDispatch({
    required BuildContext context,
    required String phone,
    required String message,
    required String companyName,
  }) async {
    await HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: message));
    final launched = await launchWhatsApp(phone: phone, message: message);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF006C4F),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  launched
                      ? 'Script copied & WhatsApp opened for $companyName'
                      : 'Script copied to clipboard (WhatsApp unavailable)',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Generate tailored B2B pitches based on specific sales angles
  static String generateAngledPitch({
    required PitchAngle angle,
    required String companyName,
    required String contactPerson,
    required String hub,
    required List<String> staffing,
  }) {
    final greeting =
        contactPerson.isNotEmpty ? contactPerson : 'سعادة المدير / المسئول';
    final staffStr = staffing.join(' و ');

    String text;
    switch (angle) {
      case PitchAngle.vipHospitality:
        text = '''
السلام عليكم ورحمة الله وبركاته،
الأستاذ/ $greeting المحترم ($companyName - $hub)،

يسرنا في مؤسسة TEA BOY للضيافة المعتمدة تقديم خدمات الضيافة المكتبية التنفيذية (VIP Tea Boys):
☕ إتقان كامل لبروتوكولات الضيافة السعودية وتقديم القهوة والشاي للوفود واجتماعات مجالس الإدارة.
👔 زي رسمي أنيق موحد مع شهادات صحية معتمدة ومظهر احترافي يليق بمقركم في $hub.
🗣️ إتقان اللغتين العربية والإنجليزية لخدمة بيئات العمل متعددة الجنسيات.

يسعدنا ترتيب زيارة تعريفية وتقديم عرض تجريبي مجاني لمكاتبكم. هل يناسبكم التنسيق هذا الأسبوع؟
''';
        break;

      case PitchAngle.pantryLogistics:
        text = '''
السلام عليكم ورحمة الله وبركاته،
الأستاذ/ $greeting المحترم ($companyName - $hub)،

نقدم لشركتكم حلول إدارة البوفيهات والمطابخ المكتبية (Pantry Staff Solutions):
🍽️ إدارة بوفيهات المكاتب والمشتريات وتجهيز المشروبات الساخنة طوال ساعات العمل.
📋 مراقبة المخزون اليومي (شاي، قهوة، لوازم ضيافة) ومنع الهدر.
🔄 فريق بديل فوري معتمد عند أي إجازة أو طارئ لضمان عدم توقف الخدمة دقيقة واحدة.

جاهزون لتزويدكم بفريق ضيافة متفرغ لمقركم في $hub فوراً. هل نرسل لكم الكتالوج المعتمد؟
''';
        break;

      case PitchAngle.nightCleaning:
        text = '''
السلام عليكم ورحمة الله وبركاته،
الأستاذ/ $greeting المحترم ($companyName - $hub)،

نقدم لمقركم في $hub خدمات النظافة المكتبية التخصصية والعقود المؤسسية:
✨ عمالة نظافة مكتبية مدربة بأعلى معايير التعقيم والمواد المعتمدة.
🌙 مرونة كاملة في الورديات (صباحية، مسائية، أو تنظيف ليلي شامل بعد انصراف الموظفين).
📑 عقود سنوية وشهرية رسمية تخضع لاشتراطات منصة قوى والعمل في المملكة.

نسعد بخدمتكم وتوفير الكوادر المطلوبة ($staffStr). هل يمكننا تقديم تسعيرة مخصصة لمكتبكم؟
''';
        break;

      case PitchAngle.freeTrial:
        text = '''
السلام عليكم ورحمة الله وبركاته،
الأستاذ/ $greeting المحترم في ($companyName - $hub)،

عرض استثنائي لمكاتب $hub:
🎁 نوفر لكم كادر ضيافة / نظافة ($staffStr) بنظام "فترة تجربة مجانية لمدة 3 أيام" بدون أي التزام تعاقدي مسبق، لتلمسوا بأنفسكم جودة التدريب والالتزام.
✅ بديل فوري خلال ساعتين في حال الرغبة بالاستبدال.
✅ إشراف إداري وميداني مباشر.

هل ترغبون ببدء التجربة اعتباراً من يوم الأحد القادم؟
''';
        break;

      case PitchAngle.formalQuotation:
        text = generatePitchTemplate(
          companyName: companyName,
          contactPerson: contactPerson,
          hub: hub,
          staffing: staffing,
        );
        break;
    }

    return isolateBiDi(text);
  }

  /// Generate Formal SAR Price Quotation with 15% VAT
  static String generateItemizedQuotationPitch({
    required String companyName,
    required String contactPerson,
    required String hub,
    required int teaBoyCount,
    required int pantryCount,
    required int cleanerCount,
    required double teaBoyRate,
    required double pantryRate,
    required double cleanerRate,
    required String shiftType,
  }) {
    final double subtotal = (teaBoyCount * teaBoyRate) +
        (pantryCount * pantryRate) +
        (cleanerCount * cleanerRate);
    final double vat = subtotal * 0.15;
    final double total = subtotal + vat;

    final String raw = '''
عرض سعر خدمات الدعم والضيافة المكتبية
السادة: $companyName المحترمون
الموقع: $hub - الرياض
عناية: ${contactPerson.isNotEmpty ? contactPerson : 'الإدارة العامة'}

يسعدنا تقديم التسعيرة الرسمية الشهرية لتزويد الكوادر البشرية:
━━━━━━━━━━━━━━━━━━━━
${teaBoyCount > 0 ? '• مقدم ضيافة (Tea Boy): $teaBoyCount كادر × ${teaBoyRate.toStringAsFixed(0)} ر.س = ${(teaBoyCount * teaBoyRate).toStringAsFixed(0)} ر.س\n' : ''}${pantryCount > 0 ? '• مشرف بوفيه (Pantry Staff): $pantryCount كادر × ${pantryRate.toStringAsFixed(0)} ر.س = ${(pantryCount * pantryRate).toStringAsFixed(0)} ر.س\n' : ''}${cleanerCount > 0 ? '• عامل نظافة مكتبية: $cleanerCount كادر × ${cleanerRate.toStringAsFixed(0)} ر.س = ${(cleanerCount * cleanerRate).toStringAsFixed(0)} ر.س\n' : ''}
نظام الوردية: $shiftType
المجموع قبل الضريبة: ${subtotal.toStringAsFixed(0)} ر.س
ضريبة القيمة المضافة (15%): ${vat.toStringAsFixed(0)} ر.س
الإجمالي الشهري الشامل (SAR): ${total.toStringAsFixed(0)} ر.س
━━━━━━━━━━━━━━━━━━━━
المميزات المشمولة:
1. تأمين صحي معتمد وإقامات نظامية سارية.
2. زي رسمي موحد (Uniform) مع شارات الاسم.
3. بديل فوري معتمد عند أي غياب أو إجازة.
4. إشراف ميداني أسبوعي من إدارة العمليات.

صلاحية العرض: 15 يوماً من تاريخه.
فريق المبيعات والتعاقدات المؤسسية - الرياض
''';

    return isolateBiDi(raw);
  }

  /// Standard enterprise staffing pitch templates for corporate Riyadh offices
  static String generatePitchTemplate({
    required String companyName,
    required String contactPerson,
    required String hub,
    required List<String> staffing,
  }) {
    final greetingName =
        contactPerson.isNotEmpty ? contactPerson : 'سعادة المدير / المسئول';
    final staffingList = staffing.join(' و ');

    final rawCopy = '''
السلام عليكم ورحمة الله وبركاته،
الأستاذ/ $greetingName المحترم ($companyName - $hub)،

نقدم لشركتكم الموقرة خدمات الضيافة والنظافة المكتبية الفاخرة للشركات:
• تزويد كوادر مدربة ومتفرغة ($staffingList).
• التزام تام بالزي الرسمي، النظافة، وإتقان بروتوكولات الضيافة السعودية.
• عقود مرنة معتمدة وفق اشتراطات العمل في المملكة، مع بديل فوري عند الإجازات.

يسعدنا تقديم عرض تجريبي مجاني لمكتبكم في $hub. هل يناسبكم التواصل لتحديد موعد زيارة؟

مع أطيب التحيات،
فريق خدمات الدعم المكتبي والضيافة - الرياض
''';

    return isolateBiDi(rawCopy);
  }
}
