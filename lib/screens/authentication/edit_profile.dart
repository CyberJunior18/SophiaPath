import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../models/user/user.dart';
import '../../services/profile_state.dart';
import '../../services/user_preferences_services.dart';
import 'authService.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserPreferencesService.instance;
  final _authService = AuthService();
  final _picker = ImagePicker();

  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _tagController = TextEditingController();
  final _ageController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String _profileImage = '';
  String _selectedGender = 'Rather Not Say';

  final List<String> _availableTags = const [
    'Student',
    'Software Engineer',
    'Teacher',
    'Developer',
    'Designer',
    'Researcher',
    'Entrepreneur',
    'Freelancer',
    'Manager',
    'Other',
  ];

  static const String _genderMale = 'Male';
  static const String _genderFemale = 'Female';
  static const String _genderRatherNotSay = 'Rather Not Say';

  String _normalizeGender(String? value) {
    final normalized = value?.trim().toLowerCase();
    switch (normalized) {
      case 'male':
        return _genderMale;
      case 'female':
        return _genderFemale;
      case 'rather not say':
        return _genderRatherNotSay;
      default:
        return _genderRatherNotSay;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _tagController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = await _userService.getUser();

    if (!mounted) return;

    if (user != null) {
      _usernameController.text = user.username;
      _fullNameController.text = user.fullName;
      _tagController.text = user.tag;
      _ageController.text = user.age.toString();
      _selectedGender = _normalizeGender(user.sex);
      _profileImage = user.profileImage;
    } else {
      _tagController.text = 'Student';
      _ageController.text = '20';
      _selectedGender = _genderRatherNotSay;
      _profileImage = User.defaultProfileImage;
    }

    setState(() => _isLoading = false);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 800,
      maxHeight: 800,
    );

    if (picked == null) return;

    var finalPath = picked.path;

    if (!kIsWeb) {
      finalPath = await _persistPickedImage(picked.path);
    }

    if (mounted) {
      setState(() => _profileImage = finalPath);
    }
  }

  Future<String> _persistPickedImage(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return sourcePath;

    final appDir = await getApplicationDocumentsDirectory();
    final profileDir = Directory(p.join(appDir.path, 'profile_images'));
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }

    final extension = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    final fileName =
        'profile_${DateTime.now().millisecondsSinceEpoch}$extension';
    final targetPath = p.join(profileDir.path, fileName);

    final copiedFile = await sourceFile.copy(targetPath);
    return copiedFile.path;
  }

  void _showImageSourceDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose image source'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _pickImage(ImageSource.gallery);
            },
            child: const Text('Gallery'),
          ),
          if (!kIsWeb)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _pickImage(ImageSource.camera);
              },
              child: const Text('Camera'),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final image = _profileImage.trim();

    return GestureDetector(
      onTap: _showImageSourceDialog,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.blue.shade50,
            child: ClipOval(
              child: image.isEmpty
                  ? const Icon(Icons.person, size: 60, color: Colors.blue)
                  : image.startsWith('http')
                  ? Image.network(
                      image,
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.blue,
                      ),
                    )
                  : kIsWeb
                  ? const Icon(Icons.person, size: 60, color: Colors.blue)
                  : Image.file(
                      File(image),
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.blue,
                      ),
                    ),
            ),
          ),
          const Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final backendResult = await _authService.updateProfile(
        username: _usernameController.text.trim(),
        fullname: _fullNameController.text.trim(),
        tag: _tagController.text.trim(),
        gender: _normalizeGender(_selectedGender),
      );

      if (backendResult['success'] != true) {
        final message =
            backendResult['message']?.toString() ?? 'Failed to update profile.';

        if (message.contains('No token found') ||
            message.contains('Session expired')) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please login again.'),
            ),
          );
          Navigator.of(context).pop();
          return;
        }

        if (!mounted) return;
        setState(() => _errorMessage = message);
        return;
      }

      final existingUser = await _userService.getUser();
      final updatedUser = User(
        username: _usernameController.text.trim(),
        fullName: _fullNameController.text.trim(),
        tag: _tagController.text.trim(),
        age:
            int.tryParse(_ageController.text.trim()) ?? existingUser?.age ?? 20,
        sex: _normalizeGender(_selectedGender),
        profileImage: _profileImage.isEmpty
            ? existingUser?.profileImage ?? User.defaultProfileImage
            : _profileImage,
        achievementsProgress:
            existingUser?.achievementsProgress ?? List<double>.filled(13, 0),
        registeredCourses: existingUser?.registeredCourses ?? const [],
        registedCoursesIndexes:
            existingUser?.registedCoursesIndexes ?? const [],
      );

      final saved = await _userService.saveUser(updatedUser);
      if (!saved) {
        throw Exception('Failed to save local profile data.');
      }

      if (!mounted) return;
      await context.read<ProfileState>().updateProfile(updatedUser);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'An unexpected error occurred: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile', style: GoogleFonts.poppins()),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildAvatar(),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Username is required';
                        }
                        if (value.trim().length < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        if (!RegExp(
                          r'^[a-zA-Z0-9_]+$',
                        ).hasMatch(value.trim())) {
                          return 'Only letters, numbers, and underscores allowed';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a valid name';
                        }
                        if (value.trim().length < 3) {
                          return 'Name must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      validator: (value) {
                        final age = int.tryParse(value?.trim() ?? '');
                        if (age == null) return 'Please enter a valid number';
                        if (age < 5 || age > 120) {
                          return 'Please enter a valid age (5-120)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items:
                          const [
                            _genderMale,
                            _genderFemale,
                            _genderRatherNotSay,
                          ].map((gender) {
                            return DropdownMenuItem(
                              value: gender,
                              child: Text(gender),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedGender = value);
                      },
                      validator: (value) =>
                          value == null ? 'Please select a gender' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _availableTags.contains(_tagController.text)
                          ? _tagController.text
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Profession',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.work),
                      ),
                      items: _availableTags.map((tag) {
                        return DropdownMenuItem(value: tag, child: Text(tag));
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        _tagController.text = value;
                      },
                      validator: (value) => value == null || value.isEmpty
                          ? 'Please select a profession'
                          : null,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Update Profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
