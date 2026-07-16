import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../application/activity_providers.dart';
import '../data/activity_dto.dart';

/// The Activity tab — a live feed of recent events across all your groups.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(activityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(activityProvider),
          ),
        ],
      ),
      body: activityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: describeApiError(e),
          onRetry: () => ref.invalidate(activityProvider),
        ),
        data: (items) => items.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: () => ref.refresh(activityProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ActivityTile(item: items[i]),
                ),
              ),
      ),
    );
  }
}

IconData _iconFor(String type) => switch (type) {
      'expense_added' => Icons.receipt_long_rounded,
      'expense_updated' => Icons.edit_rounded,
      'expense_deleted' => Icons.delete_outline_rounded,
      'settlement_recorded' => Icons.payments_rounded,
      'settlement_removed' => Icons.undo_rounded,
      'group_created' => Icons.group_add_rounded,
      'member_added' => Icons.person_add_alt_rounded,
      'member_joined' => Icons.login_rounded,
      _ => Icons.notifications_rounded,
    };

String _timeAgo(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final Activity item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Icon(_iconFor(item.type),
              color: theme.colorScheme.onSecondaryContainer),
        ),
        title: Text(item.summary),
        subtitle: Text('${item.groupName} · ${_timeAgo(item.createdAt)}'),
        onTap: () => context.push('/group/${item.groupId}'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Nothing here yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Expenses, payments, and new members across your groups will '
              'show up here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
