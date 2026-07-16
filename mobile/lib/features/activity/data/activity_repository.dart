import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'activity_dto.dart';

class ActivityRepository {
  ActivityRepository(this._dio);

  final Dio _dio;

  Future<List<Activity>> listActivity() async {
    final res = await _dio.get<List<dynamic>>('/activity');
    return (res.data ?? const [])
        .map((e) => Activity.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(ref.watch(dioProvider));
});
