import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'group_dto.dart';
import 'invite_dto.dart';

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

  Future<GroupDetail> getGroup(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/groups/$id');
    return GroupDetail.fromJson(res.data!);
  }

  /// Adds a member to a group. Provide EXACTLY ONE of:
  ///  * [name]  — a non-user placeholder (no account needed)
  ///  * [email] — an existing FairShare user, who gets linked properly
  Future<Member> addMember({
    required String groupId,
    String? name,
    String? email,
  }) async {
    assert((name == null) != (email == null),
        'Provide exactly one of `name` or `email`.');
    final res = await _dio.post<Map<String, dynamic>>(
      '/groups/$groupId/members',
      data: name != null ? {'name': name} : {'email': email},
    );
    return Member.fromJson(res.data!);
  }

  /// Removes a member from a group.
  Future<void> removeMember({
    required String groupId,
    required String memberId,
  }) async {
    await _dio.delete<void>('/groups/$groupId/members/$memberId');
  }

  /// Creates a shareable invite code. Pass [memberId] to make it a
  /// "claim this placeholder" invite; omit it for a generic group join.
  Future<String> createInvite({
    required String groupId,
    String? memberId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/groups/$groupId/invites',
      data: memberId != null ? {'member_id': memberId} : <String, dynamic>{},
    );
    return res.data!['code'] as String;
  }

  Future<InvitePreview> previewInvite(String code) async {
    final res = await _dio.get<Map<String, dynamic>>('/invites/$code');
    return InvitePreview.fromJson(res.data!);
  }

  /// Accepts an invite; returns the joined group's id.
  Future<String> acceptInvite(String code) async {
    final res =
        await _dio.post<Map<String, dynamic>>('/invites/$code/accept');
    return res.data!['id'] as String;
  }
}

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(ref.watch(dioProvider));
});
