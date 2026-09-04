import 'package:flutter/material.dart';
import 'core/data/hive_database.dart';
import 'core/supabase/supabase_config.dart';
import 'features/dashboard/presentation/pages/maison_dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveDatabase.init();
  try {
    await SupabaseConfig.initialize();
  } catch (_) {}
  runApp(const MaisonAlTeebApp());
}

class MaisonAlTeebApp extends StatelessWidget {
  const MaisonAlTeebApp({super.key});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    const black = Color(0xFF0B0B0B);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MAISON AL TEEB POS',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: black,
        colorScheme: ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.dark),
        appBarTheme: const AppBarTheme(backgroundColor: black, foregroundColor: gold),
        cardTheme: const CardThemeData(
          color: Color(0xFF151515),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
      ),
      home: const MaisonDashboardPage(),
    );
  }
}
