<?php

namespace App\Application\Exports;

use Carbon\CarbonImmutable;
use Illuminate\Database\Query\Builder;

/**
 * 6.1 review M1: which queued or running export jobs a worker may still finish. A running job
 * silent for 30 minutes (a killed worker, a timeout) or a job queued for 24 hours (no worker)
 * is stale: POST /exports starts a new job past it and exports:expire marks it failed.
 */
final class OpenExports
{
    public const int RUNNING_MINUTES = 30;

    public const int QUEUED_HOURS = 24;

    public static function live(Builder $query, CarbonImmutable $now): Builder
    {
        return $query->where(fn (Builder $q) => $q
            ->where(fn (Builder $r) => $r->where('status', 'running')->where('updated_at', '>', self::runningCutoff($now)))
            ->orWhere(fn (Builder $r) => $r->where('status', 'queued')->where('created_at', '>', self::queuedCutoff($now))));
    }

    public static function stale(Builder $query, CarbonImmutable $now): Builder
    {
        return $query->where(fn (Builder $q) => $q
            ->where(fn (Builder $r) => $r->where('status', 'running')->where('updated_at', '<=', self::runningCutoff($now)))
            ->orWhere(fn (Builder $r) => $r->where('status', 'queued')->where('created_at', '<=', self::queuedCutoff($now))));
    }

    private static function runningCutoff(CarbonImmutable $now): CarbonImmutable
    {
        return $now->subMinutes(self::RUNNING_MINUTES);
    }

    private static function queuedCutoff(CarbonImmutable $now): CarbonImmutable
    {
        return $now->subHours(self::QUEUED_HOURS);
    }
}
