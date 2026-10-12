<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 5.1 (A18 migration 6, A39, A40): one stable XP entitlement per completed habit-day and
 * the append-only ledger whose sum is users.xp. users.reward_version is the version of the
 * read-only reward_state entity.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('xp_entitlements', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('habit_id')->constrained('habits')->cascadeOnDelete();
            $table->date('log_date');
            $table->smallInteger('amount')->default(10);
            $table->string('state', 16);
            $table->integer('revision');
            $table->timestampsTz();
            $table->unique(['habit_id', 'log_date']);
            $table->index('user_id');
        });
        DB::statement("ALTER TABLE xp_entitlements ADD CONSTRAINT xp_entitlements_state CHECK (state IN ('active', 'reversed'))");
        DB::statement('ALTER TABLE xp_entitlements ADD CONSTRAINT xp_entitlements_revision_positive CHECK (revision >= 1)');
        DB::statement('ALTER TABLE xp_entitlements ADD CONSTRAINT xp_entitlements_amount CHECK (amount = 10)');

        Schema::create('xp_ledger', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('entitlement_id')->constrained('xp_entitlements')->cascadeOnDelete();
            $table->integer('entitlement_revision');
            // Spec 06: delta bigint; only these two values are ever written.
            $table->bigInteger('delta');
            $table->string('reason', 16);
            $table->uuid('mutation_id')->nullable();
            $table->timestampTz('created_at');
            $table->unique(['entitlement_id', 'entitlement_revision']);
            $table->index(['user_id', 'created_at', 'id']);
        });
        DB::statement('ALTER TABLE xp_ledger ADD CONSTRAINT xp_ledger_delta CHECK (delta IN (10, -10))');
        DB::statement("ALTER TABLE xp_ledger ADD CONSTRAINT xp_ledger_reason CHECK (reason IN ('completion', 'reversal', 'recompletion'))");

        Schema::table('users', function (Blueprint $table) {
            $table->integer('reward_version')->default(0);
        });
        DB::statement('ALTER TABLE users ADD CONSTRAINT users_reward_version_non_negative CHECK (reward_version >= 0)');
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE users DROP CONSTRAINT users_reward_version_non_negative');
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('reward_version');
        });
        Schema::dropIfExists('xp_ledger');
        Schema::dropIfExists('xp_entitlements');
    }
};
