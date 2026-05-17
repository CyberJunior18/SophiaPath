class ChatMessage {
  final String id;
  final int senderId;
  final String senderUsername;
  final int recipientId;
  final String message;
  final DateTime timestamp;
  final String? avatar;
  final bool read;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    required this.recipientId,
    required this.message,
    required this.timestamp,
    this.avatar,
    this.read = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id']?.toString() ?? '',
      senderId: _readInt(map['senderId']) ?? 0,
      senderUsername: map['senderUsername']?.toString() ?? '',
      recipientId: _readInt(map['recipientId']) ?? 0,
      message: map['message']?.toString() ?? '',
      timestamp: _parseTimestamp(map['timestamp']),
      avatar: map['avatar']?.toString(),
      read: map['read'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderUsername': senderUsername,
      'recipientId': recipientId,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'avatar': avatar,
      'read': read,
    };
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return DateTime.now();
  }
}