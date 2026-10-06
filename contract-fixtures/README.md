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
  `description`, `status`, optional `headers`, and `body`.
