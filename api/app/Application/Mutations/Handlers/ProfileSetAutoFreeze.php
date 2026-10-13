<?php

namespace App\Application\Mutations\Handlers;

use App\Application\Journal\ChangeJournal;
use App\Application\Mutations\HandlerResult;
use App\Application\Mutations\MutationContext;
use App\Application\Presenters\EntityPresenter;
use App\Domain\Clock;
use App\Exceptions\ApiException;
use App\Support\UtcTime;
use App\Support\WireTime;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * A42: profile.set_auto_freeze {enabled} on entity user. A change writes one policy version
 * effective from the server clock at apply (never occurred_at; at least one second after the
 * user's latest version, I3), so opting in is prospective and
 * never protects earlier misses (A11). An identical state is acknowledged with no bump and no
 * policy row.
 */
final readonly class ProfileSetAutoFreeze
{
    public function __construct(
        private ChangeJournal $journal,
        private EntityPresenter $presenter,
        private Clock $clock,
    ) {}

    public function handle(MutationContext $ctx): HandlerResult
    {
        $m = $ctx->mutation;
        // Another user's id is answered exactly like a missing one (invariant 2).
        if ($m->entityId !== strtolower($ctx->userId)) {
            throw new ApiException(404, 'not_found', 'Not found.');
        }
        $p = Validator::make($m->payload, ['enabled' => ['required', 'boolean:strict']])->validate();
        if ($m->baseVersion === null) {
            throw ValidationException::withMessages(['base_version' => ['base_version is required.']]);
        }

        $user = DB::table('users')->where('id', $ctx->userId)->first() ?? throw new ApiException(404, 'not_found', 'Not found.');
        $version = (int) $user->version;
        if ($m->baseVersion !== $version) {
            throw ApiException::versionConflict($ctx->userId, $m->baseVersion, $version, $this->presenter->user($user));
        }
        $enabled = (bool) $p['enabled'];
        if ($enabled === (bool) $user->auto_freeze) {
            return new HandlerResult('user', $ctx->userId, $version);
        }

        $now = UtcTime::format($this->clock->now());
        // I3: a version never ties the user's latest one, so (effective_at, id) order is the
        // order the toggles were applied in.
        $latest = DB::table('user_freeze_policy_versions')->where('user_id', $ctx->userId)->max('effective_at');
        $effectiveAt = $this->clock->now();
        if ($latest !== null) {
            $floor = WireTime::parse((string) $latest)->modify('+1 second');
            $effectiveAt = $floor > $effectiveAt ? $floor : $effectiveAt;
        }
        DB::table('users')->where('id', $ctx->userId)->update([
            'auto_freeze' => $enabled,
            'version' => $version + 1,
            'updated_at' => $now,
        ]);
        DB::table('user_freeze_policy_versions')->insert([
            'id' => (string) Str::uuid7(),
            'user_id' => $ctx->userId,
            'enabled' => $enabled,
            'effective_at' => UtcTime::format($effectiveAt),
        ]);
        $row = DB::table('users')->where('id', $ctx->userId)->first() ?? (object) [];
        $this->journal->append($ctx->userId, 'user', $ctx->userId, 'upsert', $version + 1, $this->presenter->user($row));

        return new HandlerResult('user', $ctx->userId, $version + 1);
    }
}
