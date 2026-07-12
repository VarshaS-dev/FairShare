import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/groups_providers.dart';
import '../data/group_dto.dart';

/// The Groups tab — now backed by real data from the API.
///
/// `groupsListProvider` is an AsyncValue, so `.when(...)` cleanly renders the
/// three states our user flows demand: loading, error, and data (empty or not).
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
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
        data: (groups) => groups.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: () => ref.refresh(groupsListProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _GroupCard(group: groups[i]),
                ),
              ),
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
