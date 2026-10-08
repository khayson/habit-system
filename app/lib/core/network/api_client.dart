import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/api_config.dart';
import '../exceptions/app_exception.dart';
import '../storage/token_store.dart';
import 'api_response.dart';

/// The single Dio instance. API calls happen only in services, through this client.
class ApiClient {
  final Dio _dio;
  final TokenStore _tokens;

  /// Called after the server rejects the stored token (401). The token is already cleared;
  /// local data and the outbox are left untouched.
  VoidCallback? onUnauthenticated;

  static ApiClient? _instance;

  factory ApiClient({TokenStore tokens = const SecureTokenStore()}) => _instance ??= ApiClient._(
    Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
      ),
    ),
    tokens,
  );

  @visibleForTesting
  ApiClient.withDio(Dio dio, TokenStore tokens) : this._(dio, tokens);

  ApiClient._(this._dio, this._tokens) {
    _dio.options.headers.addAll(const {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    });
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokens.read();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            options.extra[_sentTokenKey] = token;
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          await _handleUnauthorized(error);
          handler.next(error);
        },
      ),
    );
    if (kDebugMode) {
      _dio.interceptors.add(_RedactedLogInterceptor());
    }
  }

  /// The configured Dio (base URL, bearer token, 401 handling) for adapters that map raw
  /// statuses themselves, i.e. `HttpSyncTransport`. Everything else goes through [get]/[post].
  Dio get dio => _dio;

  /// The stored token (never logged), so the sync transport can tell a rotated token from an
  /// ended session on 401 (G1).
  Future<String?> currentToken() => _tokens.read();

  /// Key in `RequestOptions.extra` holding the token a request was sent with.
  static const _sentTokenKey = 'habit.sent_token';

  /// A 401 ends the session only if the request carried a token and that token is still the
  /// stored one. A late 401 from a previous session (logout, then login while it was in flight)
  /// must not clear the new session's token.
  Future<void> _handleUnauthorized(DioException error) async {
    if (error.response?.statusCode != 401) return;
    final sent = error.requestOptions.extra[_sentTokenKey];
    if (sent is! String) return;
    if (await _tokens.read() != sent) return;
    await _tokens.clear();
    onUnauthenticated?.call();
  }

  Future<ApiResponse<T>> get<T>(
    String path,
    T Function(dynamic data) parser, {
    Map<String, dynamic>? query,
  }) => _send(() => _dio.get<Object?>(path, queryParameters: query), parser);

  Future<ApiResponse<T>> post<T>(
    String path,
    T Function(dynamic data) parser, {
    Object? data,
    Map<String, String>? headers,
  }) => _send(
    () => _dio.post<Object?>(
      path,
      data: data,
      options: Options(headers: headers),
    ),
    parser,
  );

  Future<ApiResponse<T>> _send<T>(
    Future<Response<Object?>> Function() request,
    T Function(dynamic data) parser,
  ) async {
    try {
      final response = await request();
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw AppException.fromResponse(response.statusCode ?? 0, body);
      }
      return ApiResponse.fromJson(body, parser);
    } on DioException catch (e) {
      throw AppException.fromDioException(e);
    }
  }
}

/// Logs method, path, status and request id only. Never headers or bodies: those carry
/// bearer tokens, passwords and reset tokens.
class _RedactedLogInterceptor extends Interceptor {
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[api] ${response.requestOptions.method} ${response.requestOptions.path} '
      '-> ${response.statusCode} (${response.headers.value('x-request-id')})',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[api] ${err.requestOptions.method} ${err.requestOptions.path} '
      '-> ${err.response?.statusCode ?? err.type.name} '
      '(${err.response?.headers.value('x-request-id')})',
    );
    handler.next(err);
  }
}
