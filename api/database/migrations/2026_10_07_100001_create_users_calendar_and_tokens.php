<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * A18 migration 1: users, calendar history (timezone + day-start offset, A22), Sanctum tokens
 * for UUID users (A6).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name', 80);
            $table->string('email', 255);
            $table->string('password', 255);
            $table->string('timezone', 64);
            $table->string('timezone_mode', 24)->default('fixed');
            $table->boolean('auto_freeze')->default(false);
            $table->bigInteger('xp')->default(0);
            $table->smallInteger('freeze_balance')->default(0);
            $table->timestampsTz();
            $table->softDeletesTz();
        });
        // Emails are stored normalised (trimmed, lower-case); uniqueness is enforced on that form.
        DB::statement('CREATE UNIQUE INDEX users_email_unique ON users (lower(email))');
        DB::statement('ALTER TABLE users ADD CONSTRAINT users_email_normalised CHECK (email = lower(btrim(email)))');
        DB::statement('ALTER TABLE users ADD CONSTRAINT users_xp_non_negative CHECK (xp >= 0)');
        DB::statement('ALTER TABLE users ADD CONSTRAINT users_freeze_balance_range CHECK (freeze_balance BETWEEN 0 AND 2)');
        DB::statement("ALTER TABLE users ADD CONSTRAINT users_timezone_mode CHECK (timezone_mode IN ('fixed', 'ask_on_device_change'))");

        Schema::create('user_timezone_history', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->restrictOnDelete();
            $table->string('timezone', 64);
            $table->smallInteger('day_start_offset_minutes')->default(0);
            $table->timestampTz('effective_at');
            $table->timestampTz('created_at');
            $table->unique(['user_id', 'effective_at']);
        });
        DB::statement('ALTER TABLE user_timezone_history ADD CONSTRAINT user_timezone_history_offset_range CHECK (day_start_offset_minutes BETWEEN 0 AND 360)');

        Schema::create('personal_access_tokens', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuidMorphs('tokenable');
            $table->string('name', 255);
            $table->string('token', 64)->unique();
            $table->text('abilities')->nullable();
            // ASSUMPTION(A2a-device): client-generated installation id; the devices table arrives
            // with A18 migration 5. Logout revokes the token for this device.
            $table->uuid('device_id')->nullable();
            $table->timestampTz('last_used_at')->nullable();
            $table->timestampTz('expires_at')->nullable()->index();
            $table->timestampsTz();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('personal_access_tokens');
        Schema::dropIfExists('user_timezone_history');
        Schema::dropIfExists('users');
    }
};
