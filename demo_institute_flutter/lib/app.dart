import 'package:flutter/material.dart';

import 'routes.dart';
import 'screens/about_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/contact_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/student_screen.dart';
import 'theme/app_theme.dart';

class DemoInstituteApp extends StatelessWidget {
  const DemoInstituteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DEMO INSTITUTE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.about: (_) => const AboutScreen(),
        AppRoutes.contact: (_) => const ContactScreen(),
        AppRoutes.studentDashboard: (_) => const StudentScreen(),
        AppRoutes.adminDashboard: (_) => const AdminScreen(),
      },
    );
  }
}
