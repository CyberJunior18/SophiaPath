import 'package:cloud_firestore/cloud_firestore.dart';
import '../course/course_info.dart';

class User {
  final String? uid; // Local database ID
  final String? firebaseUid;
  final String username;
  final String fullName;
  final String tag;
  final int age;
  final String sex;
  final String profileImage;
  final List<double> achievementsProgress;
  final List<CourseInfo> registeredCourses;
  final List<int> registedCoursesIndexes;
  DateTime? lastSeen;
  bool isOnline = false;
  String? status;
  String? bio;

  // ✅ FIXED: Use the constant consistently
  static const String defaultProfileImage =
      'https://ui-avatars.com/api/?name=User&background=3D5CFF&color=fff&size=256';

  User({
    this.uid,
    this.firebaseUid,
    required this.username,
    required this.tag,
    required this.age,
    required this.sex,
    // ✅ FIXED: Use defaultProfileImage constant instead of hardcoded URL
    this.profileImage = defaultProfileImage,
    required this.achievementsProgress,
    required this.registeredCourses,
    required this.fullName,
    required this.registedCoursesIndexes,
  });

  bool get isAvailableForChat => isOnline && lastSeen != null;

  String get lastSeenFormatted {
    if (lastSeen == null) return 'Never seen';

    final now = DateTime.now();
    final difference = now.difference(lastSeen!);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${lastSeen!.day}/${lastSeen!.month}/${lastSeen!.year}';
  }

  // Convert to Map for SQL insert
  Map<String, dynamic> toMap() {
    return {
      'firebaseUid': firebaseUid,
      'username': username,
      'fullName': fullName,
      'tag': tag,
      'age': age,
      'gender': sex,
      'profilePicture': profileImage,
      'lastSeen': lastSeen?.toIso8601String(),
      'isOnline': isOnline,
    };
  }

  // Convert from SQL to Model
  factory User.fromMap(Map<String, dynamic> map) {
    // Handle achievementsProgress from Firestore
    final achievementsProgress =
        (map['achievementsProgress'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];

    // Handle registeredCourses from Firestore
    final registeredCourses =
        (map['registeredCourses'] as List<dynamic>?)
            ?.map((courseMap) => CourseInfo.fromMap(courseMap))
            .toList() ??
        [];

    // Handle registedCoursesIndexes from Firestore
    final registedCoursesIndexes =
        (map['registedCoursesIndexes'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [];

    return User(
        uid: map['uid']?.toString(),
        firebaseUid: map['firebaseUid']?.toString() ?? map['uid']?.toString(),
        username: map['username'] ?? map['Username'] ?? '',
        fullName: map['fullName'] ?? map['FullName'] ?? '',
        tag: map['tag'] ?? map['Tag'] ?? 'Student',
        age: (map['age'] as num?)?.toInt() ?? map['Age'] ?? 20,
        sex: map['gender'] ?? map['sex'] ?? map['Sex'] ?? 'Rather not say',
        profileImage:
            map['profilePicture'] ??
            map['profileImage'] ??
            map['ProfileImage'] ??
            defaultProfileImage,
        achievementsProgress: achievementsProgress,
        registeredCourses: registeredCourses,
        registedCoursesIndexes: registedCoursesIndexes,
      )
      ..lastSeen = map['lastSeen'] != null
          ? DateTime.parse(map['lastSeen'])
          : null
      ..isOnline = map['isOnline'] ?? false
      ..status = map['status']?.toString()
      ..bio = map['bio']?.toString();
  }

  User copyWith({
    String? firebaseUid,
    String? username,
    String? fullName,
    String? tag,
    int? age,
    String? gender,
    String? profilePicture,
    List<double>? achievementsScores,
    List<CourseInfo>? registeredCourses,
    List<int>? registedCoursesIndexes,
    DateTime? lastSeen,
    bool? isOnline,
    String? status,
    String? bio,
  }) {
    return User(
        firebaseUid: firebaseUid ?? this.firebaseUid,
        username: username ?? this.username,
        fullName: fullName ?? this.fullName,
        tag: tag ?? this.tag,
        age: age ?? this.age,
        sex: gender ?? sex,
        profileImage: profilePicture ?? profileImage,
        achievementsProgress: achievementsScores ?? achievementsProgress,
        registeredCourses: registeredCourses ?? this.registeredCourses,
        registedCoursesIndexes:
            registedCoursesIndexes ?? this.registedCoursesIndexes,
      )
      ..lastSeen = lastSeen ?? this.lastSeen
      ..isOnline = isOnline ?? this.isOnline
      ..status = status ?? this.status
      ..bio = bio ?? this.bio;
  }

  factory User.fromFirestore(Map<String, dynamic> data) {
    return User(
      uid: data['uid']?.toString() ?? '',
      firebaseUid:
          data['firebaseUid']?.toString() ?? data['uid']?.toString() ?? '',
      username:
          data['username']?.toString() ?? data['Username']?.toString() ?? '',
      fullName:
          data['fullName']?.toString() ?? data['FullName']?.toString() ?? '',
      tag: data['tag']?.toString() ?? data['Tag']?.toString() ?? 'Student',
      age: (data['age'] is num)
          ? (data['age'] as num).toInt()
          : (data['Age'] is num)
          ? (data['Age'] as num).toInt()
          : 20,
      sex:
          data['sex']?.toString() ??
          data['Sex']?.toString() ??
          'Rather not say',
      profileImage:
          data['profileImage']?.toString() ??
          data['ProfileImage']?.toString() ??
          User.defaultProfileImage,
      achievementsProgress: _safeListDouble(data['achievementsProgress']),
      registeredCourses: [], // Handle separately if needed
      registedCoursesIndexes: _safeListInt(data['registedCoursesIndexes']),
    )..isOnline = data['isOnline'] == true;
  }

  // ✅ Helper methods for safe list conversion
  static List<double> _safeListDouble(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => (e as num).toDouble()).toList();
    }
    return [];
  }

  static List<int> _safeListInt(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => (e as num).toInt()).toList();
    }
    return [];
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'firebaseUid': firebaseUid,
      'username': username,
      'fullName': fullName,
      'tag': tag,
      'age': age,
      'sex': sex,
      'profileImage': profileImage,
      'achievementsProgress': achievementsProgress,
      'registedCoursesIndexes': registedCoursesIndexes,
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    };
  }
}

// ✅ FIXED: Use defaultProfileImage constant here too
final User sampleUser = User(
  username: "Mohammad Hammadi",
  fullName: "Mohammad",
  tag: "Software Engineer",
  age: 21,
  sex: "Male",
  profileImage: User.defaultProfileImage, // Use constant
  achievementsProgress: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  registeredCourses: [],
  registedCoursesIndexes: [],
);
