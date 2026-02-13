import 'package:cloud_firestore/cloud_firestore.dart';
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

  String? get currentUserUid => _auth.currentUser?.uid;
  String? get currentUserEmail => _auth.currentUser?.email;

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
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      print('Firebase Auth error: ${e.code} - ${e.message}');
      throw _handleAuthError(e);
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
      try {
        await _userService.updateUserPresence(userCredential.user!.uid, true);
      } catch (e) {
        print('⚠️ Presence update error: $e');
        // Continue even if presence update fails
      }

      // Get user data from Firestore
      final user = await _userService.getUser(userCredential.user!.uid);

      if (user == null) {
        print('⚠️ User exists in Auth but not in Firestore');
        // You might want to create a basic profile here
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth error: ${e.code} - ${e.message}');
      throw _handleAuthError(e);
    } catch (e) {
      print('Sign in error: $e');
      rethrow;
    }
  }

  Future<void> signOut(String? firebaseUid) async {
    try {
      if (firebaseUid != null) {
        try {
          await _userService.updateUserPresence(firebaseUid, false);
        } catch (e) {
          print('⚠️ Presence update on signout error: $e');
        }
      }
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }

  // ✅ NEW: Helper to handle auth errors
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please login instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  // ✅ NEW: Check if user exists in Firestore
  Future<bool> userExistsInFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Users') // Make sure this matches your collection name
          .doc(uid)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking user existence: $e');
      return false;
    }
  }

  // ✅ NEW: Get current user with error handling
  Future<User?> getCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return null;

      return await _userService.getUser(firebaseUser.uid);
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }
}
