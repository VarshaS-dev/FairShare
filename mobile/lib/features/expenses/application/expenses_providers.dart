import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/expense_dto.dart';
import '../data/expenses_repository.dart';

/// Loads a group's expenses. Invalidate after adding one to refetch.
final expensesProvider =
    FutureProvider.family<List<Expense>, String>((ref, groupId) async {
  return ref.watch(expensesRepositoryProvider).listExpenses(groupId);
});
