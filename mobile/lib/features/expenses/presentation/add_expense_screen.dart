import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../core/network/api_error.dart';
import '../../activity/application/activity_providers.dart';
import '../../groups/application/groups_providers.dart';
import '../../groups/data/group_dto.dart';
import '../application/expenses_providers.dart';
import '../data/expense_dto.dart';
import '../data/expenses_repository.dart';

enum _Method { equal, exact, percentage, shares }

/// Log or edit an expense: amount, who paid, how it's split.
///
/// Pass [expense] to edit an existing one — it prefills as an "exact" split with
/// the current per-member shares (all locked), which the user can tweak or
/// re-split with a different method.
///
/// For Exact and Percentage, participants start on an equal share; editing a
/// field "locks" it and the remainder auto-splits across the unlocked ones.
class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key, required this.groupId, this.expense});

  final String groupId;
  final Expense? expense;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _desc = TextEditingController();
  final _amount = TextEditingController();
  String? _paidBy;
  _Method _method = _Method.equal;
  final Set<String> _participants = {};
  final Map<String, TextEditingController> _values = {};
  final Set<String> _locked = {};
  bool _submitting = false;
  bool _initialized = false;

  bool get _isEdit => widget.expense != null;

  @override
  void dispose() {
    _desc.dispose();
    _amount.dispose();
    for (final c in _values.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initFrom(GroupDetail group) {
    if (_initialized) return;
    _initialized = true;
    for (final m in group.members) {
      _values[m.id] = TextEditingController();
    }

    final expense = widget.expense;
    if (expense == null) {
      // Add mode: everyone participates, first member pays.
      if (group.members.isNotEmpty) _paidBy = group.members.first.id;
      _participants.addAll(group.members.map((m) => m.id));
    } else {
      // Edit mode: prefill from the expense as a fully-specified exact split.
      _desc.text = expense.description;
      _amount.text = Money.formatMinor(expense.amountMinor);
      _paidBy = expense.paidBy;
      _method = _Method.exact;
      for (final s in expense.splits) {
        _participants.add(s.memberId);
        _values[s.memberId]?.text = Money.formatMinor(s.shareMinor);
        _locked.add(s.memberId); // keep prefilled values as-is
      }
    }
  }

  int get _total => Money.parseToMinor(_amount.text) ?? 0;
  int _exactMinor(String id) => Money.parseToMinor(_values[id]!.text) ?? 0;
  int _intVal(String id) => int.tryParse(_values[id]!.text.trim()) ?? 0;
  int _sumExact() => _participants.fold(0, (s, id) => s + _exactMinor(id));
  int _sumInts() => _participants.fold(0, (s, id) => s + _intVal(id));

  bool get _autoBalanced =>
      _method == _Method.exact || _method == _Method.percentage;
  int _target() => _method == _Method.exact ? _total : 100;
  int _currentVal(String id) =>
      _method == _Method.exact ? _exactMinor(id) : _intVal(id);
  void _setField(String id, int value) {
    _values[id]!.text =
        _method == _Method.exact ? Money.formatMinor(value) : value.toString();
  }

  void _redistribute() {
    if (!_autoBalanced) return;
    final unlocked = _participants.where((id) => !_locked.contains(id)).toList()
      ..sort();
    if (unlocked.isEmpty) return;
    final lockedSum = _participants
        .where(_locked.contains)
        .fold(0, (s, id) => s + _currentVal(id));
    var remaining = _target() - lockedSum;
    if (remaining < 0) remaining = 0;
    final n = unlocked.length;
    final base = remaining ~/ n;
    final extra = remaining % n;
    for (var i = 0; i < n; i++) {
      _setField(unlocked[i], base + (i < extra ? 1 : 0));
    }
  }

  void _onValueEdited(String id, String text) {
    setState(() {
      if (text.trim().isEmpty) {
        _locked.remove(id);
      } else {
        _locked.add(id);
      }
      _redistribute();
    });
  }

  void _onMethodChanged(_Method m) {
    setState(() {
      _method = m;
      _locked.clear();
      if (m == _Method.shares) {
        for (final id in _participants) {
          _values[id]!.text = '1';
        }
      } else if (_autoBalanced) {
        _redistribute();
      }
    });
  }

  void _onParticipantToggled(String id, bool included) {
    setState(() {
      if (included) {
        _participants.add(id);
        if (_method == _Method.shares) _values[id]!.text = '1';
      } else {
        _participants.remove(id);
        _locked.remove(id);
      }
      if (_autoBalanced) _redistribute();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paidBy == null || _participants.isEmpty) {
      _snack('Pick who paid and at least one participant.');
      return;
    }
    final total = _total;
    if (total <= 0) {
      _snack('Enter a valid amount.');
      return;
    }

    late final List<({String memberId, int? value})> entries;
    switch (_method) {
      case _Method.equal:
        entries =
            _participants.map((id) => (memberId: id, value: null)).toList();
      case _Method.exact:
        if (_sumExact() != total) {
          _snack('The exact amounts must add up to the total.');
          return;
        }
        entries = _participants
            .map((id) => (memberId: id, value: _exactMinor(id)))
            .toList();
      case _Method.percentage:
        if (_sumInts() != 100) {
          _snack('Percentages must add up to 100.');
          return;
        }
        entries =
            _participants.map((id) => (memberId: id, value: _intVal(id))).toList();
      case _Method.shares:
        if (_sumInts() <= 0) {
          _snack('Shares must be positive.');
          return;
        }
        entries =
            _participants.map((id) => (memberId: id, value: _intVal(id))).toList();
    }

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final repo = ref.read(expensesRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.updateExpense(
          groupId: widget.groupId,
          expenseId: widget.expense!.id,
          description: _desc.text.trim(),
          amountMinor: total,
          paidBy: _paidBy!,
          method: _method.name,
          entries: entries,
        );
      } else {
        await repo.createExpense(
          groupId: widget.groupId,
          description: _desc.text.trim(),
          amountMinor: total,
          paidBy: _paidBy!,
          method: _method.name,
          entries: entries,
        );
      }
      ref.invalidate(expensesProvider(widget.groupId));
      ref.invalidate(activityProvider);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Expense updated' : 'Expense added')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(content: Text(describeApiError(e))));
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit expense' : 'Add expense')),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(describeApiError(e))),
        data: (group) {
          _initFrom(group);
          return _form(context, group);
        },
      ),
    );
  }

  Widget _form(BuildContext context, GroupDetail group) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _desc,
                  enabled: !_submitting,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'e.g. Dinner, Cab, Groceries',
                    prefixIcon: Icon(Icons.receipt_long_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Add a description'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amount,
                  enabled: !_submitting,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {
                    if (_method == _Method.exact) _redistribute();
                  }),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '${group.currency} ',
                    prefixIcon: const Icon(Icons.payments_rounded),
                  ),
                  validator: (v) => Money.parseToMinor(v ?? '') == null
                      ? 'Enter a valid amount'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _paidBy,
                  decoration: const InputDecoration(
                    labelText: 'Paid by',
                    prefixIcon: Icon(Icons.account_circle_outlined),
                  ),
                  items: group.members
                      .map((m) =>
                          DropdownMenuItem(value: m.id, child: Text(m.name)))
                      .toList(),
                  onChanged:
                      _submitting ? null : (v) => setState(() => _paidBy = v),
                ),
                const SizedBox(height: 24),
                Text('Split', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<_Method>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: _Method.equal, label: Text('Equal')),
                    ButtonSegment(value: _Method.exact, label: Text('Exact')),
                    ButtonSegment(value: _Method.percentage, label: Text('%')),
                    ButtonSegment(value: _Method.shares, label: Text('Shares')),
                  ],
                  selected: {_method},
                  onSelectionChanged:
                      _submitting ? null : (s) => _onMethodChanged(s.first),
                ),
                const SizedBox(height: 8),
                ...group.members.map((m) => _memberRow(context, group, m)),
                const SizedBox(height: 8),
                _summary(context, group),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEdit ? 'Save changes' : 'Add expense'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _memberRow(BuildContext context, GroupDetail group, Member m) {
    final included = _participants.contains(m.id);
    final needsValue = _method != _Method.equal;
    final locked = _locked.contains(m.id);
    return Row(
      children: [
        Checkbox(
          value: included,
          onChanged: _submitting
              ? null
              : (checked) => _onParticipantToggled(m.id, checked == true),
        ),
        Expanded(child: Text(m.name)),
        if (needsValue)
          SizedBox(
            width: 118,
            child: TextField(
              controller: _values[m.id],
              enabled: !_submitting && included,
              textAlign: TextAlign.right,
              keyboardType: _method == _Method.exact
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              onChanged: (text) {
                if (_autoBalanced) {
                  _onValueEdited(m.id, text);
                } else {
                  setState(() {});
                }
              },
              decoration: InputDecoration(
                isDense: true,
                suffixIcon: (_autoBalanced && included && locked)
                    ? const Icon(Icons.lock_outline_rounded, size: 16)
                    : null,
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 24, minHeight: 24),
                prefixText:
                    _method == _Method.exact ? '${group.currency} ' : null,
                suffixText: _method == _Method.percentage
                    ? '%'
                    : (_method == _Method.shares ? '×' : null),
              ),
            ),
          ),
      ],
    );
  }

  Widget _summary(BuildContext context, GroupDetail group) {
    final theme = Theme.of(context);
    final total = _total;
    final n = _participants.length;
    String text;
    bool ok = true;
    switch (_method) {
      case _Method.equal:
        final per = n > 0 ? total ~/ n : 0;
        text = n == 0
            ? 'Pick at least one participant'
            : '${group.currency} ${Money.formatMinor(per)} each'
                '${(n > 0 && total % n != 0) ? '  (rounded)' : ''}';
      case _Method.exact:
        final sum = _sumExact();
        final diff = total - sum;
        ok = diff == 0;
        text = 'Entered ${group.currency} ${Money.formatMinor(sum)} of '
            '${Money.formatMinor(total)}'
            '${diff == 0 ? '  ✓' : diff > 0 ? '  (${group.currency} ${Money.formatMinor(diff)} left)' : '  (${group.currency} ${Money.formatMinor(-diff)} over)'}';
      case _Method.percentage:
        final sum = _sumInts();
        ok = sum == 100;
        text = '$sum% of 100%${sum == 100 ? '  ✓' : ''}';
      case _Method.shares:
        final sum = _sumInts();
        ok = sum > 0;
        text = '$sum share${sum == 1 ? '' : 's'} total';
    }
    return Card(
      color: ok
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: ok ? null : theme.colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}
