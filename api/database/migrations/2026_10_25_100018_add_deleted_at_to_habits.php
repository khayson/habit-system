<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 6.6 (A51): a deleted habit stays as a tombstone row (its XP rows still point at it), with
 * its content cleared. Readers filter on deleted_at.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('habits', function (Blueprint $table) {
            $table->timestampTz('deleted_at')->nullable();
            $table->index(['user_id', 'deleted_at']);
        });
        DB::statement("ALTER TABLE habits ADD CONSTRAINT habits_deleted_cleared CHECK (deleted_at IS NULL OR name = '')");
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE habits DROP CONSTRAINT IF EXISTS habits_deleted_cleared');
        Schema::table('habits', function (Blueprint $table) {
            $table->dropIndex(['user_id', 'deleted_at']);
            $table->dropColumn('deleted_at');
        });
    }
};
