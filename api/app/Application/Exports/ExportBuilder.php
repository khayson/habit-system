<?php

namespace App\Application\Exports;

use App\Application\Avatars\AvatarStore;
use App\Application\Presenters\EntityPresenter;
use App\Domain\Clock;
use App\Domain\Export\CsvWriter;
use App\Domain\Export\ManifestSigner;
use App\Domain\Habit\HabitTypeRegistry;
use App\Support\UtcTime;
use App\Support\WireTime;
use Illuminate\Support\Facades\DB;
use RuntimeException;
use stdClass;
use ZipArchive;

/**
 * A48: builds one export inside a single REPEATABLE READ snapshot, so every row and snapshot_seq
 * belong to the same moment. Reads only: history is never changed. Never includes passwords,
 * tokens, push tokens, reset tokens, device ids or diagnostics.
 */
final readonly class ExportBuilder
{
    public const int SCHEMA_VERSION = 1;

    public function __construct(
        private EntityPresenter $presenter,
        private HabitTypeRegistry $types,
        private AvatarStore $avatars,
        private Clock $clock,
    ) {}

    /**
     * @return array{bytes: string, extension: string, snapshot_seq: int}
     */
    public function build(string $userId, string $format): array
    {
        return DB::transaction(function () use ($userId, $format) {
            // The first statement of a top-level transaction; nested (tests) keeps the outer one.
            if (DB::transactionLevel() === 1) {
                DB::statement('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY');
            }
            $user = DB::table('users')->where('id', $userId)->first() ?? throw new RuntimeException('No such user.');
            $seq = (int) $user->change_seq;

            return $format === 'csv'
                ? ['bytes' => $this->csv($userId), 'extension' => 'csv', 'snapshot_seq' => $seq]
                : ['bytes' => $this->zip($user, $seq), 'extension' => 'zip', 'snapshot_seq' => $seq];
        });
    }

    private function zip(stdClass $user, int $seq): string
    {
        $generatedAt = UtcTime::format($this->clock->now());
        $files = ['export.json' => json_encode($this->document($user, $seq, $generatedAt), JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR)];
        if ($user->avatar_key !== null) {
            $bytes = $this->avatars->read((string) $user->id, (string) $user->avatar_key, 'lg');
            if ($bytes !== null) {
                $files['avatar.'.(str_ends_with((string) $user->avatar_key, '.webp') ? 'webp' : 'jpg')] = $bytes;
            }
        }
        $manifest = $this->signer()->sign([
            'schema_version' => self::SCHEMA_VERSION,
            'user_id' => (string) $user->id,
            'snapshot_seq' => $seq,
            'generated_at' => $generatedAt,
            'files' => array_map(fn (string $name, string $bytes) => ['name' => $name, 'sha256' => hash('sha256', $bytes)], array_keys($files), array_values($files)),
        ]);
        $files['manifest.json'] = json_encode($manifest, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);

        $path = tempnam(sys_get_temp_dir(), 'export-') ?: throw new RuntimeException('No temporary file.');
        try {
            $zip = new ZipArchive;
            if ($zip->open($path, ZipArchive::OVERWRITE) !== true) {
                throw new RuntimeException('Could not open the zip.');
            }
            foreach ($files as $name => $bytes) {
                $zip->addFromString($name, $bytes);
            }
            $zip->close();

            return (string) file_get_contents($path);
        } finally {
            @unlink($path);
        }
    }

    public function signer(): ManifestSigner
    {
        return new ManifestSigner(
            ManifestSigner::parseKeys(config()->string('api.export_signing_keys')),
            config()->string('api.export_signing_kid'),
        );
    }

    /** @return array<string, mixed> */
    private function document(stdClass $user, int $seq, string $generatedAt): array
    {
        $userId = (string) $user->id;
        $rows = fn (string $table) => DB::table($table)->where('user_id', $userId)->orderBy('id')->get();
        $habits = DB::table('habits')->where('user_id', $userId)->orderBy('id')->get();
        $types = $habits->pluck('type', 'id')->all();

        return [
            'schema_version' => self::SCHEMA_VERSION,
            'generated_at' => $generatedAt,
            'snapshot_seq' => $seq,
            'profile' => [
                'name' => $user->name, 'email' => $user->email,
                'city' => $user->city, 'country_code' => $user->country_code,
            ],
            'timezone_history' => DB::table('user_timezone_history')->where('user_id', $userId)->orderBy('effective_at')->get()
                ->map(fn ($r) => [
                    'timezone' => $r->timezone, 'day_start_offset_minutes' => (int) $r->day_start_offset_minutes,
                    'effective_at' => UtcTime::format(WireTime::parse((string) $r->effective_at)),
                ])->all(),
            'habits' => $habits->map(fn ($h) => $this->presenter->habit($h))->all(),
            'logs' => DB::table('habit_logs')->where('user_id', $userId)->whereNull('deleted_at')->orderBy('log_date')->orderBy('id')->get()
                ->map(fn ($l) => [...$this->presenter->log($l, (string) ($types[$l->habit_id] ?? 'binary')), 'note' => $l->note])->all(),
            'reminders' => DB::table('reminders')->where('user_id', $userId)->whereNull('deleted_at')->orderBy('id')->get()
                ->map(fn ($r) => $this->presenter->reminder($r))->all(),
            'xp_entitlements' => $rows('xp_entitlements')->map(fn ($e) => [
                'id' => $e->id, 'habit_id' => $e->habit_id, 'log_date' => $e->log_date, 'amount' => (int) $e->amount,
                'state' => $e->state, 'revision' => (int) $e->revision,
            ])->all(),
            'xp_ledger' => $rows('xp_ledger')->map(fn ($r) => [
                'id' => $r->id, 'entitlement_id' => $r->entitlement_id, 'entitlement_revision' => (int) $r->entitlement_revision,
                'delta' => (int) $r->delta, 'reason' => $r->reason,
                'created_at' => UtcTime::format(WireTime::parse((string) $r->created_at)),
            ])->all(),
            'freeze_ledger' => $rows('freeze_ledger')->map(fn ($r) => [
                'id' => $r->id, 'kind' => $r->kind, 'delta' => (int) $r->delta, 'reason' => $r->reason,
                'created_at' => UtcTime::format(WireTime::parse((string) $r->created_at)),
            ])->all(),
            'freeze_usages' => $rows('freeze_usage')->map(fn ($u) => [
                'id' => $u->id, 'habit_id' => $u->habit_id, 'period_key' => $u->period_key, 'used_on' => $u->used_on,
                'state' => $u->state, 'definition_version' => (int) $u->definition_version,
            ])->all(),
            'freeze_policy_versions' => DB::table('user_freeze_policy_versions')->where('user_id', $userId)->orderBy('effective_at')->orderBy('id')->get()
                ->map(fn ($p) => [
                    'enabled' => (bool) $p->enabled,
                    'effective_at' => UtcTime::format(WireTime::parse((string) $p->effective_at)),
                ])->all(),
        ];
    }

    private function csv(string $userId): string
    {
        $out = CsvWriter::header();
        $habits = DB::table('habits')->where('user_id', $userId)->get()->keyBy('id');
        $definitions = DB::table('habit_definition_versions')->whereIn('habit_id', $habits->keys())->orderBy('version')->get()->groupBy('habit_id');
        $logs = DB::table('habit_logs')->where('user_id', $userId)->whereNull('deleted_at')->orderBy('log_date')->orderBy('habit_id')->get();
        foreach ($logs as $log) {
            $habit = $habits->get($log->habit_id);
            if ($habit === null) {
                continue;
            }
            // The definition in force on that date: the newest effective on or before it.
            $definition = ($definitions[$log->habit_id] ?? collect())->filter(fn ($d) => $d->effective_date <= $log->log_date)->last();
            $type = $this->types->get((string) $habit->type);
            $out .= CsvWriter::row([
                'local_date' => (string) $log->log_date,
                'habit_id' => (string) $habit->id,
                'habit_name' => (string) $habit->name,
                'category' => (string) ($definition->category ?? $habit->category),
                'type' => (string) $habit->type,
                'value' => (string) $type->formatValue($type->fromStorage((string) $log->value)),
                'unit' => $definition->unit ?? $habit->unit,
                'target' => (string) $type->formatValue($type->fromStorage((string) ($definition->target_value ?? $habit->target_value))),
                // The server's rule, as stored when the log was written; never recomputed here.
                'completed' => $log->completed_at !== null,
                'note' => $log->note,
            ]);
        }

        return $out;
    }
}
