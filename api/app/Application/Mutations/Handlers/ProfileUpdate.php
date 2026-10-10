<?php

namespace App\Application\Mutations\Handlers;

use App\Application\Accounts\ProfileRules;
use App\Application\Journal\ChangeJournal;
use App\Application\Mutations\HandlerResult;
use App\Application\Mutations\MutationContext;
use App\Application\Presenters\EntityPresenter;
use App\Domain\Clock;
use App\Exceptions\ApiException;
use App\Support\UtcTime;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

/**
 * profile.update {name, city, country_code} (A20). The payload is the whole desired state; city
 * and country_code may be null (cleared). Version-checked against users.version; an identical
 * update acknowledges without a new version (spec 07). The user entity is journaled in the
 * applier's transaction (invariant 6).
 *
 * ASSUMPTION(A3b-location-optional): city and country are independent and each optional.
 */
final readonly class ProfileUpdate
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
        $input = $m->payload;
        if (array_key_exists('city', $input) && is_string($input['city'])) {
            $city = trim($input['city']);
            $input['city'] = $city === '' ? null : $city;
        }
        $p = Validator::make($input, [
            'name' => ProfileRules::name(),
            'city' => ProfileRules::city(),
            'country_code' => ProfileRules::countryCode(),
        ])->validate();
        if ($m->baseVersion === null) {
            throw ValidationException::withMessages(['base_version' => ['base_version is required.']]);
        }

        $user = DB::table('users')->where('id', $ctx->userId)->first() ?? throw new ApiException(404, 'not_found', 'Not found.');
        $version = (int) $user->version;
        if ($m->baseVersion !== $version) {
            throw ApiException::versionConflict($ctx->userId, $m->baseVersion, $version, $this->presenter->user($user));
        }

        $desired = [
            'name' => (string) $p['name'],
            'city' => isset($p['city']) ? (string) $p['city'] : null,
            'country_code' => isset($p['country_code']) ? (string) $p['country_code'] : null,
        ];
        if ($desired === ['name' => $user->name, 'city' => $user->city, 'country_code' => $user->country_code]) {
            return new HandlerResult('user', $ctx->userId, $version);
        }

        DB::table('users')->where('id', $ctx->userId)->update([
            ...$desired,
            'version' => $version + 1,
            'updated_at' => UtcTime::format($this->clock->now()),
        ]);
        $row = DB::table('users')->where('id', $ctx->userId)->first() ?? (object) [];
        $this->journal->append($ctx->userId, 'user', $ctx->userId, 'upsert', $version + 1, $this->presenter->user($row));

        return new HandlerResult('user', $ctx->userId, $version + 1);
    }
}
