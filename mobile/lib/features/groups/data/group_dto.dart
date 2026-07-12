/// A group as returned by GET /groups (list). Immutable value object.
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.currency,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String currency;
  final DateTime createdAt;

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'] as String,
        name: json['name'] as String,
        currency: json['currency'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// A member of a group. If [userId] is null, they're a non-user placeholder
/// (added by name only) — the "add anyone" case.
class Member {
  const Member({
    required this.id,
    required this.name,
    required this.role,
    required this.userId,
  });

  final String id;
  final String name;
  final String role; // 'creator' | 'member'
  final String? userId;

  bool get isUser => userId != null;

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        userId: json['user_id'] as String?,
      );
}

/// A single group plus its members (GET /groups/{id}).
class GroupDetail {
  const GroupDetail({
    required this.id,
    required this.name,
    required this.currency,
    required this.createdAt,
    required this.members,
  });

  final String id;
  final String name;
  final String currency;
  final DateTime createdAt;
  final List<Member> members;

  factory GroupDetail.fromJson(Map<String, dynamic> json) => GroupDetail(
        id: json['id'] as String,
        name: json['name'] as String,
        currency: json['currency'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        members: (json['members'] as List<dynamic>)
            .map((e) => Member.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
