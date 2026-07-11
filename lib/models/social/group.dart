class Group {
  final String id;
  final String name;
  final String description;
  final String avatar;
  final String createdBy;
  final List<dynamic> members;
  final List<dynamic> adminIds;
  final bool onlyAdminsCanEdit;
  final bool onlyAdminsCanSendMessages;
  final bool onlyAdminsCanAddMembers;
  final DateTime? createdAt;
  final dynamic lastMessage;
  final String? lastMessageTime;
  final String? lastMessageSender;
  final int? membersCount;

  Group({
    required this.id,
    required this.name,
    required this.description,
    this.avatar = '',
    required this.createdBy,
    this.members = const [],
    this.adminIds = const [],
    this.onlyAdminsCanEdit = false,
    this.onlyAdminsCanSendMessages = false,
    this.onlyAdminsCanAddMembers = false,
    this.createdAt,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSender,
    this.membersCount,
  });

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      avatar: map['avatar'] ?? '',
      createdBy: map['createdBy']?.toString() ?? '',
      members: map['members'] is List ? List.from(map['members']) : [],
      adminIds: map['adminIds'] is List ? List.from(map['adminIds']) : [],
      onlyAdminsCanEdit: map['onlyAdminsCanEdit'] == true,
      onlyAdminsCanSendMessages: map['onlyAdminsCanSendMessages'] == true,
      onlyAdminsCanAddMembers: map['onlyAdminsCanAddMembers'] == true,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt']) : null,
      lastMessage: map['lastMessage'],
      lastMessageTime: map['lastMessageTime'],
      lastMessageSender: map['lastMessageSender'],
      membersCount: map['membersCount'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'avatar': avatar,
      'createdBy': createdBy,
      'members': members,
      'adminIds': adminIds,
      'onlyAdminsCanEdit': onlyAdminsCanEdit,
      'onlyAdminsCanSendMessages': onlyAdminsCanSendMessages,
      'onlyAdminsCanAddMembers': onlyAdminsCanAddMembers,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
