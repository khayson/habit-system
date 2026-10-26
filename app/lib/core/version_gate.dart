import 'package:flutter/foundation.dart';

/// A54 (the 6.6 review's I2): whether the server still accepts this build. Every success
/// envelope carries `meta.min_app_version`; a value above [build] requires the update, and
/// stays required for the rest of the run (a later or cached answer never unlocks it).
class VersionGate extends ChangeNotifier {
  final int build;

  VersionGate({required this.build});

  bool _updateRequired = false;

  bool get updateRequired => _updateRequired;

  /// Reads a response body; anything that is not a success envelope with an integer minimum
  /// is ignored (tolerant reader).
  void observe(Object? body) {
    if (_updateRequired || body is! Map) return;
    final meta = body['meta'];
    if (meta is! Map) return;
    final min = meta['min_app_version'];
    if (min is int && min > build) {
      _updateRequired = true;
      notifyListeners();
    }
  }
}
