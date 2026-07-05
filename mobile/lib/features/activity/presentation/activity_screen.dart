import 'package:flutter/material.dart';

/// The Activity tab — a global feed of recent expenses and settlements.
/// Slice 0 shows its empty state; real activity arrives with Slice 4+.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: Center(
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
                'Your recent expenses and settlements will show up here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
