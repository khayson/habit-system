import 'package:dio/dio.dart';

/// Broad category, for deciding retry behaviour without parsing codes.
enum AppErrorKind {
  /// No response: offline, DNS, refused connection. Retriable.
  network,

  /// Timed out. Retriable.
  timeout,

  /// The server answered with the spec error envelope.
  api,

  /// The server answered with something that is not the spec envelope.
  unexpected,
}

/// Every failed API call surfaces as this. Carries the spec error envelope
/// `{ error: { code, message, fields?, ... }, meta: { request_id, server_time } }`.
class AppException implements Exception {
  final AppErrorKind kind;
  final int? statusCode;

  /// Stable machine code, e.g. `validation_failed`, `version_conflict`.
  final String code;
  final String message;
  final Map<String, List<String>> fields;
  final String? requestId;

  /// For 409 `version_conflict`: the canonical current resource.
  final Map<String, dynamic>? current;

  /// For 429: how long to wait before retrying.
  final Duration? retryAfter;

  /// The full `error` object, including keys this app version does not know.
  final Map<String, dynamic> details;

  const AppException({
    required this.kind,
    required this.code,
    required this.message,
    this.statusCode,
    this.fields = const {},
    this.requestId,
    this.current,
    this.retryAfter,
    this.details = const {},
  });

  /// Builds from an HTTP error response. Tolerates bodies that are not the spec envelope.
  factory AppException.fromResponse(int statusCode, Object? body, {String? retryAfterHeader}) {
    final retryAfter = _parseRetryAfter(retryAfterHeader);
    final error = body is Map ? body['error'] : null;
    if (error is! Map) {
      return AppException(
        kind: AppErrorKind.unexpected,
        statusCode: statusCode,
        code: 'unexpected_response',
        message: 'Something went wrong. Try again.',
        retryAfter: retryAfter,
      );
    }
    final meta = body is Map ? body['meta'] : null;
    final details = Map<String, dynamic>.unmodifiable(error.cast<String, dynamic>());
    final current = details['current'];

    return AppException(
      kind: AppErrorKind.api,
      statusCode: statusCode,
      code: details['code'] as String? ?? 'unknown',
      message: details['message'] as String? ?? 'Something went wrong. Try again.',
      fields: _parseFields(details['fields']),
      requestId: meta is Map ? meta['request_id'] as String? : null,
      current: current is Map
          ? Map<String, dynamic>.unmodifiable(current.cast<String, dynamic>())
          : null,
      retryAfter: retryAfter,
      details: details,
    );
  }

  factory AppException.fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const AppException(
          kind: AppErrorKind.timeout,
          code: 'timeout',
          message: 'The connection timed out. Try again.',
        );
      case DioExceptionType.connectionError:
        return const AppException(
          kind: AppErrorKind.network,
          code: 'network_unavailable',
          message: 'Could not reach the server. Your work stays on this device.',
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        final response = e.response;
        if (response != null) {
          return AppException.fromResponse(
            response.statusCode ?? 0,
            response.data,
            retryAfterHeader: response.headers.value('retry-after'),
          );
        }
        return const AppException(
          kind: AppErrorKind.network,
          code: 'network_unavailable',
          message: 'Could not reach the server. Your work stays on this device.',
        );
    }
  }

  bool get isRetriable =>
      kind == AppErrorKind.network ||
      kind == AppErrorKind.timeout ||
      statusCode == 429 ||
      (statusCode ?? 0) >= 500;

  bool get isUnauthenticated => statusCode == 401;
  bool get isVersionConflict => code == 'version_conflict';
  bool get isIdempotencyMismatch => code == 'idempotency_mismatch';
  bool get isResourceDeleted => code == 'resource_deleted';
  bool get isCursorExpired => code == 'cursor_expired';

  String? firstFieldError(String field) {
    final messages = fields[field];
    return messages == null || messages.isEmpty ? null : messages.first;
  }

  static Map<String, List<String>> _parseFields(Object? raw) {
    if (raw is! Map) return const {};
    return Map.unmodifiable({
      for (final entry in raw.entries)
        entry.key.toString(): [
          if (entry.value is List)
            for (final message in entry.value as List) message.toString(),
        ],
    });
  }

  static Duration? _parseRetryAfter(String? header) {
    final seconds = int.tryParse(header?.trim() ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  @override
  String toString() => 'AppException($statusCode $code, request_id=$requestId)';
}
