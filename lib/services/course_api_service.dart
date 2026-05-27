import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sophia_path/screens/authentication/authService.dart';

class CourseApiService {
  static final CourseApiService _instance = CourseApiService._internal();
  factory CourseApiService() => _instance;
  CourseApiService._internal();

  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> getMyRegistrations() async {
    try {
      return {'success': true, 'data': await _authService.getMyRegistrations()};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> registerCourse(int courseId) async {
    try {
      return await _authService.registerInCourse(courseId: courseId);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> unregisterCourse(int courseId) async {
    try {
      return await _authService.unregisterFromCourse(courseId: courseId);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getRegisteredCourses() async {
    return getMyRegistrations();
  }

  Future<Map<String, dynamic>> getCourseLessonGrades(int courseId) async {
    try {
      return {
        'success': true,
        'data': await _authService.getCourseLessonGrades(courseId: courseId),
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> setLessonGrade(int lessonId, int grade) async {
    try {
      return await _authService.setLessonGrade(
        lessonId: lessonId,
        grade: grade.toDouble(),
      );
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getLessonGrade(int lessonId) async {
    final url = Uri.parse(
      '${AuthService.baseUrl}/courses/me/lessons/$lessonId/grade',
    );
    final token = await AuthStorage.getToken();

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final body = response.body.trim();
      final data = body.isEmpty ? null : jsonDecode(body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }

      final msg = data is Map<String, dynamic>
          ? data['message']?.toString()
          : body;
      return {
        'success': false,
        'message': msg ?? 'Failed to fetch lesson grade',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> markLessonDone(int lessonId) async {
    try {
      return await _authService.markLessonDone(lessonId: lessonId);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getMyGrades() async {
    try {
      return {'success': true, 'data': await _authService.getMyGrades()};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getLessonContent(
    int courseId,
    int lessonId,
  ) async {
    final url = Uri.parse(
      '${AuthService.baseUrl}/courses/$courseId/lessons/$lessonId/content',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      final body = response.body.trim();
      final data = body.isEmpty ? [] : jsonDecode(body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }

      final msg = data is Map<String, dynamic>
          ? data['message']?.toString()
          : body;
      return {
        'success': false,
        'message': msg ?? 'Failed to fetch lesson content',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
