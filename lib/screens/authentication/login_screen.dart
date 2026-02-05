import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sophia_path/models/user/user.dart';
import 'package:sophia_path/navigation_screen.dart';
import 'package:sophia_path/screens/register_screen.dart';
import 'package:sophia_path/services/user_preferences_services.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const LoginScreen({super.key, required this.onToggleTheme});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final credential = await firebase_auth.FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final user = credential.user!;
      final uid = user.uid;

      // 🔹 TRY to load user profile from Firestore (but don't fail if it doesn't exist)
      User? localUser;
      _firestore.collection("Users").doc(uid).set({
        'uid': uid,
        'email': user.email,
      });
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          localUser = User(
            uid: uid,
            firebaseUid: uid,
            username:
                data['username'] ?? user.email?.split('@').first ?? 'User',
            fullName: data['fullName'] ?? 'User',
            tag: data['tag'] ?? 'Student',
            age: data['age'] ?? 0,
            sex: data['sex'] ?? 'Rather not say',
            profileImage:
                data['profileImage'] ??
                'https://cdn.wallpapersafari.com/95/19/uFaSYI.jpg',
            achievementsProgress: List.filled(13, 0.0),
            registeredCourses: [],
            registedCoursesIndexes: [],
          );
        }
      } catch (e) {
        print('Firestore load failed (continuing anyway): $e');
      }

      // 🔹 If Firestore failed or profile doesn't exist, create a basic one
      if (localUser == null) {
        print('Creating basic user profile from Firebase Auth data');
        localUser = User(
          uid: uid,
          firebaseUid: uid,
          username:
              user.email?.split('@').first ?? 'user_${uid.substring(0, 6)}',
          fullName: user.displayName ?? 'User',
          tag: 'Student',
          age: 21,
          sex: 'Rather not say',
          profileImage: 'https://cdn.wallpapersafari.com/95/19/uFaSYI.jpg',
          achievementsProgress: List.filled(13, 0.0),
          registeredCourses: [],
          registedCoursesIndexes: [],
        );
      }

      // 🔹 Save locally
      await UserPreferencesService.instance.saveUser(localUser);
      await UserPreferencesService.instance.setFirstLaunchCompleted();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => NavigationScreen(onToggleTheme: widget.onToggleTheme),
        ),
        (_) => false,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'No account found with this email';
          break;
        case 'wrong-password':
          msg = 'Incorrect password';
          break;
        case 'invalid-email':
          msg = 'Invalid email format';
          break;
        default:
          msg = e.message ?? 'Login failed';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Login'),
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.brightness_6),
      //       onPressed: widget.onToggleTheme,
      //     ),
      //   ],
      // ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Welcome back',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),

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
                  obscureText: true, // make it points
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Login'),
                  ),
                ),
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
                            builder: (_) => MyAuthScreen(
                              onToggleTheme: widget.onToggleTheme,
                            ),
                          ),
                        );
                      },
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
