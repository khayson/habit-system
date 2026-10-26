<?php

namespace App\Application\Admin;

use App\Domain\Clock;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;

/**
 * A58: the one admin's sign-in: email, password (bcrypt hash from the environment) and a
 * one-time code. Every check runs on every try, so a wrong field is not told apart by timing.
 * An accepted code's step is remembered, so the same code cannot be used twice.
 */
final readonly class AdminAuth
{
    private const string LAST_STEP = 'admin:totp:last-step';

    public function __construct(private Clock $clock) {}

    /** False when any of the three settings is missing: /admin then answers 404. */
    public function configured(): bool
    {
        return config('admin.email') !== ''
            && config('admin.password_hash') !== ''
            && strlen((string) config('admin.totp_secret')) >= 16;
    }

    public function attempt(string $email, string $password, string $code): bool
    {
        if (! $this->configured()) {
            return false;
        }
        $emailOk = hash_equals((string) config('admin.email'), mb_strtolower(trim($email)));
        $passwordOk = Hash::check($password, (string) config('admin.password_hash'));
        $step = Totp::matchStep((string) config('admin.totp_secret'), trim($code), $this->clock->now()->getTimestamp());
        if (! $emailOk || ! $passwordOk || $step === null) {
            return false;
        }
        // A code is single-use: a step at or before the last accepted one is refused.
        $last = Cache::get(self::LAST_STEP);
        if (is_int($last) && $step <= $last) {
            return false;
        }
        Cache::forever(self::LAST_STEP, $step);

        return true;
    }
}
