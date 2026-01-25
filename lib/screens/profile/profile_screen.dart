import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sophia_path/models/data.dart';
import 'package:sophia_path/screens/profile/achievements_screen.dart';
import 'package:sophia_path/services/course/user_stats_service.dart';

import '../../models/user/achievements.dart';
import '../../models/user/user.dart';
import '../../services/user_preferences_services.dart';
import '../../services/course/database_helper.dart';
import 'package:share_plus/share_plus.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onProfileUpdated;

  const ProfileScreen({super.key, this.onProfileUpdated});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserPreferencesService _userService = UserPreferencesService.instance;
  final DatabaseService _dbService = DatabaseService();
  final UserStatsService _statsService = UserStatsService();
  User? _currentUser;
  bool _isLoading = true;
  List<Achievement> _achievements = [];
  bool _showAllAchievements = false;

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
    setState(() => _isLoading = true);
    _currentUser = await _userService.getUser();
    _achievements = await _calculateAchievementsProgress();
    setState(() => _isLoading = false);
  }

  Future<List<Achievement>> _calculateAchievementsProgress() async {
    final courses = await _dbService.getCourses();
    final achievements = List<Achievement>.from(achievementsInfo);
    final statsService = UserStatsService();

    final totalLessonsCompleted = courses.fold(
      0,
      (sum, course) => sum + course.lessonsFinished,
    );
    final registeredCoursesCount = courses.length;
    final hasPerfectScore = await statsService.hasPerfectScore();
    final currentStreak = await statsService.getCurrentStreak();
    final todayLessonCount = await statsService.getTodayLessonCount();
    final shareCount = await statsService.getShareCount();
    final correctAnswersCount = await statsService.getCorrectAnswersCount();
    final hasFastCompletion = await statsService.hasFastCompletion();

    bool hasMasteredCourse = courses.any((course) {
      final courseIndex = coursesInfo.indexWhere(
        (c) => c.title == course.title,
      );
      if (courseIndex >= 0 && courseIndex < lessonsInfo.length) {
        final totalLessonsInCourse = lessonsInfo[courseIndex].length;
        return course.lessonsFinished >= totalLessonsInCourse;
      }
      return false;
    });

    for (int i = 0; i < achievements.length; i++) {
      final achievement = achievements[i];
      double newProgress = 0;

      switch (achievement.name) {
        case "First Step":
          newProgress = totalLessonsCompleted >= 1 ? 1 : 0;
          break;

        case "Completionist":
          newProgress = registeredCoursesCount >= coursesInfo.length
              ? coursesInfo.length.toDouble()
              : registeredCoursesCount.toDouble();
          break;

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

        case "Master Student":
          newProgress = hasMasteredCourse ? 1 : 0;
          break;

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
    try {
      final courses = await _dbService.getCourses();
      int totalLessonsCompleted = 0;
      int totalCourses = courses.length;

      for (var course in courses) {
        totalLessonsCompleted += course.lessonsFinished;
      }

      final achievements = await _calculateAchievementsProgress();
      final completedAchievements = achievements
          .where((a) => a.isCompleted)
          .length;
      final totalAchievements = achievements.length;

      final shareText =
          '''
🎯 My Learning Progress 📚

👤 User: ${_currentUser?.username ?? 'Student'}
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

    final displayUser = _currentUser ?? sampleUser;
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isDark = theme.brightness == Brightness.dark;
    final isSmallScreen = screenWidth < 360;

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
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? const Color.fromRGBO(217, 217, 217, 100)
                        : const Color(0xFF3D5CFF),
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: isSmallScreen
                      ? screenWidth * 0.18
                      : screenWidth * 0.15,
                  backgroundImage: displayUser.profileImage.startsWith('http')
                      ? NetworkImage(displayUser.profileImage)
                      : FileImage(File(displayUser.profileImage))
                            as ImageProvider,
                ),
              ),
              SizedBox(height: screenHeight * 0.02),

              Text(
                displayUser.username,
                style: GoogleFonts.poppins(
                  fontSize: isSmallScreen
                      ? screenWidth * 0.065
                      : screenWidth * 0.06,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: screenHeight * 0.008),

              Text(
                displayUser.tag,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: screenWidth * 0.05,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: screenHeight * 0.008),

              Text(
                "${displayUser.age}, ${displayUser.sex}",
                style: GoogleFonts.poppins(
                  fontSize: isSmallScreen
                      ? screenWidth * 0.037
                      : screenWidth * 0.039,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              SizedBox(height: screenHeight * 0.03),

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
                              color: const Color(
                                0xFF3D5CFF,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'View All',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: const Color(0xFF3D5CFF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: Color(0xFF3D5CFF),
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
                                color: const Color(0xFF3D5CFF),
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
                    backgroundColor: const Color(0xFF3D5CFF),
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
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
