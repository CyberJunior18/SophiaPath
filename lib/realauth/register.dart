import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sophia_path/realauth/login.dart';
import 'dart:io';
import '../navigation_screen.dart';
import 'authService.dart';

class RegisterScreen extends StatefulWidget {
  final bool isEditing;
  const RegisterScreen({super.key, this.isEditing = false});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Add this line
  final String baseUrl = kIsWeb
      ? 'http://localhost:3000' // For web
      : Platform.isAndroid
      ? 'http://localhost:3000' // For Android emulator
      : 'http://localhost:3000'; // For Linux desktop or iOS simulator
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _successMessage;
  String? _selectedGender;
  String _profileImage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _tagController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    final result = await _authService.register(
      email: _emailController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    setState(() {
      _isLoading = true;
    });
    if (result['success'] == true) {
      setState(() {
        _successMessage = 'Account created! Please Login.';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) {
              return const LoginScreen();
            },
          ),
        );
      }
    } else {
      setState(() {
        _errorMessage = result['message'];
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      // _loadUserDataForEditing();
    } else {
      // _checkExistingUser();
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
          if (!kIsWeb)
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
                  : kIsWeb
                  ? const Icon(
                      Icons.person,
                      size: 60,
                    ) // Web doesn't support Image.file
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Profile' : 'Create Your Account',
          style: GoogleFonts.poppins(),
        ),
        centerTitle: true,
      ),

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
                        onPressed: _isLoading ? null : _handleSignup,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
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
                          // Around line where you have the login TextButton
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LoginScreen(),
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
                          onPressed: () {},
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
