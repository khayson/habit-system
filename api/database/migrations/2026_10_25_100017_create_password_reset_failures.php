<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * 6.4 review L1: one row per wrong reset try, so ten in a rolling 24 hours can stop new codes
 * for that account. Rows older than 24 hours have no use and are removed as new ones arrive.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('password_reset_failures', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->restrictOnDelete();
            $table->timestampTz('failed_at');
            $table->index(['user_id', 'failed_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('password_reset_failures');
    }
};
