import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sophia_path/screens/authentication/login_screen.dart';
import 'dart:io';
import '../models/user/user.dart';
import '../services/course/database_helper.dart';
import '../services/course/scores_repo.dart';
import '../services/course/user_stats_service.dart';
import '../services/user_preferences_services.dart';
import '../navigation_screen.dart';

class MyAuthScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isEditing;
  const MyAuthScreen({
    super.key,
    required this.onToggleTheme,
    this.isEditing = false,
  });

  @override
  State<MyAuthScreen> createState() => _MyAuthScreenState();
}

class _MyAuthScreenState extends State<MyAuthScreen> {
  final _userService = UserPreferencesService.instance;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isSigningIn = false;
  String? _errorMessage;
  String? _selectedGender;
  String _profileImage = '';
  String? _firebaseUid;

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
      _loadUserDataForEditing();
    } else {
      _checkExistingUser();
    }
  }

  Future<void> _loadUserDataForEditing() async {
    setState(() => _isLoading = true);

    final user = await _userService.getUser();
    if (user != null) {
      _usernameController.text = user.username;
      _fullNameController.text = user.fullName;
      _tagController.text = user.tag;
      _ageController.text = user.age.toString();
      _selectedGender = user.sex;
      _profileImage = user.profileImage;
      _firebaseUid = user.firebaseUid;
    }

    setState(() => _isLoading = false);
  }

  Future<void> _checkExistingUser() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;

    if (user != null) {
      _firebaseUid = user.uid;

      final existingUser = await _userService.getUser();
      if (existingUser != null && mounted) {
        _navigateToHomeScreen();
      }
    }
  }

  // DELETE ACCOUNT METHODS
  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);

    try {
      // 1. Clear local user data
      await _userService.clearAllData();

      // 2. Reset stats & scores
      try {
        final service = UserStatsService();
        await service.resetAllProgress();
        await ScoresRepository.clearScores();
      } catch (e) {
        debugPrint("Stats reset error: $e");
      }

      // 3. Sign out (important!)
      await firebase_auth.FirebaseAuth.instance.signOut();

      setState(() => _isLoading = false);

      if (!mounted) return;

      // 4. Navigate to registration screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => MyAuthScreen(
            onToggleTheme: widget.onToggleTheme,
            isEditing: false,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      setState(() => _isLoading = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Your profile information'),
            Text('• All your progress and scores'),
            Text('• Your learning history'),
            SizedBox(height: 16),
            Text(
              'This action cannot be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteAccount();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createOrUpdateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      // If editing, we already have Firebase UID
      if (!widget.isEditing && _firebaseUid == null) {
        final username = normalizeUsername(_usernameController.text);
        firebase_auth.UserCredential credential;
        firebase_auth.User firebaseUser;

        // 🔐 EMAIL + PASSWORD
        if (_emailController.text.isNotEmpty &&
            _passwordController.text.isNotEmpty) {
          credential = await firebase_auth.FirebaseAuth.instance
              .createUserWithEmailAndPassword(
                email: _emailController.text.trim(),
                password: _passwordController.text.trim(),
              );
        }
        // 👤 ANONYMOUS
        else {
          credential = await firebase_auth.FirebaseAuth.instance
              .signInAnonymously();
        }

        firebaseUser = credential.user!;
        _firebaseUid = firebaseUser.uid;

        // Reserve username in Firestore
        await _reserveUsername(username, firebaseUser.uid);

        await _storeUserInFirestore(
          firebaseUser.uid,
          isAnonymous: firebaseUser.isAnonymous,
        );
      } else if (widget.isEditing && _firebaseUid != null) {
        // Update Firestore for editing
        await _updateUserInFirestore(_firebaseUid!);
      }

      // 3. Create/Update local user profile
      final localUser = User(
        uid: _firebaseUid, // Use Firebase UID as local ID
        firebaseUid: _firebaseUid,
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

      // 4. Save user to local database
      final saved = await _userService.saveUser(localUser);

      if (!saved) {
        throw Exception("Failed to save user locally");
      }

      // 5. Set first launch completed (only for new users)
      if (!widget.isEditing) {
        await _userService.setFirstLaunchCompleted();
      }

      print(
        "Profile ${widget.isEditing ? 'updated' : 'created'} successfully for UID: $_firebaseUid",
      );

      // 6. Navigate to main app
      _navigateToHomeScreen();
    } on firebase_auth.FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "Authentication failed";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "An unexpected error occurred: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isSigningIn = false;
      });
    }
  }

  String normalizeUsername(String input) {
    return input.trim().toLowerCase();
  }

  Future<void> _reserveUsername(String username, String uid) async {
    final ref = FirebaseFirestore.instance
        .collection('usernames')
        .doc(username);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snapshot = await tx.get(ref);

      if (snapshot.exists) {
        throw Exception('Username already taken');
      }

      tx.set(ref, {'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
    });
  }

  Future<void> _storeUserInFirestore(
    String uid, {
    required bool isAnonymous,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'username': _usernameController.text.trim(),
      'fullName': _fullNameController.text.trim(),
      'tag': _tagController.text.trim(),
      'age': int.tryParse(_ageController.text) ?? 0,
      'sex': _selectedGender,
      'email': isAnonymous ? null : _emailController.text.trim(),
      'isAnonymous': isAnonymous,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateUserInFirestore(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'username': _usernameController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'tag': _tagController.text.trim(),
        'age': int.tryParse(_ageController.text) ?? 0,
        'sex': _selectedGender,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print("User data updated in Firestore for UID: $uid");
    } catch (e) {
      print("Firestore update error: $e");
    }
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

  void _navigateToHomeScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            NavigationScreen(onToggleTheme: widget.onToggleTheme),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Profile' : 'Create Your Profile',
          style: GoogleFonts.poppins(),
        ),
        leading: widget.isEditing
            ? IconButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => NavigationScreen(
                        onToggleTheme: widget.onToggleTheme,
                        selectedIndex: 1,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_back),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // if (!widget.isEditing) ...[
                    //   const SizedBox(height: 20),
                    //   const Text(
                    //     'Welcome! Create your account',
                    //     style: TextStyle(fontSize: 18),
                    //     textAlign: TextAlign.center,
                    //   ),
                    //   const SizedBox(height: 30),
                    // ],
                    _buildAvatar(),
                    const SizedBox(height: 30),
                    if (!widget.isEditing) ...[
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Enter a valid email'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.length < 6
                            ? 'Min 6 characters'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? "Please enter a valid username"
                          : v.length < 3
                          ? 'Username must be at least 3 characters'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? "Please enter a valid Name"
                          : v.length < 3
                          ? 'Name must be at least 3 characters'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Please enter your age'
                          : int.tryParse(v) == null
                          ? 'Please enter a valid number'
                          : int.parse(v) < 5 || int.parse(v) > 120
                          ? 'Please enter a valid age (5-120)'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Male', 'Female', 'Rather not say']
                          .map(
                            (g) => DropdownMenuItem(value: g, child: Text(g)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedGender = v!),
                      validator: (v) =>
                          v == null ? "Please select a gender" : null,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _tagController.text.isEmpty
                          ? null
                          : _tagController.text,
                      decoration: const InputDecoration(
                        labelText: 'Profession',
                        border: OutlineInputBorder(),
                      ),
                      items: _availableTags
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) => _tagController.text = v!,
                      validator: (v) => v == null || v.isEmpty
                          ? "Please select a profession"
                          : null,
                    ),

                    const SizedBox(height: 20),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSigningIn ? null : _createOrUpdateProfile,
                        child: _isSigningIn
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    widget.isEditing
                                        ? 'Updating...'
                                        : 'Creating Account...',
                                  ),
                                ],
                              )
                            : Text(
                                widget.isEditing
                                    ? 'Update Profile'
                                    : 'Create Account & Continue',
                              ),
                      ),
                    ),

                    if (!widget.isEditing) ...[
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LoginScreen(
                                onToggleTheme: widget.onToggleTheme,
                              ),
                            ),
                          );
                        },
                        child: const Text('Already have an account? Login'),
                      ),
                    ],

                    if (!widget.isEditing) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 10),
                      Text(
                        'By continuing, you agree to our Terms of Service and Privacy Policy',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (widget.isEditing) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: OutlinedButton(
                          onPressed: _showDeleteConfirmation,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
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
