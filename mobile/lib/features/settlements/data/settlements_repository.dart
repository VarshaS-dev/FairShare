import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'settlement_dto.dart';

class SettlementsRepository {
  SettlementsRepository(this._dio);

  final Dio _dio;

  Future<List<Settlement>> listSettlements(String groupId) async {
    final res = await _dio.get<List<dynamic>>('/groups/$groupId/settlements');
    return (res.data ?? const [])
        .map((e) => Settlement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createSettlement({
    required String groupId,
    required String fromMember,
    required String toMember,
    required int amountMinor,
    String? note,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/groups/$groupId/settlements',
      data: {
        'from_member': fromMember,
        'to_member': toMember,
        'amount_minor': amountMinor,
        'note': ?note,
      },
    );
  }

  Future<void> deleteSettlement({
    required String groupId,
    required String settlementId,
  }) async {
    await _dio.delete<void>('/groups/$groupId/settlements/$settlementId');
  }
}

final settlementsRepositoryProvider = Provider<SettlementsRepository>((ref) {
  return SettlementsRepository(ref.watch(dioProvider));
});
