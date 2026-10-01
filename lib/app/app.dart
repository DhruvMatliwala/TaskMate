import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../providers/location_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/notification_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/task_detail_screen.dart';
import '../screens/tasks/my_tasks_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/chat/inbox_screen.dart';
import '../models/task_model.dart';

class TaskMateApp extends StatelessWidget {
  const TaskMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'TaskMate',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        initialRoute: '/',
        onGenerateRoute: _generateRoute,
      ),
    );
  }

  // ── Theme ─────────────────────────────────────────────────────────────────

  ThemeData _buildTheme() {
    final base = ThemeData.dark();

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F0F1A),
      primaryColor: const Color(0xFF6C63FF),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6C63FF),
        secondary: Color(0xFFFF6584),
        surface: Color(0xFF1A1A2E),
        error: Color(0xFFFF6584),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
        bodyLarge: GoogleFonts.poppins(color: Colors.white),
        bodyMedium: GoogleFonts.poppins(color: const Color(0xFFE0E0E0)),
        bodySmall: GoogleFonts.poppins(color: const Color(0xFF9E9E9E)),
        titleLarge: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0F0F1A),
        selectedItemColor: Color(0xFF6C63FF),
        unselectedItemColor: Color(0xFF4A4A6A),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: Color(0xFF6C63FF),
        labelColor: Color(0xFF6C63FF),
        unselectedLabelColor: Color(0xFF4A4A6A),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1A2E),
        contentTextStyle: GoogleFonts.poppins(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2D2D4E)),
        ),
        hintStyle: const TextStyle(color: Color(0xFF3A3A5A)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 8,
      ),
      dividerColor: const Color(0xFF2D2D4E),
    );
  }

  // ── Routing ───────────────────────────────────────────────────────────────

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return _slide(const SplashScreen());
      case '/login':
        return _slide(const LoginScreen());
      case '/register':
        return _slide(const RegisterScreen());
      case '/home':
        return _slide(const HomeScreen());
      case '/my-tasks':
        return _slide(const MyTasksScreen());
      case '/profile':
        return _slide(const ProfileScreen());
      case '/inbox':
        return _slide(const InboxScreen());
      case '/task-detail':
        final task = settings.arguments as TaskModel;
        return _slide(TaskDetailScreen(task: task));
      default:
        return _slide(const SplashScreen());
    }
  }

  PageRouteBuilder<T> _slide<T>(Widget page) {
    return PageRouteBuilder<T>(
      settings: RouteSettings(name: page.runtimeType.toString()),
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
