# Contract fixtures

Golden JSON consumed by both the PHP (Pest) and Dart test suites. A fixture is the
acceptance truth: add or change the fixture first, then the code on both sides.

## Placeholders

Values that differ per request are written as placeholders. Test harnesses must check
the format and then treat them as equal.

| Placeholder     | Matches                                                     |
|-----------------|-------------------------------------------------------------|
| `{{uuid}}`      | a lowercase RFC 9562 UUID (request ids are version 7)       |
| `{{timestamp}}` | an ISO-8601 UTC timestamp with seconds and `Z`, e.g. `2026-05-28T17:22:00Z` |
| `{{int}}`       | a positive integer written as a string (HTTP header values) |

## Layout

- `envelope/` — response envelope and error shapes (Phase 0). Each file has
  `description`, `status`, optional `headers`, and `body`. One file per error code
  (`docs/api-error-codes.md`).
- `domain/` — business rules (Phase 1). Each file has `kind`, `suites` (which test suites must
  consume it: `php`, `dart`) and `description`. Cases inside may narrow `suites` further.

## Domain seeds (A12)

Every domain case declares its whole world. Nothing is implied.

| Field | Meaning |
|---|---|
| `calendar` | Ordered calendar history: `effective_at` (UTC), `timezone` (IANA), `day_start_offset_minutes` (A22). |
| `habit.definitions[]` | `version`, `effective_date`, `type`, `target`, `unit`, `frequency_type`, `frequency_config`. |
| `habit.active_ranges[]` | Half-open local-date ranges `[starts_on, ends_before)`; `ends_before: null` is open. |
| `habit.logs` | `{ "YYYY-MM-DD": value }`, one row per habit and local date. |
| `protected` | Period keys with an active freeze usage. |
| `now` / `today` | The injected clock instant, or the user's local date when only dates matter. |

Values travel in wire form: binary `0`/`1` (integer), quantity a decimal string with up to three
decimals (`"2000.000"`), duration whole seconds (integer). Period keys follow A3:
`d:YYYY-MM-DD`, `w:<Monday>`.

The spec example account (May 2026, America/Los_Angeles) is in `insights.json`; its numbers
reconcile with the spec: 95/125 for May, 9/15 for the week of 25 May.
