<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Support\Str;
use Laravel\Sanctum\PersonalAccessToken as SanctumToken;

/**
 * Sanctum token with a UUIDv7 id, bound to one device installation (A6). Plain-text form is
 * "{uuid}|{secret}"; only the SHA-256 of the secret is stored.
 *
 * @property string|null $device_id
 */
class PersonalAccessToken extends SanctumToken
{
    use HasUuids;

    protected $fillable = ['name', 'token', 'abilities', 'device_id', 'expires_at'];

    /**
     * Rejects malformed ids before they reach PostgreSQL (a non-UUID id would otherwise raise
     * an SQL error and a 500 instead of a 401).
     *
     * @param  string  $token
     */
    public static function findToken($token): ?static
    {
        if (! str_contains($token, '|')) {
            return null;
        }
        [$id, $secret] = explode('|', $token, 2);
        if (! Str::isUuid($id)) {
            return null;
        }

        $instance = static::query()->find($id);

        return $instance !== null && hash_equals($instance->token, hash('sha256', $secret)) ? $instance : null;
    }
}
