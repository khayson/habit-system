import 'package:dio/dio.dart';

import 'avatar_transport.dart';

/// [AvatarTransport] over HTTP (A20). Pure Dart, like [HttpSyncTransport]: [dio] already
/// carries the base URL and the bearer token. The upload is a real multipart PUT (field
/// "photo"), not a POST with a method override.
class HttpAvatarTransport implements AvatarTransport {
  final Dio _dio;

  HttpAvatarTransport(this._dio);

  @override
  Future<AvatarAck> put(String idempotencyKey, List<int> jpeg) => _ack(
    () => _dio.put<Object?>(
      '/me/avatar',
      data: FormData.fromMap({
        'photo': MultipartFile.fromBytes(
          jpeg,
          filename: 'photo.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
      }),
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    ),
  );

  @override
  Future<AvatarAck> delete() => _ack(() => _dio.delete<Object?>('/me/avatar'));

  @override
  Future<AvatarFetch> fetchMd({String? etag}) async {
    final Response<List<int>> response;
    try {
      response = await _dio.get<List<int>>(
        '/me/avatar/md',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'If-None-Match': ?etag},
          validateStatus: (status) => status == 200 || status == 304 || status == 404,
        ),
      );
    } on DioException catch (e) {
      throw _failure(e);
    }
    return switch (response.statusCode) {
      404 => const AvatarFetch(notFound: true),
      304 => AvatarFetch(etag: etag),
      _ => AvatarFetch(bytes: response.data, etag: response.headers.value('etag')),
    };
  }

  Future<AvatarAck> _ack(Future<Response<Object?>> Function() request) async {
    final Response<Object?> response;
    try {
      response = await request();
    } on DioException catch (e) {
      throw _failure(e);
    }
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    final avatarVersion = data is Map ? data['avatar_version'] : null;
    final version = data is Map ? data['version'] : null;
    if (avatarVersion is! int || version is! int) {
      // A 2xx that is not the envelope: a proxy or captive portal, not the API.
      throw const AvatarTransportException(AvatarFailure.network);
    }
    return AvatarAck(avatarVersion: avatarVersion, version: version);
  }

  static AvatarTransportException _failure(DioException e) {
    final response = e.response;
    if (response == null) return const AvatarTransportException(AvatarFailure.network);
    final body = response.data;
    final error = body is Map ? body['error'] : null;
    final code = error is Map && error['code'] is String ? error['code'] as String : null;
    final status = response.statusCode ?? 0;
    return switch (status) {
      401 => AvatarTransportException(AvatarFailure.unauthorized, code: code),
      429 => AvatarTransportException(
        AvatarFailure.rateLimited,
        retryAfter: _retryAfter(response.headers.value('retry-after')),
        code: code,
      ),
      >= 400 && < 500 => AvatarTransportException(
        AvatarFailure.rejected,
        code: code ?? 'http_$status',
      ),
      _ => AvatarTransportException(AvatarFailure.server, code: code),
    };
  }

  static Duration? _retryAfter(String? header) {
    final seconds = int.tryParse(header?.trim() ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }
}
