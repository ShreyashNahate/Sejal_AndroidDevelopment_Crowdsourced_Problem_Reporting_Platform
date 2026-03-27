import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'constants/app_colors.dart';
import 'services/auth_service.dart';
import 'services/issue_service.dart';
import 'services/user_service.dart';
import 'screens/home/home_screen.dart';
import 'screens/report/report_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/chatbot/chatbot_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/admin/admin_screen.dart';
import 'screens/emergency/emergency_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  runApp(const SmartCityApp());
}

class SmartCityApp extends StatelessWidget {
  const SmartCityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth service - handles dummy user session
        ChangeNotifierProvider(create: (_) => AuthService()),
        // Issue service - handles CRUD for civic issues
        ChangeNotifierProvider(create: (_) => IssueService()),
        // User service - handles trust scores & profiles
        ChangeNotifierProvider(create: (_) => UserService()),
      ],
      child: MaterialApp(
        title: 'SmartCity',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.poppinsTextTheme(),
          useMaterial3: true,
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
          cardTheme: CardThemeData(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // Named routes for navigation
        initialRoute: '/home',
        routes: {
          '/home': (ctx) => const HomeScreen(),
          '/report': (ctx) => const ReportScreen(),
          '/map': (ctx) => const MapScreen(),
          '/chatbot': (ctx) => const ChatbotScreen(),
          '/leaderboard': (ctx) => const LeaderboardScreen(),
          '/admin': (ctx) => const AdminScreen(),
          '/emergency': (ctx) => const EmergencyScreen(),
        },
      ),
    );
  }
}
