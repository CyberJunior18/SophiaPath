import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registration failed',
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

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token =
            data['accessToken'] ?? data['token'] ?? data['access_token'];
        if (token != null) {
          // Store the token (in memory for now — use shared_preferences for persistence)
          AuthStorage.token = token;
          return {'success': true, 'token': token};
        } else {
          return {'success': false, 'message': 'Token not found in response'};
        }
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ─── GET PROFILE ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getProfile() async {
    final url = Uri.parse('$baseUrl/auth/profile');

    if (AuthStorage.token == null) {
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
          'Authorization': 'Bearer ${AuthStorage.token}',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else if (response.statusCode == 401) {
        AuthStorage.token = null; // Token expired or invalid
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

  // ─── LOGOUT ──────────────────────────────────────────────────────────────────
  void logout() {
    AuthStorage.token = null;
  }
}

// Simple in-memory token storage
// Replace with shared_preferences or flutter_secure_storage for persistence
class AuthStorage {
  static String? token;
}
