import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sophia_path/navigation_screen.dart';
import 'package:sophia_path/screens/chat/chat_screen.dart';
import 'package:sophia_path/screens/chat/chats_list_screen.dart';
import 'package:sophia_path/services/profile_state.dart';
import 'package:sophia_path/services/course/user_stats_service.dart';
import 'package:sophia_path/widgets/theme.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'firebase_options.dart';
import 'models/data.dart';
import 'screens/authentication/myauthscreen.dart';
import 'screens/register_screen.dart';
import 'services/course/scores_repo.dart';
import 'services/user_preferences_services.dart';
import 'package:sophia_path/services/chat/chat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await ScoresRepository.initializeScores(coursesInfo.length, 10);
  });

  final statsService = UserStatsService();
  await statsService.updateLoginStreak();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Initialize SharedPreferences for chat
  await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ProfileState()),
        Provider(create: (context) => ChatService()),
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: _buildHomeScreen(),
      routes: {
        '/home': (context) => NavigationScreen(onToggleTheme: toggleTheme),
        '/chats': (context) => const ChatsListScreen(),
        '/chat': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return ChatScreen(
            chatUser: args['user'],
            chatId: args['chatId'], // Now this will work
          );
        },
      },
    );
  }

  Widget _buildHomeScreen() {
    if (_isChecking) {
      return const SplashScreen();
    }

    if (!_hasUser || _isFirstLaunch) {
      return UserProfileScreen(isEditing: false, onToggleTheme: toggleTheme);
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 80, color: Theme.of(context).primaryColor),
            const SizedBox(height: 20),
            Text(
              'Learning App',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
