class Community {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String bannerColor;
  final String category;
  final String ownerId;
  final int membersCount;
  final bool isJoined;
  final bool isPrivate;
  final bool isNSFW;
  final int? nsfwAgeLimit;
  final List<String> rules;
  final List<String> moderatorIds;
  final int maxMembers;
  final List<dynamic>? members;

  Community({
    required this.id,
    required this.name,
    required this.description,
    this.icon = '⭐',
    this.bannerColor = '',
    this.category = 'Software Engineering',
    required this.ownerId,
    this.membersCount = 0,
    this.isJoined = false,
    this.isPrivate = false,
    this.isNSFW = false,
    this.nsfwAgeLimit,
    this.rules = const [],
    this.moderatorIds = const [],
    this.maxMembers = 1000,
    this.members,
  });

  factory Community.fromMap(Map<String, dynamic> map) {
    return Community(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      icon: map['icon'] ?? '⭐',
      bannerColor: map['bannerColor'] ?? '',
      category: map['category'] ?? 'Software Engineering',
      ownerId: map['ownerId']?.toString() ?? '',
      membersCount: map['membersCount'] ?? map['members']?.length ?? 0,
      isJoined: map['isJoined'] == true,
      isPrivate: map['isPrivate'] == true,
      isNSFW: map['isNSFW'] == true,
      nsfwAgeLimit: map['nsfwAgeLimit'],
      rules: map['rules'] is List ? List<String>.from(map['rules']) : [],
      moderatorIds: map['moderatorIds'] is List
          ? List<String>.from((map['moderatorIds'] as List).map((e) => e.toString()))
          : [],
      maxMembers: map['maxMembers'] ?? 1000,
      members: map['members'] is List ? List.from(map['members']) : null,
    );
  }
}

class Room {
  final String id;
  final String communityId;
  final String name;
  final String description;

  Room({
    required this.id,
    required this.communityId,
    required this.name,
    this.description = '',
  });

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      id: map['id']?.toString() ?? '',
      communityId: map['communityId']?.toString() ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
    );
  }
}
