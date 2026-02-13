import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/course/course_info.dart';
import '../../models/data.dart';
import '../../models/user/user.dart';
import '../../navigation_screen.dart';
import '../register_screen.dart';
import '../../services/user_preferences_services.dart';

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

      // 🔹 FIRST: Try to get user data from Firestore
      User? localUser;

      try {
        // IMPORTANT: Use consistent collection name (either 'Users' or 'users')
        // Based on your registration, you're using 'Users' (capital U)
        final doc = await _firestore.collection('Users').doc(uid).get();

        if (doc.exists) {
          final data = doc.data()!;
          List<int> registeredIndexes = [];
          if (data['registedCoursesIndexes'] != null) {
            registeredIndexes = List<int>.from(data['registedCoursesIndexes']);
          }

          // ✅ Load course progress (how many lessons finished per course)
          Map<String, int> coursesProgress = {};
          if (data['coursesProgress'] != null) {
            coursesProgress = Map<String, int>.from(data['coursesProgress']);
          }

          // ✅ Build the actual CourseInfo objects from indexes and progress
          List<CourseInfo> registeredCourses = [];
          for (int index in registeredIndexes) {
            // Get the base course info from your global list
            CourseInfo baseCourse =
                coursesInfo[index]; // Assuming you have a global list

            // Get how many lessons this user has finished for this course
            int finishedLessons = coursesProgress[index.toString()] ?? 0;

            // Create a new CourseInfo with the user's progress
            registeredCourses.add(
              CourseInfo(
                id: baseCourse.id,
                title: baseCourse.title,
                description: baseCourse.description,
                numberOfFinishedLessons:
                    finishedLessons, // User's actual progress
                totalLessons: baseCourse.totalLessons,
                about: baseCourse.about,
                imageUrl: baseCourse.imageUrl,
                sections: baseCourse.sections,
              ),
            );
          }

          // Load achievements progress
          List<double> achievementsProgress = List.filled(13, 0.0);
          if (data['achievementsProgress'] != null) {
            achievementsProgress = List<double>.from(
              (data['achievementsProgress'] as List).map(
                (e) => (e as num).toDouble(),
              ),
            );
          }
          localUser = User(
            uid: uid,
            firebaseUid: uid,
            username:
                data['username'] ??
                data['Username'] ?? // Try lowercase first, then uppercase
                user.email?.split('@').first ??
                'User',
            fullName:
                data['fullName'] ??
                data['FullName'] ??
                data['username'] ??
                data['Username'] ??
                'User',
            tag: data['tag'] ?? data['Tag'] ?? 'Student',
            age: data['age'] ?? data['Age'] ?? 20,
            sex: data['sex'] ?? data['Sex'] ?? 'Rather not say',
            profileImage:
                data['profileImage'] ??
                data['ProfileImage'] ??
                'https://cdn.wallpapersafari.com/95/19/uFaSYI.jpg',
            achievementsProgress: List.filled(13, 0.0),
            registeredCourses: registeredCourses,
            registedCoursesIndexes: registeredIndexes,
          );

          print('✅ User data loaded from Firestore: ${localUser.username}');
        } else {
          print('⚠️ No user document found in Firestore for uid: $uid');
        }
      } catch (e) {
        print('❌ Firestore load failed: $e');
      }

      // 🔹 SECOND: If Firestore failed or profile doesn't exist, create a basic one
      if (localUser == null) {
        print('⚠️ Creating basic user profile from Firebase Auth data');

        // Try to get username from email
        String username =
            user.email?.split('@').first ?? 'user_${uid.substring(0, 4)}';
        localUser = User(
          uid: uid,
          firebaseUid: uid,
          username: username,
          fullName: user.displayName ?? username,
          tag: 'Student',
          age: 21,
          sex: 'Rather not say',
          profileImage: 'https://cdn.wallpapersafari.com/95/19/uFaSYI.jpg',
          achievementsProgress: List.filled(13, 0.0),
          registeredCourses: [],
          registedCoursesIndexes: [],
        );

        // OPTIONAL: Save this basic profile to Firestore for future logins
        try {
          await _firestore.collection('Users').doc(uid).set({
            'uid': uid,
            'firebaseUid': uid,
            'email': user.email,
            'username': username,
            'fullName': username,
            'tag': 'Student',
            'age': 21,
            'sex': 'Rather not say',
            'profileImage': 'https://cdn.wallpapersafari.com/95/19/uFaSYI.jpg',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print('✅ Basic user profile saved to Firestore');
        } catch (e) {
          print('❌ Failed to save basic profile: $e');
        }
      }

      // 🔹 THIRD: Save locally
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
        case 'invalid-credential':
          msg = 'Invalid email or password';
          break;
        default:
          msg = e.message ?? 'Login failed';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
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
                    prefixIcon: Icon(Icons.lock),
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
                    const Text("Don't have an account?"),
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
