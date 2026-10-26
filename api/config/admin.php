<?php

/*
 * A58: the one admin. All three must be set or every /admin address is a plain 404.
 * `php artisan admin:setup` prints the hash and a fresh secret; they live only in Render.
 */
return [
    'email' => strtolower(trim((string) env('ADMIN_EMAIL', ''))),
    'password_hash' => (string) env('ADMIN_PASSWORD_HASH', ''),
    'totp_secret' => strtoupper(str_replace(' ', '', (string) env('ADMIN_TOTP_SECRET', ''))),

    // The session ends after this long idle, and after the absolute limit in all.
    'idle_minutes' => 30,
    'absolute_minutes' => 480,

    // Sign-in tries per IP per minute.
    'login_per_minute' => 5,
];
