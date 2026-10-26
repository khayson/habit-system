<?php

namespace App\Application\Ops;

use App\Support\UtcTime;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\Cache;

/**
 * A55: the two facts the ops status needs that no table holds: when the tick last ran, and how
 * many reset emails failed per day. Kept in the cache store (the database in production), with
 * no personal data. A lost cache only loses these counters.
 */
final readonly class OpsMetrics
{
    private const string LAST_TICK = 'ops:last-tick-at';

    private const string LAST_MAIL_FAILURE = 'ops:mail-failure-last-at';

    private const int DAYS_KEPT = 8;

    public function recordTick(CarbonImmutable $now): void
    {
        Cache::forever(self::LAST_TICK, UtcTime::format($now));
    }

    public function recordMailFailure(CarbonImmutable $now): void
    {
        $key = self::mailFailureKey($now);
        Cache::add($key, 0, $now->addDays(self::DAYS_KEPT));
        Cache::increment($key);
        Cache::forever(self::LAST_MAIL_FAILURE, UtcTime::format($now));
    }

    public function lastTickAt(): ?string
    {
        $value = Cache::get(self::LAST_TICK);

        return is_string($value) ? $value : null;
    }

    /** @return array{last_7_days: int, last_at: ?string} */
    public function mailFailures(CarbonImmutable $now): array
    {
        $count = 0;
        for ($day = 0; $day < 7; $day++) {
            $count += (int) Cache::get(self::mailFailureKey($now->subDays($day)), 0);
        }
        $last = Cache::get(self::LAST_MAIL_FAILURE);
        $last = is_string($last) && CarbonImmutable::parse($last)->greaterThan($now->subDays(7)) ? $last : null;

        return ['last_7_days' => $count, 'last_at' => $count === 0 ? null : $last];
    }

    private static function mailFailureKey(CarbonImmutable $day): string
    {
        return 'ops:mail-failures:'.$day->utc()->format('Y-m-d');
    }
}
