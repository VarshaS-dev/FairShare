import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/activity_dto.dart';
import '../data/activity_repository.dart';

/// The global activity feed across all the user's groups. Invalidate after an
/// action (expense/settlement) to refresh it.
final activityProvider = FutureProvider<List<Activity>>((ref) async {
  return ref.watch(activityRepositoryProvider).listActivity();
});
