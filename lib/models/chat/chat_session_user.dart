class ChatSessionUser {
  final int userId;
  final String username;
  final String displayName;
  final String? avatar;

  const ChatSessionUser({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatar,
  });

  factory ChatSessionUser.fromMap(Map<String, dynamic> map) {
    final int? parsedUserId = _readInt(map['userId'] ?? map['id']);

    if (parsedUserId == null) {
      throw StateError('Chat profile did not include a numeric user id');
    }

    final String username = _readString(map['username']) ?? '';
    final String fullName =
        _readString(map['fullname']) ??
        _readString(map['fullName']) ??
        username;

    return ChatSessionUser(
      userId: parsedUserId,
      username: username,
      displayName: fullName,
      avatar: _readString(map['profileImage']) ?? _readString(map['avatar']),
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _readString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}