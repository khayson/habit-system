<?php

namespace App\Application\Admin;

use App\Domain\Clock;
use App\Support\UtcTime;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use stdClass;

/**
 * A58: the admin dashboard's numbers. Counts across all accounts only, never one person's
 * habits, check-ins or notes. Windows are rolling (the last 7 days, 24-hour buckets counted back
 * from now), so no day boundary is computed here (R4, invariant 15).
 */
final readonly class AdminStats
{
    public const int DAYS = 30;

    private const int DAY_SECONDS = 86_400;

    public function __construct(private Clock $clock) {}

    /**
     * This week (the last 7 × 24 hours) against the week before.
     *
     * @return array{accounts: int, signups: array{now: int, before: int}, active: array{now: int, before: int}, check_ins: array{now: int, before: int}, notices_live: int}
     */
    public function kpis(): array
    {
        $now = $this->clock->now();
        $weekAgo = $this->at($now->subDays(7));
        $twoWeeksAgo = $this->at($now->subDays(14));
        $nowText = $this->at($now);
        $pair = fn (callable $count) => [
            'now' => $count($weekAgo, $nowText),
            'before' => $count($twoWeeksAgo, $weekAgo),
        ];

        return [
            'accounts' => DB::table('users')->whereNull('deleted_at')->count(),
            'signups' => $pair(fn (string $from, string $to) => DB::table('users')
                ->where('created_at', '>=', $from)->where('created_at', '<', $to)->count()),
            'active' => $pair(fn (string $from, string $to) => (int) DB::table('mutation_receipts')
                ->where('committed_at', '>=', $from)->where('committed_at', '<', $to)
                ->distinct()->count('user_id')),
            'check_ins' => $pair(fn (string $from, string $to) => DB::table('habit_logs')->whereNull('deleted_at')
                ->where('created_at', '>=', $from)->where('created_at', '<', $to)->count()),
            'notices_live' => DB::table('notices')->where('starts_at', '<=', $nowText)
                ->where(fn ($q) => $q->whereNull('ends_at')->orWhere('ends_at', '>', $nowText))->count(),
        ];
    }

    /**
     * Three 30-bucket series, oldest first; bucket i ends (29 - i) × 24 hours before now.
     *
     * @return array{signups: list<int>, check_ins: list<int>, active: list<int>, ends: list<string>}
     */
    public function series(): array
    {
        $now = $this->clock->now();

        return [
            'signups' => $this->buckets('users', 'created_at', 'count(*)'),
            'check_ins' => $this->buckets('habit_logs', 'created_at', 'count(*)', 'deleted_at is null'),
            'active' => $this->buckets('mutation_receipts', 'committed_at', 'count(distinct user_id)'),
            'ends' => array_map(
                fn (int $i) => UtcTime::format($now->subSeconds((self::DAYS - 1 - $i) * self::DAY_SECONDS)),
                range(0, self::DAYS - 1),
            ),
        ];
    }

    /**
     * Jobs waiting and failed, by job type only: never a payload, and for a failure only the
     * exception's class (its message can hold data).
     *
     * @return array{waiting: list<array{id: int, job: string, queue: string, attempts: int, since: string}>, failed: list<array{uuid: string, job: string, queue: string, error: string, at: string}>}
     */
    public function jobs(int $limit = 50): array
    {
        return [
            'waiting' => array_values(DB::table('jobs')->orderBy('id')->limit($limit)->get()
                ->map(fn (stdClass $j) => [
                    'id' => (int) $j->id,
                    'job' => $this->jobName((string) $j->payload),
                    'queue' => (string) $j->queue,
                    'attempts' => (int) $j->attempts,
                    'since' => UtcTime::format(CarbonImmutable::createFromTimestampUTC((int) $j->created_at)),
                ])->all()),
            'failed' => array_values(DB::table('failed_jobs')->orderByDesc('failed_at')->limit($limit)->get()
                ->map(fn (stdClass $j) => [
                    'uuid' => (string) $j->uuid,
                    'job' => $this->jobName((string) $j->payload),
                    'queue' => (string) $j->queue,
                    'error' => $this->errorClass((string) $j->exception),
                    'at' => UtcTime::format(CarbonImmutable::parse((string) $j->failed_at)),
                ])->all()),
        ];
    }

    public function retryFailed(string $uuid): bool
    {
        if (! DB::table('failed_jobs')->where('uuid', $uuid)->exists()) {
            return false;
        }
        Artisan::call('queue:retry', ['id' => [$uuid]]);

        return true;
    }

    public function forgetFailed(string $uuid): bool
    {
        return DB::table('failed_jobs')->where('uuid', $uuid)->delete() === 1;
    }

    public function forgetAllFailed(): int
    {
        return DB::table('failed_jobs')->delete();
    }

    /** @return list<int> */
    private function buckets(string $table, string $column, string $aggregate, ?string $where = null): array
    {
        $now = $this->at($this->clock->now());
        $rows = DB::select(
            "select floor(extract(epoch from (?::timestamptz - {$column})) / ".self::DAY_SECONDS.")::int as ago, {$aggregate} as n
             from {$table}
             where {$column} > ?::timestamptz - interval '".self::DAYS." days' and {$column} <= ?::timestamptz"
            .($where === null ? '' : " and {$where}")
            .' group by ago',
            [$now, $now, $now],
        );
        $out = array_fill(0, self::DAYS, 0);
        foreach ($rows as $row) {
            $ago = (int) $row->ago;
            if ($ago >= 0 && $ago < self::DAYS) {
                $out[self::DAYS - 1 - $ago] = (int) $row->n;
            }
        }

        return $out;
    }

    private function jobName(string $payload): string
    {
        $data = json_decode($payload, true);
        $name = is_array($data) ? ($data['displayName'] ?? null) : null;

        return is_string($name) ? class_basename($name) : 'Unknown job';
    }

    private function errorClass(string $exception): string
    {
        $first = strtok($exception, ":\n");

        return $first === false ? 'Unknown error' : class_basename(trim($first));
    }

    private function at(CarbonImmutable $instant): string
    {
        return UtcTime::format($instant);
    }
}
