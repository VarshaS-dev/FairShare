import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../application/groups_providers.dart';
import '../data/groups_repository.dart';
import '../data/invite_dto.dart';

/// Enter an invite code → preview the group → join. Completes the invite loop.
class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final _code = TextEditingController();
  InvitePreview? _preview;
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookUp() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final preview =
          await ref.read(groupsRepositoryProvider).previewInvite(code);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text(describeApiError(e))));
    }
  }

  Future<void> _accept() async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = _preview?.groupName ?? 'group';
    try {
      await ref
          .read(groupsRepositoryProvider)
          .acceptInvite(_code.text.trim().toUpperCase());
      ref.invalidate(groupsListProvider); // the new group now shows in the list
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Joined $name')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text(describeApiError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _preview;

    return Scaffold(
      appBar: AppBar(title: const Text('Join a group')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Enter your invite code',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  enabled: !_loading,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Invite code',
                    hintText: 'e.g. K7P2M9QX',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                  onChanged: (_) {
                    // Editing the code invalidates a stale preview.
                    if (_preview != null) setState(() => _preview = null);
                  },
                  onSubmitted: (_) => _lookUp(),
                ),
                const SizedBox(height: 16),
                if (preview == null)
                  FilledButton(
                    onPressed: _loading ? null : _lookUp,
                    child: _loading ? const _Spinner() : const Text('Continue'),
                  )
                else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(preview.groupName,
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(preview.currency,
                              style: theme.textTheme.bodyMedium),
                          if (preview.claimName != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              'You\'ll take over "${preview.claimName}" in this group.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                          if (preview.alreadyMember) ...[
                            const SizedBox(height: 10),
                            Text(
                              "You're already a member of this group.",
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed:
                        (_loading || preview.alreadyMember) ? null : _accept,
                    child: _loading
                        ? const _Spinner()
                        : Text('Join ${preview.groupName}'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
}
