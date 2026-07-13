enum UserRole {
  student(0, 'Student'),
  expert(1, 'Expert'),
  moderator(2, 'Moderator'),
  admin(3, 'Admin');

  final int value;
  final String label;

  const UserRole(this.value, this.label);

  // This helper changes the backend number into a Flutter UserRole
  static UserRole fromInt(dynamic val) {
    final parsed = val is int ? val : int.tryParse(val?.toString() ?? '');
    switch (parsed) {
      case 1:
        return UserRole.expert;
      case 2:
        return UserRole.moderator;
      case 3:
        return UserRole.admin;
      case 0:
      default:
        return UserRole.student;
    }
  }
}
