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
}
