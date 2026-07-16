import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../core/network/api_error.dart';
import '../../activity/application/activity_providers.dart';
import '../../groups/application/groups_providers.dart';
import '../application/settlements_providers.dart';
import '../data/settlements_repository.dart';

/// Record a payment between two members. Optionally prefilled from a suggested
/// payment (who → who → how much).
class RecordSettlementDialog extends ConsumerStatefulWidget {
  const RecordSettlementDialog({
    super.key,
    required this.groupId,
    this.fromMemberId,
    this.toMemberId,
    this.amountMinor,
  });

  final String groupId;
  final String? fromMemberId;
  final String? toMemberId;
  final int? amountMinor;

  @override
  ConsumerState<RecordSettlementDialog> createState() =>
      _RecordSettlementDialogState();
}

class _RecordSettlementDialogState
    extends ConsumerState<RecordSettlementDialog> {
  final _amount = TextEditingController();
  String? _from;
  String? _to;
  bool _submitting = false;
  bool _initialized = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _initFrom(List<dynamic> members) {
    if (_initialized) return;
    _initialized = true;
    _from = widget.fromMemberId ??
        (members.isNotEmpty ? members.first.id as String : null);
    _to = widget.toMemberId;
    if (widget.amountMinor != null) {
      _amount.text = Money.formatMinor(widget.amountMinor!);
    }
  }

  Future<void> _submit() async {
    final from = _from;
    final to = _to;
    if (from == null || to == null) {
      _snack('Pick who paid and who received.');
      return;
    }
    if (from == to) {
      _snack('Pick two different people.');
      return;
    }
    final minor = Money.parseToMinor(_amount.text);
    if (minor == null) {
      _snack('Enter a valid amount.');
      return;
    }

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(settlementsRepositoryProvider).createSettlement(
            groupId: widget.groupId,
            fromMember: from,
            toMember: to,
            amountMinor: minor,
          );
      ref.invalidate(settlementsProvider(widget.groupId));
      ref.invalidate(activityProvider);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Payment recorded')));
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
    final group = ref.watch(groupDetailProvider(widget.groupId)).asData?.value;
    if (group == null) {
      return const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    _initFrom(group.members);
    final members = group.members;

    return AlertDialog(
      title: const Text('Record a payment'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _from,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Who paid',
                prefixIcon: Icon(Icons.arrow_upward_rounded),
              ),
              items: members
                  .map((m) =>
                      DropdownMenuItem(value: m.id, child: Text(m.name)))
                  .toList(),
              onChanged: _submitting ? null : (v) => setState(() => _from = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _to,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Who received',
                prefixIcon: Icon(Icons.arrow_downward_rounded),
              ),
              items: members
                  .map((m) =>
                      DropdownMenuItem(value: m.id, child: Text(m.name)))
                  .toList(),
              onChanged: _submitting ? null : (v) => setState(() => _to = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              enabled: !_submitting,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${group.currency} ',
              ),
            ),
          ],
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
              : const Text('Record'),
        ),
      ],
    );
  }
}
