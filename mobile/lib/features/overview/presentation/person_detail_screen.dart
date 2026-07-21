import 'package:flutter/material.dart';

import '../../../core/money.dart';
import '../data/overview_dto.dart';

const _owedColor = Color(0xFF2E7D32); // green 800 — money owed to you

/// Detailed breakdown of your balance with one person: overall net + the
/// contribution from each shared group.
class PersonDetailScreen extends StatelessWidget {
  const PersonDetailScreen({super.key, required this.person});

  final OverviewPerson person;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = person.netMinor;
    final owedToMe = net > 0;
    final overall = owedToMe
        ? '${person.name} owes you ${Money.formatWithCurrency(net, person.currency)}'
        : 'You owe ${person.name} ${Money.formatWithCurrency(-net, person.currency)}';
    final color = owedToMe ? _owedColor : theme.colorScheme.error;

    return Scaffold(
      appBar: AppBar(title: Text(person.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overall balance', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    overall,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Breakdown', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...person.breakdown.map(
            (g) => _GroupBreakdownTile(
              person: person,
              group: g,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupBreakdownTile extends StatelessWidget {
  const _GroupBreakdownTile({required this.person, required this.group});

  final OverviewPerson person;
  final OverviewGroupBalance group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bal = group.balanceMinor;
    final owedToMe = bal > 0;
    final text = owedToMe
        ? '${person.name} owes you ${Money.formatWithCurrency(bal, person.currency)}'
        : 'You owe ${person.name} ${Money.formatWithCurrency(-bal, person.currency)}';
    final color = owedToMe ? _owedColor : theme.colorScheme.error;
    return Card(
      child: ListTile(
        title: Text(group.groupName),
        subtitle: Text(text, style: TextStyle(color: color)),
      ),
    );
  }
}
