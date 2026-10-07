import 'dart:async';

import 'package:flutter/foundation.dart';

/// A Provider-friendly wrapper around a drift watch-query: the latest value, or the error the
/// stream reported. Screens render from local data, so there is no network "loading" here; the
/// first value usually arrives within a frame.
class StreamModel<T> extends ChangeNotifier {
  StreamSubscription<T>? _subscription;
  bool _disposed = false;

  StreamModel(Future<Stream<T>> source) {
    source.then((stream) {
      if (_disposed) return;
      _subscription = stream.listen(
        (value) {
          _value = value;
          _hasValue = true;
          _error = null;
          notifyListeners();
        },
        onError: (Object error) {
          _error = error;
          notifyListeners();
        },
      );
    });
  }

  T? _value;
  bool _hasValue = false;
  Object? _error;

  T? get value => _value;
  bool get hasValue => _hasValue;
  Object? get error => _error;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
