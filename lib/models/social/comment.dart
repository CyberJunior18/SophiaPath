class Comment {
  final String id;
  final String questionId;
  final String content;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final DateTime timestamp;
  final int upvotes;
  final List<dynamic> upvotedUsers;
  final List<dynamic> downvotedUsers;
  final bool userUpvoted;
  final bool userDownvoted;
  final List<Comment> replies;

  Comment({
    required this.id,
    required this.questionId,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorAvatar = '',
    required this.timestamp,
    this.upvotes = 0,
    this.upvotedUsers = const [],
    this.downvotedUsers = const [],
    this.userUpvoted = false,
    this.userDownvoted = false,
    this.replies = const [],
  });

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id']?.toString() ?? '',
      questionId: map['questionId']?.toString() ?? '',
      content: map['content'] ?? '',
      authorId: map['authorId']?.toString() ?? '',
      authorName: map['authorName'] ?? 'User',
      authorAvatar: map['authorAvatar'] ?? '',
      timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp']) : DateTime.now(),
      upvotes: map['upvotes'] ?? 0,
      upvotedUsers: map['upvotedUsers'] is List ? List.from(map['upvotedUsers']) : [],
      downvotedUsers: map['downvotedUsers'] is List ? List.from(map['downvotedUsers']) : [],
      userUpvoted: map['userUpvoted'] == true,
      userDownvoted: map['userDownvoted'] == true,
      replies: map['replies'] is List
          ? (map['replies'] as List).map((r) => Comment.fromMap(r)).toList()
          : [],
    );
  }
}
