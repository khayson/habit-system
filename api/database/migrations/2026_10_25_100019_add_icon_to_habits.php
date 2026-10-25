<?php

use App\Application\Habits\HabitIconBackfill;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 6.8 (A53): a habit's chosen icon, a Hugeicons key or null. Then the one-time backfill
 * from the habit's name (journaled, so synced devices receive it).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('habits', function (Blueprint $table) {
            $table->string('icon', 64)->nullable();
        });
        DB::statement("ALTER TABLE habits ADD CONSTRAINT habits_icon_key CHECK (icon IS NULL OR icon ~ '^[a-z0-9]+(-[a-z0-9]+)*$')");
        app(HabitIconBackfill::class)->run();
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE habits DROP CONSTRAINT IF EXISTS habits_icon_key');
        Schema::table('habits', function (Blueprint $table) {
            $table->dropColumn('icon');
        });
    }
};
