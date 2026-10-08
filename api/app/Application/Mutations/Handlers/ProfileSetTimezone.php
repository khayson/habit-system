<?php

namespace App\Application\Mutations\Handlers;

use App\Application\Calendar\UserCalendar;
use App\Application\Journal\ChangeJournal;
use App\Application\Mutations\HandlerResult;
use App\Application\Mutations\MutationContext;
use App\Application\Presenters\EntityPresenter;
use App\Domain\Calendar\CalendarEntry;
use App\Domain\Calendar\CalendarHistory;
use App\Domain\Clock;
use App\Exceptions\ApiException;
use App\Support\UtcTime;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * profile.set_timezone {timezone} (D1, A26). Version-checked against users.version. The new
 * zone takes effect at the user's next local day start in the old calendar (CalendarHistory);
 * a pending change is replaced, and changing back cancels it. The day-start offset in force is
 * kept. The user entity is journaled with its recent calendar entries.
 */
final readonly class ProfileSetTimezone
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
        $p = Validator::make($m->payload, ['timezone' => ['required', 'string', 'max:64']])->validate();
        if (! CalendarEntry::isIanaZone((string) $p['timezone'])) {
            throw ValidationException::withMessages(['timezone' => ['Choose a time zone from the list.']]);
        }
        if ($m->baseVersion === null) {
            throw ValidationException::withMessages(['base_version' => ['base_version is required.']]);
        }

        $user = DB::table('users')->where('id', $ctx->userId)->first() ?? throw new ApiException(404, 'not_found', 'Not found.');
        $version = (int) $user->version;
        if ($m->baseVersion !== $version) {
            throw ApiException::versionConflict($ctx->userId, $m->baseVersion, $version, $this->presenter->user($user));
        }

        $now = $this->clock->now();
        $timeline = UserCalendar::timeline($ctx->userId);
        $inForce = $timeline->entryAt($now);
        $change = (new CalendarHistory($this->clock))->appendChange($timeline, (string) $p['timezone'], $inForce->dayStartOffsetMinutes);
        if (! $change->changed) {
            // Identical desired state: acknowledge without a new version (spec 07).
            return new HandlerResult('user', $ctx->userId, $version);
        }

        $stamp = UtcTime::format($now);
        DB::table('user_timezone_history')->where('user_id', $ctx->userId)->where('effective_at', '>', $stamp)->delete();
        if ($change->added !== null) {
            DB::table('user_timezone_history')->insert([
                'id' => (string) Str::uuid7(),
                'user_id' => $ctx->userId,
                'timezone' => $change->added->timezone,
                'day_start_offset_minutes' => $change->added->dayStartOffsetMinutes,
                'effective_at' => UtcTime::format($change->added->effectiveAt),
                'created_at' => $stamp,
            ]);
        }
        DB::table('users')->where('id', $ctx->userId)->update(['version' => $version + 1, 'updated_at' => $stamp]);
        $row = DB::table('users')->where('id', $ctx->userId)->first() ?? (object) [];
        $this->journal->append($ctx->userId, 'user', $ctx->userId, 'upsert', $version + 1, $this->presenter->user($row));

        return new HandlerResult('user', $ctx->userId, $version + 1);
    }
}
