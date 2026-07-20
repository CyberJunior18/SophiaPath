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
import 'screens/home_screen.dart';
import 'screens/authentication/authService.dart';
import 'package:sophia_path/widgets/background_animation_widget.dart';
import 'services/user_preferences_services.dart';
import 'package:provider/provider.dart';
import 'package:sophia_path/services/profile_state.dart';
import 'package:sophia_path/screens/authentication/login.dart';

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
  late Widget currentScreen = const SizedBox();
  
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
    _loadInitialData().then((_) {
      if (mounted) {
        setState(() {
          switchScreen();
        });
      }
    });
  }

  void switchScreen() {
    final isGuest = currentUser == null;
    if (isGuest) {
      currentScreen = CoursesScreen();
    } else {
      if (_selectedIndex == 0) {
        currentScreen = HomeScreen();
      } else if (_selectedIndex == 1) {
        currentScreen = CoursesScreen();
      } else {
        currentScreen = ProfileScreen(key: UniqueKey(), onToggleTheme: widget.onToggleTheme);
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _loadUserData();
        });
      }
    }
  }

  List<String> menuItems = ["Chats", "Groups", "Communities"];

  Drawer _buildDrawer() {
    final theme = Theme.of(context);
    final textColor =
        theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;
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
              leading: Icon(Icons.book, color: textColor),
              title: Text(
                'Courses',
                style: GoogleFonts.poppins(color: textColor),
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
                    leading: Icon(Icons.circle, size: 10, color: textColor),
                    title: Text(
                      course.title,
                      style: GoogleFonts.poppins(color: textColor),
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
                leading: Icon(iconData, color: textColor),
                title: Text(item, style: GoogleFonts.poppins(color: textColor)),
                onTap: () async {
                  Navigator.pop(context);
                  final token = await AuthStorage.getToken();
                  if (token == null) {
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Login Required', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        content: Text(
                          'Please log in to access $item.',
                          style: GoogleFonts.poppins(),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LoginScreen(onToggleTheme: widget.onToggleTheme),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text('Log In', style: GoogleFonts.poppins()),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  Widget screen;
                  if (item == 'Groups') {
                    screen = const GroupsListScreen();
                  } else if (item == 'Communities') {
                    screen = const CommunitiesListScreen();
                  } else {
                    screen = const ChatsListScreen();
                  }
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => screen),
                    );
                  }
                },
              );
            }),
            const Spacer(),
            ListTile(
              leading: Icon(Icons.settings, color: textColor),
              title: Text(
                'Settings',
                style: GoogleFonts.poppins(color: textColor),
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
            const Divider(),
            if (currentUser != null)
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: Text(
                  'Log out',
                  style: GoogleFonts.poppins(color: Colors.redAccent),
                ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await UserPreferencesService.instance.clearAllData();
                  await AuthStorage.clearToken();
                  print('✅ Local data cleared');

                  if (context.mounted) {
                    Provider.of<ProfileState>(context, listen: false).refreshUser();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) {
                          return LoginScreen(onToggleTheme: widget.onToggleTheme);
                        },
                      ),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  print('❌ Error during logout: $e');

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Logout failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
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
    final bool isDarkNav =
        ThemeData.estimateBrightnessForColor(theme.cardColor) ==
        Brightness.dark;

    return Scaffold(
      appBar: screenAppBar(context, _selectedIndex, widget.onToggleTheme),
      drawer: (_selectedIndex == 0 || _selectedIndex == 1) ? _buildDrawer() : null,
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
          if (currentUser != null)
            Container(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.home,
                    color: _selectedIndex == 0
                        ? (ThemeData.estimateBrightnessForColor(
                                    theme.primaryColor,
                                  ) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black)
                        : (isDarkNav
                              ? Colors.white70
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                )),
                    size: 24,
                  ),
                  Text(
                    'Home',
                    style: TextStyle(
                      color: _selectedIndex == 0
                          ? (ThemeData.estimateBrightnessForColor(
                                      theme.primaryColor,
                                    ) ==
                                    Brightness.dark
                                ? Colors.white
                                : Colors.black)
                          : (isDarkNav
                                ? Colors.white70
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  )),
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
                  Icons.school,
                  color: _selectedIndex == 1
                      ? (ThemeData.estimateBrightnessForColor(
                                  theme.primaryColor,
                                ) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black)
                      : (isDarkNav
                            ? Colors.white70
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              )),
                  size: 24,
                ),
                Text(
                  'Courses',
                  style: TextStyle(
                    color: _selectedIndex == 1
                        ? (ThemeData.estimateBrightnessForColor(
                                    theme.primaryColor,
                                  ) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black)
                        : (isDarkNav
                              ? Colors.white70
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                )),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (currentUser != null)
            Container(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person,
                    color: _selectedIndex == 2
                        ? (ThemeData.estimateBrightnessForColor(
                                    theme.primaryColor,
                                  ) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black)
                        : (isDarkNav
                              ? Colors.white70
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                )),
                    size: 24,
                  ),
                  Text(
                    'Profile',
                    style: TextStyle(
                      color: _selectedIndex == 2
                          ? (ThemeData.estimateBrightnessForColor(
                                      theme.primaryColor,
                                    ) ==
                                    Brightness.dark
                                ? Colors.white
                                : Colors.black)
                          : (isDarkNav
                                ? Colors.white70
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  )),
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

          final isGuest = currentUser == null;
          final profileIndex = isGuest ? 1 : 2;

          if (index == profileIndex) {
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
