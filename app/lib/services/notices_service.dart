import '../config/api_config.dart';
import '../core/network/api_client.dart';
import '../models/notice.dart';

/// GET /notices (A57): Khay Studios' notices for Today's carousel.
class NoticesService {
  final ApiClient _api;

  NoticesService(this._api);

  Future<List<Notice>> fetch() async {
    final response = await _api.get(
      ApiConfig.notices,
      (data) => [
        for (final item in data is List ? data : const <Object?>[]) ?Notice.tryParse(item),
      ],
    );
    return response.data;
  }
}
