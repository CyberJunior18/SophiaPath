import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScoresRepository {
  static const String _key = 'scores';

  static Future<void> initializeScores(
    int courseCount,
    int lessonsPerCourse,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_key);

    if (encodedData == null) {
      final List<List<int>> initialScores = List.generate(
        courseCount,
        (_) => List.filled(lessonsPerCourse, 0),
      );
      await saveScores(initialScores);
    }
  }

  static Future<void> saveScores(List<List<int>> scores) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(scores);
    await prefs.setString(_key, encodedData);
  }

  static Future<List<List<int>>?> getScores() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_key);

    if (encodedData == null) return null;

    try {
      final List<dynamic> decodedData = jsonDecode(encodedData);
      final List<List<int>> scores =
          decodedData.map<List<int>>((innerList) {
            return (innerList as List<dynamic>).map<int>((item) {
              return item is int ? item : (item as num).toInt();
            }).toList();
          }).toList();

      return scores;
    } catch (e) {
      return null;
    }
  }

  static Future<void> addScore(
    int courseIndex,
    int lessonIndex,
    int score,
  ) async {
    return _updateScore(courseIndex, lessonIndex, score);
  }

  static Future<void> updateScore(
    int courseIndex,
    int lessonIndex,
    int newScore,
  ) async {
    return _updateScore(courseIndex, lessonIndex, newScore);
  }

  static Future<void> changeScore(
    int courseIndex,
    int lessonIndex,
    int newScore,
  ) async {
    return _updateScore(courseIndex, lessonIndex, newScore);
  }

  static Future<void> _updateScore(
    int courseIndex,
    int lessonIndex,
    int score,
  ) async {
    final List<List<int>>? currentScores = await getScores();

    if (currentScores == null) {
      final newScores = List.generate(
        courseIndex + 1,
        (_) => List.filled(lessonIndex + 1, 0),
      );
      newScores[courseIndex][lessonIndex] = score;
      await saveScores(newScores);
    } else {
      final List<List<int>> updatedScores = List.from(currentScores);

      while (updatedScores.length <= courseIndex) {
        updatedScores.add([]);
      }

      while (updatedScores[courseIndex].length <= lessonIndex) {
        updatedScores[courseIndex].add(0);
      }

      updatedScores[courseIndex][lessonIndex] = score;
      await saveScores(updatedScores);
    }
  }

  static Future<int?> getScore(int courseIndex, int lessonIndex) async {
    final List<List<int>>? allScores = await getScores();

    if (allScores == null ||
        courseIndex >= allScores.length ||
        lessonIndex >= allScores[courseIndex].length) {
      return null;
    }

    return allScores[courseIndex][lessonIndex];
  }

  static Future<List<int>> getCourseScores(int courseIndex) async {
    final List<List<int>>? allScores = await getScores();

    if (allScores == null || courseIndex >= allScores.length) {
      return [];
    }

    return List<int>.from(allScores[courseIndex]);
  }

  static Future<List<List<int>>> getAllCoursesScores() async {
    final scores = await getScores();
    return scores ?? [];
  }

  static Future<void> resetScore(int courseIndex, int lessonIndex) async {
    await _updateScore(courseIndex, lessonIndex, 0);
  }

  static Future<void> resetCourseScores(int courseIndex) async {
    final List<List<int>>? currentScores = await getScores();

    if (currentScores == null || courseIndex >= currentScores.length) {
      return;
    }

    final List<List<int>> updatedScores = List.from(currentScores);

    updatedScores[courseIndex] = List.filled(
      currentScores[courseIndex].length,
      0,
    );

    await saveScores(updatedScores);
  }

  static Future<void> deleteScore(int courseIndex, int lessonIndex) async {
    await resetScore(courseIndex, lessonIndex);
  }

  static Future<void> clearScores() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<int> getHighestScoreForCourse(int courseIndex) async {
    final scores = await getCourseScores(courseIndex);
    return scores.isNotEmpty ? scores.reduce((a, b) => a > b ? a : b) : 0;
  }

  static Future<double> getAverageScoreForCourse(int courseIndex) async {
    final scores = await getCourseScores(courseIndex);
    if (scores.isEmpty) return 0.0;

    final sum = scores.reduce((a, b) => a + b);
    return sum / scores.length;
  }

  static Future<bool> isLessonCompleted(
    int courseIndex,
    int lessonIndex, {
    int passingScore = 70,
  }) async {
    final score = await getScore(courseIndex, lessonIndex);
    return score != null && score >= passingScore;
  }

  static Future<int> getCompletedLessonsCount(
    int courseIndex, {
    int passingScore = 70,
  }) async {
    final scores = await getCourseScores(courseIndex);
    return scores.where((score) => score >= passingScore).length;
  }
}
