/// `meta` of a success envelope: `{ api_version, server_time, request_id, ...extra }`.
class ApiMeta {
  final String? apiVersion;
  final DateTime? serverTime;
  final String? requestId;

  /// Every meta key, including ones this app version does not know (tolerant reader).
  final Map<String, dynamic> raw;

  const ApiMeta({this.apiVersion, this.serverTime, this.requestId, this.raw = const {}});

  factory ApiMeta.fromJson(Map<String, dynamic>? json) {
    final meta = json ?? const <String, dynamic>{};
    final serverTime = meta['server_time'];
    return ApiMeta(
      apiVersion: meta['api_version'] as String?,
      serverTime: serverTime is String ? DateTime.tryParse(serverTime)?.toUtc() : null,
      requestId: meta['request_id'] as String?,
      raw: Map.unmodifiable(meta),
    );
  }
}

/// Success envelope of this API: `{ data, meta }`. Errors never reach this type; they are
/// raised as [AppException].
class ApiResponse<T> {
  final T data;
  final ApiMeta meta;

  const ApiResponse({required this.data, required this.meta});

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic data) parser) {
    return ApiResponse(
      data: parser(json['data']),
      meta: ApiMeta.fromJson(json['meta'] as Map<String, dynamic>?),
    );
  }
}
