import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'group_dto.dart';

/// Talks to the backend's /groups endpoints. The Dio it receives already
/// attaches the Firebase token, so this layer just deals in groups.
class GroupsRepository {
  GroupsRepository(this._dio);

  final Dio _dio;

  Future<List<Group>> listGroups() async {
    final res = await _dio.get<List<dynamic>>('/groups');
    final data = res.data ?? const [];
    return data
        .map((e) => Group.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Group> createGroup({
    required String name,
    required String currency,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/groups',
      data: {'name': name, 'currency': currency},
    );
    return Group.fromJson(res.data!);
  }
}

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(ref.watch(dioProvider));
});
