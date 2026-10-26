<?php

namespace App\Application\Notices;

use App\Domain\Clock;
use App\Support\UtcTime;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use InvalidArgumentException;
use stdClass;

/**
 * A57: notices Khay Studios publishes (artisan) for everyone or for chosen people, read through
 * GET /notices. Plain text. The table's CHECK constraints repeat the limits, so a row written
 * any other way is refused too.
 */
final class NoticeBoard
{
    public const int TITLE_MAX = 60;

    public const int BODY_MAX = 280;

    public const int LIMIT = 5;

    public function __construct(private readonly Clock $clock) {}

    /**
     * The notices active now for [$userId] (started, not yet ended; the end is exclusive):
     * everyone's, and those addressed to that account. Newest first.
     *
     * @return list<array{id: string, title: string, body: string, starts_at: string, ends_at: string|null}>
     */
    public function activeFor(string $userId): array
    {
        $now = UtcTime::format($this->clock->now());

        return array_values(DB::table('notices')
            ->where(fn ($q) => $q->where('audience', 'everyone')->orWhereExists(
                fn ($r) => $r->from('notice_recipients')
                    ->whereColumn('notice_recipients.notice_id', 'notices.id')
                    ->where('notice_recipients.user_id', $userId),
            ))
            ->where('starts_at', '<=', $now)
            ->where(fn ($q) => $q->whereNull('ends_at')->orWhere('ends_at', '>', $now))
            ->orderByDesc('starts_at')
            ->orderByDesc('id')
            ->limit(self::LIMIT)
            ->get()
            ->map(fn (stdClass $row) => $this->present($row))
            ->all());
    }

    /**
     * Every notice with who it is for ('everyone', or a count of people), for the console.
     *
     * @return list<array{id: string, title: string, starts_at: string, ends_at: string|null, audience: string}>
     */
    public function all(): array
    {
        $counts = DB::table('notice_recipients')->selectRaw('notice_id, count(*) as n')
            ->groupBy('notice_id')->pluck('n', 'notice_id');

        return array_values(DB::table('notices')->orderByDesc('starts_at')->get()
            ->map(function (stdClass $row) use ($counts) {
                $n = $this->present($row);

                return [
                    'id' => $n['id'],
                    'title' => $n['title'],
                    'starts_at' => $n['starts_at'],
                    'ends_at' => $n['ends_at'],
                    'audience' => $row->audience === 'everyone' ? 'everyone' : ((int) ($counts[$row->id] ?? 0)).' people',
                ];
            })->all());
    }

    /**
     * Publishes a notice; it starts now unless [$starts] is given (ISO-8601). With [$to] (account
     * emails), only those people see it; an email with no account stops the publish.
     *
     * @param  list<string>  $to
     *
     * @throws InvalidArgumentException with a plain message for the console
     */
    public function publish(string $title, string $body, ?string $starts = null, ?string $ends = null, array $to = []): string
    {
        $title = trim($title);
        $body = trim($body);
        if ($title === '' || mb_strlen($title) > self::TITLE_MAX) {
            throw new InvalidArgumentException('The title needs 1 to '.self::TITLE_MAX.' characters.');
        }
        if ($body === '' || mb_strlen($body) > self::BODY_MAX) {
            throw new InvalidArgumentException('The body needs 1 to '.self::BODY_MAX.' characters.');
        }
        $from = $starts === null ? $this->clock->now() : $this->instant($starts, 'start');
        $until = $ends === null ? null : $this->instant($ends, 'end');
        if ($until !== null && $until <= $from) {
            throw new InvalidArgumentException('The end must be after the start.');
        }
        $emails = array_values(array_unique(array_map(fn (string $e) => mb_strtolower(trim($e)), $to)));
        $users = DB::table('users')->whereIn('email', $emails)->pluck('id', 'email');
        $missing = array_diff($emails, $users->keys()->all());
        if ($missing !== []) {
            throw new InvalidArgumentException('No account for: '.implode(', ', $missing).'.');
        }
        $id = (string) Str::uuid7();
        DB::transaction(function () use ($id, $title, $body, $from, $until, $users) {
            DB::table('notices')->insert([
                'id' => $id,
                'title' => $title,
                'body' => $body,
                'starts_at' => UtcTime::format($from),
                'ends_at' => $until === null ? null : UtcTime::format($until),
                'audience' => $users->isEmpty() ? 'everyone' : 'people',
                'created_at' => UtcTime::format($this->clock->now()),
            ]);
            DB::table('notice_recipients')->insert(
                $users->values()->map(fn ($userId) => ['notice_id' => $id, 'user_id' => $userId])->all(),
            );
        });

        return $id;
    }

    /**
     * Ends a notice now; one not started yet was never shown and is removed. False when there
     * is no such notice, or it has already ended.
     */
    public function retire(string $id): bool
    {
        if (! Str::isUuid($id)) {
            return false;
        }
        $now = UtcTime::format($this->clock->now());
        $live = fn () => DB::table('notices')->where('id', $id)
            ->where(fn ($q) => $q->whereNull('ends_at')->orWhere('ends_at', '>', $now));

        return $live()->where('starts_at', '<', $now)->update(['ends_at' => $now]) === 1
            || $live()->where('starts_at', '>=', $now)->delete() === 1;
    }

    private function instant(string $value, string $which): CarbonImmutable
    {
        if (! preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?(Z|[+-]\d{2}:\d{2})$/', $value)) {
            throw new InvalidArgumentException("The {$which} must be an ISO-8601 time with a zone, e.g. 2026-11-01T09:00:00Z.");
        }

        return CarbonImmutable::parse($value)->utc();
    }

    /**
     * @return array{id: string, title: string, body: string, starts_at: string, ends_at: string|null}
     */
    private function present(stdClass $row): array
    {
        return [
            'id' => (string) $row->id,
            'title' => (string) $row->title,
            'body' => (string) $row->body,
            'starts_at' => UtcTime::format(CarbonImmutable::parse((string) $row->starts_at)),
            'ends_at' => $row->ends_at === null ? null : UtcTime::format(CarbonImmutable::parse((string) $row->ends_at)),
        ];
    }
}
