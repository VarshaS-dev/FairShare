import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settlement_dto.dart';
import '../data/settlements_repository.dart';

/// A group's recorded payments (newest first).
final settlementsProvider =
    FutureProvider.family<List<Settlement>, String>((ref, groupId) async {
  return ref.watch(settlementsRepositoryProvider).listSettlements(groupId);
});
