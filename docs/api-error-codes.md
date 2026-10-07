# API error codes

Every error response uses one envelope (CLAUDE.md, A25):

```json
{
  "error": { "code": "…", "message": "…", "…": "code-specific keys" },
  "meta":  { "request_id": "uuid-v7", "server_time": "2026-05-28T17:22:00Z" }
}
```

- `code` is the stable, machine-readable contract. Clients branch on `code`, never on `message`.
- `message` is a fixed, user-safe English sentence. It never contains exception text, SQL,
  traces, model names or ids.
- Every code below has exactly one golden fixture in `contract-fixtures/envelope/`. The PHP and
  Dart suites both consume it, and `tests/Feature/ErrorCodesDocTest.php` fails if this table and
  the fixtures disagree.
- Domain exceptions (`DayResolutionException`, `UnknownHabitType`, `UnsupportedOperation`,
  `InvalidHabitValue`) become these codes in exactly one place: `App\Exceptions\DomainErrorMapper`
  (A28). `/sync` acks use the same mapper.
- Additive changes (a new code, a new key) do not bump `/v1`. Clients treat unknown codes by
  HTTP status class (tolerant reader, A21).

## Active codes

| Code | HTTP | When | Extra keys in `error` | Fixture |
|---|---|---|---|---|
| `bad_request` | 400 | Request rejected as unreadable. | — | `error_400_bad_request.json` |
| `unauthenticated` | 401 | Missing, expired or revoked bearer token. | — | `error_401_unauthenticated.json` |
| `forbidden` | 403 | Authenticated, but blocked by policy. | — | `error_403_forbidden.json` |
| `not_found` | 404 | Missing **or foreign** resource or route. Identical for both. | — | `error_404_not_found.json` |
| `method_not_allowed` | 405 | Route exists, wrong method. | `Allow` header | `error_405_method_not_allowed.json` |
| `version_conflict` | 409 | Stale `base_version` on an absolute edit. | `resource_id`, `expected_version`, `current_version`, `current` (canonical resource) | `error_409_version_conflict.json` |
| `idempotency_mismatch` | 409 | Same `mutation_id` / `Idempotency-Key`, different payload hash. | — | `error_409_idempotency_mismatch.json` |
| `resource_deleted` | 409 | Target is tombstoned. | `entity`, `resource_id`, `current_version` (tombstone version) | `error_409_resource_deleted.json` |
| `cursor_expired` | 410 | Sync cursor older than the 180-day journal. Client bootstraps and keeps its outbox. | — | `error_410_cursor_expired.json` |
| `payload_too_large` | 413 | Body or batch over its cap (e.g. more than 100 sync mutations). | — | `error_413_payload_too_large.json` |
| `unsupported_media_type` | 415 | Body content type not accepted. | — | `error_415_unsupported_media_type.json` |
| `validation_failed` | 422 | Field validation. | `fields: { name: [messages] }` | `error_422_validation_failed.json` |
| `future_event` | 422 | Event dated more than 5 minutes ahead of server time. | — | `error_422_future_event.json` |
| `event_too_old` | 422 | Event more than 90 days old. | — | `error_422_event_too_old.json` |
| `timezone_context_mismatch` | 422 | Client's `captured_timezone` disagrees with the server calendar at `occurred_at` and `local_date_hint` does not equal the server date (A5, A29). Sent for review, never silently re-dated. | `calendar` {timezone, day_start_offset_minutes, effective_at} | `error_422_timezone_context_mismatch.json` |
| `backdate_future` | 422 | Explicit backdate after the user's local today. | — | `error_422_backdate_future.json` |
| `backdate_too_old` | 422 | Explicit backdate more than 30 days back. | — | `error_422_backdate_too_old.json` |
| `unsupported_type` | 422 | Habit type unknown or not declared in `X-Capabilities` (A21). | — | `error_422_unsupported_type.json` |
| `unsupported_operation` | 422 | Operation (or alias) not supported by the habit's type (A21, A27). | — | `error_422_unsupported_operation.json` |
| `invalid_value` | 422 | Value, target or increment breaks the type's rules. | — | `error_422_invalid_value.json` |
| `rate_limited` | 429 | Rate limit hit. | `Retry-After` header (seconds) | `error_429_rate_limited.json` |
| `http_error` | other 4xx (e.g. 418) | Fallback for a 4xx with no dedicated code. | — | `error_4xx_http_error.json` |
| `server_error` | 500 (and 5xx without a code) | Unhandled failure. Retriable. In a `/sync` ack it is per mutation (status `rejected`, no receipt). | `retryable: true` in a sync ack (`sync/ack_server_error.json`) | `error_500_server_error.json` |
| `unavailable` | 503 | Maintenance or a dependency briefly down. Retriable. | — | `error_503_unavailable.json` |

## Reserved codes (later phases)

Not emitted yet. Each gets a fixture in the phase that introduces it.

| Code | HTTP | Phase | Meaning |
|---|---|---|---|
| `dependency_pending` | (sync ack) | 2 | Mutation depends on an entity not yet applied (e.g. log before its habit). Retriable. |

## `/sync` acknowledgements

In `/sync` a per-mutation failure is not an HTTP status: the response is 200 and the mutation's
ack carries `status` (`conflict`, `rejected`, `dependency_pending`) plus an `error` object with
exactly the shapes above (Phase 2).
