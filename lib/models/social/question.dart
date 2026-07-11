class Question {
  final String id;
  final String roomId;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final DateTime timestamp;
  final int upvotes;
  final List<dynamic> upvotedUsers;
  final List<dynamic> downvotedUsers;
  final int commentsCount;
  final bool userUpvoted;
  final bool userDownvoted;
  final String? pollQuestion;
  final List<dynamic>? pollOptions;
  final Map<String, dynamic>? pollVotes;

  Question({
    required this.id,
    required this.roomId,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorAvatar = '',
    required this.timestamp,
    this.upvotes = 0,
    this.upvotedUsers = const [],
    this.downvotedUsers = const [],
    this.commentsCount = 0,
    this.userUpvoted = false,
    this.userDownvoted = false,
    this.pollQuestion,
    this.pollOptions,
    this.pollVotes,
  });

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id']?.toString() ?? '',
      roomId: map['roomId']?.toString() ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      authorId: map['authorId']?.toString() ?? '',
      authorName: map['authorName'] ?? 'User',
      authorAvatar: map['authorAvatar'] ?? '',
      timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp']) : DateTime.now(),
      upvotes: map['upvotes'] ?? 0,
      upvotedUsers: map['upvotedUsers'] is List ? List.from(map['upvotedUsers']) : [],
      downvotedUsers: map['downvotedUsers'] is List ? List.from(map['downvotedUsers']) : [],
      commentsCount: map['commentsCount'] ?? 0,
      userUpvoted: map['userUpvoted'] == true,
      userDownvoted: map['userDownvoted'] == true,
      pollQuestion: map['pollQuestion'],
      pollOptions: map['pollOptions'] is List ? List.from(map['pollOptions']) : null,
      pollVotes: map['pollVotes'] is Map ? Map<String, dynamic>.from(map['pollVotes']) : null,
    );
  }
}
