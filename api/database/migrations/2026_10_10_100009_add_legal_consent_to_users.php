<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * A33: the Terms and Privacy versions a user accepted at registration, and when (server clock).
 * Null only for accounts created before A33. Never returned by an endpoint.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->char('terms_version', 10)->nullable();
            $table->char('privacy_version', 10)->nullable();
            $table->timestampTz('legal_accepted_at')->nullable();
        });
        DB::statement("ALTER TABLE users ADD CONSTRAINT users_terms_version_format CHECK (terms_version ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')");
        DB::statement("ALTER TABLE users ADD CONSTRAINT users_privacy_version_format CHECK (privacy_version ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')");
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE users DROP CONSTRAINT IF EXISTS users_privacy_version_format');
        DB::statement('ALTER TABLE users DROP CONSTRAINT IF EXISTS users_terms_version_format');
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['terms_version', 'privacy_version', 'legal_accepted_at']);
        });
    }
};
