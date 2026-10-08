import 'package:flutter/foundation.dart';

/// API endpoints. The base URL comes from `--dart-define=API_BASE_URL=...`; the default reaches
/// a host-machine API from the Android emulator.
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Endpoints
  static const String health = '/health';
  static String heatmap(String habitId) => '/habits/$habitId/heatmap';

  /// Called once at start-up. A release build refuses to run against a non-HTTPS API:
  /// bearer tokens and personal history must never travel in clear text.
  static void ensureSafe({bool isRelease = kReleaseMode, String url = baseUrl}) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) {
      throw StateError('API_BASE_URL is not a valid absolute URL.');
    }
    if (isRelease && uri.scheme != 'https') {
      throw StateError('Release builds require an https:// API_BASE_URL.');
    }
  }
}
