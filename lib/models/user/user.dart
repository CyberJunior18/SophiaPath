import '../course/course_info.dart';
import 'user_role.dart';

class User {
  final String username;
  final String fullName;
  final String tag; // enum tag
  final int age;
  final String sex; // enum type gender
  final String profileImage;
  final List<double> achievementsProgress;
  final List<CourseInfo> registeredCourses;
  final List<int> registedCoursesIndexes;
  final int xp;
  final String email;
  final UserRole role;
  DateTime? lastSeen;
  bool isOnline = false;
  String? status;
  String? bio;

  static const String defaultProfileImage =
      'https://ui-avatars.com/api/?name=User&background=3D5CFF&color=fff&size=256';

  User({
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
    this.xp = 0,
    this.email = '',
    this.role = UserRole.student,
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
      'username': username,
      'fullName': fullName,
      'tag': tag,
      'age': age,
      'gender': sex,
      'profilePicture': profileImage,
      'xp': xp,
      'lastSeen': lastSeen?.toIso8601String(),
      'isOnline': isOnline,
      'email': email,
      'roleID': role.value,
      'role': role.value,
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
        username: map['username'] ?? map['Username'] ?? '',
        fullName: map['fullName'] ?? map['FullName'] ?? '',
        tag: map['tag'] ?? map['Tag'] ?? 'Student',
        age: (map['age'] as num?)?.toInt() ?? map['Age'] ?? 20,
        sex: map['gender'] ?? map['sex'] ?? map['Sex'] ?? 'Rather not say',
        profileImage:
            map['avatar'] ??
            map['profilePicture'] ??
            map['profileImage'] ??
            map['ProfileImage'] ??
            defaultProfileImage,
        achievementsProgress: achievementsProgress,
        registeredCourses: registeredCourses,
        registedCoursesIndexes: registedCoursesIndexes,
        xp: (map['xp'] as num?)?.toInt() ?? map['XP'] ?? 0,
        email: map['email'] ?? map['Email'] ?? '',
        role: UserRole.fromInt(map['roleID'] ?? map['role']),
      )
      ..lastSeen = map['lastSeen'] != null
          ? DateTime.parse(map['lastSeen'])
          : null
      ..isOnline = map['isOnline'] ?? false
      ..status = map['status']?.toString()
      ..bio = map['bio']?.toString();
  }

  User copyWith({
    String? username,
    String? fullName,
    String? tag,
    int? age,
    String? gender,
    String? profilePicture,
    List<double>? achievementsScores,
    List<CourseInfo>? registeredCourses,
    List<int>? registedCoursesIndexes,
    int? xp,
    DateTime? lastSeen,
    bool? isOnline,
    String? status,
    String? bio,
    String? email,
    UserRole? role,
  }) {
    return User(
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
        xp: xp ?? this.xp,
        email: email ?? this.email,
        role: role ?? this.role,
      )
      ..lastSeen = lastSeen ?? this.lastSeen
      ..isOnline = isOnline ?? this.isOnline
      ..status = status ?? this.status
      ..bio = bio ?? this.bio;
  }

  factory User.fromFirestore(Map<String, dynamic> data) {
    return User(
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
          data['avatar']?.toString() ??
          data['profileImage']?.toString() ??
          data['profilePicture']?.toString() ??
          data['ProfileImage']?.toString() ??
          User.defaultProfileImage,
      achievementsProgress: _safeListDouble(data['achievementsProgress']),
      registeredCourses: [], // Handle separately if needed
      registedCoursesIndexes: _safeListInt(data['registedCoursesIndexes']),
      xp: (data['xp'] as num?)?.toInt() ?? (data['XP'] as num?)?.toInt() ?? 0,
      email: data['email']?.toString() ?? '',
      role: UserRole.fromInt(data['roleID'] ?? data['role']),
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
  xp: 0,
  email: "test@example.com",
);

extension UserRoleHelpers on User {
  bool get isStudent => role == UserRole.student;
  bool get isExpert => role == UserRole.expert;
  bool get isModerator => role == UserRole.moderator;
  bool get isAdmin => role == UserRole.admin;
}
