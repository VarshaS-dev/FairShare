import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money.dart';
import '../../../core/network/api_error.dart';
import '../../groups/application/groups_providers.dart';
import '../application/expenses_providers.dart';
import '../data/expense_dto.dart';
import '../data/expenses_repository.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Full detail of one expense, with its per-member split and edit/delete.
///
/// Reads the expense reactively from [expensesProvider] (by id) so an edit
/// elsewhere is reflected here, and a delete makes it disappear cleanly.
class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({
    super.key,
    required this.groupId,
    required this.expenseId,
  });

  final String groupId;
  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider(groupId));
    final group = ref.watch(groupDetailProvider(groupId)).asData?.value;
    final currency = group?.currency ?? '';
    final names = {for (final m in group?.members ?? const []) m.id: m.name};

    return expensesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(describeApiError(e))),
      ),
      data: (expenses) {
        final matches = expenses.where((e) => e.id == expenseId);
        if (matches.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('This expense is no longer here.')),
          );
        }
        final expense = matches.first;
        return Scaffold(
          appBar: AppBar(
            title: Text(expense.description),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: () => context.push(
                  '/group/$groupId/edit-expense',
                  extra: expense,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(context, ref, expense),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(expense: expense, currency: currency),
              const SizedBox(height: 24),
              Text('Split', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...expense.splits.map(
                (s) => Card(
                  child: ListTile(
                    title: Text(names[s.memberId] ?? 'Member'),
                    trailing: Text(
                      Money.formatWithCurrency(s.shareMinor, currency),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('“${expense.description}” will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(expensesRepositoryProvider)
          .deleteExpense(groupId: groupId, expenseId: expense.id);
      ref.invalidate(expensesProvider(groupId));
      navigator.pop(); // back to the group
      messenger.showSnackBar(const SnackBar(content: Text('Expense deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeApiError(e))));
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.expense, required this.currency});

  final Expense expense;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Money.formatWithCurrency(expense.amountMinor, currency),
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Paid by ${expense.paidByName}',
                style: theme.textTheme.bodyLarge),
            const SizedBox(height: 2),
            Text(_fmtDate(expense.spentAt),
                style: theme.textTheme.bodyMedium),
            if (expense.category != null && expense.category!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Chip(label: Text(expense.category!)),
            ],
          ],
        ),
      ),
    );
  }
}
