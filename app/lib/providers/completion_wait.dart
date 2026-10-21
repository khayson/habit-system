import 'dart:async';

import '../data/local_mutation_service.dart';
import '../sync/outbox_states.dart';
import '../sync/sync_engine.dart';
import 'account_context.dart';

/// A46: after a save that left the habit-day complete on this device, ask for a sync at once
/// and wait (at most [timeout]) for that mutation's ack. [result] is the xp_delta to show on the
/// completion screen, or null to leave as today. After [cancel] it never completes.
class CompletionWait {
  static const Duration timeout = Duration(seconds: 6);

  /// Outcomes that end the wait at once; busy keeps waiting.
  static const _leaveOn = {
    SyncOutcome.offline,
    SyncOutcome.backoff,
    SyncOutcome.rateLimited,
    SyncOutcome.failed,
    SyncOutcome.paused,
    SyncOutcome.loggedOut,
  };

  final Future<int?> result;
  final void Function() cancel;

  const CompletionWait._(this.result, this.cancel);

  /// Null when there is nothing to wait for: the write did not complete the day (nor join the
  /// unsent row that did), or the device is offline
  /// (ASSUMPTION(A44-offline-return)). Then the save screen leaves at once, as before.
  static CompletionWait? start(AccountContext account, LocalWrite write, {Duration? wait}) {
    if (!write.mayEarnXp || account.sync.offline) return null;
    final id = write.mutationId;
    final ack = account.ackWatch.waitFor(id, wait ?? timeout);
    final done = Completer<int?>();
    var cancelled = false;

    void finish(int? value) {
      if (!cancelled && !done.isCompleted) done.complete(value);
    }

    ack.result.then((summary) {
      final delta = summary?.xpDelta;
      finish(
        summary != null && summary.status == 'accepted' && delta != null && delta > 0
            ? delta
            : null,
      );
    });

    // The sync, cancelling the debounce. A second caller shares a run already in progress,
    // which may have claimed its rows before this write: if it ends completed and this
    // mutation is still pending, run once more.
    () async {
      try {
        var outcome = await account.sync.sync();
        if (outcome == SyncOutcome.completed && await _stillPending(account, id)) {
          outcome = await account.sync.sync();
        }
        if (_leaveOn.contains(outcome)) {
          ack.cancel();
          finish(null);
        }
      } on Object {
        ack.cancel();
        finish(null);
      }
    }();

    return CompletionWait._(done.future, () {
      cancelled = true;
      ack.cancel();
    });
  }

  static Future<bool> _stillPending(AccountContext account, String mutationId) async {
    final db = account.session.db;
    final row = await (db.select(
      db.outbox,
    )..where((o) => o.mutationId.equals(mutationId))).getSingleOrNull();
    return row != null && row.state == OutboxState.pending;
  }
}
