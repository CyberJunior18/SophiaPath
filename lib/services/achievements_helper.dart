import '../models/user/achievements.dart';
import '../models/data.dart';
import 'course/database_helper.dart';
import 'course/user_stats_service.dart';

class AchievementsHelper {
  static Future<List<Achievement>> calculateAchievementsProgress() async {
    final DatabaseService dbService = DatabaseService();
    final courses = await dbService.getCourses();
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
}
