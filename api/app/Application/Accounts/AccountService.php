<?php

namespace App\Application\Accounts;

use App\Application\Journal\ChangeJournal;
use App\Application\Presenters\EntityPresenter;
use App\Domain\Clock;
use App\Models\PersonalAccessToken;
use App\Models\User;
use App\Support\UtcTime;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * Account lifecycle (spec 05, A6). Registration creates the user, its first calendar entry
 * (effective now; it also governs earlier instants, A26) and a journal row, in one transaction.
 */
final readonly class AccountService
{
    public function __construct(
        private ChangeJournal $journal,
        private EntityPresenter $presenter,
        private Clock $clock,
    ) {}

    /** A33: the accepted Terms and Privacy versions are stored with the server time of acceptance. */
    public function register(string $name, string $email, string $password, string $timezone, string $termsVersion, string $privacyVersion): User
    {
        return DB::transaction(function () use ($name, $email, $password, $timezone, $termsVersion, $privacyVersion): User {
            $now = UtcTime::format($this->clock->now());
            $id = (string) Str::uuid7();

            DB::table('users')->insert([
                'id' => $id,
                'name' => trim($name),
                'email' => $email,
                'password' => Hash::make($password),
                'timezone' => $timezone,
                // H5: the registration entry below is the calendar this user entity publishes.
                'calendar_journaled_at' => $now,
                'terms_version' => $termsVersion,
                'privacy_version' => $privacyVersion,
                'legal_accepted_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            DB::table('user_timezone_history')->insert([
                'id' => (string) Str::uuid7(),
                'user_id' => $id,
                'timezone' => $timezone,
                'day_start_offset_minutes' => 0,
                'effective_at' => $now,
                'created_at' => $now,
            ]);
            // ASSUMPTION(A2a-signup-grant): A11's signup freeze grant needs the freeze ledger
            // (A18 migration 7, Phase 5); the balance stays 0 until then so it always matches
            // the ledger.

            $this->journal->lockUser($id);
            $row = DB::table('users')->where('id', $id)->first();
            $this->journal->append($id, 'user', $id, 'upsert', 1, $this->presenter->user($row ?? (object) []));

            return User::query()->findOrFail($id);
        });
    }

    /** A29: how long a refreshed (old) token keeps working, for a refresh whose response was lost. */
    public const int REFRESH_GRACE_SECONDS = 600;

    /**
     * A6 rotation with a grace window (A29): issue a new token for the same device and shorten
     * the old one to 10 minutes instead of deleting it, so a lost response never logs a user out.
     */
    public function refresh(User $user, PersonalAccessToken $current): string
    {
        return DB::transaction(function () use ($user, $current): string {
            $token = $this->issueToken($user, $current->name, $current->device_id);
            $grace = $this->clock->now()->addSeconds(self::REFRESH_GRACE_SECONDS);
            if ($current->expires_at === null || $current->expires_at->greaterThan($grace)) {
                $current->forceFill(['expires_at' => $grace])->save();
            }
            // One full-lifetime token per user and device: a retry loop replaces tokens but
            // never accumulates them (Phase 2a.1 review, Q2).
            if ($current->device_id !== null) {
                $this->deviceTokens($user, $current->device_id)
                    ->whereKeyNot([$current->getKey(), strtok($token, '|')])
                    ->delete();
            }

            return $token;
        });
    }

    /** Login: a new session for a known device replaces that device's older tokens. */
    public function login(User $user, string $deviceName, ?string $deviceId): string
    {
        return DB::transaction(function () use ($user, $deviceName, $deviceId): string {
            if ($deviceId !== null) {
                $this->deviceTokens($user, $deviceId)->delete();
            }

            return $this->issueToken($user, $deviceName, $deviceId);
        });
    }

    /** @return Builder<PersonalAccessToken> */
    private function deviceTokens(User $user, string $deviceId): Builder
    {
        return PersonalAccessToken::query()
            ->where('tokenable_type', $user->getMorphClass())
            ->where('tokenable_id', $user->getKey())
            ->where('device_id', $deviceId);
    }

    /** Issues a token bound to one device (A6). Plain text is returned once. */
    public function issueToken(User $user, string $deviceName, ?string $deviceId): string
    {
        $secret = Str::random(48);
        /** @var PersonalAccessToken $token */
        $token = $user->tokens()->create([
            'name' => $deviceName,
            'token' => hash('sha256', $secret),
            'abilities' => ['*'],
            'device_id' => $deviceId,
            'expires_at' => $this->clock->now()->addMinutes(config()->integer('sanctum.expiration')),
        ]);

        return $token->getKey().'|'.$secret;
    }
}
