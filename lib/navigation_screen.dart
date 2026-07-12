import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/chat/chats_list_screen.dart';
import 'screens/groups/groups_list_screen.dart';
import 'screens/communities/communities_list_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'models/course/course_info.dart';
import 'widgets/screen_app_bar.dart';
import 'screens/settings_screen.dart';
import 'models/user/user.dart';
import 'screens/course/course_info_screen.dart';
import 'screens/course/learning_screen.dart';
import 'screens/authentication/authService.dart';
import 'package:sophia_path/widgets/background_animation_widget.dart';
import 'services/user_preferences_services.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    super.key,
    required this.onToggleTheme,
    this.selectedIndex = 0,
  });
  final void Function() onToggleTheme;
  final int selectedIndex;
  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int _selectedIndex = 0;

  bool coursesExpanded = false;
  final AuthService _authService = AuthService();
  List<CourseInfo> courses = [];
  late List<CourseInfo> registeredCourses = [];
  late Widget currentScreen;

  @override
  void initState() {
    super.initState();
    setState(() {
      _selectedIndex = widget.selectedIndex;
      if (_selectedIndex == 0) {
        currentScreen = LearningScreen();
      } else {
        currentScreen = ProfileScreen(key: UniqueKey());
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _loadUserData();
          }
        });
      }
    });
    _loadInitialData();
    _loadUserData();
  }

  void switchScreen() {
    if (_selectedIndex == 0) {
      currentScreen = LearningScreen();
    } else {
      currentScreen = ProfileScreen(key: UniqueKey());
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _loadUserData();
        }
      });
    }
  }

  List<String> menuItems = ["Chats", "Groups", "Communities"];

  Drawer _buildDrawer() {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.8,
      backgroundColor: theme.drawerTheme.backgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Menu',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.book,
                color: textColor,
              ),
              title: Text(
                'Courses',
                style: GoogleFonts.poppins(
                  color: textColor,
                ),
              ),
              trailing: Icon(
                coursesExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: textColor,
              ),
              onTap: () {
                setState(() {
                  coursesExpanded = !coursesExpanded;
                });
              },
            ),
            if (coursesExpanded)
              ...courses.map(
                (course) => Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: ListTile(
                    leading: Icon(
                      Icons.circle,
                      size: 10,
                      color: textColor,
                    ),
                    title: Text(
                      course.title,
                      style: GoogleFonts.poppins(
                        color: textColor,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) {
                            return CourseInfoScreen(course: course);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ...menuItems.map((item) {
              IconData iconData = Icons.chat;
              if (item == 'Groups') iconData = Icons.group;
              if (item == 'Communities') iconData = Icons.forum;

              return ListTile(
                leading: Icon(
                  iconData,
                  color: textColor,
                ),
                title: Text(
                  item,
                  style: GoogleFonts.poppins(
                    color: textColor,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Widget screen;
                  if (item == 'Groups') {
                    screen = const GroupsListScreen();
                  } else if (item == 'Communities') {
                    screen = const CommunitiesListScreen();
                  } else {
                    screen = const ChatsListScreen();
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => screen,
                    ),
                  );
                },
              );
            }),
            const Spacer(),
            ListTile(
              leading: Icon(
                Icons.settings,
                color: textColor,
              ),
              title: Text(
                'Settings',
                style: GoogleFonts.poppins(
                  color: textColor,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SettingsScreen(onToggleTheme: widget.onToggleTheme),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  final UserPreferencesService _userService = UserPreferencesService.instance;
  User? currentUser;
  bool _isLoading = true;

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _userService.getUser(),
        _authService.getAllCourses(),
      ]);

      currentUser = results[0] as User?;
      courses = results[1] as List<CourseInfo>;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    try {
      currentUser = await _userService.getUser();
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final bool isDarkNav = ThemeData.estimateBrightnessForColor(theme.cardColor) == Brightness.dark;

    return Scaffold(
      appBar: screenAppBar(context, _selectedIndex, widget.onToggleTheme),
      drawer: _selectedIndex == 0 ? _buildDrawer() : null,
      body: BackgroundAnimationWidget(child: currentScreen),
      bottomNavigationBar: CurvedNavigationBar(
        index: _selectedIndex,
        height: 65,
        backgroundColor: Colors.transparent,
        color: theme.cardColor,
        buttonBackgroundColor: theme.primaryColor,
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 400),
        letIndexChange: (index) => true,
        items: [
          Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school,
                  color: _selectedIndex == 0
                      ? (ThemeData.estimateBrightnessForColor(theme.primaryColor) == Brightness.dark
                          ? Colors.white
                          : Colors.black)
                      : (isDarkNav ? Colors.white70 : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  size: 24,
                ),
                Text(
                  'Learning',
                  style: TextStyle(
                    color: _selectedIndex == 0
                        ? (ThemeData.estimateBrightnessForColor(theme.primaryColor) == Brightness.dark
                            ? Colors.white
                            : Colors.black)
                        : (isDarkNav ? Colors.white70 : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person,
                  color: _selectedIndex == 1
                      ? (ThemeData.estimateBrightnessForColor(theme.primaryColor) == Brightness.dark
                          ? Colors.white
                          : Colors.black)
                      : (isDarkNav ? Colors.white70 : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  size: 24,
                ),
                Text(
                  'Profile',
                  style: TextStyle(
                    color: _selectedIndex == 1
                        ? (ThemeData.estimateBrightnessForColor(theme.primaryColor) == Brightness.dark
                            ? Colors.white
                            : Colors.black)
                        : (isDarkNav ? Colors.white70 : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            switchScreen();
          });

          if (index == 1) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                _loadUserData();
              }
            });
          }
        },
      ),
    );
  }
}
