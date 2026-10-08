<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 3.1: owner FK on period_evaluations (spec 02: every user resource carries its owner),
 * added before the closer first fills the table. Backfill-safe: nullable, filled from the
 * habit, then NOT NULL.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('period_evaluations', function (Blueprint $table) {
            $table->uuid('user_id')->nullable();
        });
        DB::statement('UPDATE period_evaluations pe SET user_id = h.user_id FROM habits h WHERE h.id = pe.habit_id');
        DB::statement('ALTER TABLE period_evaluations ALTER COLUMN user_id SET NOT NULL');
        Schema::table('period_evaluations', function (Blueprint $table) {
            $table->foreign('user_id')->references('id')->on('users')->restrictOnDelete();
            $table->index(['user_id', 'habit_id', 'start_date']);
        });
    }

    public function down(): void
    {
        Schema::table('period_evaluations', function (Blueprint $table) {
            $table->dropIndex(['user_id', 'habit_id', 'start_date']);
            $table->dropForeign(['user_id']);
            $table->dropColumn('user_id');
        });
    }
};
