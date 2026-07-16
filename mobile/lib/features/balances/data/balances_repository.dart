import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'balance_dto.dart';

class BalancesRepository {
  BalancesRepository(this._dio);

  final Dio _dio;

  Future<Balances> getBalances(String groupId) async {
    final res =
        await _dio.get<Map<String, dynamic>>('/groups/$groupId/balances');
    return Balances.fromJson(res.data!);
  }
}

final balancesRepositoryProvider = Provider<BalancesRepository>((ref) {
  return BalancesRepository(ref.watch(dioProvider));
});
