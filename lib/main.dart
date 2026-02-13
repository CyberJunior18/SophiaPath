import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'firebase_options.dart';
import 'models/data.dart';
import 'navigation_screen.dart';
import 'screens/register_screen.dart';
import 'services/course/scores_repo.dart';
import 'services/course/user_stats_service.dart';
import 'services/profile_state.dart';
import 'services/user_preferences_services.dart';
import 'widgets/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Run these in background to not block UI
  Future.microtask(() async {
    try {
      await ScoresRepository.initializeScores(coursesInfo.length, 10);
    } catch (e) {
      print('Scores init error: $e');
    }
  });

  Future.microtask(() async {
    try {
      final statsService = UserStatsService();
      await statsService.updateLoginStreak();
    } catch (e) {
      print('Stats update error: $e');
    }
  });

  // Database initialization
  try {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  } catch (e) {
    print('Database init error: $e');
  }

  // Firebase initialization with timeout
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.web,
      ).timeout(const Duration(seconds: 5));
      print('✅ Firebase Web initialized');
    } else if (!Platform.isLinux && !Platform.isWindows) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 5));
      print('✅ Firebase Mobile initialized');
    }
  } catch (e) {
    print('⚠️ Firebase init error (continuing anyway): $e');
  }

  // SharedPreferences
  try {
    await SharedPreferences.getInstance();
    print('✅ SharedPreferences initialized');
  } catch (e) {
    print('SharedPreferences error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ProfileState()),
        // ✅ Remove the broken provider
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  final UserPreferencesService _userService = UserPreferencesService.instance;
  bool _isChecking = true;
  bool _hasUser = false;
  bool _isFirstLaunch = true;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
    _loadThemePreference();
  }

  Future<void> _checkUserStatus() async {
    _hasUser = await _userService.hasUser();
    _isFirstLaunch = await _userService.isFirstLaunch();

    setState(() => _isChecking = false);
  }

  Future<void> _loadThemePreference() async {
    final isDarkMode = await _userService.getThemePreference();
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void toggleTheme() async {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });

    await _userService.saveThemePreference(_themeMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr, // Add this
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeMode,
        home: _buildHomeScreen(),
      ),
    );
  }

  Widget _buildHomeScreen() {
    if (_isChecking) {
      return const SplashScreen();
    }

    // For new users or first launch
    if (!_hasUser || _isFirstLaunch) {
      return MyAuthScreen(onToggleTheme: toggleTheme, isEditing: false);
    }

    return NavigationScreen(onToggleTheme: toggleTheme);
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Directionality(
        // Also wrap SplashScreen with Directionality
        textDirection: TextDirection.ltr,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 20),
              Text(
                'Learning App',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
