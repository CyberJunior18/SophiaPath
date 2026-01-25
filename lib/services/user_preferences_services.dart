// services/user_preferences_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user/user.dart';

class UserPreferencesService {
  UserPreferencesService._privateConstructor();
  static final UserPreferencesService instance =
      UserPreferencesService._privateConstructor();

  static const String _userKey = 'user_data';
  static const String _isFirstLaunchKey = 'is_first_launch';
  static const String _themeKey = 'theme_preference';

  Future<bool> saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userMap = user.toMap();

      userMap['achievementsScores'] = jsonEncode(user.achievementsProgress);
      userMap['registedCoursesIndexes'] = jsonEncode(
        user.registedCoursesIndexes,
      );

      final userJson = jsonEncode(userMap);
      return await prefs.setString(_userKey, userJson);
    } catch (e) {
      return false;
    }
  }

  Future<User?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);

      if (userJson == null || userJson.isEmpty) {
        return null;
      }

      final userMap = jsonDecode(userJson) as Map<String, dynamic>;

      return User(
        username: userMap['username'] ?? '',
        fullName: userMap['firstName'] ?? '',
        tag: userMap['tag'] ?? '',
        age: userMap['age'] ?? 0,
        sex: userMap['gender'] ?? '',
        profileImage: userMap['profilePicture'] ?? '',
        achievementsProgress: userMap['achievementsScores'] != null
            ? (jsonDecode(userMap['achievementsScores']) as List)
                  .map((e) => (e as num).toDouble())
                  .toList()
            : [],
        registeredCourses: [],
        registedCoursesIndexes: userMap['registedCoursesIndexes'] != null
            ? (jsonDecode(userMap['registedCoursesIndexes']) as List)
                  .map((e) => (e as num).toInt())
                  .toList()
            : [],
      );
    } catch (e) {
      return null;
    }
  }

  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstLaunchKey) ?? true;
  }

  Future<void> setFirstLaunchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstLaunchKey, false);
  }

  Future<bool> hasUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_userKey);
  }

  Future<bool> deleteUser() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove(_userKey);
  }

  Future<bool> updateUser({
    String? username,
    String? firstName,
    String? tag,
    int? age,
    String? gender,
    String? profilePicture,
    List<double>? achievementsScores,
    List<int>? registedCoursesIndexes,
  }) async {
    try {
      final currentUser = await getUser();
      if (currentUser == null) return false;

      final updatedUser = currentUser.copyWith(
        username: username,
        firstname: firstName,
        tag: tag,
        age: age,
        gender: gender,
        profilePicture: profilePicture,
        achievementsScores: achievementsScores,
        registedCoursesIndexes: registedCoursesIndexes,
      );

      return await saveUser(updatedUser);
    } catch (e) {
      return false;
    }
  }

  Future<void> saveThemePreference(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDarkMode);
  }

  Future<bool> getThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? false;
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_themeKey);
    await prefs.setBool(_isFirstLaunchKey, true);
  }
}
