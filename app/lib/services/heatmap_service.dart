import '../config/api_config.dart';
import '../core/network/api_client.dart';
import '../data/habit_detail_view.dart';
import '../domain/calendar/local_date.dart';

/// GET /habits/{id}/heatmap for months older than the local window (screen 12). The answer is
/// shown from memory only and never written to the confirmed tables.
class HeatmapService implements RemoteHeatmap {
  final ApiClient _api;

  const HeatmapService(this._api);

  @override
  Future<Map<String, String>> fetch(String habitId, LocalDate from, LocalDate to) async {
    final response = await _api.get(
      ApiConfig.heatmap(habitId),
      (data) => {
        for (final day
            in ((data as Map<String, dynamic>)['days'] as List).cast<Map<String, dynamic>>())
          day['date'] as String: day['status'] as String,
      },
      query: {'from': from.toString(), 'to': to.toString()},
    );
    return response.data;
  }
}
