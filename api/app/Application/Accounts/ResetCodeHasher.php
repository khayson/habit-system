<?php

namespace App\Application\Accounts;

/**
 * A50: the only form a reset code is stored in, an HMAC-SHA256 keyed by the app key. Every reset
 * path calls it exactly once, known email or not, so the work does not tell them apart.
 */
class ResetCodeHasher
{
    public function hash(string $code): string
    {
        return hash_hmac('sha256', $code, (string) config('app.key'));
    }
}
