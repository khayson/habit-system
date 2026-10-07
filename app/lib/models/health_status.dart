/// `GET /health` result.
class HealthStatus {
  final String status;
  final DateTime serverTime;
  final String requestId;

  const HealthStatus({required this.status, required this.serverTime, required this.requestId});
}
