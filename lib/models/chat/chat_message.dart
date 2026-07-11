class ChatMessage {
  final String id;
  final int senderId;
  final String senderUsername;
  final int recipientId;
  final String message;
  final DateTime timestamp;
  final String? avatar;
  final bool read;
  final bool pinned;
  final bool edited;
  final bool deleted;
  final String? replyToId;
  final String? replyToMessage;
  final String? replyToUsername;
  final bool forwarded;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    required this.recipientId,
    required this.message,
    required this.timestamp,
    this.avatar,
    this.read = false,
    this.pinned = false,
    this.edited = false,
    this.deleted = false,
    this.replyToId,
    this.replyToMessage,
    this.replyToUsername,
    this.forwarded = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id']?.toString() ?? '',
      senderId: _readInt(map['senderId']) ?? 0,
      senderUsername: map['senderUsername']?.toString() ?? map['username']?.toString() ?? '',
      recipientId: _readInt(map['recipientId']) ?? 0,
      message: map['message']?.toString() ?? '',
      timestamp: _parseTimestamp(map['timestamp']),
      avatar: map['avatar']?.toString(),
      read: map['read'] == true,
      pinned: map['pinned'] == true,
      edited: map['edited'] == true,
      deleted: map['deleted'] == true,
      replyToId: map['replyToId']?.toString(),
      replyToMessage: map['replyToMessage']?.toString(),
      replyToUsername: map['replyToUsername']?.toString(),
      forwarded: map['forwarded'] == true,
    );
  }

  ChatMessage copyWith({
    String? id,
    int? senderId,
    String? senderUsername,
    int? recipientId,
    String? message,
    DateTime? timestamp,
    String? avatar,
    bool? read,
    bool? pinned,
    bool? edited,
    bool? deleted,
    String? replyToId,
    String? replyToMessage,
    String? replyToUsername,
    bool? forwarded,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      recipientId: recipientId ?? this.recipientId,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      avatar: avatar ?? this.avatar,
      read: read ?? this.read,
      pinned: pinned ?? this.pinned,
      edited: edited ?? this.edited,
      deleted: deleted ?? this.deleted,
      replyToId: replyToId ?? this.replyToId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
      replyToUsername: replyToUsername ?? this.replyToUsername,
      forwarded: forwarded ?? this.forwarded,
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
      'pinned': pinned,
      'edited': edited,
      'deleted': deleted,
      'replyToId': replyToId,
      'replyToMessage': replyToMessage,
      'replyToUsername': replyToUsername,
      'forwarded': forwarded,
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