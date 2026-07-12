import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sophia_path/models/course/course_info.dart';
import 'package:sophia_path/models/course/lesson.dart';

import '../../models/course/lessonContent.dart' hide Lesson;

class AuthService {
  // Use 10.0.2.2 for Android emulator to reach localhost on your PC
  // If using a real device, replace with your PC's local IP e.g. http://192.168.1.x:3000
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000';

    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3000'
        : 'http://localhost:3000';
  }

  // login, register, logout shit
  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String fullname,
    required String password,
    required String tag,
    required String gender,
    required int age,
  }) async {
    final url = Uri.parse('$baseUrl/auth/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'username': username,
          'fullname': fullname,
          'password': password,
          'tag': tag,
          'gender': gender,
          'age': age,
        }),
      );

      final responseBody = response.body.trim();
      final dynamic data = responseBody.isEmpty
          ? null
          : _tryDecodeJson(responseBody);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        final backendMessage = data is Map<String, dynamic>
            ? data['message']?.toString()
            : null;
        return {
          'success': false,
          'message':
              backendMessage ??
              'Registration failed (HTTP ${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final responseBody = response.body.trim();
      final dynamic data = responseBody.isEmpty
          ? null
          : _tryDecodeJson(responseBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final extracted = _extractToken(data);
        if (extracted != null && extracted.isNotEmpty) {
          await AuthStorage.setToken(extracted);
          return {'success': true, 'token': extracted};
        }
        return {'success': false, 'message': 'Token not found in response'};
      } else {
        final backendMessage = data is Map<String, dynamic>
            ? data['message']?.toString()
            : null;
        return {
          'success': false,
          'message':
              backendMessage ?? 'Login failed (HTTP ${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<void> logout() async {
    await AuthStorage.clearToken();
  }

  // profile shit
  Future<Map<String, dynamic>> getProfile() async {
    final token = await AuthStorage.getToken();

    if (token == null) {
      return {
        'success': false,
        'message': 'No token found. Please login again.',
      };
    }

    final profileEndpoints = <String>[
      '$baseUrl/users/me',
      '$baseUrl/auth/profile',
    ];

    try {
      for (final endpoint in profileEndpoints) {
        final response = await http.get(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        final responseBody = response.body.trim();
        final dynamic data = responseBody.isEmpty
            ? null
            : _tryDecodeJson(responseBody);

        if (response.statusCode == 200) {
          final normalizedProfile = _normalizeProfileData(data);
          if (normalizedProfile != null) {
            return {'success': true, 'data': normalizedProfile};
          }
        }

        if (response.statusCode == 401) {
          await AuthStorage.clearToken();
          return {
            'success': false,
            'message': 'Session expired. Please login again.',
          };
        }
      }

      return {'success': false, 'message': 'Failed to load profile'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<int> getMyXp() async {
    final profileResult = await getProfile();
    if (profileResult['success'] != true || profileResult['data'] is! Map) {
      return 0;
    }

    final profile = Map<String, dynamic>.from(profileResult['data'] as Map);
    return _asInt(profile['xp']);
  }

  Future<Map<String, dynamic>> updateProfile({
    required String username,
    required String fullname,
    required String tag,
    required String gender,
    String? avatar,
  }) async {
    final url = Uri.parse('$baseUrl/users/me');
    final token = await AuthStorage.getToken();

    if (token == null) {
      return {
        'success': false,
        'message': 'No token found. Please login again.',
      };
    }

    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'username': username,
          'fullname': fullname,
          'tag': tag,
          'gender': gender,
          if (avatar != null) 'avatar': avatar,
        }),
      );

      final responseBody = response.body.trim();
      final dynamic data = responseBody.isEmpty
          ? null
          : jsonDecode(responseBody);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'data': data};
      }

      if (response.statusCode == 401) {
        await AuthStorage.clearToken();
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      }

      final message = data is Map<String, dynamic>
          ? (data['message']?.toString() ?? 'Failed to update profile')
          : 'Failed to update profile';

      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  String? _extractToken(dynamic data) {
    if (data is! Map) return null;

    final dynamic direct =
        data['accessToken'] ?? data['token'] ?? data['access_token'];
    final normalizedDirect = AuthStorage.normalizeToken(direct?.toString());
    if (normalizedDirect != null) return normalizedDirect;

    final dynamic tokens = data['tokens'];
    if (tokens is Map) {
      final dynamic nested =
          tokens['accessToken'] ?? tokens['token'] ?? tokens['access_token'];
      final normalizedNested = AuthStorage.normalizeToken(nested?.toString());
      if (normalizedNested != null) return normalizedNested;
    }

    final dynamic payload = data['data'];
    if (payload is Map) {
      final dynamic payloadToken =
          payload['accessToken'] ?? payload['token'] ?? payload['access_token'];
      final normalizedPayload = AuthStorage.normalizeToken(
        payloadToken?.toString(),
      );
      if (normalizedPayload != null) return normalizedPayload;
    }

    return null;
  }

  dynamic _tryDecodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return {'message': raw};
    }
  }

  Map<String, dynamic>? _normalizeProfileData(dynamic data) {
    if (data is Map<String, dynamic>) {
      final candidates = <dynamic>[
        data['user'],
        data['data'],
        data['profile'],
        data['result'],
      ];

      for (final candidate in candidates) {
        if (candidate is Map<String, dynamic>) {
          return _withProfileAliases(candidate);
        }
        if (candidate is Map) {
          return _withProfileAliases(Map<String, dynamic>.from(candidate));
        }
      }

      return _withProfileAliases(Map<String, dynamic>.from(data));
    }

    if (data is Map) {
      return _withProfileAliases(Map<String, dynamic>.from(data));
    }

    return null;
  }

  Map<String, dynamic> _withProfileAliases(Map<String, dynamic> profile) {
    profile.putIfAbsent('xp', () => _asInt(profile['xp'] ?? profile['XP']));
    profile.putIfAbsent('XP', () => profile['xp']);
    profile.putIfAbsent('userId', () => profile['id']);
    profile.putIfAbsent('id', () => profile['userId']);
    profile.putIfAbsent('fullName', () => profile['fullname']);
    profile.putIfAbsent('fullname', () => profile['fullName']);
    profile.putIfAbsent('profileImage', () => profile['avatar']);
    profile.putIfAbsent('avatar', () => profile['profileImage']);
    profile.putIfAbsent('roleID', () => profile['role']);
    profile.putIfAbsent('role', () => profile['roleID']);
    profile.putIfAbsent('dateTime', () => profile['date']);
    profile.putIfAbsent('date', () => profile['dateTime']);
    return profile;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, String> _jsonHeaders({String? token}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  bool _looksLikeExerciseLesson(dynamic pages) {
    if (pages is! List) return false;

    for (final page in pages.whereType<Map>()) {
      final map = Map<String, dynamic>.from(page);
      if (map.containsKey('question') || map.containsKey('answers')) {
        return true;
      }

      final blocks = map['blocks'];
      if (blocks is List) {
        for (final block in blocks.whereType<Map>()) {
          final blockMap = Map<String, dynamic>.from(block);
          final type = (blockMap['type'] ?? '').toString().toLowerCase();
          if (type == 'mcq' ||
              type == 'fill_code' ||
              type == 'write_line' ||
              type == 'find_error') {
            return true;
          }
        }
      }
    }

    return false;
  }

  List<Map<String, dynamic>> _normalizeMapList(dynamic rawList) {
    if (rawList is! List) {
      return <Map<String, dynamic>>[];
    }

    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  dynamic _extractPayload(dynamic data, {List<String> keys = const []}) {
    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        if (data.containsKey(key)) {
          return data[key];
        }
      }
      return data;
    }

    return data;
  }

  Future<List<CourseInfo>> getAllCourses() async {
    final url = Uri.parse('$baseUrl/courses');

    try {
      final response = await http.get(url, headers: _jsonHeaders());

      final responseBody = response.body.trim();
      final dynamic data = responseBody.isEmpty
          ? null
          : _tryDecodeJson(responseBody);

      if (response.statusCode == 200) {
        final dynamic rawList = data is List
            ? data
            : (data is Map<String, dynamic>
                  ? (data['courses'] ?? data['data'] ?? data['items'])
                  : null);

        if (rawList is! List) {
          return <CourseInfo>[];
        }

        return rawList
            .whereType<Map>()
            .map((item) => CourseInfo.fromMap(Map<String, dynamic>.from(item)))
            .toList();
      }

      if (response.statusCode == 401) {
        await AuthStorage.clearToken();
        throw Exception('Session expired. Please login again.');
      }

      final backendMessage = data is Map<String, dynamic>
          ? data['message']?.toString()
          : null;
      throw Exception(
        backendMessage ??
            'Failed to fetch courses (HTTP ${response.statusCode})',
      );
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<LessonContent?> getLessonContentById({
    required int courseId,
    required int sectionId,
    required int lessonId,
    required int contentId,
  }) async {
    try {
      final fullSection = await getLessonById(
        courseId: courseId,
        sectionId: sectionId,
        lessonId: lessonId,
      );
      // Find the specific content
      for (final content in fullSection.contents) {
        if (content.id == contentId) {
          return content;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Lesson> getLessonById({
    required int courseId,
    required int sectionId,
    required int lessonId,
  }) async {
    final url = Uri.parse(
      '$baseUrl/courses/$courseId/sections/$sectionId/lessons/$lessonId',
    );
    final token = await AuthStorage.getToken();

    if (token == null) {
      throw Exception('No token found. Please login again.');
    }

    try {
      final response = await http.get(url, headers: _jsonHeaders(token: token));

      final responseBody = response.body.trim();
      final dynamic data = responseBody.isEmpty
          ? null
          : _tryDecodeJson(responseBody);

      if (response.statusCode == 200) {
        final dynamic rawLesson = data is Map<String, dynamic>
            ? (data['lesson'] ?? data['data'] ?? data)
            : data;

        if (rawLesson is! Map) {
          throw Exception('Invalid lesson payload format.');
        }

        final lessonMap = Map<String, dynamic>.from(rawLesson);
        final dynamic pages = lessonMap['pages'];
        final isExercise =
            lessonMap['category']?.toString().toLowerCase() == 'exercise' ||
            _looksLikeExerciseLesson(pages);

        lessonMap
          ..putIfAbsent('partTitle', () => lessonMap['title'])
          ..putIfAbsent('category', () => isExercise ? 'exercise' : 'learning')
          ..putIfAbsent('type', () => isExercise ? 'mcq' : 'text')
          ..putIfAbsent('pages', () => pages is List ? pages : <dynamic>[]);

        return Lesson.fromMap(lessonMap);
      }

      if (response.statusCode == 401) {
        await AuthStorage.clearToken();
        throw Exception('Session expired. Please login again.');
      }

      final backendMessage = data is Map<String, dynamic>
          ? data['message']?.toString()
          : null;

      throw Exception(
        backendMessage ??
            'Failed to fetch lesson (HTTP ${response.statusCode})',
      );
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // profile shit
  Future<List<Map<String, dynamic>>> getSectionLessonsGrades({
    required int courseID,
    required int sectionID,
  }) async {
    final token = await AuthStorage.getToken();

    if (token == null) {
      return [];
    }

    final donelessonsEndpoint =
        '$baseUrl/courses/$courseID/sections/$sectionID/done-lessons';

    try {
      final response = await http.get(
        Uri.parse(donelessonsEndpoint),
        headers: _jsonHeaders(token: token),
      );

      final responseBody = response.body.trim();
      final dynamic data = responseBody.isEmpty
          ? null
          : _tryDecodeJson(responseBody);

      if (response.statusCode == 200) {
        final dynamic rawList = data is List
            ? data
            : (data is Map<String, dynamic>
                  ? (data['doneLessons'] ??
                        data['lessons'] ??
                        data['data'] ??
                        data['items'])
                  : null);

        if (rawList is! List) {
          return [];
        }

        final lessons = rawList.whereType<Map>().map((item) {
          final lesson = Map<String, dynamic>.from(item);
          return {
            'lessonId':
                lesson['lessonId'] ?? lesson['id'] ?? lesson['doneLessonId'],
            'grade': lesson['grade'] ?? lesson['score'],
          };
        }).toList();

        return lessons;
      }

      if (response.statusCode == 401) {
        await AuthStorage.clearToken();
        return [];
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSectionLessons({
    required int courseId,
    required int sectionId,
  }) async {
    final token = await AuthStorage.getToken();

    if (token == null) {
      return [];
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courses/$courseId/sections/$sectionId/lessons'),
        headers: _jsonHeaders(token: token),
      );

      final responseBody = response.body.trim();
      final dynamic data = responseBody.isEmpty
          ? null
          : _tryDecodeJson(responseBody);

      if (response.statusCode == 200) {
        final rawList = _normalizeMapList(
          _extractPayload(data, keys: const ['lessons', 'data', 'items']),
        );

        return rawList;
      }

      if (response.statusCode == 401) {
        await AuthStorage.clearToken();
        return [];
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> registerInCourse({required int courseId}) async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'No token found. Please login again.',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/courses/me/register/$courseId'),
        headers: _jsonHeaders(token: token),
      );

      final responseBody = response.body.trim();
      final dynamic data = responseBody.isEmpty
          ? null
          : _tryDecodeJson(responseBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      }

      if (response.statusCode == 401) {
        await AuthStorage.clearToken();
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      }

      final backendMessage = data is Map<String, dynamic>
          ? data['message']?.toString()
          : null;
      return {
        'success': false,
        'message':
            backendMessage ??
            'Failed to register in course (HTTP ${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> unregisterFromCourse({
    required int courseId,
  }) async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'No token found. Please login again.',
      };
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/courses/me/register/$courseId'),
        headers: _jsonHeaders(token: token),
      );

      final responseBody = response.body.trim();
      final dynamic data = responseBody.isEmpty
          ? null
          : _tryDecodeJson(responseBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      }

      if (response.statusCode == 401) {
        await AuthStorage.clearToken();
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      }

      final backendMessage = data is Map<String, dynamic>
          ? data['message']?.toString()
          : null;
      return {
        'success': false,
        'message':
            backendMessage ??
            'Failed to unregister from course (HTTP ${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> getMyRegistrations() async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      return [];
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courses/me/registrations'),
        headers: _jsonHeaders(token: token),
      );

      final responseBody = response.body.trim();
      final dynamic data = responseBody.isEmpty
          ? null
          : _tryDecodeJson(responseBody);

      if (response.statusCode == 200) {
        final dynamic rawList = data is List
            ? data
            : (data is Map<String, dynamic>
                  ? (data['registrations'] ?? data['data'] ?? data['items'])
                  : null);

        if (rawList is! List) {
          return [];
        }

        return rawList.whereType<Map>().map((item) {
          final registration = Map<String, dynamic>.from(item);
          return {
            'registrationId':
                registration['registrationId'] ?? registration['id'],
            'registeredAt': registration['registeredAt'],
            'course': registration['course'],
          };
        }).toList();
      }

      if (response.statusCode == 401) {
        await AuthStorage.clearToken();
        return [];
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMyGrades() async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      return [];
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courses/me/grades'),
        headers: _jsonHeaders(token: token),
      );

      final responseBody = response.body.trim();
      final dynamic data = responseBody.isEmpty
          ? null
          : _tryDecodeJson(responseBody);

      if (response.statusCode == 200) {
        final dynamic rawList = data is List
            ? data
            : (data is Map<String, dynamic>
                  ? (data['grades'] ?? data['data'] ?? data['items'])
                  : null);

        if (rawList is! List) {
          return [];
        }

        return rawList.whereType<Map>().map((item) {
          final grade = Map<String, dynamic>.from(item);
          return grade;
        }).toList();
      }

      if (response.statusCode == 401) {
        await AuthStorage.clearToken();
        return [];
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCourseLessonGrades({
    required int courseId,
  }) async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      return [];
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courses/me/courses/$courseId/grades'),
        headers: _jsonHeaders(token: token),
      );

      final responseBody = response.body.trim();
      final dynamic data = responseBody.isEmpty
          ? null
          : _tryDecodeJson(responseBody);

      if (response.statusCode == 200) {
        final dynamic rawList = data is List
            ? data
            : (data is Map<String, dynamic>
                  ? (data['lessons'] ??
                        data['grades'] ??
                        data['data'] ??
                        data['items'])
                  : null);

        if (rawList is! List) {
          return [];
        }

        return rawList
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }

      if (response.statusCode == 401) {
        await AuthStorage.clearToken();
        return [];
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDoneLessonsInCourse({
    required int courseId,
    int? sectionId,
  }) async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      return [];
    }

    final uri = Uri.parse('$baseUrl/courses/me/courses/$courseId/done-lessons')
        .replace(
          queryParameters: sectionId == null
              ? null
              : {'sectionId': sectionId.toString()},
        );

    try {
      final response = await http.get(uri, headers: _jsonHeaders(token: token));

      final responseBody = response.body.trim();
      final dynamic data = responseBody.isEmpty
          ? null
          : _tryDecodeJson(responseBody);

      if (response.statusCode == 200) {
        final dynamic rawList = data is List
            ? data
            : (data is Map<String, dynamic>
                  ? (data['doneLessons'] ??
                        data['lessons'] ??
                        data['data'] ??
                        data['items'])
                  : null);

        if (rawList is! List) {
          return [];
        }

        return rawList
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }

      if (response.statusCode == 401) {
        await AuthStorage.clearToken();
        return [];
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDoneLessonsInSection({
    required int courseId,
    required int sectionId,
  }) async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      return [];
    }

    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/courses/$courseId/sections/$sectionId/done-lessons',
        ),
        headers: _jsonHeaders(token: token),
      );

      final responseBody = response.body.trim();
      final dynamic data = responseBody.isEmpty
          ? null
          : _tryDecodeJson(responseBody);

      if (response.statusCode == 200) {
        final dynamic rawList = data is List
            ? data
            : (data is Map<String, dynamic>
                  ? (data['doneLessons'] ??
                        data['lessons'] ??
                        data['data'] ??
                        data['items'])
                  : null);

        if (rawList is! List) {
          return [];
        }

        return rawList
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }

      if (response.statusCode == 401) {
        await AuthStorage.clearToken();
        return [];
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> setLessonGrade({
    required int lessonId,
    required double grade,
  }) async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'No token found. Please login again.',
      };
    }

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/courses/me/lessons/$lessonId/grade'),
        headers: _jsonHeaders(token: token),
        body: jsonEncode({'grade': grade}),
      );

      final responseBody = response.body.trim();
      final dynamic data = responseBody.isEmpty
          ? null
          : _tryDecodeJson(responseBody);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }

      if (response.statusCode == 401) {
        await AuthStorage.clearToken();
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      }

      final backendMessage = data is Map<String, dynamic>
          ? data['message']?.toString()
          : null;
      return {
        'success': false,
        'message':
            backendMessage ??
            'Failed to set lesson grade (HTTP ${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> markLessonDone({required int lessonId}) async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'No token found. Please login again.',
      };
    }

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/courses/me/lessons/$lessonId/done'),
        headers: _jsonHeaders(token: token),
      );

      final responseBody = response.body.trim();
      final dynamic data = responseBody.isEmpty
          ? null
          : _tryDecodeJson(responseBody);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }

      if (response.statusCode == 401) {
        await AuthStorage.clearToken();
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      }

      final backendMessage = data is Map<String, dynamic>
          ? data['message']?.toString()
          : null;
      return {
        'success': false,
        'message':
            backendMessage ??
            'Failed to mark lesson done (HTTP ${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> unmarkLessonDone({required int lessonId}) async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'No token found. Please login again.',
      };
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/courses/me/lessons/$lessonId/done'),
        headers: _jsonHeaders(token: token),
      );

      final responseBody = response.body.trim();
      final dynamic data = responseBody.isEmpty
          ? null
          : _tryDecodeJson(responseBody);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }

      if (response.statusCode == 401) {
        await AuthStorage.clearToken();
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      }

      final backendMessage = data is Map<String, dynamic>
          ? data['message']?.toString()
          : null;
      return {
        'success': false,
        'message':
            backendMessage ??
            'Failed to unmark lesson done (HTTP ${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==========================================
  // CHAT FUNCTIONS
  // ==========================================

  Future<dynamic> getConversationHistory(int userId1, int userId2) async {
    final token = await AuthStorage.getToken();
    final response = await http.get(Uri.parse('$baseUrl/api/chat/conversation/$userId1/$userId2'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> getUserConversations(int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.get(Uri.parse('$baseUrl/api/chat/user/$userId/conversations'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> clearConversation(int userId1, int userId2) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/chat/conversation/$userId1/$userId2/clear'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> markMessagesAsRead(int userId1, int userId2) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/chat/conversation/$userId1/$userId2/mark-read'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> getUnreadCount(int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.get(Uri.parse('$baseUrl/api/chat/user/$userId/unread-count'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> getStatistics() async {
    final token = await AuthStorage.getToken();
    final response = await http.get(Uri.parse('$baseUrl/api/chat/statistics'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> sendMessage({
    required int senderId,
    required int recipientId,
    required String message,
    required String username,
    String? avatar,
    String? replyToId,
    String? replyToMessage,
    String? replyToUsername,
    bool? forwarded,
  }) async {
    final token = await AuthStorage.getToken();
    final body = jsonEncode({
      'senderId': senderId,
      'recipientId': recipientId,
      'message': message,
      'username': username,
      if (avatar != null) 'avatar': avatar,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToMessage != null) 'replyToMessage': replyToMessage,
      if (replyToUsername != null) 'replyToUsername': replyToUsername,
      if (forwarded != null) 'forwarded': forwarded,
    });
    final response = await http.post(Uri.parse('$baseUrl/api/chat/send-message'), headers: _jsonHeaders(token: token), body: body);
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> pinMessage(String messageId, bool pin) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/chat/message/$messageId/pin'), headers: _jsonHeaders(token: token), body: jsonEncode({'pin': pin}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> deleteMessage(String messageId, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.delete(Uri.parse('$baseUrl/api/chat/message/$messageId?userId=$userId'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> searchMessages(int userId, String query) async {
    final token = await AuthStorage.getToken();
    final response = await http.get(Uri.parse('$baseUrl/api/chat/user/$userId/search-messages?query=$query'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> setTypingStatus(int userId, int recipientId, String username, bool typing) async {
    final token = await AuthStorage.getToken();
    final body = jsonEncode({
      'userId': userId,
      'recipientId': recipientId,
      'username': username,
      'typing': typing,
    });
    final response = await http.post(Uri.parse('$baseUrl/api/chat/typing'), headers: _jsonHeaders(token: token), body: body);
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> checkTypingStatus(int userId, int otherUserId) async {
    final token = await AuthStorage.getToken();
    final response = await http.get(Uri.parse('$baseUrl/api/chat/typing/$userId/$otherUserId'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> editDirectMessage(String messageId, String text, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/chat/message/$messageId/edit'), headers: _jsonHeaders(token: token), body: jsonEncode({'text': text, 'userId': userId}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> getActiveTypingStates(int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.get(Uri.parse('$baseUrl/api/chat/users/$userId/active-typing-states'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  // ==========================================
  // GROUPS FUNCTIONS
  // ==========================================

  Future<dynamic> getGroups(int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.get(Uri.parse('$baseUrl/api/groups/user/$userId'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> getGroupById(int groupId, {int? userId}) async {
    final token = await AuthStorage.getToken();
    final query = userId != null ? '?userId=$userId' : '';
    final response = await http.get(Uri.parse('$baseUrl/api/groups/$groupId$query'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> createGroup({
    required String name,
    required List<int> memberIds,
    required int creatorId,
    required String creatorName,
    String? description,
  }) async {
    final token = await AuthStorage.getToken();
    final body = jsonEncode({
      'name': name,
      'memberIds': memberIds,
      'creatorId': creatorId,
      'creatorName': creatorName,
      if (description != null) 'description': description,
    });
    final response = await http.post(Uri.parse('$baseUrl/api/groups/create'), headers: _jsonHeaders(token: token), body: body);
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> addGroupMembers(int groupId, List<int> memberIds, {int? userId}) async {
    final token = await AuthStorage.getToken();
    final body = jsonEncode({
      'memberIds': memberIds,
      if (userId != null) 'userId': userId,
    });
    final response = await http.post(Uri.parse('$baseUrl/api/groups/$groupId/add-members'), headers: _jsonHeaders(token: token), body: body);
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> sendGroupMessage({
    required int groupId,
    required int senderId,
    required String senderName,
    required String text,
    String? senderAvatar,
    String? replyToId,
    String? replyToMessage,
    String? replyToUsername,
    bool? forwarded,
    String? pollQuestion,
    List<String>? pollOptions,
  }) async {
    final token = await AuthStorage.getToken();
    final body = jsonEncode({
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      if (senderAvatar != null) 'senderAvatar': senderAvatar,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToMessage != null) 'replyToMessage': replyToMessage,
      if (replyToUsername != null) 'replyToUsername': replyToUsername,
      if (forwarded != null) 'forwarded': forwarded,
      if (pollQuestion != null) 'pollQuestion': pollQuestion,
      if (pollOptions != null) 'pollOptions': pollOptions,
    });
    final response = await http.post(Uri.parse('$baseUrl/api/groups/$groupId/send-message'), headers: _jsonHeaders(token: token), body: body);
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> makeGroupAdmin(int groupId, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/groups/$groupId/make-admin'), headers: _jsonHeaders(token: token), body: jsonEncode({'userId': userId}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> removeGroupAdmin(int groupId, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/groups/$groupId/remove-admin'), headers: _jsonHeaders(token: token), body: jsonEncode({'userId': userId}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> removeGroupMember(int groupId, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/groups/$groupId/remove-member'), headers: _jsonHeaders(token: token), body: jsonEncode({'userId': userId}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> updateGroupDetails(int groupId, int userId, Map<String, dynamic> updates) async {
    final token = await AuthStorage.getToken();
    final body = jsonEncode({
      'userId': userId,
      'updates': updates,
    });
    final response = await http.post(Uri.parse('$baseUrl/api/groups/$groupId/update'), headers: _jsonHeaders(token: token), body: body);
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> pinGroupMessage(String messageId, bool pin) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/groups/message/$messageId/pin'), headers: _jsonHeaders(token: token), body: jsonEncode({'pin': pin}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> deleteGroupMessage(String messageId, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.delete(Uri.parse('$baseUrl/api/groups/message/$messageId?userId=$userId'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> voteGroupMessagePoll(String messageId, int userId, int optionIndex) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/groups/message/$messageId/vote-poll'), headers: _jsonHeaders(token: token), body: jsonEncode({'userId': userId, 'optionIndex': optionIndex}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> editGroupMessage(String messageId, String text, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/groups/message/$messageId/edit'), headers: _jsonHeaders(token: token), body: jsonEncode({'text': text, 'userId': userId}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> setGroupTypingStatus(int groupId, int userId, String username, bool typing) async {
    final token = await AuthStorage.getToken();
    final body = jsonEncode({
      'userId': userId,
      'username': username,
      'typing': typing,
    });
    final response = await http.post(Uri.parse('$baseUrl/api/groups/$groupId/typing'), headers: _jsonHeaders(token: token), body: body);
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> getGroupTypingStatus(int groupId) async {
    final token = await AuthStorage.getToken();
    final response = await http.get(Uri.parse('$baseUrl/api/groups/$groupId/typing'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> joinGroupByLink(String inviteToken, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/groups/join-by-link/$inviteToken'), headers: _jsonHeaders(token: token), body: jsonEncode({'userId': userId}));
    return _tryDecodeJson(response.body);
  }

  // ==========================================
  // COMMUNITIES FUNCTIONS
  // ==========================================

  Future<dynamic> getCommunities({int? userId}) async {
    final token = await AuthStorage.getToken();
    final query = userId != null ? '?userId=$userId' : '';
    final response = await http.get(Uri.parse('$baseUrl/api/communities$query'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> getCommunityById(int communityId) async {
    final token = await AuthStorage.getToken();
    final response = await http.get(Uri.parse('$baseUrl/api/communities/$communityId'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> createCommunity({
    required String name,
    required int ownerId,
    String? description,
    String? icon,
    bool? isPrivate,
    bool? isNSFW,
    List<String>? rules,
    String? category,
    int? maxMembers,
  }) async {
    final token = await AuthStorage.getToken();
    final body = jsonEncode({
      'name': name,
      'ownerId': ownerId,
      if (description != null) 'description': description,
      if (icon != null) 'icon': icon,
      if (isPrivate != null) 'isPrivate': isPrivate,
      if (isNSFW != null) 'isNSFW': isNSFW,
      if (rules != null) 'rules': rules,
      if (category != null) 'category': category,
      if (maxMembers != null) 'maxMembers': maxMembers,
    });
    final response = await http.post(Uri.parse('$baseUrl/api/communities/create'), headers: _jsonHeaders(token: token), body: body);
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> toggleJoinCommunity(int communityId, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/communities/$communityId/join'), headers: _jsonHeaders(token: token), body: jsonEncode({'userId': userId}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> createRoom(int communityId, String name, String description, int creatorId) async {
    final token = await AuthStorage.getToken();
    final body = jsonEncode({
      'name': name,
      'description': description,
      'creatorId': creatorId,
    });
    final response = await http.post(Uri.parse('$baseUrl/api/communities/$communityId/create-room'), headers: _jsonHeaders(token: token), body: body);
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> getQuestionById(int questionId) async {
    final token = await AuthStorage.getToken();
    final response = await http.get(Uri.parse('$baseUrl/api/communities/questions/$questionId'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> getQuestions(int roomId, {String sortBy = 'new', int? userId}) async {
    final token = await AuthStorage.getToken();
    final query = userId != null ? '?sortBy=$sortBy&userId=$userId' : '?sortBy=$sortBy';
    final response = await http.get(Uri.parse('$baseUrl/api/communities/rooms/$roomId/questions$query'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> createQuestion({
    required int roomId,
    required String title,
    required String content,
    required int authorId,
    required String authorName,
    String? authorAvatar,
    String? pollQuestion,
    List<String>? pollOptions,
  }) async {
    final token = await AuthStorage.getToken();
    final body = jsonEncode({
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      if (authorAvatar != null) 'authorAvatar': authorAvatar,
      if (pollQuestion != null) 'pollQuestion': pollQuestion,
      if (pollOptions != null) 'pollOptions': pollOptions,
    });
    final response = await http.post(Uri.parse('$baseUrl/api/communities/rooms/$roomId/questions/create'), headers: _jsonHeaders(token: token), body: body);
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> upvoteQuestion(int questionId, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/communities/questions/$questionId/upvote'), headers: _jsonHeaders(token: token), body: jsonEncode({'userId': userId}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> downvoteQuestion(int questionId, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/communities/questions/$questionId/downvote'), headers: _jsonHeaders(token: token), body: jsonEncode({'userId': userId}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> getComments(int questionId) async {
    final token = await AuthStorage.getToken();
    final response = await http.get(Uri.parse('$baseUrl/api/communities/questions/$questionId/comments'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> addComment({
    required int questionId,
    required String content,
    required int authorId,
    required String authorName,
    String? authorAvatar,
  }) async {
    final token = await AuthStorage.getToken();
    final body = jsonEncode({
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      if (authorAvatar != null) 'authorAvatar': authorAvatar,
    });
    final response = await http.post(Uri.parse('$baseUrl/api/communities/questions/$questionId/comments/create'), headers: _jsonHeaders(token: token), body: body);
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> addReply({
    required int commentId,
    required String content,
    required int authorId,
    required String authorName,
    String? authorAvatar,
    int? parentReplyId,
  }) async {
    final token = await AuthStorage.getToken();
    final body = jsonEncode({
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      if (authorAvatar != null) 'authorAvatar': authorAvatar,
      if (parentReplyId != null) 'parentReplyId': parentReplyId,
    });
    final response = await http.post(Uri.parse('$baseUrl/api/communities/comments/$commentId/replies/create'), headers: _jsonHeaders(token: token), body: body);
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> upvoteComment(int commentId, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/communities/comments/$commentId/upvote'), headers: _jsonHeaders(token: token), body: jsonEncode({'userId': userId}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> downvoteComment(int commentId, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/communities/comments/$commentId/downvote'), headers: _jsonHeaders(token: token), body: jsonEncode({'userId': userId}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> approveQuestion(int questionId, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/communities/questions/$questionId/approve'), headers: _jsonHeaders(token: token), body: jsonEncode({'userId': userId}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> addModerator(int communityId, int moderatorId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/communities/$communityId/add-moderator'), headers: _jsonHeaders(token: token), body: jsonEncode({'moderatorId': moderatorId}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> removeModerator(int communityId, int moderatorId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/communities/$communityId/remove-moderator'), headers: _jsonHeaders(token: token), body: jsonEncode({'moderatorId': moderatorId}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> updateCommunity(int communityId, Map<String, dynamic> updates) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/communities/$communityId/update'), headers: _jsonHeaders(token: token), body: jsonEncode(updates));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> deleteCommunity(int communityId, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/communities/$communityId/delete'), headers: _jsonHeaders(token: token), body: jsonEncode({'userId': userId}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> updateQuestion(int questionId, String title, String content, {String? pollQuestion, List<String>? pollOptions}) async {
    final token = await AuthStorage.getToken();
    final body = jsonEncode({
      'title': title,
      'content': content,
      if (pollQuestion != null) 'pollQuestion': pollQuestion,
      if (pollOptions != null) 'pollOptions': pollOptions,
    });
    final response = await http.post(Uri.parse('$baseUrl/api/communities/questions/$questionId/update'), headers: _jsonHeaders(token: token), body: body);
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> deleteQuestion(int questionId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/communities/questions/$questionId/delete'), headers: _jsonHeaders(token: token));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> updateComment(int commentId, String content) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/communities/comments/$commentId/update'), headers: _jsonHeaders(token: token), body: jsonEncode({'content': content}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> deleteComment(int commentId, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/communities/comments/$commentId/delete'), headers: _jsonHeaders(token: token), body: jsonEncode({'userId': userId}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> updateReply(int replyId, String content) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/communities/replies/$replyId/update'), headers: _jsonHeaders(token: token), body: jsonEncode({'content': content}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> deleteReply(int replyId, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/communities/replies/$replyId/delete'), headers: _jsonHeaders(token: token), body: jsonEncode({'userId': userId}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> votePostPoll(int postId, int userId, int optionIndex) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/communities/questions/$postId/vote-poll'), headers: _jsonHeaders(token: token), body: jsonEncode({'userId': userId, 'optionIndex': optionIndex}));
    return _tryDecodeJson(response.body);
  }

  Future<dynamic> joinCommunityByInviteLink(int communityId, int userId) async {
    final token = await AuthStorage.getToken();
    final response = await http.post(Uri.parse('$baseUrl/api/communities/$communityId/join-invite'), headers: _jsonHeaders(token: token), body: jsonEncode({'userId': userId}));
    return _tryDecodeJson(response.body);
  }
}

class AuthStorage {
  static const String _tokenKey = 'auth_token';
  static String? token;

  static String? normalizeToken(String? rawToken) {
    if (rawToken == null) return null;

    final trimmed = rawToken.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return null;
    }

    final bearerPrefix = RegExp(r'^bearer\s+', caseSensitive: false);
    final normalized = trimmed.replaceFirst(bearerPrefix, '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  static Future<void> setToken(String newToken) async {
    final normalized = normalizeToken(newToken);
    if (normalized == null) return;

    token = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, normalized);
  }

  static Future<String?> getToken() async {
    final memoryToken = normalizeToken(token);
    if (memoryToken != null) {
      token = memoryToken;
      return memoryToken;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedToken = normalizeToken(prefs.getString(_tokenKey));
    token = storedToken;
    return token;
  }

  static Future<void> clearToken() async {
    token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
