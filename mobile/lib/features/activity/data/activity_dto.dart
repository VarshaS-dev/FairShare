/// One event in the activity feed.
class Activity {
  const Activity({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.type,
    required this.summary,
    required this.actorName,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String groupName;
  final String type;
  final String summary;
  final String? actorName;
  final DateTime createdAt;

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        groupName: json['group_name'] as String,
        type: json['type'] as String,
        summary: json['summary'] as String,
        actorName: json['actor_name'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
