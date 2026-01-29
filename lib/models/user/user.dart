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

  User({
    this.uid,
    this.firebaseUid,
    required this.username,
    required this.tag,
    required this.age,
    required this.sex,
    this.profileImage =
        "https://cdn.wallpapersafari.com/95/19/uFaSYI.jpg", // Default image
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
      'firstName': fullName,
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
        firebaseUid: map['firebaseUid']?.toString(),
        username: map['username'] ?? '',
        fullName: map['firstName'] ?? map['fullName'] ?? '',
        tag: map['tag'] ?? '',
        age: (map['age'] as num?)?.toInt() ?? 0,
        sex: map['gender'] ?? map['sex'] ?? '',
        profileImage: map['profilePicture'] ?? map['profileImage'] ?? '',
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
    String? firstname,
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
        firebaseUid: firebaseUid,
        username: username ?? this.username,
        fullName: firstname ?? fullName,
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
}

//In case of error in user input this is the default user info
final User sampleUser = User(
  username: "Mohammad Hammadi",
  fullName: "Mohammad",
  tag: "Software Engineer",
  age: 21,
  sex: "Male",
  profileImage: "https://cdn.wallpapersafari.com/95/19/uFaSYI.jpg",
  achievementsProgress: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  registeredCourses: [],
  registedCoursesIndexes: [],
);
