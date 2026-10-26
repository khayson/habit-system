/// A57: a notice Khay Studios publishes for Today's carousel. Plain text, the same for every
/// account. Unknown fields are ignored (A21's tolerant reader); a notice missing its id, title
/// or body is skipped by [tryParse], never a crash.
class Notice {
  final String id;
  final String title;
  final String body;
  final DateTime? endsAt;

  const Notice({required this.id, required this.title, required this.body, this.endsAt});

  static Notice? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final title = json['title'];
    final body = json['body'];
    if (id is! String || title is! String || body is! String || id.isEmpty) return null;
    final ends = json['ends_at'];
    return Notice(
      id: id,
      title: title,
      body: body,
      endsAt: ends is String ? DateTime.tryParse(ends)?.toUtc() : null,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'ends_at': endsAt?.toIso8601String(),
  };

  /// Hidden once its end has passed on this device's clock (display only, A57).
  bool liveAt(DateTime now) => endsAt == null || now.toUtc().isBefore(endsAt!);
}
