<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * A18 migration 2: habits, definition versions (authoritative, A4) and active ranges.
 * habits.type is varchar(24) validated by the HabitTypeRegistry, not a DB enum (A21).
 */
return new class extends Migration
{
    private const string CATEGORIES = "'health', 'mindfulness', 'learning', 'productivity', 'other'";

    private const string FREQUENCIES = "'daily', 'weekdays', 'weekly_count', 'interval'";

    public function up(): void
    {
        Schema::create('habits', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->restrictOnDelete();
            $table->string('name', 100);
            // Denormalised projection of the latest definition version (A4).
            $table->string('type', 24);
            $table->string('unit', 24)->nullable();
            $table->string('category', 24);
            $table->decimal('target_value', 12, 3);
            $table->string('frequency_type', 24);
            $table->jsonb('frequency_config');
            $table->date('start_local_date');
            $table->timestampTz('archived_at')->nullable();
            $table->bigInteger('version')->default(1);
            $table->bigInteger('definition_version')->default(1);
            $table->timestampsTz();
            $table->index(['user_id', 'archived_at']);
        });
        DB::statement('ALTER TABLE habits ADD CONSTRAINT habits_category CHECK (category IN ('.self::CATEGORIES.'))');
        DB::statement('ALTER TABLE habits ADD CONSTRAINT habits_frequency_type CHECK (frequency_type IN ('.self::FREQUENCIES.'))');
        DB::statement('ALTER TABLE habits ADD CONSTRAINT habits_target_positive CHECK (target_value > 0)');
        DB::statement('ALTER TABLE habits ADD CONSTRAINT habits_version_positive CHECK (version >= 1 AND definition_version >= 1)');

        Schema::create('habit_definition_versions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('habit_id')->constrained('habits')->restrictOnDelete();
            $table->integer('version');
            $table->date('effective_date');
            $table->string('type', 24);
            $table->decimal('target_value', 12, 3);
            $table->string('unit', 24)->nullable();
            $table->string('category', 24);
            $table->string('frequency_type', 24);
            $table->jsonb('frequency_config');
            $table->jsonb('config')->default('{}');
            $table->timestampTz('created_at');
            $table->unique(['habit_id', 'effective_date']);
            $table->unique(['habit_id', 'version']);
        });
        DB::statement('ALTER TABLE habit_definition_versions ADD CONSTRAINT habit_definition_versions_category CHECK (category IN ('.self::CATEGORIES.'))');
        DB::statement('ALTER TABLE habit_definition_versions ADD CONSTRAINT habit_definition_versions_frequency_type CHECK (frequency_type IN ('.self::FREQUENCIES.'))');
        DB::statement('ALTER TABLE habit_definition_versions ADD CONSTRAINT habit_definition_versions_target_positive CHECK (target_value > 0)');

        Schema::create('habit_active_ranges', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('habit_id')->constrained('habits')->restrictOnDelete();
            $table->date('starts_on');
            $table->date('ends_before')->nullable();
            $table->timestampTz('created_at');
            $table->index(['habit_id', 'starts_on']);
        });
        DB::statement('ALTER TABLE habit_active_ranges ADD CONSTRAINT habit_active_ranges_order CHECK (ends_before IS NULL OR ends_before > starts_on)');
        // Half-open ranges never overlap per habit (spec 02). btree_gist is a trusted extension.
        DB::statement('CREATE EXTENSION IF NOT EXISTS btree_gist');
        DB::statement("ALTER TABLE habit_active_ranges ADD CONSTRAINT habit_active_ranges_no_overlap EXCLUDE USING gist (habit_id WITH =, daterange(starts_on, ends_before, '[)') WITH &&)");
    }

    public function down(): void
    {
        Schema::dropIfExists('habit_active_ranges');
        Schema::dropIfExists('habit_definition_versions');
        Schema::dropIfExists('habits');
        // btree_gist stays: it is database-level infrastructure that other objects may use.
    }
};
