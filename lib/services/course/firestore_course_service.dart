// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class FirestoreCourseService {
//   static final FirestoreCourseService _instance =
//       FirestoreCourseService._internal();
//   factory FirestoreCourseService() => _instance;
//   FirestoreCourseService._internal();

//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   String get _currentUserId => _auth.currentUser?.uid ?? '';

//   // Get reference to user's courses collection
//   CollectionReference get _userCoursesCollection => _firestore
//       .collection('Users')
//       .doc(_currentUserId)
//       .collection('RegisteredCourses');

//   /// Get all registered courses for the current user
//   Future<List<Course>> getCourses() async {
//     if (_currentUserId.isEmpty) {
//       print('⚠️ No user logged in');
//       return [];
//     }

//     try {
//       final snapshot = await _userCoursesCollection
//           .orderBy('courseIndex')
//           .get()
//           .timeout(const Duration(seconds: 10));

//       return snapshot.docs
//           .map(
//             (doc) => Course.fromMap(doc.data() as Map<String, dynamic>, doc.id),
//           )
//           .toList();
//     } catch (e) {
//       print('❌ Error fetching courses from Firestore: $e');
//       return [];
//     }
//   }

//   /// Register a new course
//   Future<String?> insertCourse(Course course) async {
//     if (_currentUserId.isEmpty) {
//       print('⚠️ No user logged in');
//       return null;
//     }

//     try {
//       final docRef = await _userCoursesCollection.add(course.toFirestore());
//       print('✅ Course registered: ${course.title}');
//       return docRef.id;
//     } catch (e) {
//       print('❌ Error registering course: $e');
//       return null;
//     }
//   }

//   /// Update course data
//   Future<void> updateCourse(Course course) async {
//     if (_currentUserId.isEmpty || course.id == null) {
//       print('⚠️ No user logged in or course ID is null');
//       return;
//     }

//     try {
//       await _userCoursesCollection.doc(course.id).update(course.toFirestore());
//       print('✅ Course updated: ${course.title}');
//     } catch (e) {
//       print('❌ Error updating course: $e');
//     }
//   }

//   /// Update lessons finished count
//   Future<void> updateLessonsFinished(
//     String courseId,
//     int lessonsFinished,
//   ) async {
//     if (_currentUserId.isEmpty) {
//       print('⚠️ No user logged in');
//       return;
//     }

//     try {
//       await _userCoursesCollection.doc(courseId).update({
//         'lessonsFinished': lessonsFinished,
//       });
//       print('✅ Lessons updated: $lessonsFinished');
//     } catch (e) {
//       print('❌ Error updating lessons finished: $e');
//     }
//   }

//   /// Increment lessons finished count
//   Future<void> incrementLessonsFinished(String courseId) async {
//     if (_currentUserId.isEmpty) {
//       print('⚠️ No user logged in');
//       return;
//     }

//     try {
//       await _userCoursesCollection.doc(courseId).update({
//         'lessonsFinished': FieldValue.increment(1),
//       });
//       print('✅ Lessons incremented for course: $courseId');
//     } catch (e) {
//       print('❌ Error incrementing lessons: $e');
//     }
//   }

//   /// Delete a course
//   Future<void> deleteCourse(String courseId) async {
//     if (_currentUserId.isEmpty) {
//       print('⚠️ No user logged in');
//       return;
//     }

//     try {
//       await _userCoursesCollection.doc(courseId).delete();
//       print('✅ Course deleted: $courseId');
//     } catch (e) {
//       print('❌ Error deleting course: $e');
//     }
//   }

//   /// Get stream of courses for real-time updates
//   Stream<List<Course>> getCoursesStream() {
//     if (_currentUserId.isEmpty) {
//       print('⚠️ No user logged in');
//       return Stream.value([]);
//     }

//     return _userCoursesCollection
//         .orderBy('courseIndex')
//         .snapshots()
//         .map(
//           (snapshot) => snapshot.docs
//               .map(
//                 (doc) =>
//                     Course.fromMap(doc.data() as Map<String, dynamic>, doc.id),
//               )
//               .toList(),
//         );
//   }
// }

class Course {
  final String? id; // Firestore document ID
  final String title;
  final int courseIndex;
  final int lessonsFinished;

  Course({
    this.id,
    required this.title,
    required this.courseIndex,
    this.lessonsFinished = 0,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'courseIndex': courseIndex,
      'lessonsFinished': lessonsFinished,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map, String docId) {
    return Course(
      id: docId,
      title: map['title'] ?? '',
      courseIndex: map['courseIndex'] ?? 0,
      lessonsFinished: map['lessonsFinished'] ?? 0,
    );
  }

  Course copyWith({
    String? id,
    String? title,
    int? courseIndex,
    int? lessonsFinished,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      courseIndex: courseIndex ?? this.courseIndex,
      lessonsFinished: lessonsFinished ?? this.lessonsFinished,
    );
  }

  double calculateProgress(int totalLessons) {
    if (totalLessons <= 0) return 0.0;
    return (lessonsFinished / totalLessons).clamp(0.0, 1.0);
  }
}
