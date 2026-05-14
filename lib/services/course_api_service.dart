import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sophia_path/screens/authentication/authService.dart';

class CourseApiService {
  static final CourseApiService _instance = CourseApiService._internal();
  factory CourseApiService() => _instance;
  CourseApiService._internal();

  Future<Map<String, dynamic>> getMyRegistrations() async {
    final url = Uri.parse('${AuthService.baseUrl}/courses/me/registrations');
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
      final data = body.isEmpty ? [] : jsonDecode(body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }

      final msg = data is Map<String, dynamic>
          ? data['message']?.toString()
          : body;
      return {
        'success': false,
        'message': msg ?? 'Failed to fetch registrations',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> registerCourse(int courseId) async {
    final url = Uri.parse(
      '${AuthService.baseUrl}/courses/me/register/$courseId',
    );
    final token = await AuthStorage.getToken();

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final body = response.body.trim();
      final data = body.isEmpty ? null : jsonDecode(body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      }

      final msg = data is Map<String, dynamic>
          ? data['message']?.toString()
          : body;
      return {'success': false, 'message': msg ?? 'Failed to register course'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> unregisterCourse(int courseId) async {
    final url = Uri.parse(
      '${AuthService.baseUrl}/courses/me/register/$courseId',
    );
    final token = await AuthStorage.getToken();

    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final body = response.body.trim();
      final data = body.isEmpty ? null : jsonDecode(body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'data': data};
      }

      final msg = data is Map<String, dynamic>
          ? data['message']?.toString()
          : body;
      return {
        'success': false,
        'message': msg ?? 'Failed to unregister course',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getRegisteredCourses() async {
    return getMyRegistrations();
  }

  Future<Map<String, dynamic>> getCourseLessonGrades(int courseId) async {
    final url = Uri.parse(
      '${AuthService.baseUrl}/courses/me/courses/$courseId/grades',
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
      final data = body.isEmpty ? [] : jsonDecode(body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }

      final msg = data is Map<String, dynamic>
          ? data['message']?.toString()
          : body;
      return {
        'success': false,
        'message': msg ?? 'Failed to fetch course lesson grades',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

}
