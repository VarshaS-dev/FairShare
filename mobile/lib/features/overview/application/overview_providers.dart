import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/overview_dto.dart';
import '../data/overview_repository.dart';

/// Consolidated cross-group balances per person. Invalidated whenever an
/// expense or settlement changes (see the add-expense / settlement flows), so
/// the home screen stays current.
final overviewProvider = FutureProvider<Overview>((ref) async {
  return ref.watch(overviewRepositoryProvider).getOverview();
});
