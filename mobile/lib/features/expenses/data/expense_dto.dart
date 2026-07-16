/// One participant's share of an expense, in minor units.
class ExpenseSplit {
  const ExpenseSplit({required this.memberId, required this.shareMinor});

  final String memberId;
  final int shareMinor;

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) => ExpenseSplit(
        memberId: json['member_id'] as String,
        shareMinor: json['share_minor'] as int,
      );
}

/// An expense: someone paid [amountMinor], split across [splits].
class Expense {
  const Expense({
    required this.id,
    required this.description,
    required this.amountMinor,
    required this.paidBy,
    required this.paidByName,
    required this.category,
    required this.spentAt,
    required this.splits,
  });

  final String id;
  final String description;
  final int amountMinor;
  final String paidBy; // member id
  final String paidByName;
  final String? category;
  final DateTime spentAt;
  final List<ExpenseSplit> splits;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        description: json['description'] as String,
        amountMinor: json['amount_minor'] as int,
        paidBy: json['paid_by'] as String,
        paidByName: json['paid_by_name'] as String,
        category: json['category'] as String?,
        spentAt: DateTime.parse(json['spent_at'] as String),
        splits: (json['splits'] as List<dynamic>)
            .map((e) => ExpenseSplit.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
