import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money.dart';
import '../../overview/application/overview_providers.dart';
import '../../overview/data/overview_dto.dart';
import '../application/groups_providers.dart';
import '../data/group_dto.dart';

const _owedColor = Color(0xFF2E7D32); // green 800 — money owed to you

/// The home screen: a consolidated per-person balance section, then the groups.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.input_rounded),
            tooltip: 'Join a group',
            onPressed: () => context.push('/join'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-group'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New group'),
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorState(
          onRetry: () => ref.invalidate(groupsListProvider),
        ),
        data: (groups) {
          if (groups.isEmpty) return const _EmptyState();
          final people =
              ref.watch(overviewProvider).asData?.value.people ?? const [];
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(overviewProvider);
              ref.invalidate(groupsListProvider);
              await ref.read(groupsListProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (people.isNotEmpty) ...[
                  Text('Balances', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...people.map((p) => _PersonCard(person: p)),
                  const SizedBox(height: 24),
                ],
                Text('Groups', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...groups.map((g) => _GroupCard(group: g)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person});

  final OverviewPerson person;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = person.netMinor;
    final owedToMe = net > 0;
    final text = owedToMe
        ? 'owes you ${Money.formatWithCurrency(net, person.currency)}'
        : 'you owe ${Money.formatWithCurrency(-net, person.currency)}';
    final color = owedToMe ? _owedColor : theme.colorScheme.error;
    final initial =
        person.name.trim().isNotEmpty ? person.name.trim()[0].toUpperCase() : '?';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary,
          child: Text(initial,
              style: TextStyle(color: theme.colorScheme.onPrimary)),
        ),
        title: Text(person.name),
        subtitle: Text(text, style: TextStyle(color: color)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push('/person', extra: person),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial =
        group.name.trim().isNotEmpty ? group.name.trim()[0].toUpperCase() : '?';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondary,
          child: Text(
            initial,
            style: TextStyle(color: theme.colorScheme.onSecondary),
          ),
        ),
        title: Text(group.name),
        subtitle: Text(group.currency),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push('/group/${group.id}'),
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
            Icon(Icons.groups_rounded, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('No groups yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Create a group to start splitting expenses with friends, '
              'roommates, or travel buddies.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/create-group'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create your first group'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text("Couldn't load your groups", style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Check that the backend is running, then try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
