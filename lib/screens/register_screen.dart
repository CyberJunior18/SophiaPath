import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'authentication/login_screen.dart';
import 'dart:io';
import '../models/user/user.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isSigningIn = false;
  String? _errorMessage;
  String? _selectedGender;
  String _profileImage = '';
  String? _firebaseUid;

  // Add this flag
  final bool _useFirestore = false; // Set to true after you set up Firestore

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

      // Try to get email from auth
      if (user.email != null) {
        _emailController.text = user.email!;
      }

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
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        // Only delete from Firestore if enabled
        if (_useFirestore) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .delete();

            // Delete username reservation
            final username = await _userService.getUser();
            if (username != null) {
              await FirebaseFirestore.instance
                  .collection('usernames')
                  .doc(normalizeUsername(username.username))
                  .delete();
            }
          } catch (e) {
            print('Firestore delete error (ignored): $e');
          }
        }

        // Delete Firebase Auth account
        await currentUser.delete();
      }

      // Clear local data
      await _userService.clearAllData();

      // Reset stats
      try {
        final service = UserStatsService();
        await service.resetAllProgress();
        await ScoresRepository.clearScores();
      } catch (e) {
        debugPrint("Stats reset error: $e");
      }

      setState(() => _isLoading = false);

      if (!mounted) return;

      // Navigate to registration screen
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
    } on firebase_auth.FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);

      if (e.code == 'requires-recent-login') {
        // Re-authenticate needed
        if (!mounted) return;

        await _showReauthenticateDialog();
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showReauthenticateDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Re-authentication Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter your credentials to delete your account.'),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final user = firebase_auth.FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final credential = firebase_auth.EmailAuthProvider.credential(
                    email: emailController.text,
                    password: passwordController.text,
                  );
                  await user.reauthenticateWithCredential(credential);
                  Navigator.pop(context);
                  await _deleteAccount();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Authentication failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
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

  String _getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'email-already-in-use':
        return 'This email is already registered. Please login instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password authentication is not enabled.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  Future<void> _createOrUpdateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      if (!widget.isEditing) {
        // 🔐 EMAIL + PASSWORD ONLY (No anonymous)
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        // Validate email and password for new users
        if (email.isEmpty || password.isEmpty) {
          throw Exception('Email and password are required');
        }
        // Create user with email/password
        final credential = await firebase_auth.FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        final firebaseUser = credential.user!;
        _firebaseUid = firebaseUser.uid;
        await _storeUserInFirestore(firebaseUser.uid);
        // _firestore.collection("Users").doc(_firebaseUid).set({
        //   'uid': _firebaseUid,
        //   'email': email,
        // });

        // Reserve username (skip if Firestore not enabled)
        if (_useFirestore) {
          await _reserveUsername(
            normalizeUsername(_usernameController.text),
            firebaseUser.uid,
          );
        }

        // Store user in Firestore (skip if not enabled)
        if (_useFirestore) {
          await _storeUserInFirestore(firebaseUser.uid);
        }
      } else if (widget.isEditing && _firebaseUid != null) {
        // Update existing user (skip if Firestore not enabled)
        if (_useFirestore) {
          await _updateUserInFirestore(_firebaseUid!);
        }
      }

      // Create/Update local user profile
      final localUser = User(
        uid: _firebaseUid,
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

      // Save user to local database
      final saved = await _userService.saveUser(localUser);
      if (!saved) {
        throw Exception("Failed to save user locally");
      }

      // Set first launch completed (only for new users)
      if (!widget.isEditing) {
        await _userService.setFirstLaunchCompleted();
      }

      print(
        "Profile ${widget.isEditing ? 'updated' : 'created'} successfully for UID: $_firebaseUid",
      );

      // Navigate to main app
      _navigateToHomeScreen();
    } on firebase_auth.FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getAuthErrorMessage(e.code);
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
    try {
      final ref = FirebaseFirestore.instance
          .collection('usernames')
          .doc(username);

      final snapshot = await ref.get();

      if (snapshot.exists) {
        throw Exception('Username "$username" is already taken');
      }

      await ref.set({'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Error reserving username: $e');
      rethrow;
    }
  }

  Future<void> _storeUserInFirestore(String uid) async {
    try {
      final userData = {
        'uid': uid,
        'username': _usernameController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'tag': _tagController.text.trim(),
        'age': int.tryParse(_ageController.text) ?? 0,
        'sex': _selectedGender,
        'email': _emailController.text.trim(),
        'profileImage': _profileImage.isEmpty
            ? 'https://cdn.wallpapersafari.com/95/19/uFaSYI.jpg'
            : _profileImage,
        'achievementsProgress': List.filled(13, 0.0),
        'registeredCourses': [],
        'registedCoursesIndexes': {},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      };

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .set(userData); // stores data in firebase database called Users

      print('✅ User saved to Firestore successfully with all data');
    } catch (e) {
      print('Error saving to Firestore: $e');
      rethrow;
    }
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
      rethrow;
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
      appBar: widget.isEditing
          ? AppBar(
              title: Text(
                widget.isEditing ? 'Edit Profile' : 'Create Your Account',
                style: GoogleFonts.poppins(),
              ),
              centerTitle: true,
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
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (!widget.isEditing) ...[
                      const SizedBox(height: 40),
                      const Text(
                        'Welcome! Create your account',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (widget.isEditing) _buildAvatar(),
                    const SizedBox(height: 30),

                    // 🔐 EMAIL FIELD (Always visible for new users)
                    if (!widget.isEditing)
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Email is required';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),

                    if (!widget.isEditing) const SizedBox(height: 16),

                    // 🔐 PASSWORD FIELD (Always visible for new users)
                    if (!widget.isEditing)
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true, // make password points (hidden)
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),

                    if (!widget.isEditing) const SizedBox(height: 16),
                    // if (widget.isEditing) ...[
                    //   const Divider(),
                    //   const SizedBox(height: 10),

                    //   const Text(
                    //     'Profile Information',
                    //     style: TextStyle(
                    //       fontSize: 18,
                    //       fontWeight: FontWeight.bold,
                    //     ),
                    //   ),
                    //   const SizedBox(height: 20),
                    // ],

                    // Username field
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Username is required';
                        }
                        if (value.length < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
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
                        prefixIcon: Icon(Icons.calendar_today),
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
                      initialValue: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
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
                      initialValue:
                          _tagController.text.isEmpty ||
                              _tagController.text == "Member"
                          ? null
                          : _tagController.text,
                      decoration: const InputDecoration(
                        labelText: 'Profession',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.work),
                      ),
                      items: _availableTags
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) => _tagController.text = v!,
                      validator: (v) =>
                          v == null ||
                              v.isEmpty ||
                              _tagController.text ==
                                  "Member" // to fix a bug that happened , we could add type Member later on
                          ? "Please select a profession"
                          : null,
                    ),

                    // const SizedBox(height: 20),
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // // Add this note about Firestore
                    // // if (!_useFirestore && !widget.isEditing)
                    // //   Container(
                    // //     padding: const EdgeInsets.all(12),
                    // //     margin: const EdgeInsets.only(bottom: 10),
                    // //     decoration: BoxDecoration(
                    // //       color: Colors.amber.shade50,
                    // //       borderRadius: BorderRadius.circular(8),
                    // //       border: Border.all(color: Colors.amber.shade200),
                    // //     ),
                    // //     child: Row(
                    // //       children: [
                    // //         const Icon(Icons.info, color: Colors.amber),
                    // //         const SizedBox(width: 10),
                    // //         Expanded(
                    // //           child: Text(
                    // //             'Note: Cloud sync is disabled. Set up Firestore to enable data backup.',
                    // //             style: TextStyle(color: Colors.amber.shade800),
                    // //           ),
                    // //         ),
                    // //       ],
                    // //     ),
                    // //   ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSigningIn ? null : _createOrUpdateProfile,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSigningIn
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.isEditing
                                    ? 'Update Profile'
                                    : 'Create Account',
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    if (!widget.isEditing) ...[
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Already have an account?'),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LoginScreen(
                                    onToggleTheme: widget.onToggleTheme,
                                  ),
                                ),
                              );
                            },
                            child: const Text('Login'),
                          ),
                        ],
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
