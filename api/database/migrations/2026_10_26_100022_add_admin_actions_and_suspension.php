<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * A58: an account Khay Studios suspended (sign-in refused until resumed), and the append-only
 * audit of what the admin did. Audit rows hold no IP address and no secret; the subject is an
 * id (a user or a notice), so a purged account leaves only an id behind.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestampTz('suspended_at')->nullable();
        });

        Schema::create('admin_actions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->text('action');
            $table->text('subject')->nullable();
            $table->jsonb('detail')->default('{}');
            $table->timestampTz('created_at');
            $table->index('created_at');
        });
        DB::statement('ALTER TABLE admin_actions ADD CONSTRAINT admin_actions_action_length CHECK (char_length(action) BETWEEN 1 AND 60)');
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_actions');
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('suspended_at');
        });
    }
};
