import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sophia_path/services/course/database_helper.dart';
import '../models/user/user.dart';
import '../services/course/scores_repo.dart';
import '../services/user_preferences_services.dart';
import '../navigation_screen.dart';
import '../services/course/user_stats_service.dart';

class UserProfileScreen extends StatefulWidget {
  final bool isEditing;
  final VoidCallback onToggleTheme;

  const UserProfileScreen({
    super.key,
    this.isEditing = false,
    required this.onToggleTheme,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _userService = UserPreferencesService.instance;
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _tagController = TextEditingController();
  final _ageController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  String? _selectedGender;
  String _profileImage = '';

  final List<String> _availableTags = [
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

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    final user = await _userService.getUser();
    if (user != null) {
      _usernameController.text = user.username;
      _fullNameController.text = user.fullName;
      _tagController.text = user.tag;
      _ageController.text = user.age.toString();
      _selectedGender = user.sex;
      _profileImage = user.profileImage;
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

    if (picked != null) {
      setState(() => _profileImage = picked.path);
    }
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = User(
      username: _usernameController.text.trim(),
      fullName: _fullNameController.text.trim(),
      tag: _tagController.text.trim(),
      age: int.tryParse(_ageController.text) ?? 0,
      sex: _selectedGender!,
      profileImage: _profileImage.isEmpty
          ? 'https://cdn.wallpapersafari.com/95/19/uFaSYI.jpg'
          : _profileImage,
      achievementsProgress: List.filled(13, 0.0),
      registeredCourses: [],
      registedCoursesIndexes: [],
    );

    final saved = await _userService.saveUser(user);

    setState(() => _isLoading = false);

    if (!saved || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditing
              ? 'Profile updated successfully'
              : 'Welcome ${user.username}',
        ),
        backgroundColor: Colors.green,
      ),
    );

    if (widget.isEditing) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (ctx) {
            return NavigationScreen(
              onToggleTheme: widget.onToggleTheme,
              selectedIndex: 1,
            );
          },
        ),
      );
    } else {
      await _userService.setFirstLaunchCompleted();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => NavigationScreen(onToggleTheme: widget.onToggleTheme),
        ),
      );
    }
  }

  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);
    await _userService.clearAllData();
    final service = UserStatsService();
    await service.resetAllProgress();
    await ScoresRepository.clearScores();

    final DatabaseService dbService = DatabaseService();
    final courses = await dbService.getCourses();
    for (var course in courses) {
      if (course.id != null) {
        await dbService.deleteCourse(course.id!);
      }
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account and all progress deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          isEditing: false,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
      (route) => false,
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Delete Account',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This action is permanent and cannot be undone.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteAccount();
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: () => _showImageSourceDialog(),
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.blue,
            child: ClipOval(
              child: _profileImage.isEmpty
                  ? const Icon(Icons.person, size: 60)
                  : _profileImage.startsWith('http')
                  ? Image.network(_profileImage, fit: BoxFit.cover)
                  : Image.file(File(_profileImage), fit: BoxFit.cover),
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

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Choose Image Source'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            child: const Text('Gallery'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
            child: const Text('Camera'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Profile' : 'Complete Profile',
          style: GoogleFonts.poppins(),
        ),
        leading: widget.isEditing
            ? IconButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) {
                        return NavigationScreen(
                          onToggleTheme: widget.onToggleTheme,
                          selectedIndex: 1,
                        );
                      },
                    ),
                  );
                },
                icon: Icon(Icons.arrow_back),
              )
            : Container(),
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
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (v) => v == null || v.isEmpty
                          ? "Please enter a valid username"
                          : v.length < 3
                          ? 'Invalid username'
                          : null,
                      // todo : when we create database,check if username already exists, show : username exists
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (v) => v == null || v.isEmpty
                          ? "Please enter a valid Name"
                          : v.length < 3
                          ? 'Invalid Name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age'),
                      validator: (v) => v == null
                          ? 'Please enter a value'
                          : int.tryParse(v) == null
                          ? 'Please enter a valid number'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _selectedGender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: ['Male', 'Female', 'Rather not say']
                          .map(
                            (g) => DropdownMenuItem(value: g, child: Text(g)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedGender = v!),
                      validator: (v) =>
                          v == null ? "Please Select a Gender" : null,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _tagController.text.isEmpty
                          ? null
                          : _tagController.text,
                      decoration: const InputDecoration(
                        labelText: 'Profession',
                      ),
                      items: _availableTags
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) => _tagController.text = v!,
                      validator: (v) => v == null || v.isEmpty
                          ? "Please Select a Profession"
                          : null,
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveUser,
                        child: Text(
                          widget.isEditing ? 'Update Profile' : 'Get Started',
                        ),
                      ),
                    ),

                    if (widget.isEditing) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: OutlinedButton(
                          onPressed: _showDeleteConfirmation,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Delete Account',
                            style: TextStyle(color: Colors.red, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
