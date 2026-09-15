import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// Unicode BiDi isolation to ensure clean visual rendering of mixed Arabic/English pitch copy.
  /// \u202B: Right-to-Left Embedding (RLE)
  /// \u202A: Left-to-Right Embedding (LRE)
  /// \u202C: Pop Directional Formatting (PDF)
  /// \u200E: Left-to-Right Mark (LRM)
  /// \u200F: Right-to-Left Mark (RLM)
  static String isolateBiDi(String text, {bool isArabicDominant = true}) {
    if (isArabicDominant) {
      // Isolate any embedded English tokens (e.g., 'KAFD', 'Tea Boy', 'B2B CRM') with LRE/PDF
      final englishSegmentRegex = RegExp(r'([A-Za-z0-9\+\-\:\/\.\s]{2,})');
      final isolated = text.replaceAllMapped(englishSegmentRegex, (match) {
        return '\u202A${match[1]}\u202C\u200F';
      });
      return '\u202B$isolated\u202C';
    } else {
      // English dominant with Arabic isolation
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

    // Primary Native Scheme: whatsapp://send?phone=...&text=...
    final nativeUri = Uri(
      scheme: 'whatsapp',
      host: 'send',
      queryParameters: {
        'phone': sanitizedPhone,
        'text': message,
      },
    );

    // Fallback Web Scheme: https://wa.me/9665xxxxxxxx?text=...
    final webUri = Uri.parse(
      'https://wa.me/$sanitizedPhone?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Proceed to fallback
    }

    try {
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Fail gracefully
    }

    return false;
  }

  /// 1-tap "Copy Script & Launch WhatsApp" action with haptic feedback & confirmation SnackBar
  static Future<void> copyScriptAndDispatch({
    required BuildContext context,
    required String phone,
    required String message,
    required String companyName,
  }) async {
    // 1. Haptic feedback
    await HapticFeedback.lightImpact();

    // 2. Copy script to clipboard
    await Clipboard.setData(ClipboardData(text: message));

    // 3. Launch WhatsApp
    final launched = await launchWhatsApp(phone: phone, message: message);

    // 4. SnackBar confirmation
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF006C4F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
