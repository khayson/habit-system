<?php

namespace App\Models;

use App\Support\UtcTime;
use DateTimeInterface;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

/**
 * Placeholder so Sanctum and the auth guard resolve. The users table, its columns and token
 * storage arrive with A18 migration 1 in Phase 2.
 */
class User extends Authenticatable
{
    use HasApiTokens, HasUuids;

    protected function serializeDate(DateTimeInterface $date): string
    {
        return UtcTime::format($date);
    }
}
