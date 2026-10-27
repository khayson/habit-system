<?php

namespace App\Application\Admin;

use App\Domain\Clock;
use App\Mail\AnnouncementMail;
use App\Support\UtcTime;
use Carbon\CarbonImmutable;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use InvalidArgumentException;
use stdClass;
use Throwable;

/**
 * A59: service announcement emails. Audiences are resolved when sending starts and frozen into
 * one delivery row per recipient (never twice). The timer sends in batches under a rolling
 * 24-hour cap; a campaign over the cap carries on by itself. Windows are rolling (R4).
 */
final readonly class EmailCampaigns
{
    public const array AUDIENCES = ['everyone', 'active', 'inactive', 'new', 'emails'];

    public const int SUBJECT_MAX = 120;

    public const int BODY_MAX = 5000;

    public function __construct(private Clock $clock) {}

    /**
     * Checks and normalises an audience from the form.
     *
     * @return array{type: string, days?: int, emails?: list<string>}
     */
    public function audience(string $type, string $days, string $emails): array
    {
        if (! in_array($type, self::AUDIENCES, true)) {
            throw new InvalidArgumentException('Choose who it is for.');
        }
        if (in_array($type, ['active', 'inactive', 'new'], true)) {
            $n = (int) $days;
            if ($n < 1 || $n > 365) {
                throw new InvalidArgumentException('Days must be from 1 to 365.');
            }

            return ['type' => $type, 'days' => $n];
        }
        if ($type === 'emails') {
            $list = array_values(array_unique(array_filter(array_map(
                fn (string $e) => mb_strtolower(trim($e)),
                preg_split('/[\s,;]+/', $emails) ?: [],
            ))));
            if ($list === []) {
                throw new InvalidArgumentException('Add at least one email.');
            }

            return ['type' => 'emails', 'emails' => $list];
        }

        return ['type' => 'everyone'];
    }

    /**
     * Who an audience reaches now: live, not suspended, not stopped.
     *
     * @param  array<string, mixed>  $audience
     */
    public function recipients(array $audience): Builder
    {
        $now = $this->clock->now();
        $q = DB::table('users')->whereNull('deleted_at')->whereNull('suspended_at')->whereNull('service_emails_stopped_at');
        $since = isset($audience['days']) ? UtcTime::format($now->subDays((int) $audience['days'])) : null;
        $active = fn (Builder $r) => $r->from('mutation_receipts')->whereColumn('mutation_receipts.user_id', 'users.id')
            ->where('committed_at', '>=', $since);
        match ($audience['type']) {
            'active' => $q->whereExists($active),
            'inactive' => $q->whereNotExists($active)->where('created_at', '<', $since),
            'new' => $q->where('created_at', '>=', $since),
            'emails' => $q->whereIn('email', $audience['emails'] ?? []),
            default => null,
        };

        return $q;
    }

    /** @param  array<string, mixed>  $audience */
    public function count(array $audience): int
    {
        return $this->recipients($audience)->count();
    }

    /**
     * The audience in words, for lists and previews.
     *
     * @param  array<string, mixed>  $audience
     */
    public static function describe(array $audience): string
    {
        return match ($audience['type'] ?? '') {
            'active' => 'Active in the last '.$audience['days'].' days',
            'inactive' => 'Inactive for '.$audience['days'].' days or more',
            'new' => 'Signed up in the last '.$audience['days'].' days',
            'emails' => count($audience['emails'] ?? []).' chosen '.(count($audience['emails'] ?? []) === 1 ? 'email' : 'emails'),
            default => 'Everyone',
        };
    }

    /** Fills {name} and {first_name}. */
    public static function personalise(string $text, string $name): string
    {
        $first = trim(explode(' ', trim($name))[0]);

        return strtr($text, ['{name}' => trim($name), '{first_name}' => $first === '' ? trim($name) : $first]);
    }

    /**
     * Saves a campaign as a draft, scheduled or due now. Returns its id.
     *
     * @param  array{type: string, days?: int, emails?: list<string>}  $audience
     */
    public function save(string $subject, string $body, array $audience, ?CarbonImmutable $sendAt): string
    {
        $subject = trim($subject);
        $body = trim(str_replace("\r\n", "\n", $body));
        if ($subject === '' || mb_strlen($subject) > self::SUBJECT_MAX) {
            throw new InvalidArgumentException('The subject needs 1 to '.self::SUBJECT_MAX.' characters.');
        }
        if ($body === '' || mb_strlen($body) > self::BODY_MAX) {
            throw new InvalidArgumentException('The message needs 1 to '.self::BODY_MAX.' characters.');
        }
        $now = UtcTime::format($this->clock->now());
        $id = (string) Str::uuid7();
        DB::table('email_campaigns')->insert([
            'id' => $id,
            'subject' => $subject,
            'body' => $body,
            'audience' => json_encode($audience, JSON_THROW_ON_ERROR),
            'status' => $sendAt === null ? 'draft' : 'scheduled',
            'scheduled_at' => $sendAt === null ? null : UtcTime::format($sendAt),
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return $id;
    }

    /** A draft goes out on the next tick. */
    public function sendDraftNow(string $id): bool
    {
        if (! Str::isUuid($id)) {
            return false;
        }
        $now = UtcTime::format($this->clock->now());

        return DB::table('email_campaigns')->where('id', $id)->where('status', 'draft')
            ->update(['status' => 'scheduled', 'scheduled_at' => $now, 'updated_at' => $now]) === 1;
    }

    /** Stops a campaign that has not finished; its unsent deliveries are skipped. */
    public function cancel(string $id): bool
    {
        if (! Str::isUuid($id)) {
            return false;
        }

        return DB::transaction(function () use ($id) {
            $now = UtcTime::format($this->clock->now());
            $changed = DB::table('email_campaigns')->where('id', $id)->whereIn('status', ['draft', 'scheduled', 'sending'])
                ->update(['status' => 'cancelled', 'finished_at' => $now, 'updated_at' => $now]);
            DB::table('email_deliveries')->where('campaign_id', $id)->where('status', 'queued')->update(['status' => 'skipped']);

            return $changed === 1;
        });
    }

    /** Sends one email to the admin address, filled in as for the admin. */
    public function sendTest(string $subject, string $body): void
    {
        $to = (string) config('admin.email');
        Mail::to($to)->send(new AnnouncementMail(
            self::personalise($subject, 'Habit admin'),
            self::personalise($body, 'Habit admin'),
            null,
        ));
    }

    /**
     * The timer's work: start due campaigns and send one batch under the daily cap. Returns how
     * many emails it sent.
     */
    public function sendDue(): int
    {
        $now = $this->clock->now();
        $nowText = UtcTime::format($now);
        foreach (DB::table('email_campaigns')->where('status', 'scheduled')->where('scheduled_at', '<=', $nowText)->pluck('id') as $id) {
            $this->start((string) $id);
        }
        $sentToday = DB::table('email_deliveries')->where('status', 'sent')
            ->where('sent_at', '>=', UtcTime::format($now->subDay()))->count();
        $budget = min((int) config('admin.email_batch'), max(0, (int) config('admin.email_daily_limit') - $sentToday));
        $sent = 0;
        $queued = DB::table('email_deliveries')
            ->join('email_campaigns', 'email_campaigns.id', '=', 'email_deliveries.campaign_id')
            ->where('email_campaigns.status', 'sending')->where('email_deliveries.status', 'queued')
            ->orderBy('email_campaigns.started_at')->orderBy('email_deliveries.id')
            ->limit($budget)->get(['email_deliveries.id', 'email_deliveries.user_id', 'email_campaigns.subject', 'email_campaigns.body']);
        foreach ($queued as $delivery) {
            $sent += $this->deliver($delivery) ? 1 : 0;
        }
        $this->finishDone();

        return $sent;
    }

    /**
     * @return list<array{id: string, subject: string, audience: string, status: string, scheduled_at: string|null, total: int, sent: int, failed: int, skipped: int, created_at: string}>
     */
    public function all(): array
    {
        $counts = DB::table('email_deliveries')->selectRaw('campaign_id, status, count(*) as n')
            ->groupBy('campaign_id', 'status')->get()->groupBy('campaign_id');

        return array_values(DB::table('email_campaigns')->orderByDesc('created_at')->limit(100)->get()
            ->map(fn (stdClass $c) => $this->present($c, $counts->get($c->id, collect())->pluck('n', 'status')->all()))->all());
    }

    /**
     * @return array{campaign: array<string, mixed>, deliveries: list<array{email: string, status: string, error: string|null, sent_at: string|null}>}|null
     */
    public function show(string $id): ?array
    {
        if (! Str::isUuid($id)) {
            return null;
        }
        $c = DB::table('email_campaigns')->where('id', $id)->first();
        if ($c === null) {
            return null;
        }
        $counts = DB::table('email_deliveries')->where('campaign_id', $id)->selectRaw('status, count(*) as n')
            ->groupBy('status')->pluck('n', 'status')->all();
        $deliveries = DB::table('email_deliveries')->join('users', 'users.id', '=', 'email_deliveries.user_id')
            ->where('campaign_id', $id)->orderByRaw("case email_deliveries.status when 'failed' then 0 when 'queued' then 1 else 2 end")
            ->orderBy('users.email')->limit(500)->get(['users.email', 'email_deliveries.status', 'email_deliveries.error', 'email_deliveries.sent_at']);

        return [
            'campaign' => [...$this->present($c, $counts), 'body' => (string) $c->body, 'audience_raw' => json_decode((string) $c->audience, true)],
            'deliveries' => array_values($deliveries->map(fn (stdClass $d) => [
                'email' => (string) $d->email,
                'status' => (string) $d->status,
                'error' => $d->error === null ? null : (string) $d->error,
                'sent_at' => $d->sent_at === null ? null : UtcTime::format(CarbonImmutable::parse((string) $d->sent_at)),
            ])->all()),
        ];
    }

    /** Freezes the audience into deliveries and marks the campaign sending. */
    private function start(string $id): void
    {
        DB::transaction(function () use ($id) {
            $c = DB::table('email_campaigns')->where('id', $id)->where('status', 'scheduled')->lockForUpdate()->first();
            if ($c === null) {
                return;
            }
            $audience = json_decode((string) $c->audience, true);
            $userIds = $this->recipients(is_array($audience) ? $audience : ['type' => 'emails', 'emails' => []])->pluck('id');
            foreach ($userIds->chunk(500) as $chunk) {
                DB::table('email_deliveries')->insertOrIgnore($chunk->map(fn ($userId) => [
                    'id' => (string) Str::uuid7(), 'campaign_id' => $id, 'user_id' => $userId, 'status' => 'queued',
                ])->values()->all());
            }
            $now = UtcTime::format($this->clock->now());
            DB::table('email_campaigns')->where('id', $id)->update([
                'status' => 'sending', 'started_at' => $now, 'total' => $userIds->count(), 'updated_at' => $now,
            ]);
        });
    }

    private function deliver(stdClass $delivery): bool
    {
        $user = DB::table('users')->where('id', $delivery->user_id)->first();
        $now = UtcTime::format($this->clock->now());
        // Re-checked at send time: someone may have stopped these emails since it started.
        if ($user === null || $user->deleted_at !== null || $user->suspended_at !== null || $user->service_emails_stopped_at !== null) {
            DB::table('email_deliveries')->where('id', $delivery->id)->update(['status' => 'skipped']);

            return false;
        }
        try {
            Mail::to((string) $user->email)->send(new AnnouncementMail(
                self::personalise((string) $delivery->subject, (string) $user->name),
                self::personalise((string) $delivery->body, (string) $user->name),
                (string) $user->id,
            ));
        } catch (Throwable $e) {
            // The error's class only: its message can carry an address.
            DB::table('email_deliveries')->where('id', $delivery->id)->update(['status' => 'failed', 'error' => class_basename($e)]);

            return false;
        }
        DB::table('email_deliveries')->where('id', $delivery->id)->update(['status' => 'sent', 'sent_at' => $now]);

        return true;
    }

    private function finishDone(): void
    {
        $now = UtcTime::format($this->clock->now());
        DB::table('email_campaigns')->where('status', 'sending')
            ->whereNotExists(fn (Builder $q) => $q->from('email_deliveries')
                ->whereColumn('email_deliveries.campaign_id', 'email_campaigns.id')->where('email_deliveries.status', 'queued'))
            ->update(['status' => 'sent', 'finished_at' => $now, 'updated_at' => $now]);
    }

    /**
     * @param  array<string, int|string>  $counts
     * @return array{id: string, subject: string, audience: string, status: string, scheduled_at: string|null, total: int, sent: int, failed: int, skipped: int, created_at: string}
     */
    private function present(stdClass $c, array $counts): array
    {
        $audience = json_decode((string) $c->audience, true);

        return [
            'id' => (string) $c->id,
            'subject' => (string) $c->subject,
            'audience' => self::describe(is_array($audience) ? $audience : []),
            'status' => (string) $c->status,
            'scheduled_at' => $c->scheduled_at === null ? null : UtcTime::format(CarbonImmutable::parse((string) $c->scheduled_at)),
            'total' => (int) $c->total,
            'sent' => (int) ($counts['sent'] ?? 0),
            'failed' => (int) ($counts['failed'] ?? 0),
            'skipped' => (int) ($counts['skipped'] ?? 0),
            'created_at' => UtcTime::format(CarbonImmutable::parse((string) $c->created_at)),
        ];
    }
}
