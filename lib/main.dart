import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/dashboard_screen.dart';
import 'services/gemini_service.dart';
import 'services/hive_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Harden system UI overlay style for Saudi corporate emerald aesthetic
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize offline Hive storage singleton & seed corporate database
  await HiveService.instance.init();

  // Load user Gemini API key if previously configured
  GeminiService.customApiKey = HiveService.instance.getApiKey();

  runApp(const TeaBoyCrmApp());
}

class TeaBoyCrmApp extends StatelessWidget {
  const TeaBoyCrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TEA BOY B2B CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const DashboardScreen(),
    );
  }
}
