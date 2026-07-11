import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sophia_path/screens/authentication/login.dart';
import 'package:sophia_path/screens/authentication/register.dart';
import 'navigation_screen.dart';
// import 'screens/register_screen.dart';
import 'services/course/user_stats_service.dart';
import 'services/profile_state.dart';
import 'services/user_preferences_services.dart';
import 'screens/authentication/authService.dart';
import 'services/settings_provider.dart';
import 'widgets/sophia_path_loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Future.microtask(() async {
  //   try {
  //     await ScoresRepository.initializeScores(coursesInfo.length, 10);
  //   } catch (e) {
  //     print('Scores init error: $e');
  //   }
  // });

  Future.microtask(() async {
    try {
      final statsService = UserStatsService();

      await statsService.updateLoginStreak();
    } catch (e) {
      print('Stats update error: $e');
    }
  });

  // Database initialization
  // try {
  //   print('🔄 Initializing database factory...');
  //   if (kIsWeb) {
  //     print(
  //       '⚠️  Running on Web - sqflite not supported. Using in-memory storage.',
  //     );
  //     // Web doesn't support sqflite - skip initialization
  //   } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
  //     sqfliteFfiInit();
  //     databaseFactory = databaseFactoryFfi;
  //     print('✅ Database: Desktop FFI initialized');
  //   } else {
  //     print('✅ Database: Using default SQLite (Mobile)');
  //   }
  // } catch (e) {
  //   print('❌ Database init error: $e');
  // }

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
        ChangeNotifierProvider(create: (context) => SettingsProvider()),
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
  final UserPreferencesService _userService = UserPreferencesService.instance;
  bool _isChecking = true;
  bool _hasUser = false;
  bool _isFirstLaunch = true;
  bool _hasToken = false;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    _hasUser = await _userService.hasUser();
    _isFirstLaunch = await _userService.isFirstLaunch();
    _hasToken = (await AuthStorage.getToken()) != null;

    setState(() => _isChecking = false);
  }

  void toggleTheme() async {
    if (!mounted) return;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final newPreset = settings.themePreset == 'light' ? 'dark' : 'light';
    await settings.setThemePreset(newPreset);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: settings.themeData,
        home: _buildHomeScreen(),
      ),
    );
  }

  Widget _buildHomeScreen() {
    if (_isChecking) {
      return const SplashScreen();
    }

    // For new users or first launch
    if (_isFirstLaunch || !_hasUser) {
      return RegisterScreen(onToggleTheme: toggleTheme);
    }

    if (!_hasToken) {
      return LoginScreen(onToggleTheme: toggleTheme);
    }

    return NavigationScreen(onToggleTheme: toggleTheme);
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SophiaPathLoadingScreen();
  }
}

