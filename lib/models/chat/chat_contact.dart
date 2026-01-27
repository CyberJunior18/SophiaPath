class ChatContact {
  final String userId;
  final String chatId;

  // for _buildChatItem in chats_list_screen
  final DateTime lastMessageTime;
  final String lastMessage;
  final int unreadCount;

  ChatContact({
    required this.userId,
    required this.chatId,
    required this.lastMessageTime,
    required this.lastMessage,
    this.unreadCount = 0,
  });

  // builds map of chat data
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'chatId': chatId,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
    };
  }

  //Create a ChatContact using the map in parameter
  factory ChatContact.fromMap(Map<String, dynamic> map) {
    return ChatContact(
      userId: map['userId'],
      chatId: map['chatId'],
      lastMessageTime: DateTime.parse(map['lastMessageTime']),
      lastMessage: map['lastMessage'],
      unreadCount: map['unreadCount'] ?? 0,
    );
  }

  //copy another chatcontact with ability to change any value
  ChatContact copyWith({
    String? userId,
    String? chatId,
    DateTime? lastMessageTime,
    String? lastMessage,
    int? unreadCount,
  }) {
    return ChatContact(
      userId: userId ?? this.userId,
      chatId: chatId ?? this.chatId,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
