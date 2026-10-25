<?php

namespace App\Application\Habits;

use App\Application\Journal\ChangeJournal;
use App\Application\Presenters\EntityPresenter;
use App\Domain\Clock;
use App\Domain\Habit\HabitIcons;
use App\Support\UtcTime;
use Illuminate\Support\Facades\DB;

/**
 * A53: the one-time pass that gives existing habits the keyword table's icon. Only habits with
 * no icon change; each change raises the habit's version and is journaled, one transaction per
 * user under the user lock, so devices that already synced receive it.
 */
final readonly class HabitIconBackfill
{
    public function __construct(
        private ChangeJournal $journal,
        private EntityPresenter $presenter,
        private Clock $clock,
    ) {}

    public function run(): void
    {
        $users = DB::table('habits')->join('users', 'users.id', '=', 'habits.user_id')
            ->whereNull('habits.icon')->whereNull('habits.deleted_at')->whereNull('users.deleted_at')
            ->distinct()->orderBy('habits.user_id')->pluck('habits.user_id');
        foreach ($users as $userId) {
            DB::transaction(function () use ($userId) {
                $this->journal->lockUser((string) $userId);
                $now = UtcTime::format($this->clock->now());
                $habits = DB::table('habits')->where('user_id', $userId)->whereNull('icon')->whereNull('deleted_at')->orderBy('id')->get();
                foreach ($habits as $habit) {
                    $icon = HabitIcons::suggest((string) $habit->name);
                    if ($icon === null) {
                        continue;
                    }
                    $version = (int) $habit->version + 1;
                    DB::table('habits')->where('id', $habit->id)->update(['icon' => $icon, 'version' => $version, 'updated_at' => $now]);
                    $row = DB::table('habits')->where('id', $habit->id)->first();
                    if ($row !== null) {
                        $this->journal->append((string) $userId, 'habit', (string) $habit->id, 'upsert', $version, $this->presenter->habit($row));
                    }
                }
            });
        }
    }
}
