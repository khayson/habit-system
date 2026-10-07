<?php

namespace App\Models;

use App\Support\UtcTime;
use DateTimeInterface;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

/**
 * Account identity. xp, freeze_balance and change_seq are server-owned caches; they are never
 * mass-assigned and never accepted from clients (invariant 1).
 *
 * @property string $id
 * @property string $name
 * @property string $email
 * @property string $password
 * @property string $timezone
 * @property string $timezone_mode
 * @property bool $auto_freeze
 * @property int $xp
 * @property int $freeze_balance
 * @property int $change_seq
 */
class User extends Authenticatable
{
    /** @use HasApiTokens<PersonalAccessToken> */
    use HasApiTokens, HasUuids, SoftDeletes;

    protected $hidden = ['password'];

    protected function casts(): array
    {
        return [
            'password' => 'hashed',
            'auto_freeze' => 'boolean',
            'xp' => 'integer',
            'freeze_balance' => 'integer',
            'change_seq' => 'integer',
        ];
    }

    protected function serializeDate(DateTimeInterface $date): string
    {
        return UtcTime::format($date);
    }
}
