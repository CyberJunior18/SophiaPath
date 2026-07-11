class GroupMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  String text;
  final DateTime timestamp;
  bool pinned;
  bool deleted;
  bool edited;
  final String? replyToId;
  final String? replyToMessage;
  final String? replyToUsername;
  final bool forwarded;
  final String? pollQuestion;
  final List<dynamic>? pollOptions;
  final List<dynamic>? pollVotes;

  GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar = '',
    required this.text,
    required this.timestamp,
    this.pinned = false,
    this.deleted = false,
    this.edited = false,
    this.replyToId,
    this.replyToMessage,
    this.replyToUsername,
    this.forwarded = false,
    this.pollQuestion,
    this.pollOptions,
    this.pollVotes,
  });

  factory GroupMessage.fromMap(Map<String, dynamic> map) {
    return GroupMessage(
      id: map['id']?.toString() ?? '',
      groupId: map['groupId']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      senderName: map['senderName'] ?? map['username'] ?? 'User',
      senderAvatar: map['senderAvatar'] ?? map['avatar'] ?? '',
      text: map['text'] ?? map['message'] ?? '',
      timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp']) : DateTime.now(),
      pinned: map['pinned'] == true,
      deleted: map['deleted'] == true,
      edited: map['edited'] == true,
      replyToId: map['replyToId']?.toString(),
      replyToMessage: map['replyToMessage'],
      replyToUsername: map['replyToUsername'],
      forwarded: map['forwarded'] == true,
      pollQuestion: map['pollQuestion'],
      pollOptions: map['pollOptions'] is List ? List.from(map['pollOptions']) : null,
      pollVotes: map['pollVotes'] is List ? List.from(map['pollVotes']) : null,
    );
  }
}
