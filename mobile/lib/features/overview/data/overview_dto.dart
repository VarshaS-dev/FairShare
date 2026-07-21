/// One group's contribution to a person's overall balance.
class OverviewGroupBalance {
  const OverviewGroupBalance({
    required this.groupId,
    required this.groupName,
    required this.balanceMinor,
  });

  final String groupId;
  final String groupName;
  final int balanceMinor; // + they owe me here, - I owe them here

  factory OverviewGroupBalance.fromJson(Map<String, dynamic> json) =>
      OverviewGroupBalance(
        groupId: json['group_id'] as String,
        groupName: json['group_name'] as String,
        balanceMinor: json['balance_minor'] as int,
      );
}

/// A consolidated balance with one person (in one currency), across all groups.
class OverviewPerson {
  const OverviewPerson({
    required this.userId,
    required this.name,
    required this.currency,
    required this.netMinor,
    required this.breakdown,
  });

  final String? userId;
  final String name;
  final String currency;
  final int netMinor; // + they owe me overall, - I owe them
  final List<OverviewGroupBalance> breakdown;

  factory OverviewPerson.fromJson(Map<String, dynamic> json) => OverviewPerson(
        userId: json['user_id'] as String?,
        name: json['name'] as String,
        currency: json['currency'] as String,
        netMinor: json['net_minor'] as int,
        breakdown: (json['breakdown'] as List<dynamic>)
            .map((e) => OverviewGroupBalance.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Overview {
  const Overview({required this.people});

  final List<OverviewPerson> people;

  factory Overview.fromJson(Map<String, dynamic> json) => Overview(
        people: (json['people'] as List<dynamic>)
            .map((e) => OverviewPerson.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
