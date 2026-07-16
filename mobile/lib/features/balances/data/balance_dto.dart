/// A member's net position: positive = they're owed, negative = they owe.
class MemberBalance {
  const MemberBalance({
    required this.memberId,
    required this.name,
    required this.netMinor,
  });

  final String memberId;
  final String name;
  final int netMinor;

  factory MemberBalance.fromJson(Map<String, dynamic> json) => MemberBalance(
        memberId: json['member_id'] as String,
        name: json['name'] as String,
        netMinor: json['net_minor'] as int,
      );
}

/// One transfer in the simplified settlement plan.
class SuggestedPayment {
  const SuggestedPayment({
    required this.fromMemberId,
    required this.fromName,
    required this.toMemberId,
    required this.toName,
    required this.amountMinor,
  });

  final String fromMemberId;
  final String fromName;
  final String toMemberId;
  final String toName;
  final int amountMinor;

  factory SuggestedPayment.fromJson(Map<String, dynamic> json) =>
      SuggestedPayment(
        fromMemberId: json['from_member_id'] as String,
        fromName: json['from_name'] as String,
        toMemberId: json['to_member_id'] as String,
        toName: json['to_name'] as String,
        amountMinor: json['amount_minor'] as int,
      );
}

class Balances {
  const Balances({
    required this.currency,
    required this.meMemberId,
    required this.balances,
    required this.settlements,
  });

  final String currency;
  final String? meMemberId;
  final List<MemberBalance> balances;
  final List<SuggestedPayment> settlements;

  factory Balances.fromJson(Map<String, dynamic> json) => Balances(
        currency: json['currency'] as String,
        meMemberId: json['me_member_id'] as String?,
        balances: (json['balances'] as List<dynamic>)
            .map((e) => MemberBalance.fromJson(e as Map<String, dynamic>))
            .toList(),
        settlements: (json['settlements'] as List<dynamic>)
            .map((e) => SuggestedPayment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
