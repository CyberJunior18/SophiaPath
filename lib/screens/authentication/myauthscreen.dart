// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // If using Firestore
// import 'package:flutter/material.dart';

// class MyAuthScreen extends StatefulWidget {
//   const MyAuthScreen({super.key});

//   @override
//   State<MyAuthScreen> createState() => _MyAuthScreenState();
// }

// class _MyAuthScreenState extends State<MyAuthScreen> {
//   final TextEditingController _usernameController = TextEditingController();
//   bool _isSigningIn = false;
//   String? _errorMessage;

//   @override
//   void initState() {
//     super.initState();
//     // Check if user is already signed in anonymously
//     FirebaseAuth.instance.authStateChanges().listen((User? user) {
//       if (user == null) {
//         print('User is currently signed out!');
//         // User needs to sign in or will be prompted
//       } else {
//         print('User is signed in anonymously with UID: ${user.uid}');
//         // If user is signed in, check if they have a username set
//         // For simplicity, we'll navigate directly to HomeScreen if signed in
//         _navigateToHomeScreen(user.uid);
//       }
//     });
//   }

//   void _signInAnonymouslyAndSetUsername() async {
//     setState(() {
//       _isSigningIn = true;
//       _errorMessage = null;
//     });
//     try {
//       // 1. Sign in anonymously
//       UserCredential userCredential = await FirebaseAuth.instance
//           .signInAnonymously();
//       User? user = userCredential.user;

//       if (user != null) {
//         print("Signed in with anonymous user: ${user.uid}");

//         // 2. Get username from text field
//         String username = _usernameController.text.trim();
//         if (username.isEmpty) {
//           setState(() {
//             _errorMessage = "Please enter a username.";
//             _isSigningIn = false;
//           });
//           return;
//         }

//         // 3. Store username in Firestore (or Realtime Database)
//         await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
//           'username': username,
//           'createdAt': FieldValue.serverTimestamp(),
//           'uid': user.uid,
//         });
//         print("Username '$username' stored for UID: ${user.uid}");

//         // 4. Navigate to your main app screen
//         _navigateToHomeScreen(user.uid);
//       }
//     } on FirebaseAuthException catch (e) {
//       setState(() {
//         _errorMessage = e.message;
//       });
//     } catch (e) {
//       setState(() {
//         _errorMessage = "An unexpected error occurred: $e";
//       });
//     } finally {
//       setState(() {
//         _isSigningIn = false;
//       });
//     }
//   }

//   void _navigateToHomeScreen(String uid) {
//     // You would replace this with actual navigation to your app's main content
//     Navigator.of(context).pushReplacement(
//       MaterialPageRoute(builder: (context) => HomeScreen(uid: uid)),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Welcome')),
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Text(
//                 'Create your anonymous account or sign in:',
//                 style: TextStyle(fontSize: 18),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 20),
//               TextField(
//                 controller: _usernameController,
//                 decoration: const InputDecoration(
//                   labelText: 'Choose a Username',
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               const SizedBox(height: 20),
//               if (_errorMessage != null)
//                 Padding(
//                   padding: const EdgeInsets.only(bottom: 10),
//                   child: Text(
//                     _errorMessage!,
//                     style: const TextStyle(color: Colors.red),
//                   ),
//                 ),
//               _isSigningIn
//                   ? const CircularProgressIndicator()
//                   : ElevatedButton(
//                       onPressed: _signInAnonymouslyAndSetUsername,
//                       child: const Text('Continue as Guest'),
//                     ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // Your main content screen
// class HomeScreen extends StatelessWidget {
//   final String uid;
//   const HomeScreen({super.key, required this.uid});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Main App Content')),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text('You are logged in with UID: $uid'),
//             const Text('Now you can access protected data.'),
//             ElevatedButton(
//               onPressed: () async {
//                 await FirebaseAuth.instance.signOut();
//                 // After signing out, navigate back to the auth screen
//                 Navigator.of(context).pushReplacement(
//                   MaterialPageRoute(builder: (context) => const MyAuthScreen()),
//                 );
//               },
//               child: const Text('Sign Out'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
