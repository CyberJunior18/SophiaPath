import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sophia_path/models/course/course_info.dart';
import 'package:sophia_path/models/course/lesson.dart';

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

  Future<Map<String, dynamic>> updateProfile({
    required String username,
    required String fullname,
    required String tag,
    required String gender,
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

  //   Future<Map<String, dynamic>> registerCourse({
  //     required String  courseID
  //   }) async {
  //     final url = Uri.parse('$baseUrl/courses/me/register/$courseID');
  //     final token = await AuthStorage.getToken();
  //    try{
  // final response = await http.patch(
  //         url,
  //         headers: {
  //           'Content-Type': 'application/json',
  //           'Authorization': 'Bearer $token',
  //         },
  //         body: jsonEncode({
  //           'username': username,
  //         }),
  //       );
  //    }
  //    catch(e){

  //    }
  //   }
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
