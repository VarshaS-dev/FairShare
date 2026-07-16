import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../expenses/application/expenses_providers.dart';
import '../../settlements/application/settlements_providers.dart';
import '../data/balance_dto.dart';
import '../data/balances_repository.dart';

/// Balances are derived from expenses AND settlements, so we `watch` both:
/// whenever either changes (an expense or a payment added/removed), balances
/// recompute automatically. No manual invalidation needed at each call site.
final balancesProvider =
    FutureProvider.family<Balances, String>((ref, groupId) async {
  ref.watch(expensesProvider(groupId));
  ref.watch(settlementsProvider(groupId));
  return ref.watch(balancesRepositoryProvider).getBalances(groupId);
});
