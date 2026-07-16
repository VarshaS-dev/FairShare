/// A recorded payment from one member to another.
class Settlement {
  const Settlement({
    required this.id,
    required this.fromMember,
    required this.fromName,
    required this.toMember,
    required this.toName,
    required this.amountMinor,
    required this.note,
    required this.settledAt,
  });

  final String id;
  final String fromMember;
  final String fromName;
  final String toMember;
  final String toName;
  final int amountMinor;
  final String? note;
  final DateTime settledAt;

  factory Settlement.fromJson(Map<String, dynamic> json) => Settlement(
        id: json['id'] as String,
        fromMember: json['from_member'] as String,
        fromName: json['from_name'] as String,
        toMember: json['to_member'] as String,
        toName: json['to_name'] as String,
        amountMinor: json['amount_minor'] as int,
        note: json['note'] as String?,
        settledAt: DateTime.parse(json['settled_at'] as String),
      );
}
