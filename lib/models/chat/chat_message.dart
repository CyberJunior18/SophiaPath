import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final MessageStatus status;
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final MessageType type;
  final Map<String, String> reactions;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    this.reactions = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'type': type.toString(),
      'reactions': reactions,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      senderId: map['senderId'],
      senderName: map['senderName'],
      message: map['message'],
      timestamp: DateTime.parse(map['timestamp']),
      isRead: map['isRead'] ?? false,
      type: MessageType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => MessageType.text,
      ),
      reactions: Map<String, String>.from(map['reactions'] ?? {}),
    );
  }

  ChatMessage copyWith({
    MessageStatus? status,
    String? id,
    String? senderId,
    String? senderName,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    MessageType? type,
    Map<String, String>? reactions,
  }) {
    return ChatMessage(
      status: status ?? this.status,
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      reactions: reactions ?? this.reactions,
    );
  }

  factory ChatMessage.fromFirestore(Map<String, dynamic> data) {
    return ChatMessage(
      id: data['id'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      message: data['message'] as String? ?? '',
      timestamp: data['timestamp'] != null 
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      type: MessageType.values.firstWhere(
        (e) => e.toString() == (data['type'] as String? ?? 'MessageType.text'),
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == (data['status'] as String? ?? 'MessageStatus.sent'),
        orElse: () => MessageStatus.sent,
      ),
      reactions: (data['reactions'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(key, value as String)),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'type': type.toString(),
      'status': status.toString(),
      'reactions': reactions,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

enum MessageType { text, image, file, system }

enum MessageStatus { sending, sent, delivered, read, failed }
