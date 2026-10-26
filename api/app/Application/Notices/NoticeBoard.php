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
 * A57: notices Khay Studios publishes (artisan) and every account reads (GET /notices). Plain
 * text, the same for everyone, no personal data. The table's CHECK constraints repeat the
 * limits, so a row written any other way is refused too.
 */
final class NoticeBoard
{
    public const int TITLE_MAX = 60;

    public const int BODY_MAX = 280;

    public const int LIMIT = 5;

    public function __construct(private readonly Clock $clock) {}

    /**
     * Notices active now (started, not yet ended; the end is exclusive), newest first.
     *
     * @return list<array{id: string, title: string, body: string, starts_at: string, ends_at: string|null}>
     */
    public function active(): array
    {
        $now = UtcTime::format($this->clock->now());

        return array_values(DB::table('notices')
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
     * @return list<array{id: string, title: string, body: string, starts_at: string, ends_at: string|null}>
     */
    public function all(): array
    {
        return array_values(DB::table('notices')->orderByDesc('starts_at')->get()
            ->map(fn (stdClass $row) => $this->present($row))->all());
    }

    /**
     * Publishes a notice; it starts now unless [$starts] is given (ISO-8601).
     *
     * @throws InvalidArgumentException with a plain message for the console
     */
    public function publish(string $title, string $body, ?string $starts = null, ?string $ends = null): string
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
        $id = (string) Str::uuid7();
        DB::table('notices')->insert([
            'id' => $id,
            'title' => $title,
            'body' => $body,
            'starts_at' => UtcTime::format($from),
            'ends_at' => $until === null ? null : UtcTime::format($until),
            'created_at' => UtcTime::format($this->clock->now()),
        ]);

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
