/// A group as returned by the backend. Immutable value object.
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

  /// Parses the JSON shape returned by `GET /groups` (snake_case fields).
  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'] as String,
        name: json['name'] as String,
        currency: json['currency'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
