import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sophia_path/services/profile_state.dart';
import 'package:sophia_path/widgets/profileImage.dart';
import '../../models/data.dart';
import '../authentication/login.dart';
import 'achievements_screen.dart';
import '../../services/course/user_stats_service.dart';

import '../../models/user/achievements.dart';
import '../../models/user/user.dart';
import '../authentication/authService.dart';
import '../../services/user_preferences_services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/user/user_role.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onProfileUpdated;
  final VoidCallback? onToggleTheme;

  const ProfileScreen({super.key, this.onProfileUpdated, this.onToggleTheme});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final UserPreferencesService _userService = UserPreferencesService.instance;
  // final FirestoreCourseService _courseService = FirestoreCourseService();
  final UserStatsService _statsService = UserStatsService();
  User? _currentUser;
  int _registeredCoursesCount = 0;
  int _totalLessonsCompleted = 0;
  int _currentStreak = 0;
  bool _isLoading = true;
  List<Achievement> _achievements = [];
  bool _showAllAchievements = false;
  bool _isGuest = false;

  Map<String, bool> get achievementCompletionMap {
    return {for (var a in _achievements) a.name: a.isCompleted};
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final statsService = UserStatsService();
      await statsService.updateLoginStreak();
    });
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        if (mounted) {
          setState(() {
            _isGuest = true;
            _isLoading = false;
          });
        }
        return;
      }
      _isGuest = false;

      _currentUser = await _userService.getUser();
      if (_currentUser != null) {
        final xp = await _authService.getMyXp();
        _currentUser = _currentUser!.copyWith(xp: xp);
      }
      _achievements = await _calculateAchievementsProgress();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<Achievement>> _calculateAchievementsProgress() async {
    int registeredCoursesCount = 0;
    int totalLessonsCompleted = 0;

    try {
      final registrations = await _authService.getMyRegistrations();
      registeredCoursesCount = registrations.length;

      final grades = await _authService.getMyGrades();
      totalLessonsCompleted = grades.length;
    } catch (e) {
      debugPrint('❌ Error fetching courses/grades in profile: $e');
    }

    final achievements = List<Achievement>.from(achievementsInfo);
    final statsService = UserStatsService();

    // Save to state
    _registeredCoursesCount = registeredCoursesCount;
    _totalLessonsCompleted = totalLessonsCompleted;

    final hasPerfectScore = await statsService.hasPerfectScore();
    final currentStreak = await statsService.getCurrentStreak();
    _currentStreak = currentStreak;
    final todayLessonCount = await statsService.getTodayLessonCount();
    final shareCount = await statsService.getShareCount();
    final correctAnswersCount = await statsService.getCorrectAnswersCount();
    final hasFastCompletion = await statsService.hasFastCompletion();

    // bool hasMasteredCourse = courses.any((course) {
    //   final courseIndex = coursesInfo.indexWhere(
    //     (c) => c.title == course.title,
    //   );
    //   if (courseIndex >= 0 && courseIndex < lessonsInfo.length) {
    //     final totalLessonsInCourse = lessonsInfo[courseIndex].length;
    //     return course.lessonsFinished >= totalLessonsInCourse;
    //   }
    //   return false;
    // });

    for (int i = 0; i < achievements.length; i++) {
      final achievement = achievements[i];
      double newProgress = 0;

      switch (achievement.name) {
        case "First Step":
          newProgress = totalLessonsCompleted >= 1 ? 1 : 0;
          break;

        // case "Completionist":
        //   newProgress = registeredCoursesCount >= coursesInfo.length
        //       ? coursesInfo.length.toDouble()
        //       : registeredCoursesCount.toDouble();
        //   break;

        case "Perfect Score":
          newProgress = hasPerfectScore ? 1 : 0;
          break;

        case "3-Day Streak":
          newProgress = currentStreak >= 3 ? 3 : currentStreak.toDouble();
          break;

        case "Speed Learner":
          newProgress = todayLessonCount >= 5 ? 5 : todayLessonCount.toDouble();
          break;

        case "Consistent":
          newProgress = totalLessonsCompleted >= 10
              ? 10
              : totalLessonsCompleted.toDouble();
          break;

        case "Course Explorer":
          newProgress = registeredCoursesCount >= 3
              ? 3
              : registeredCoursesCount.toDouble();
          break;

        // case "Master Student":
        //   newProgress = hasMasteredCourse ? 1 : 0;
        //   break;

        case "Social Learner":
          newProgress = shareCount >= 5 ? 5 : shareCount.toDouble();
          break;

        case "Quick Thinker":
          newProgress = correctAnswersCount >= 20
              ? 20
              : correctAnswersCount.toDouble();
          break;

        case "Fast Starter":
          newProgress = hasFastCompletion ? 1 : 0;
          break;

        case "Perfect Week":
          newProgress = currentStreak >= 7 ? 7 : currentStreak.toDouble();
          break;

        default:
          newProgress = achievement.progress;
      }

      achievements[i] = achievement.copyWith(progress: newProgress);
    }

    return achievements;
  }

  void refresh() {
    _loadUserData();
  }

  Future<void> _shareProgress() async {
    final username =
        Provider.of<ProfileState>(
          context,
          listen: false,
        ).currentUser?.username ??
        'Student';
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Share feature not available on Web'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final achievements = await _calculateAchievementsProgress();

      int totalLessonsCompleted = _totalLessonsCompleted;
      int totalCourses = _registeredCoursesCount;
      final completedAchievements = achievements
          .where((a) => a.isCompleted)
          .length;
      final totalAchievements = achievements.length;

      final shareText =
          '''
🎯 My Learning Progress 📚

👤 User: $username
📊 Courses: $totalCourses registered
✅ Lessons: $totalLessonsCompleted completed
🏆 Achievements: $completedAchievements/$totalAchievements unlocked

Keep learning with me! 💪

#LearningApp #Progress #AchievementUnlocked
''';

      // ignore: deprecated_member_use
      await Share.share(shareText, subject: 'My Learning Progress');

      await _statsService.incrementShareCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progress shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, bool> getAchievementCompletionMap() {
    return {
      for (var achievement in _achievements)
        achievement.name: achievement.isCompleted,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    if (_isGuest) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline,
                size: 80,
                color: theme.primaryColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'Login Required',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please log in to view your profile, achievements, and progress.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => LoginScreen(
                          onToggleTheme: widget.onToggleTheme ?? () {},
                        ),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Log In or Register',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isDark = theme.brightness == Brightness.dark;
    final isSmallScreen = screenWidth < 360;
    final profileState = Provider.of<ProfileState>(context);
    final user = profileState.currentUser ?? sampleUser;
    final displayUser = user.copyWith(xp: _currentUser?.xp);
    return Container(
      constraints: BoxConstraints(minHeight: screenHeight),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: 16,
          ),
          child: Column(
            children: [
              // Top User Info Card (Like Screenshot)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayUser.username,
                          style: GoogleFonts.poppins(
                            fontSize: isSmallScreen ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              displayUser.role == UserRole.student
                                  ? Icons.school
                                  : Icons.verified,
                              size: 16,
                              color: theme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              displayUser.role.label,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.greenAccent, width: 2),
                    ),
                    child: ProfileImage(
                      imageUrl: displayUser.profileImage,
                      radius: isSmallScreen ? 35 : 40,
                      name: displayUser.fullName,
                    ),
                  ),
                ],
              ),

              SizedBox(height: screenHeight * 0.03),

              // Stats Row: XP and Streak Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF141A27)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person,
                            size: 28,
                            color: theme.primaryColor,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Lvl ${(displayUser.xp / 100).floor() + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF141A27)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Streak',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                '$_currentStreak',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.local_fire_department,
                                size: 18,
                                color: Colors.deepOrange,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF141A27)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Finished',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$_totalLessonsCompleted',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: screenHeight * 0.025),

              Container(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Achievements',
                          style: GoogleFonts.poppins(
                            fontSize: isSmallScreen ? 18 : 20,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AchievementsScreen(),
                              ),
                            ).then((_) => _loadUserData());
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'View All',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: theme.primaryColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: _showAllAchievements
                            ? _achievements.length
                            : (_achievements.length > 6
                                  ? 6
                                  : _achievements.length),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemBuilder: (context, index) {
                          final achievement = _achievements[index];
                          final isCompleted =
                              achievementCompletionMap[achievement.name] ??
                              false;

                          return _buildAchievementPreview(
                            achievement: achievement,
                            isCompleted: isCompleted,
                            context: context,
                            isSmallScreen: isSmallScreen,
                          );
                        },
                      ),
                    ),

                    if (_achievements.length > 6 && !_showAllAchievements)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showAllAchievements = true;
                              });
                            },
                            child: Text(
                              '+ ${_achievements.length - 6} more achievements',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: theme.primaryColor,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (_showAllAchievements && _achievements.length > 6)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showAllAchievements = false;
                              });
                            },
                            child: Text(
                              'Show less',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.03),
              SizedBox(height: screenHeight * 0.02),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _shareProgress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.015,
                      horizontal: screenWidth * 0.05,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    Icons.share,
                    color: Colors.white,
                    size: isSmallScreen
                        ? screenWidth * 0.05
                        : screenWidth * 0.045,
                  ),
                  label: Text(
                    'Share My Progress',
                    style: GoogleFonts.poppins(
                      fontSize: isSmallScreen
                          ? screenWidth * 0.04
                          : screenWidth * 0.038,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementPreview({
    required Achievement achievement,
    required bool isCompleted,
    required BuildContext context,
    required bool isSmallScreen,
  }) {
    final theme = Theme.of(context);

    return Tooltip(
      message: achievement.description,
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isCompleted
              ? achievement.color.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
          border: Border.all(
            color: isCompleted
                ? achievement.color.withValues(alpha: 0.3)
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: isCompleted ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? achievement.color.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                  child: Icon(
                    achievement.icon,
                    size: isSmallScreen ? 20 : 24,
                    color: isCompleted ? achievement.color : Colors.grey,
                  ),
                ),
                if (isCompleted)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            FittedBox(
              child: Text(
                achievement.name,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: isSmallScreen ? 10 : 12,
                  fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
