import 'package:flutter/foundation.dart';

import '../core/exceptions/app_exception.dart';
import '../models/health_status.dart';
import '../services/health_service.dart';

/// Explicit network action, so it carries loading / error / retry state.
class HealthProvider extends ChangeNotifier {
  final HealthService _service;

  HealthProvider(this._service);

  HealthStatus? _status;
  AppException? _error;
  bool _isLoading = false;

  HealthStatus? get status => _status;
  AppException? get error => _error;
  bool get isLoading => _isLoading;

  Future<void> check() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _status = await _service.check();
    } on AppException catch (e) {
      // A failed check means the last success is no longer true: never show it as current.
      _status = null;
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
