import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sophia_path/models/data.dart';
import 'package:sophia_path/screens/profile_screen.dart';
import 'package:sophia_path/models/course_info.dart';
import 'package:sophia_path/widgets/screen_app_bar.dart';
import 'package:sophia_path/screens/settings_screen.dart';
import 'package:sophia_path/widgets/tobeimplementedAlert.dart';
import 'models/user.dart';
import 'screens/course_info_screen.dart';
import 'screens/learning_screen.dart';
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
  final List<CourseInfo> courses = coursesInfo;
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
                  color: theme.textTheme.bodyLarge!.color!,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.book,
                color: theme.textTheme.bodyLarge!.color!,
              ),
              title: Text(
                'Courses',
                style: GoogleFonts.poppins(
                  color: theme.textTheme.bodyLarge!.color!,
                ),
              ),
              trailing: Icon(
                coursesExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: theme.textTheme.bodyLarge!.color!,
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
                      color: theme.textTheme.bodyLarge!.color!,
                    ),
                    title: Text(
                      course.title,
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.bodyLarge!.color!,
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
              return ListTile(
                leading: Icon(
                  Icons.chat,
                  color: theme.textTheme.bodyLarge!.color!,
                ),
                title: Text(
                  item,
                  style: GoogleFonts.poppins(
                    color: theme.textTheme.bodyLarge!.color!,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (ctx) {
                      return toBeImplemented(context);
                    },
                  );
                },
              );
            }),
            const Spacer(),
            ListTile(
              leading: Icon(
                Icons.settings,
                color: theme.textTheme.bodyLarge!.color!,
              ),
              title: Text(
                'Settings',
                style: GoogleFonts.poppins(
                  color: theme.textTheme.bodyLarge!.color!,
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

  Future<void> _loadUserData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      currentUser = await _userService.getUser();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: screenAppBar(context, _selectedIndex, widget.onToggleTheme),
      drawer: _selectedIndex == 0 ? _buildDrawer() : null,
      body: currentScreen,
      bottomNavigationBar: CurvedNavigationBar(
        index: _selectedIndex,
        height: 65,
        backgroundColor: Colors.transparent,
        color: const Color(0xFF161632),
        buttonBackgroundColor: const Color(0xFF18193C),
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
                  color: _selectedIndex == 0 ? Colors.white : Colors.white70,
                  size: 24,
                ),
                Text(
                  'Learning',
                  style: TextStyle(
                    color: _selectedIndex == 0 ? Colors.white : Colors.white70,
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
                  color: _selectedIndex == 1 ? Colors.white : Colors.white70,
                  size: 24,
                ),
                Text(
                  'Profile',
                  style: TextStyle(
                    color: _selectedIndex == 1 ? Colors.white : Colors.white70,
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
