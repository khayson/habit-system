<?php

namespace App\Application\Accounts;

use App\Application\Journal\ChangeJournal;
use App\Application\Presenters\EntityPresenter;
use App\Domain\Clock;
use App\Models\PersonalAccessToken;
use App\Models\User;
use App\Support\UtcTime;
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

    public function register(string $name, string $email, string $password, string $timezone): User
    {
        return DB::transaction(function () use ($name, $email, $password, $timezone): User {
            $now = UtcTime::format($this->clock->now());
            $id = (string) Str::uuid7();

            DB::table('users')->insert([
                'id' => $id,
                'name' => trim($name),
                'email' => $email,
                'password' => Hash::make($password),
                'timezone' => $timezone,
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
