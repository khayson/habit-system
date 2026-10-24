<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 6.1 (A48, spec export_jobs): one row per requested export. Not a domain table: nothing
 * here is journaled, and history is never changed by a job.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('export_jobs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('format', 8);
            $table->string('status', 16);
            $table->bigInteger('snapshot_seq')->nullable();
            $table->string('object_key', 200)->nullable();
            $table->timestampTz('expires_at')->nullable();
            $table->string('error_code', 40)->nullable();
            $table->timestampsTz();
            $table->index(['user_id', 'created_at']);
        });
        DB::statement("ALTER TABLE export_jobs ADD CONSTRAINT export_jobs_format CHECK (format IN ('json', 'csv'))");
        DB::statement("ALTER TABLE export_jobs ADD CONSTRAINT export_jobs_status CHECK (status IN ('queued', 'running', 'ready', 'failed', 'expired'))");
        // A ready job has its object and expiry; a failed one says why.
        DB::statement("ALTER TABLE export_jobs ADD CONSTRAINT export_jobs_ready_complete CHECK (
            status <> 'ready' OR (object_key IS NOT NULL AND expires_at IS NOT NULL AND snapshot_seq IS NOT NULL))");
        DB::statement("ALTER TABLE export_jobs ADD CONSTRAINT export_jobs_failed_reason CHECK (
            status <> 'failed' OR error_code IS NOT NULL)");
    }

    public function down(): void
    {
        Schema::dropIfExists('export_jobs');
    }
};
