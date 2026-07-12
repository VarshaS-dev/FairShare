/// Shown before accepting an invite, so the user knows what they're joining.
class InvitePreview {
  const InvitePreview({
    required this.groupName,
    required this.currency,
    required this.claimName,
    required this.alreadyMember,
  });

  final String groupName;
  final String currency;

  /// If this invite claims a placeholder, the placeholder's name; else null.
  final String? claimName;
  final bool alreadyMember;

  factory InvitePreview.fromJson(Map<String, dynamic> json) => InvitePreview(
        groupName: json['group_name'] as String,
        currency: json['currency'] as String,
        claimName: json['claim_name'] as String?,
        alreadyMember: json['already_member'] as bool,
      );
}
