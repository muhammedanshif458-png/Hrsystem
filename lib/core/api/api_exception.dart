// ─── lib/core/api/api_exception.dart ─────────────────────────────────────────
// Custom exception type thrown by ApiService for all HTTP / network errors.
// The UI layer catches ApiException and shows the appropriate message.
// ─────────────────────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data; // raw response body, if any

  const ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';

  // ── Convenience factories ─────────────────────────────────────────────────

  /// Server returned 4xx / 5xx with a JSON body
  factory ApiException.fromResponse({
    required int statusCode,
    required dynamic responseData,
  }) {
    String message = 'Something went wrong. Please try again.';

    if (responseData is Map<String, dynamic>) {
      // Check for validation errors array first (e.g. from express-validator)
      if (responseData['errors'] is List &&
          (responseData['errors'] as List).isNotEmpty) {
        final errList = (responseData['errors'] as List)
            .map((e) => e is Map ? (e['message'] ?? e['msg'] ?? e.toString()) : e.toString())
            .where((m) => m != null && m.toString().trim().isNotEmpty)
            .toList();
        if (errList.isNotEmpty) {
          message = errList.join(', ');
        } else {
          message = (responseData['message'] as String?) ?? message;
        }
      } else {
        message = (responseData['message'] as String?) ??
            (responseData['error'] as String?) ??
            (responseData['msg'] as String?) ??
            message;
      }
    }

    return ApiException(
      message: message,
      statusCode: statusCode,
      data: responseData,
    );
  }

  /// No internet / connection refused / timeout
  factory ApiException.noConnection() => const ApiException(
        message: 'Unable to connect. Please check your internet connection.',
        statusCode: null,
      );

  /// Request timed out
  factory ApiException.timeout() => const ApiException(
        message: 'The server is taking too long to respond (it may be waking up). Please wait a moment and try again.',
        statusCode: null,
      );

  /// Unknown / unexpected error
  factory ApiException.unknown(Object error) => ApiException(
        message: 'An unexpected error occurred: $error',
        statusCode: null,
      );

  // ── Helpers for common HTTP codes ─────────────────────────────────────────
  bool get isUnauthorized  => statusCode == 401;
  bool get isForbidden     => statusCode == 403;
  bool get isNotFound      => statusCode == 404;
  bool get isServerError   => statusCode != null && statusCode! >= 500;
}
