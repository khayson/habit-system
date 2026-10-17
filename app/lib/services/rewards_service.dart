import '../config/api_config.dart';
import '../core/exceptions/app_exception.dart';
import '../core/network/api_client.dart';
import '../models/reward_pages.dart';

/// GET /rewards and GET /freezes for screens 16 and 17 (A39 to A43). An explicit network
/// action: the answer is shown from memory and never written to the local database.
class RewardsService {
  static const int defaultLimit = 20;

  final ApiClient _api;

  const RewardsService(this._api);

  Future<RewardsPage> fetchRewards({String? cursor, int limit = defaultLimit}) =>
      _get(ApiConfig.rewards, RewardsPage.fromJson, cursor, limit);

  Future<FreezesPage> fetchFreezes({String? cursor, int limit = defaultLimit}) =>
      _get(ApiConfig.freezes, FreezesPage.fromJson, cursor, limit);

  Future<T> _get<T>(
    String path,
    T Function(Map<String, dynamic>) decode,
    String? cursor,
    int limit,
  ) async {
    final response = await _api.get(path, (data) {
      try {
        return decode((data as Map).cast<String, dynamic>());
      } on Object {
        // A missing required field or a wrong type: not a shape this app can show.
        throw const AppException(
          kind: AppErrorKind.unexpected,
          code: 'unexpected_response',
          message: 'Something went wrong. Try again.',
        );
      }
    }, query: {'limit': limit, 'cursor': ?cursor});
    return response.data;
  }
}
