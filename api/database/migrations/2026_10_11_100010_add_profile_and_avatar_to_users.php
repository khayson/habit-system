<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * A20: the profile's location labels (typed or picked, never GPS) and the avatar pointer. The
 * avatar bytes live in private storage; avatar_key and avatar_sha256 are never returned.
 * users.version already exists (profile.set_timezone).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('city', 60)->nullable();
            $table->char('country_code', 2)->nullable();
            $table->text('avatar_key')->nullable();
            $table->integer('avatar_version')->default(0);
            $table->char('avatar_sha256', 64)->nullable();
        });
        DB::statement("ALTER TABLE users ADD CONSTRAINT users_country_code_format CHECK (country_code ~ '^[A-Z]{2}$')");
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE users DROP CONSTRAINT IF EXISTS users_country_code_format');
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['city', 'country_code', 'avatar_key', 'avatar_version', 'avatar_sha256']);
        });
    }
};
