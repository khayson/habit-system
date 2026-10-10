<?php

/*
 * API behaviour that operators may tune without a release.
 * Rate limits: defaults approved in the Phase 0 review (A25); keyed by user id when
 * authenticated, IP otherwise.
 */

return [
    'rate_limits' => [
        'api_per_minute' => (int) env('RATE_LIMIT_API_PER_MINUTE', 120),
        'auth_per_minute_per_ip' => (int) env('RATE_LIMIT_AUTH_PER_MINUTE_PER_IP', 20),
        'auth_per_minute_per_email' => (int) env('RATE_LIMIT_AUTH_PER_MINUTE_PER_EMAIL', 5),
        'password_reset_per_hour_per_ip' => (int) env('RATE_LIMIT_PASSWORD_RESET_PER_HOUR_PER_IP', 20),
        'password_reset_per_hour_per_email' => (int) env('RATE_LIMIT_PASSWORD_RESET_PER_HOUR_PER_EMAIL', 5),
        'sync_per_minute' => (int) env('RATE_LIMIT_SYNC_PER_MINUTE', 60),
        'avatar_uploads_per_hour' => (int) env('RATE_LIMIT_AVATAR_UPLOADS_PER_HOUR', 10),
    ],

    // A20: the shared country list (contract-fixtures/profile/countries.json).
    'countries_path' => env('COUNTRIES_PATH', base_path('../contract-fixtures/profile/countries.json')),
];
