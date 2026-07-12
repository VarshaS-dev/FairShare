import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/group_dto.dart';
import '../data/groups_repository.dart';

/// Loads the signed-in user's groups from the backend.
///
/// A [FutureProvider] hands the UI an AsyncValue with loading / error / data
/// states for free. Call `ref.invalidate(groupsListProvider)` after creating a
/// group to refetch the list.
final groupsListProvider = FutureProvider<List<Group>>((ref) async {
  return ref.watch(groupsRepositoryProvider).listGroups();
});

/// Loads one group's detail (incl. members). `.family` parameterizes the
/// provider by group id, so each group gets its own cached async state.
final groupDetailProvider =
    FutureProvider.family<GroupDetail, String>((ref, id) async {
  return ref.watch(groupsRepositoryProvider).getGroup(id);
});
