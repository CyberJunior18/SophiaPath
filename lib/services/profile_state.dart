import 'package:flutter/material.dart';
import 'package:sophia_path/services/user_preferences_services.dart';

import '../models/user/user.dart';

class ProfileState extends ChangeNotifier {
  User? _currentUser;
  final UserPreferencesService _userService = UserPreferencesService.instance;

  User? get currentUser => _currentUser;

  ProfileState() {
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    _currentUser = await _userService.getUser();
    notifyListeners(); // so ui updates automatically
  }

  Future<void> refreshUser() async {
    await _loadUserData();
  }

  Future<void> updateProfile(User user) async {
    await _userService.saveUser(user);
    _currentUser = user;
    notifyListeners();
  }
}
// to use , just  profileState = context.read<ProfileState>() 