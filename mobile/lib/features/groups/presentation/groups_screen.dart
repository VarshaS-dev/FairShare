import 'package:flutter/material.dart';

/// The Groups tab — the app's home.
///
/// For Slice 0 this is the "no groups yet" EMPTY STATE from our user flows.
/// It's intentionally not a blank screen: every empty state is a chance to
/// guide the user toward the next action (here, creating their first group).
/// The buttons are wired up in Slice 2 when groups become real.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {}, // TODO(slice-2): open Add Expense
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add expense'),
      ),
      body: Center(
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
                onPressed: () {}, // TODO(slice-2): open Create Group
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create your first group'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
