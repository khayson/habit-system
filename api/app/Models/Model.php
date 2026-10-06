<?php

namespace App\Models;

use App\Support\UtcTime;
use DateTimeInterface;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model as Eloquent;

/**
 * Base for every domain model: UUIDv7 primary keys (time-ordered for B-tree locality) and
 * UTC `Z` timestamps on the wire. Mass assignment stays closed (Eloquent's default `$guarded`).
 */
abstract class Model extends Eloquent
{
    use HasUuids;

    protected function serializeDate(DateTimeInterface $date): string
    {
        return UtcTime::format($date);
    }
}
