<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 3.2b: reminders as a synced entity (spec 06 "reminders"). A clock time and days of the
 * week, never a UTC instant; the device schedules them. Written only through the
 * MutationApplier (reminder.create / update / delete); a delete is a tombstone.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reminders', function (Blueprint $table) {
            $table->uuid('id')->primary();
            // Owner FK on every user resource (spec 02): owner scoping without a join.
            $table->foreignUuid('user_id')->constrained('users')->restrictOnDelete();
            $table->foreignUuid('habit_id')->constrained('habits')->restrictOnDelete();
            $table->time('local_time');
            $table->jsonb('days_of_week');
            $table->string('timezone_mode', 16);
            $table->string('timezone', 64)->nullable();
            $table->boolean('enabled')->default(true);
            $table->bigInteger('version')->default(1);
            $table->softDeletesTz();
            $table->timestampsTz();
            $table->index(['user_id', 'habit_id']);
        });
        DB::statement("ALTER TABLE reminders ADD CONSTRAINT reminders_timezone_mode CHECK (timezone_mode IN ('habit_zone', 'device_zone'))");
        DB::statement("ALTER TABLE reminders ADD CONSTRAINT reminders_days_of_week CHECK (jsonb_typeof(days_of_week) = 'array' AND jsonb_array_length(days_of_week) BETWEEN 1 AND 7)");
        DB::statement('ALTER TABLE reminders ADD CONSTRAINT reminders_version_positive CHECK (version >= 1)');
    }

    public function down(): void
    {
        Schema::dropIfExists('reminders');
    }
};
