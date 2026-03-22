import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Use 10.0.2.2 for Android emulator to reach localhost on your PC
  // If using a real device, replace with your PC's local IP e.g. http://192.168.1.x:3000
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000';

    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3000'
        : 'http://localhost:3000';
  }

  // ─── REGISTER ───────────────────────────────────────────────────────────────
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

  // ─── LOGIN ───────────────────────────────────────────────────────────────────
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
              backendMessage ??
              'Login failed (HTTP ${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ─── GET PROFILE ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getProfile() async {
    final url = Uri.parse('$baseUrl/auth/profile');
    final token = await AuthStorage.getToken();

    if (token == null) {
      return {
        'success': false,
        'message': 'No token found. Please login again.',
      };
    }

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else if (response.statusCode == 401) {
        await AuthStorage.clearToken();
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to load profile',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ─── UPDATE PROFILE ──────────────────────────────────────────────────────────
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

  // ─── LOGOUT ──────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await AuthStorage.clearToken();
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
