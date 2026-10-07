import '../config/api_config.dart';
import '../core/exceptions/app_exception.dart';
import '../core/network/api_client.dart';
import '../models/health_status.dart';

class HealthService {
  final ApiClient _api;

  const HealthService(this._api);

  Future<HealthStatus> check() async {
    final response = await _api.get(
      ApiConfig.health,
      (data) => (data as Map<String, dynamic>)['status'] as String,
    );
    final serverTime = response.meta.serverTime;
    final requestId = response.meta.requestId;
    if (serverTime == null || requestId == null) {
      throw const AppException(
        kind: AppErrorKind.unexpected,
        code: 'unexpected_response',
        message: 'Something went wrong. Try again.',
      );
    }
    return HealthStatus(status: response.data, serverTime: serverTime, requestId: requestId);
  }
}
