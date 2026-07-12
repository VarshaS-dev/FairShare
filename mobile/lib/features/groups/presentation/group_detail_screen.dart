import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../application/groups_providers.dart';
import '../data/group_dto.dart';
import '../data/groups_repository.dart';

/// Generates an invite (group-wide, or a placeholder claim if [memberId] is
/// set) and shows its code. Shared by the app-bar action and the member menu.
Future<void> _createAndShowInvite(
  BuildContext context,
  WidgetRef ref,
  String groupId, {
  String? memberId,
  String? forName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final code = await ref
        .read(groupsRepositoryProvider)
        .createInvite(groupId: groupId, memberId: memberId);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _InviteCodeDialog(code: code, forName: forName),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(describeApiError(e))));
  }
}

/// Shows one group and its members. Reached by tapping a group card.
class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupDetailProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        title: Text(groupAsync.asData?.value.name ?? 'Group'),
        actions: [
          if (groupAsync.asData != null)
            IconButton(
              icon: const Icon(Icons.link_rounded),
              tooltip: 'Invite to group',
              onPressed: () => _createAndShowInvite(context, ref, groupId),
            ),
        ],
      ),
      floatingActionButton: groupAsync.asData != null
          ? FloatingActionButton.extended(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _AddMemberDialog(groupId: groupId),
              ),
              icon: const Icon(Icons.person_add_alt_rounded),
              label: const Text('Add member'),
            )
          : null,
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 56),
                const SizedBox(height: 12),
                Text(describeApiError(e), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(groupDetailProvider(groupId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (group) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _GroupHeader(group: group),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Members', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 6),
                Text('(${group.members.length})',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 8),
            ...group.members
                .map((m) => _MemberTile(groupId: groupId, member: m)),
            const SizedBox(height: 80), // breathing room above the FAB
          ],
        ),
      ),
    );
  }
}

class _InviteCodeDialog extends StatelessWidget {
  const _InviteCodeDialog({required this.code, this.forName});

  final String code;
  final String? forName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    return AlertDialog(
      title: Text(forName == null ? 'Invite to group' : 'Invite for $forName'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            forName == null
                ? 'Share this code. Whoever enters it joins the group.'
                : 'Share this code with $forName. When they sign up and enter '
                    'it, they take over this spot — keeping its history.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    code,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(letterSpacing: 3),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  tooltip: 'Copy',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Expires in 7 days · single use',
              style: theme.textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

enum _AddMode { name, email }

/// Add someone as a placeholder (name only) or by linking an existing user (email).
class _AddMemberDialog extends ConsumerStatefulWidget {
  const _AddMemberDialog({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<_AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  _AddMode _mode = _AddMode.name;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final value = _controller.text.trim();

    try {
      await ref.read(groupsRepositoryProvider).addMember(
            groupId: widget.groupId,
            name: _mode == _AddMode.name ? value : null,
            email: _mode == _AddMode.email ? value : null,
          );
      ref.invalidate(groupDetailProvider(widget.groupId));
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Member added')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(content: Text(describeApiError(e))));
    }
  }

  String? _validate(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) {
      return _mode == _AddMode.name ? 'Enter a name' : 'Enter an email';
    }
    if (_mode == _AddMode.email &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
      return 'Enter a valid email';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final byName = _mode == _AddMode.name;
    return AlertDialog(
      title: const Text('Add member'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<_AddMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _AddMode.name,
                    icon: Icon(Icons.person_outline_rounded),
                    label: Text('By name'),
                  ),
                  ButtonSegment(
                    value: _AddMode.email,
                    icon: Icon(Icons.mail_outline_rounded),
                    label: Text('By email'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: _submitting
                    ? null
                    : (s) => setState(() {
                          _mode = s.first;
                          _controller.clear();
                          _formKey.currentState?.reset();
                        }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                autofocus: true,
                enabled: !_submitting,
                keyboardType:
                    byName ? TextInputType.name : TextInputType.emailAddress,
                textCapitalization: byName
                    ? TextCapitalization.words
                    : TextCapitalization.none,
                decoration: InputDecoration(
                  labelText: byName ? 'Name' : 'Email',
                  hintText: byName ? 'e.g. Riya' : 'e.g. riya@example.com',
                  helperText: byName
                      ? "They don't need an account"
                      : 'Must already have a FairShare account',
                  prefixIcon: Icon(byName
                      ? Icons.person_outline_rounded
                      : Icons.mail_outline_rounded),
                ),
                validator: _validate,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final GroupDetail group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = group.members.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                group.name.trim().isNotEmpty
                    ? group.name.trim()[0].toUpperCase()
                    : '?',
                style:
                    TextStyle(color: theme.colorScheme.onPrimary, fontSize: 22),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${group.currency} · $count member${count == 1 ? '' : 's'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.groupId, required this.member});

  final String groupId;
  final Member member;

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('Remove ${member.name} from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(groupsRepositoryProvider)
          .removeMember(groupId: groupId, memberId: member.id);
      ref.invalidate(groupDetailProvider(groupId));
      messenger.showSnackBar(const SnackBar(content: Text('Member removed')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeApiError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final initial = member.name.trim().isNotEmpty
        ? member.name.trim()[0].toUpperCase()
        : '?';
    final isCreator = member.role == 'creator';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondary,
          child: Text(initial,
              style: TextStyle(color: theme.colorScheme.onSecondary)),
        ),
        title: Text(member.name),
        subtitle: member.isUser ? null : const Text('No account yet'),
        trailing: isCreator
            ? const Chip(
                label: Text('Creator'),
                visualDensity: VisualDensity.compact,
              )
            : PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'invite') {
                    _createAndShowInvite(context, ref, groupId,
                        memberId: member.id, forName: member.name);
                  } else if (v == 'remove') {
                    _confirmRemove(context, ref);
                  }
                },
                itemBuilder: (_) => [
                  // Only placeholders (no account) can be "claimed" via invite.
                  if (!member.isUser)
                    const PopupMenuItem(
                      value: 'invite',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.link_rounded),
                        title: Text('Invite to claim'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.person_remove_outlined),
                      title: Text('Remove'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
