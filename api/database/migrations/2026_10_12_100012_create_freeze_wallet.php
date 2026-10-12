<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 5.1 (A18 migration 7, A41, A42, spec 06): the freeze ledger whose sum is
 * users.freeze_balance, one usage per protected (habit, period_key), the auto-freeze policy
 * history, and the protected periods inside the current streak on the streak cache.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('freeze_ledger', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('kind', 8);
            $table->smallInteger('delta');
            $table->string('reason', 24);
            $table->string('source_key', 160);
            $table->timestampTz('created_at');
            $table->unique(['user_id', 'source_key']);
            $table->index(['user_id', 'created_at', 'id']);
        });
        DB::statement("ALTER TABLE freeze_ledger ADD CONSTRAINT freeze_ledger_kind CHECK (kind IN ('grant', 'spend', 'refund'))");
        DB::statement("ALTER TABLE freeze_ledger ADD CONSTRAINT freeze_ledger_delta_by_kind CHECK (
            (kind = 'spend' AND delta = -1)
            OR (kind = 'refund' AND delta BETWEEN 0 AND 1)
            OR (kind = 'grant' AND delta BETWEEN 0 AND 2))");

        // Spec 06 names the table freeze_usage (singular) and gives used_on, definition_version
        // and reconciled_at; refund_ledger_id links the one refund (A41).
        Schema::create('freeze_usage', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('habit_id')->constrained('habits')->cascadeOnDelete();
            $table->string('period_key', 32);
            $table->integer('definition_version');
            $table->date('used_on');
            $table->string('state', 16);
            $table->foreignUuid('spend_ledger_id')->constrained('freeze_ledger')->cascadeOnDelete();
            $table->foreignUuid('refund_ledger_id')->nullable()->constrained('freeze_ledger')->cascadeOnDelete();
            $table->timestampTz('reconciled_at')->nullable();
            $table->timestampsTz();
            $table->unique(['habit_id', 'period_key']);
            $table->index(['user_id', 'state']);
        });
        DB::statement("ALTER TABLE freeze_usage ADD CONSTRAINT freeze_usage_state CHECK (state IN ('active', 'refunded'))");
        DB::statement("ALTER TABLE freeze_usage ADD CONSTRAINT freeze_usage_refund_consistent CHECK (
            (state = 'active' AND refund_ledger_id IS NULL AND reconciled_at IS NULL)
            OR (state = 'refunded' AND refund_ledger_id IS NOT NULL AND reconciled_at IS NOT NULL))");

        Schema::create('user_freeze_policy_versions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->boolean('enabled');
            $table->timestampTz('effective_at');
            $table->index(['user_id', 'effective_at']);
        });

        Schema::table('habit_streak_cache', function (Blueprint $table) {
            $table->smallInteger('protected_in_streak')->default(0);
        });
        DB::statement('ALTER TABLE habit_streak_cache ADD CONSTRAINT habit_streak_cache_protected_non_negative CHECK (protected_in_streak >= 0)');
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE habit_streak_cache DROP CONSTRAINT habit_streak_cache_protected_non_negative');
        Schema::table('habit_streak_cache', function (Blueprint $table) {
            $table->dropColumn('protected_in_streak');
        });
        Schema::dropIfExists('user_freeze_policy_versions');
        Schema::dropIfExists('freeze_usage');
        Schema::dropIfExists('freeze_ledger');
    }
};
