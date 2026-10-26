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
        'tick_per_minute' => (int) env('RATE_LIMIT_TICK_PER_MINUTE', 6),
        'exports_per_hour' => (int) env('RATE_LIMIT_EXPORTS_PER_HOUR', 6),
        'avatar_uploads_per_hour' => (int) env('RATE_LIMIT_AVATAR_UPLOADS_PER_HOUR', 10),
    ],

    // A54: the outside timer's shared secret (X-Tick-Secret on POST /internal/tick); empty
    // disables the endpoint. The worker's limits keep one tick inside a minute.
    'tick_secret' => (string) env('TICK_SECRET', ''),
    'tick_max_seconds' => (int) env('TICK_MAX_SECONDS', 50),
    'tick_memory_mb' => (int) env('TICK_MEMORY_MB', 128),

    // A54: Render's proxy addresses are not fixed and nothing else reaches the service.
    'trusted_proxies' => (string) env('TRUSTED_PROXIES', '*'),

    // A54: the lowest app build number this server accepts; travels in every success meta.
    'min_app_version' => (int) env('MIN_APP_VERSION', 1),

    // A20: the private disk avatar objects live on (never a public one).
    'avatar_disk' => env('AVATAR_DISK', 'local'),

    // A48: exports on a private disk; signing keys as kid:secret pairs (none in the repository).
    'export_disk' => env('EXPORT_DISK', 'local'),
    'export_signing_keys' => env('EXPORT_SIGNING_KEYS', ''),
    'export_signing_kid' => env('EXPORT_SIGNING_KID', ''),
    'export_link_hours' => 24,

    // A20: the server's copy of the shared country list (scripts/gen-countries.php writes it).
    'countries_path' => env('COUNTRIES_PATH', resource_path('countries.json')),
];
