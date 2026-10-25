<?php

namespace App\Application\Accounts;

use App\Application\Journal\ChangeJournal;
use App\Domain\Clock;
use App\Exceptions\AccountDeleted;
use App\Models\User;
use App\Support\UtcTime;
use App\Support\WireTime;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * A50: issues and redeems 6-digit reset codes. The callers answer every email the same way; this
 * class keeps the work the same too (one hash per call, known email or not).
 */
final readonly class PasswordResetService
{
    public const int CODE_MINUTES = 15;

    public const int MAX_ATTEMPTS = 5;

    public const int COOLDOWN_SECONDS = 60;

    /** 6.4 review L1: wrong tries per account in a rolling 24 hours before codes stop. */
    public const int DAILY_WRONG_TRIES = 10;

    public function __construct(
        private ResetCodeHasher $hasher,
        private ChangeJournal $journal,
        private Clock $clock,
    ) {}

    /** The code to email, or null when nothing is sent (unknown, deleted, or in the cooldown). */
    public function issue(string $email): ?string
    {
        $user = $this->liveUser($email);
        $code = str_pad((string) random_int(0, 999_999), 6, '0', STR_PAD_LEFT);
        $hash = $this->hasher->hash($code);
        if ($user === null) {
            return null;
        }

        try {
            return DB::transaction(function () use ($user, $code, $hash): ?string {
                $this->journal->lockUser((string) $user->id);
                $now = $this->clock->now();
                $last = DB::table('password_reset_codes')->where('user_id', $user->id)->max('created_at');
                if ($last !== null && WireTime::parse((string) $last) > $now->subSeconds(self::COOLDOWN_SECONDS)) {
                    return null;
                }
                $wrong = DB::table('password_reset_failures')->where('user_id', $user->id)
                    ->where('failed_at', '>', UtcTime::format($now->subDay()))->count();
                if ($wrong >= self::DAILY_WRONG_TRIES) {
                    return null;
                }
                // A new code replaces any earlier unused one.
                DB::table('password_reset_codes')->where('user_id', $user->id)->whereNull('consumed_at')->delete();
                DB::table('password_reset_codes')->insert([
                    'id' => (string) Str::uuid7(), 'user_id' => $user->id, 'code_hash' => $hash,
                    'expires_at' => UtcTime::format($now->addMinutes(self::CODE_MINUTES)), 'attempts' => 0,
                    'created_at' => UtcTime::format($now),
                ]);

                return $code;
            });
        } catch (AccountDeleted) {
            return null;
        }
    }

    /**
     * True when the code was valid and the password is changed (every session revoked). A wrong
     * try is counted and committed before false is returned.
     */
    public function reset(string $email, string $code, string $password): bool
    {
        $user = $this->liveUser($email);
        $hash = $this->hasher->hash($code);
        if ($user === null) {
            return false;
        }

        try {
            return DB::transaction(function () use ($user, $hash, $password): bool {
                $this->journal->lockUser((string) $user->id);
                $now = $this->clock->now();
                $row = DB::table('password_reset_codes')->where('user_id', $user->id)->whereNull('consumed_at')
                    ->lockForUpdate()->first();
                if ($row === null
                    || WireTime::parse((string) $row->expires_at) <= $now
                    || (int) $row->attempts >= self::MAX_ATTEMPTS) {
                    return false;
                }
                if (! hash_equals((string) $row->code_hash, $hash)) {
                    DB::table('password_reset_codes')->where('id', $row->id)->increment('attempts');
                    DB::table('password_reset_failures')->where('user_id', $user->id)
                        ->where('failed_at', '<=', UtcTime::format($now->subDay()))->delete();
                    DB::table('password_reset_failures')->insert([
                        'id' => (string) Str::uuid7(), 'user_id' => $user->id, 'failed_at' => UtcTime::format($now),
                    ]);

                    return false;
                }
                $at = UtcTime::format($now);
                DB::table('users')->where('id', $user->id)->update(['password' => Hash::make($password), 'updated_at' => $at]);
                DB::table('password_reset_codes')->where('id', $row->id)->update(['consumed_at' => $at]);
                // Every device signs out: the spec's "revoke old sessions".
                DB::table('personal_access_tokens')->where('tokenable_type', (new User)->getMorphClass())
                    ->where('tokenable_id', $user->id)->delete();

                return true;
            });
        } catch (AccountDeleted) {
            return false;
        }
    }

    private function liveUser(string $email): ?User
    {
        return User::query()->where('email', $email)->whereNull('deleted_at')->first();
    }
}
