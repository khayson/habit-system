<?php

namespace App\Application\Admin;

use App\Domain\Clock;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;

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
        $passwordOk = $this->passwordMatches($password, (string) config('admin.password_hash'));
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

    /**
     * A setting that is not a bcrypt hash (a cut-off copy, say) refuses sign-in instead of
     * throwing, and says so in the log (never the value).
     */
    private function passwordMatches(string $password, string $hash): bool
    {
        if (password_get_info($hash)['algoName'] !== 'bcrypt') {
            // Only its length and whether it starts like one (60 characters, "$2y$"): never any of
            // its characters, in case a password was pasted there by mistake.
            Log::warning('admin sign-in: ADMIN_PASSWORD_HASH is not a bcrypt hash; run php artisan admin:setup again', [
                'length' => strlen($hash),
                'starts_like_bcrypt' => str_starts_with($hash, '$2'),
            ]);

            return false;
        }

        return Hash::check($password, $hash);
    }
}
