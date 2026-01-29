import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/material.dart';

import '../models/user/user.dart';
import 'user_services.dart';

ValueNotifier<AuthService> authService = ValueNotifier(AuthService());

// class AuthService {
//   // Create a Firebase instance [1]
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   // Provides access to the current user at any point [1, 3]
//   User? get currentUser => _auth.currentUser;

//   // Stream to determine if the user is connected or not [1, 2]
//   Stream<User?> get authStateChanges => _auth.authStateChanges();

//   // Sign in with email and password [2, 5]
//   Future<void> signIn(String email, String password) async {
//     await _auth.signInWithEmailAndPassword(email: email, password: password);
//   }

//   // Create a new user account [2, 6]
//   Future<void> createAccount(String email, String password) async {
//     await _auth.createUserWithEmailAndPassword(
//       email: email,
//       password: password,
//     );
//   }

//   // Log the user out [2, 7]
//   Future<void> signOut() async {
//     await _auth.signOut();
//   }

//   // Send a password reset email [2, 3, 8]
//   Future<void> resetPassword(String email) async {
//     await _auth.sendPasswordResetEmail(email: email);
//   }

//   // Update the user's display name [3, 9, 10]
//   Future<void> updateUsername(String name) async {
//     // This uses the currentUser property specifically [3, 10]
//     await _auth.currentUser!.updateDisplayName(name);
//   }

//   // Delete account (Requires reauthentication because it is a security-sensitive operation) [3, 11, 12]
//   Future<void> deleteAccount(String email, String password) async {
//     // 1. Create credential [3]
//     AuthCredential credential = EmailAuthProvider.credential(
//       email: email,
//       password: password,
//     );
//     // 2. Reauthenticate user [3, 11]
//     await _auth.currentUser!.reauthenticateWithCredential(credential);
//     // 3. Delete the account and sign out [11, 12]
//     await _auth.currentUser!.delete();
//     await _auth.signOut();
//   }

//   // Change password for a connected user (Also requires reauthentication) [11, 13]
//   Future<void> changePassword(
//     String email,
//     String currentPassword,
//     String newPassword,
//   ) async {
//     // 1. Create credential [11]
//     AuthCredential credential = EmailAuthProvider.credential(
//       email: email,
//       password: currentPassword,
//     );
//     await _auth.currentUser!.reauthenticateWithCredential(credential);
//     // 3. Update to the new password [11, 13]
//     await _auth.currentUser!.updatePassword(newPassword);
//   }
// }

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  Future<User?> signUpWithEmail(
    String email,
    String password,
    User userData,
  ) async {
    try {
      // 1. Create user in Firebase Authentication
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Set firebaseUid in your User object
      final userWithUid = userData.copyWith(
        firebaseUid: userCredential.user!.uid,
      );

      // 3. Save user data to Firestore
      await _userService.saveUser(userWithUid);

      return userWithUid;
    } catch (e) {
      print('Sign up error: $e');
      rethrow;
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update user presence
      await _userService.updateUserPresence(userCredential.user!.uid, true);

      // Get user data from Firestore
      return await _userService.getUser(userCredential.user!.uid);
    } catch (e) {
      print('Sign in error: $e');
      rethrow;
    }
  }

  Future<void> signOut(String? firebaseUid) async {
    if (firebaseUid != null) {
      await _userService.updateUserPresence(firebaseUid, false);
    }
    await _auth.signOut();
  }
}
