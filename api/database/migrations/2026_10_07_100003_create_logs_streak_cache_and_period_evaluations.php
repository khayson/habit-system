<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * A18 migration 3: daily logs (one row per habit and local date), streak cache and period
 * evaluations. The cache and evaluations are filled from Phase 3; the tables exist now so
 * log writes can mark the cache dirty in the same transaction.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('habit_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            // Owner FK on every user resource (spec 02): owner scoping without a join.
            $table->foreignUuid('user_id')->constrained('users')->restrictOnDelete();
            $table->foreignUuid('habit_id')->constrained('habits')->restrictOnDelete();
            $table->date('log_date');
            $table->decimal('value', 12, 3)->default(0);
            $table->jsonb('detail')->default('{}');
            $table->text('note')->nullable();
            $table->timestampTz('occurred_at', 6);
            $table->timestampTz('completed_at', 6)->nullable();
            $table->string('resolved_timezone', 64);
            $table->smallInteger('day_start_offset_minutes')->default(0);
            $table->integer('definition_version');
            $table->bigInteger('version')->default(1);
            $table->softDeletesTz();
            $table->timestampsTz();
            $table->unique(['habit_id', 'log_date']);
            $table->index(['user_id', 'habit_id']);
        });
        DB::statement('CREATE INDEX habit_logs_habit_date_desc ON habit_logs (habit_id, log_date DESC)');
        DB::statement('ALTER TABLE habit_logs ADD CONSTRAINT habit_logs_value_non_negative CHECK (value >= 0)');
        DB::statement('ALTER TABLE habit_logs ADD CONSTRAINT habit_logs_version_positive CHECK (version >= 1)');

        Schema::create('habit_streak_cache', function (Blueprint $table) {
            $table->uuid('habit_id')->primary();
            $table->foreign('habit_id')->references('id')->on('habits')->restrictOnDelete();
            $table->integer('current')->default(0);
            $table->integer('longest')->default(0);
            $table->string('unit', 16)->default('days');
            $table->date('computed_through')->nullable();
            $table->date('dirty_from')->nullable();
            $table->bigInteger('version')->default(1);
            $table->timestampTz('updated_at');
        });
        DB::statement('ALTER TABLE habit_streak_cache ADD CONSTRAINT habit_streak_cache_non_negative CHECK ("current" >= 0 AND longest >= 0)');

        Schema::create('period_evaluations', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('habit_id')->constrained('habits')->restrictOnDelete();
            $table->string('period_key', 16);
            $table->integer('definition_version');
            $table->date('start_date');
            $table->date('end_date');
            $table->string('timezone', 64);
            $table->timestampTz('starts_at');
            $table->timestampTz('ends_at');
            $table->boolean('completed');
            $table->boolean('protected');
            $table->integer('revision')->default(1);
            $table->timestampsTz();
            $table->unique(['habit_id', 'period_key']);
            $table->index(['habit_id', 'ends_at']);
        });
        DB::statement("ALTER TABLE period_evaluations ADD CONSTRAINT period_evaluations_key_format CHECK (period_key ~ '^[dw]:[0-9]{4}-[0-9]{2}-[0-9]{2}$')");
        DB::statement('ALTER TABLE period_evaluations ADD CONSTRAINT period_evaluations_dates CHECK (end_date >= start_date AND ends_at > starts_at)');
    }

    public function down(): void
    {
        Schema::dropIfExists('period_evaluations');
        Schema::dropIfExists('habit_streak_cache');
        Schema::dropIfExists('habit_logs');
    }
};
