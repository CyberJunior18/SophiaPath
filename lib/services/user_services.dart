import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sophia_path/models/user/user.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference
  CollectionReference get usersCollection => _firestore.collection('users');

  // Save user to Firestore
  Future<void> saveUser(User user) async {
    try {
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
      });

      await usersCollection.doc(user.firebaseUid).set(userData);
      print('User saved successfully!');
    } catch (e) {
      print('Error saving user: $e');
      rethrow;
    }
  }

  // Update user in Firestore
  Future<void> updateUser(User user) async {
    try {
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
      print('User updated successfully!');
    } catch (e) {
      print('Error updating user: $e');
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
      return null;
    } catch (e) {
      print('Error getting user: $e');
      rethrow;
    }
  }

  // Update last seen and online status
  Future<void> updateUserPresence(String firebaseUid, bool isOnline) async {
    try {
      await usersCollection.doc(firebaseUid).update({
        'lastSeen': DateTime.now().toIso8601String(),
        'isOnline': isOnline,
      });
    } catch (e) {
      print('Error updating presence: $e');
    }
  }
}
