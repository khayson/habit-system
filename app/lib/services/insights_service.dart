import '../config/api_config.dart';
import '../core/exceptions/app_exception.dart';
import '../core/network/api_client.dart';
import '../models/insights.dart';

/// GET /insights for screens 14 and 15 (A47). An explicit network action: the answer is kept in
/// memory per period (and category) while the account is open, never written to the database.
class InsightsService {
  final ApiClient _api;
  final Map<String, Insights> _last = {};

  InsightsService(this._api);

  /// The last answer for [period] (and [category]) this session, or null.
  Insights? last(String period, {String? category}) => _last[_key(period, category)];

  Future<Insights> fetch(String period, {String? category}) async {
    final response = await _api.get(ApiConfig.insights, (data) {
      try {
        return Insights.fromJson((data as Map).cast<String, dynamic>());
      } on Object {
        // A missing required field or a wrong type: not a shape this app can show.
        throw const AppException(
          kind: AppErrorKind.unexpected,
          code: 'unexpected_response',
          message: 'Something went wrong. Try again.',
        );
      }
    }, query: {'period': period, 'category': ?category});
    return _last[_key(period, category)] = response.data;
  }

  static String _key(String period, String? category) => '$period/${category ?? ''}';
}
