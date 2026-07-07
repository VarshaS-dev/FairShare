import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base URL of the FastAPI backend.
///
/// On web (Chrome) the backend is reachable at localhost:8000. When we add
/// Android, the emulator reaches the host machine via 10.0.2.2 instead — we'll
/// branch on the platform then.
const String _baseUrl = 'http://localhost:8000/api/v1';

/// A configured Dio instance, provided via Riverpod so the whole app shares one
/// client (and tests can override it).
///
/// The interceptor attaches the caller's Firebase ID token to every request as
/// a Bearer header. `getIdToken()` returns a cached token and refreshes it
/// automatically when it's near expiry, so we never ship a stale token.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final token = await user.getIdToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
    ),
  );

  return dio;
});
