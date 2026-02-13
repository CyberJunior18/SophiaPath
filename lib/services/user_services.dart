import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import '../models/user/user.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ FIXED: Change from 'users' to 'Users' to match your screens
  CollectionReference get usersCollection => _firestore.collection('Users');

  // Save user to Firestore
  Future<void> saveUser(User user) async {
    try {
      if (user.firebaseUid == null) {
        throw Exception('Cannot save user without firebaseUid');
      }

      // Use firebaseUid as the document ID
      final userData = user.toMap();

      // Add additional fields that aren't in toMap()
      userData.addAll({
        'achievementsProgress': user.achievementsProgress,
        'registeredCourses': user.registeredCourses
            .map((course) => course.toMap())
            .toList(),
        'registedCoursesIndexes': user.registedCoursesIndexes,
        'status': user.status,
        'bio': user.bio,
        'email': _getEmailFromFirebase(user.firebaseUid!), // Optional
      });

      await usersCollection.doc(user.firebaseUid).set(userData);
      print('✅ User saved successfully to Firestore');
    } catch (e) {
      print('❌ Error saving user: $e');
      rethrow;
    }
  }

  // Update user in Firestore
  Future<void> updateUser(User user) async {
    try {
      if (user.firebaseUid == null) {
        throw Exception('Cannot update user without firebaseUid');
      }

      final userData = user.toMap();

      // Add additional fields
      userData.addAll({
        'achievementsProgress': user.achievementsProgress,
        'registeredCourses': user.registeredCourses
            .map((course) => course.toMap())
            .toList(),
        'registedCoursesIndexes': user.registedCoursesIndexes,
        'status': user.status,
        'bio': user.bio,
        'lastSeen': user.lastSeen?.toIso8601String(),
        'isOnline': user.isOnline,
      });

      await usersCollection.doc(user.firebaseUid).update(userData);
      print('✅ User updated successfully in Firestore');
    } catch (e) {
      print('❌ Error updating user: $e');
      rethrow;
    }
  }

  // Get user by Firebase UID
  Future<User?> getUser(String firebaseUid) async {
    try {
      final doc = await usersCollection.doc(firebaseUid).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return User.fromMap(data);
      }
      print('⚠️ No user found with UID: $firebaseUid');
      return null;
    } catch (e) {
      print('❌ Error getting user: $e');
      return null; // Don't rethrow, just return null
    }
  }

  // Update last seen and online status
  Future<void> updateUserPresence(String firebaseUid, bool isOnline) async {
    try {
      await usersCollection.doc(firebaseUid).update({
        'lastSeen': DateTime.now().toIso8601String(),
        'isOnline': isOnline,
      });
      print('✅ User presence updated');
    } catch (e) {
      print('⚠️ Error updating presence: $e');
      // Don't rethrow - presence updates shouldn't break the app
    }
  }

  // ✅ NEW: Helper to get email from Firebase Auth
  String? _getEmailFromFirebase(String uid) {
    try {
      return FirebaseAuth.instance.currentUser?.email;
    } catch (e) {
      return null;
    }
  }

  // ✅ NEW: Check if user exists
  Future<bool> userExists(String firebaseUid) async {
    try {
      final doc = await usersCollection.doc(firebaseUid).get();
      return doc.exists;
    } catch (e) {
      print('Error checking user existence: $e');
      return false;
    }
  }

  // ✅ NEW: Delete user from Firestore
  Future<void> deleteUser(String firebaseUid) async {
    try {
      await usersCollection.doc(firebaseUid).delete();
      print('✅ User deleted from Firestore');
    } catch (e) {
      print('❌ Error deleting user: $e');
      rethrow;
    }
  }
}
