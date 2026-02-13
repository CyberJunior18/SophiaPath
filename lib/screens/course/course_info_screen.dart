import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/data.dart';
import 'lesson_path_screen.dart';
import '../../services/course/database_helper.dart';
import '../../models/course/course_info.dart';
import '../../services/course/scores_repo.dart';

class CourseInfoScreen extends StatefulWidget {
  final CourseInfo course;
  const CourseInfoScreen({super.key, required this.course});

  @override
  State<CourseInfoScreen> createState() => _CourseInfoScreenState();
}

class _CourseInfoScreenState extends State<CourseInfoScreen> {
  bool _isLoading = false;
  bool _isCourseRegistered = false;
  List<Course> _registeredCourses = [];
  final DatabaseService _databaseService = DatabaseService();
  late int courseIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  @override
  void initState() {
    super.initState();
    _checkIfCourseRegistered();
    setState(() {
      courseIndex = coursesInfo.indexOf(widget.course);
    });
  }

  String? get _userId => _auth.currentUser?.uid;
  Future<void> _syncCourseToFirestore(bool registered) async {
    String? uid = _userId;
    if (uid == null) return;

    try {
      if (registered) {
        // Add course to user's registered courses in Firestore
        await _firestore.collection('Users').doc(uid).update({
          'registedCoursesIndexes': FieldValue.arrayUnion([courseIndex]),
          'coursesProgress.$courseIndex': 0, // Initialize progress
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Remove course from user's registered courses
        await _firestore.collection('Users').doc(uid).update({
          'registedCoursesIndexes': FieldValue.arrayRemove([courseIndex]),
          'coursesProgress.$courseIndex':
              FieldValue.delete(), // Remove progress
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      print('✅ Synced course registration to Firebase');
    } catch (e) {
      print('❌ Error syncing to Firebase: $e');
    }
  }

  Future<void> _checkIfCourseRegistered() async {
    setState(() => _isLoading = true);

    try {
      final courses = await _databaseService.getCourses();
      setState(() {
        _registeredCourses = courses;
        _isCourseRegistered = courses.any(
          (course) => course.title == widget.course.title,
        );
        _isLoading = false;
      });
      if (_isCourseRegistered) {
        await _loadCourseProgressFromFirebase();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registerCourse() async {
    if (_isCourseRegistered) return;

    setState(() => _isLoading = true);

    try {
      final newCourse = Course(
        title: widget.course.title,
        courseIndex: _registeredCourses.length,
      );
      await _databaseService.insertCourse(newCourse);

      // Sync to Firebase
      await _syncCourseToFirestore(true);

      setState(() {
        _isCourseRegistered = true;
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course registered successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error registering course: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _unregisterCourse() async {
    if (!_isCourseRegistered) return;
    await ScoresRepository.resetCourseScores(courseIndex);
    setState(() => _isLoading = true);

    try {
      final courseToDelete = _registeredCourses.firstWhere(
        (course) => course.title == widget.course.title,
      );

      if (courseToDelete.id != null) {
        // Delete from local SQLite
        await _databaseService.deleteCourse(courseToDelete.id!);

        // Sync to Firebase
        await _syncCourseToFirestore(false);
      }

      setState(() {
        _isCourseRegistered = false;
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course unregistered!'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCourseProgressFromFirebase() async {
    String? uid = _userId;
    if (uid == null || !_isCourseRegistered) return;

    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('Users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

        // Get progress for this course
        if (data['coursesProgress'] != null) {
          Map<String, dynamic> progress = data['coursesProgress'];
          int finishedLessons = progress[courseIndex.toString()] ?? 0;

          // Update local database with progress from Firebase
          // You might want to update your Course model or ScoresRepository
          print('📊 Course $courseIndex progress: $finishedLessons lessons');
        }
      }
    } catch (e) {
      print('❌ Error loading progress: $e');
    }
  }

  void _navigateToLessonPath() {
    if (!_isCourseRegistered) {
      _registerCourse().then((_) {
        if (!mounted) return;
        if (_isCourseRegistered) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LessonPathScreen(course: widget.course),
            ),
          );
        }
      });
    } else {
      _loadCourseProgressFromFirebase();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LessonPathScreen(course: widget.course),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: theme.textTheme.bodyLarge!.color!,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.course.title,
          style: GoogleFonts.poppins(color: theme.textTheme.bodyLarge!.color!),
        ),
        actions: [
          if (_isCourseRegistered)
            IconButton(
              icon: Icon(Icons.delete_outlined, color: Colors.red),
              onPressed: _isLoading ? null : _unregisterCourse,
              tooltip: 'Unregister from course',
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: widget.course.imageUrl.startsWith('http')
                        ? Image.network(
                            widget.course.imageUrl,
                            height: 180,
                            width: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 180,
                                width: 100,
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.book,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          )
                        : Image.network(
                            widget.course.imageUrl,
                            height: 180,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    "About the course",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge!.color!,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.course.about,
                    style: GoogleFonts.poppins(
                      color: theme.textTheme.bodyLarge!.color!,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        icon: Icons.menu_book,
                        label: 'Lessons',
                        value: lessonsInfo[courseIndex].length.toString(),
                      ),
                      _buildStatItem(
                        icon: Icons.schedule,
                        label: 'Duration',
                        value: '${widget.course.sections.length * 30} min',
                      ),
                      _buildStatItem(
                        icon: Icons.people,
                        label: 'Level',
                        value: 'Beginner',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    "Course Sections",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge!.color!,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...lessonsInfo[courseIndex].map(
                    (lesson) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: _isCourseRegistered
                                ? const Color(0xFF3D5CFF)
                                : Colors.grey,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              lesson.title,
                              style: GoogleFonts.poppins(
                                color: theme.textTheme.bodyLarge!.color!,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // we need this for later
                  // ...widget.course.sections.map(
                  //   (section) => Padding(
                  //     padding: const EdgeInsets.only(bottom: 10),
                  //     child: Row(
                  //       children: [
                  //         Icon(
                  //           Icons.check_circle,
                  //           size: 18,
                  //           color:
                  //               _isCourseRegistered
                  //                   ? const Color(0xFF3D5CFF)
                  //                   : Colors.grey,
                  //         ),
                  //         const SizedBox(width: 10),
                  //         Expanded(
                  //           child: Text(
                  //             section,
                  //             style: GoogleFonts.poppins(
                  //               color: theme.textTheme.bodyLarge!.color!,
                  //             ),
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _navigateToLessonPath,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3D5CFF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              _isCourseRegistered
                                  ? "Continue Learning"
                                  : "Register Now",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  if (_isCourseRegistered)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Already registered',
                            style: GoogleFonts.poppins(
                              color: Colors.green,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 30, color: const Color(0xFF3D5CFF)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
