import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../core/network/api_error.dart';
import '../../activity/application/activity_providers.dart';
import '../../groups/application/groups_providers.dart';
import '../../overview/application/overview_providers.dart';
import '../application/settlements_providers.dart';
import '../data/settlement_dto.dart';
import '../data/settlements_repository.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

class SettlementsHistoryScreen extends ConsumerWidget {
  const SettlementsHistoryScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(settlementsProvider(groupId));
    final currency =
        ref.watch(groupDetailProvider(groupId)).asData?.value.currency ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Payment history')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(describeApiError(e))),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No payments recorded yet.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _SettlementRow(
                  groupId: groupId,
                  s: list[i],
                  currency: currency,
                ),
              ),
      ),
    );
  }
}

class _SettlementRow extends ConsumerWidget {
  const _SettlementRow({
    required this.groupId,
    required this.s,
    required this.currency,
  });

  final String groupId;
  final Settlement s;
  final String currency;

  Future<void> _undo(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Undo this payment?'),
        content: Text(
          'Removing this will add ${Money.formatWithCurrency(s.amountMinor, currency)} '
          'back to the balances.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Undo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(settlementsRepositoryProvider)
          .deleteSettlement(groupId: groupId, settlementId: s.id);
      ref.invalidate(settlementsProvider(groupId));
      ref.invalidate(activityProvider);
      ref.invalidate(overviewProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Payment removed')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeApiError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = (s.note != null && s.note!.isNotEmpty)
        ? '${_fmtDate(s.settledAt)} · ${s.note}'
        : _fmtDate(s.settledAt);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.arrow_forward_rounded),
        title: Text('${s.fromName} → ${s.toName}'),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Money.formatWithCurrency(s.amountMinor, currency),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              tooltip: 'Undo',
              onPressed: () => _undo(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
