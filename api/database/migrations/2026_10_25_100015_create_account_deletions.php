<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 6.2 (A49): one row per account deletion. It outlives the purge (user_id becomes null) so
 * the status receipt can still read it; it holds no personal data, only ids, times and the
 * receipt's SHA-256 hash.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('account_deletions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('status', 16);
            $table->timestampTz('requested_at');
            $table->timestampTz('purge_after');
            $table->timestampTz('completed_at')->nullable();
            $table->char('receipt_hash', 64)->unique();
            $table->timestampTz('receipt_expires_at');
            $table->timestampsTz();
            $table->index(['status', 'purge_after']);
        });
        DB::statement("ALTER TABLE account_deletions ADD CONSTRAINT account_deletions_status CHECK (status IN ('queued', 'purging', 'completed'))");
        DB::statement("ALTER TABLE account_deletions ADD CONSTRAINT account_deletions_completed CHECK ((status = 'completed') = (completed_at IS NOT NULL))");
        DB::statement("ALTER TABLE account_deletions ADD CONSTRAINT account_deletions_receipt_hash CHECK (receipt_hash ~ '^[0-9a-f]{64}$')");
    }

    public function down(): void
    {
        Schema::dropIfExists('account_deletions');
    }
};
