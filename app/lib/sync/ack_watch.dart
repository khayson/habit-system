import 'dart:async';
import 'dart:collection';

/// What one final ack said (A43, A46): enough for a save screen to decide whether to show the
/// completion screen. xpDelta is read only when the wire value is an integer.
class AckSummary {
  final String mutationId;

  /// accepted, conflict or rejected.
  final String status;
  final int? xpDelta;

  const AckSummary(this.mutationId, this.status, this.xpDelta);

  static const finalStatuses = {'accepted', 'conflict', 'rejected'};

  /// Null for a status that is not final (dependency_pending) or an ack without an id.
  static AckSummary? fromAck(Map<String, dynamic> ack) {
    final id = ack['mutation_id'];
    final status = ack['status'];
    if (id is! String || status is! String || !finalStatuses.contains(status)) return null;
    final delta = ack['xp_delta'];
    return AckSummary(id, status, delta is int ? delta : null);
  }
}

/// A wait for one mutation's ack. [result] completes with the summary, or with null at the
/// timeout. After [cancel] it never completes.
class AckWait {
  final Future<AckSummary?> result;
  final void Function() cancel;

  const AckWait._(this.result, this.cancel);
}

/// Phase 5.2c (A46): the last [capacity] final ack summaries, in memory only. The engine
/// publishes after its apply transaction commits; a save screen waits for its own mutation.
/// One per account, owned by AccountContext.
class AckWatch {
  static const int capacity = 50;

  final LinkedHashMap<String, AckSummary> _known = LinkedHashMap();
  final Map<String, List<Completer<AckSummary?>>> _waiting = {};

  final Set<String> _opened = {};

  AckSummary? known(String mutationId) => _known[mutationId];

  /// A46: true the first time a completion screen is opened for [mutationId], false after.
  bool firstOpening(String mutationId) => _opened.add(mutationId);

  /// Records [summary] and answers anyone waiting for it. A duplicate replay publishes again.
  void publish(AckSummary summary) {
    _known
      ..remove(summary.mutationId)
      ..[summary.mutationId] = summary;
    while (_known.length > capacity) {
      _known.remove(_known.keys.first);
    }
    for (final waiter in _waiting.remove(summary.mutationId) ?? const <Completer<AckSummary?>>[]) {
      if (!waiter.isCompleted) waiter.complete(summary);
    }
  }

  AckWait waitFor(String mutationId, Duration timeout) {
    final ready = _known[mutationId];
    if (ready != null) return AckWait._(Future.value(ready), () {});

    final completer = Completer<AckSummary?>();
    var cancelled = false;
    late final Timer timer;
    void forget() => _waiting[mutationId]?.remove(completer);
    timer = Timer(timeout, () {
      forget();
      if (!completer.isCompleted) completer.complete(null);
    });
    _waiting.putIfAbsent(mutationId, () => []).add(completer);
    completer.future.whenComplete(timer.cancel);
    return AckWait._(completer.future, () {
      if (cancelled) return;
      cancelled = true;
      timer.cancel();
      forget();
    });
  }

  /// Releases waiters with the account (they never complete).
  void dispose() {
    _waiting.clear();
    _known.clear();
    _opened.clear();
  }
}
