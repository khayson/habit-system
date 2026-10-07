/// Outbox row states (PHASE_2A_REVIEW §5, PHASE_2A1_REVIEW §5).
abstract final class OutboxState {
  /// Written locally, not sent yet. Only these rows may be coalesced.
  static const pending = 'pending';

  /// Inside a request whose response has not been applied. Back to pending on restart.
  static const inFlight = 'in_flight';

  /// Acknowledged by the server; kept until the confirmed row catches up, then pruned.
  static const acked = 'acked';

  /// dependency_pending: waits for its parent (a habit) to be acked or pulled.
  static const waiting = 'waiting';

  /// Retryable server error: exponential backoff; blocks only its own entity.
  static const blocked = 'blocked';

  /// Conflict or permanent rejection: kept with its data for the user; never auto-resubmitted.
  static const needsAttention = 'needs_attention';

  /// Rows that still describe an unacknowledged local intent.
  static const unacked = [pending, inFlight, waiting, blocked, needsAttention];

  /// Rows whose intent is expected to reach the server (they bump the expected version).
  static const outstanding = [pending, inFlight, waiting, blocked];
}
