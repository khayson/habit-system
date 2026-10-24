import 'reward_pages.dart' show parseInstant;

/// A48 job statuses; a word a newer server sends reads as [unknown] (invariant 13).
enum ExportStatus {
  queued,
  running,
  ready,
  failed,
  expired,
  unknown;

  static ExportStatus from(Object? wire) =>
      ExportStatus.values.firstWhere((s) => s.name == wire && s != unknown, orElse: () => unknown);

  /// Still being prepared.
  bool get pending => this == queued || this == running;
}

/// An export job as GET /exports/{id} sends it (A48). Shown from memory, never stored.
class ExportJob {
  final String id;

  /// json or csv.
  final String format;
  final ExportStatus status;
  final DateTime? requestedAt;
  final DateTime? expiresAt;

  /// Set only while ready.
  final String? downloadUrl;
  final String? errorCode;

  const ExportJob({
    required this.id,
    required this.format,
    required this.status,
    required this.requestedAt,
    this.expiresAt,
    this.downloadUrl,
    this.errorCode,
  });

  factory ExportJob.fromJson(Map<String, dynamic> j) => ExportJob(
    id: j['id'] as String,
    format: j['format'] as String,
    status: ExportStatus.from(j['status']),
    requestedAt: parseInstant(j['requested_at']),
    expiresAt: j['expires_at'] == null ? null : parseInstant(j['expires_at']),
    downloadUrl: j['download_url'] as String?,
    errorCode: j['error_code'] as String?,
  );
}
