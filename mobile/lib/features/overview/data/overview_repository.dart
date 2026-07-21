import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'overview_dto.dart';

class OverviewRepository {
  OverviewRepository(this._dio);

  final Dio _dio;

  Future<Overview> getOverview() async {
    final res = await _dio.get<Map<String, dynamic>>('/overview');
    return Overview.fromJson(res.data!);
  }
}

final overviewRepositoryProvider = Provider<OverviewRepository>((ref) {
  return OverviewRepository(ref.watch(dioProvider));
});
