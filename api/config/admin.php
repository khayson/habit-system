<?php

/*
 * A58: the one admin. All three must be set or every /admin address is a plain 404.
 * `php artisan admin:setup` prints the hash and a fresh secret; they live only in Render.
 * Common paste slips are undone here: a copied "ADMIN_…=" prefix, quotes and spaces.
 */
$setting = function (string $key): string {
    $value = trim((string) env($key, ''));
    $value = (string) preg_replace('/^'.preg_quote($key, '/').'\s*=\s*/', '', $value);

    return trim($value, " \t\n\r\0\x0B\"'");
};

return [
    'email' => strtolower($setting('ADMIN_EMAIL')),
    'password_hash' => $setting('ADMIN_PASSWORD_HASH'),
    'totp_secret' => strtoupper(str_replace(' ', '', $setting('ADMIN_TOTP_SECRET'))),

    // The session ends after this long idle, and after the absolute limit in all.
    'idle_minutes' => 30,
    'absolute_minutes' => 480,

    // Sign-in tries per IP per minute.
    'login_per_minute' => 5,
];
