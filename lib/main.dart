import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Importación de páginas
import 'pages/splash_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/map_page.dart';
import 'pages/report_page.dart';               // Para crear reporte
import 'pages/zone_ranking_page.dart';         // Ranking de zonas

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const EcoMapApp());
}

class EcoMapApp extends StatelessWidget {
  const EcoMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoMap',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        brightness: Brightness.light,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashPage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/settings': (context) => const SettingsPage(),
        '/map': (context) => const MapPage(),
        '/crear_reporte': (context) => const ReportPage(),   // nuevo reporte
        '/ranking_zonas': (context) => const ZoneRankingPage(), // ranking de zonas
      },
    );
  }
}