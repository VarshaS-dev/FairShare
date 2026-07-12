import 'package:dio/dio.dart';

/// Turns a network/API failure into a friendly, user-facing message.
///
/// FastAPI puts human-readable text in the `detail` field of its error bodies
/// (e.g. "They're already in this group."), so we surface that when present.
/// Keeping this in one place means screens never parse exceptions themselves.
String describeApiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    // 422 validation errors put a *list* in `detail`, so check the type.
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return 'Cannot reach the server. Is the backend running?';
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'The server took too long to respond.';
      default:
        break;
    }
  }
  return 'Something went wrong. Please try again.';
}
