import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money.dart';
import '../../../core/network/api_error.dart';
import '../../balances/presentation/balances_tab.dart';
import '../../expenses/application/expenses_providers.dart';
import '../../expenses/data/expense_dto.dart';
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

/// Group detail: an Expenses tab and a Members tab. The FAB matches the tab.
class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {})); // swap the FAB per tab
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        title: Text(groupAsync.asData?.value.name ?? 'Group'),
        actions: [
          if (groupAsync.asData != null)
            IconButton(
              icon: const Icon(Icons.link_rounded),
              tooltip: 'Invite to group',
              onPressed: () =>
                  _createAndShowInvite(context, ref, widget.groupId),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Balances'),
            Tab(text: 'Members'),
          ],
        ),
      ),
      floatingActionButton: groupAsync.asData == null
          ? null
          : switch (_tab.index) {
              0 => FloatingActionButton.extended(
                  onPressed: () =>
                      context.push('/group/${widget.groupId}/add-expense'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add expense'),
                ),
              2 => FloatingActionButton.extended(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _AddMemberDialog(groupId: widget.groupId),
                  ),
                  icon: const Icon(Icons.person_add_alt_rounded),
                  label: const Text('Add member'),
                ),
              _ => null,
            },
      body: TabBarView(
        controller: _tab,
        children: [
          _ExpensesTab(groupId: widget.groupId),
          BalancesTab(groupId: widget.groupId),
          _MembersTab(groupId: widget.groupId),
        ],
      ),
    );
  }
}

class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider(groupId));
    final currency =
        ref.watch(groupDetailProvider(groupId)).asData?.value.currency ?? '';

    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorRetry(
        message: describeApiError(e),
        onRetry: () => ref.invalidate(expensesProvider(groupId)),
      ),
      data: (expenses) => expenses.isEmpty
          ? const _EmptyExpenses()
          : RefreshIndicator(
              onRefresh: () => ref.refresh(expensesProvider(groupId).future),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: expenses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _ExpenseTile(
                    groupId: groupId, expense: expenses[i], currency: currency),
              ),
            ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.groupId,
    required this.expense,
    required this.currency,
  });

  final String groupId;
  final Expense expense;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondary,
          child: Icon(Icons.receipt_long_rounded,
              color: theme.colorScheme.onSecondary),
        ),
        title: Text(expense.description),
        subtitle: Text('Paid by ${expense.paidByName}'),
        trailing: Text(
          Money.formatWithCurrency(expense.amountMinor, currency),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        onTap: () => context.push('/group/$groupId/expense/${expense.id}'),
      ),
    );
  }
}

class _EmptyExpenses extends StatelessWidget {
  const _EmptyExpenses();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('No expenses yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Tap “Add expense” to start splitting.',
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupDetailProvider(groupId));
    return groupAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorRetry(
        message: describeApiError(e),
        onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
      ),
      data: (group) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
          ...group.members.map((m) => _MemberTile(groupId: groupId, member: m)),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

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
