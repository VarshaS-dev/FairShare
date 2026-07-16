import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money.dart';
import '../../../core/network/api_error.dart';
import '../../settlements/presentation/record_settlement_dialog.dart';
import '../application/balances_providers.dart';
import '../data/balance_dto.dart';

// Money owed to you reads as positive/green; money you owe as negative/red.
const _owedColor = Color(0xFF2E7D32); // green 800

class BalancesTab extends ConsumerWidget {
  const BalancesTab({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(balancesProvider(groupId));

    return balancesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(describeApiError(e), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(balancesProvider(groupId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (bal) {
        MemberBalance? me;
        for (final b in bal.balances) {
          if (b.memberId == bal.meMemberId) {
            me = b;
            break;
          }
        }
        final theme = Theme.of(context);
        return RefreshIndicator(
          onRefresh: () => ref.refresh(balancesProvider(groupId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (me != null) _MeCard(me: me, currency: bal.currency),
              const SizedBox(height: 16),
              Text('Everyone', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...bal.balances.map((b) => _BalanceTile(
                    b: b,
                    currency: bal.currency,
                    isMe: b.memberId == bal.meMemberId,
                  )),
              const SizedBox(height: 24),
              Text('Suggested payments', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('The fewest transfers to settle everyone up.',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              if (bal.settlements.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.check_circle_rounded, color: _owedColor),
                    title: Text('Everyone is settled up 🎉'),
                  ),
                )
              else
                ...bal.settlements.map((s) => _SettlementTile(
                      groupId: groupId,
                      s: s,
                      currency: bal.currency,
                    )),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            RecordSettlementDialog(groupId: groupId),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Record a payment'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => context.push('/group/$groupId/payments'),
                    child: const Text('History'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MeCard extends StatelessWidget {
  const _MeCard({required this.me, required this.currency});

  final MemberBalance me;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = me.netMinor;
    final (label, color) = net > 0
        ? ('Overall, you are owed', _owedColor)
        : net < 0
            ? ('Overall, you owe', theme.colorScheme.error)
            : ('You are all settled up 🎉', theme.colorScheme.onSurface);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.titleMedium),
            if (net != 0) ...[
              const SizedBox(height: 6),
              Text(
                Money.formatWithCurrency(net.abs(), currency),
                style: theme.textTheme.headlineMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.b,
    required this.currency,
    required this.isMe,
  });

  final MemberBalance b;
  final String currency;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = b.netMinor;
    final (text, color) = net > 0
        ? ('gets back ${Money.formatWithCurrency(net, currency)}', _owedColor)
        : net < 0
            ? ('owes ${Money.formatWithCurrency(-net, currency)}',
                theme.colorScheme.error)
            : ('settled up', theme.colorScheme.onSurfaceVariant);
    return Card(
      child: ListTile(
        title: Text(isMe ? '${b.name} (you)' : b.name,
            style: isMe
                ? const TextStyle(fontWeight: FontWeight.w600)
                : null),
        trailing: Text(text, style: TextStyle(color: color)),
      ),
    );
  }
}

class _SettlementTile extends StatelessWidget {
  const _SettlementTile({
    required this.groupId,
    required this.s,
    required this.currency,
  });

  final String groupId;
  final SuggestedPayment s;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.arrow_forward_rounded),
        title: Text('${s.fromName} → ${s.toName}'),
        subtitle: Text(Money.formatWithCurrency(s.amountMinor, currency)),
        trailing: FilledButton.tonal(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => RecordSettlementDialog(
              groupId: groupId,
              fromMemberId: s.fromMemberId,
              toMemberId: s.toMemberId,
              amountMinor: s.amountMinor,
            ),
          ),
          child: const Text('Settle up'),
        ),
      ),
    );
  }
}
