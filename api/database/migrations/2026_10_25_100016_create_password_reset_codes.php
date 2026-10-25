<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 6.4 (A50): one row per issued reset code. The code itself is never stored, only its
 * HMAC; at most one unconsumed code per user.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('password_reset_codes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->restrictOnDelete();
            $table->char('code_hash', 64);
            $table->timestampTz('expires_at');
            $table->smallInteger('attempts')->default(0);
            $table->timestampTz('consumed_at')->nullable();
            $table->timestampTz('created_at');
            $table->index(['user_id', 'created_at']);
        });
        DB::statement('ALTER TABLE password_reset_codes ADD CONSTRAINT password_reset_codes_attempts CHECK (attempts BETWEEN 0 AND 5)');
        DB::statement("ALTER TABLE password_reset_codes ADD CONSTRAINT password_reset_codes_hash CHECK (code_hash ~ '^[0-9a-f]{64}$')");
        DB::statement('CREATE UNIQUE INDEX password_reset_codes_one_open ON password_reset_codes (user_id) WHERE consumed_at IS NULL');
    }

    public function down(): void
    {
        Schema::dropIfExists('password_reset_codes');
    }
};
