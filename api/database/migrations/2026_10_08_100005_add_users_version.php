<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 3.1 (D1): users.version, so profile mutations are version-checked like every other
 * absolute edit and the user entity is journaled with a real version.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->bigInteger('version')->default(1);
        });
        DB::statement('ALTER TABLE users ADD CONSTRAINT users_version_positive CHECK (version >= 1)');
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE users DROP CONSTRAINT users_version_positive');
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('version');
        });
    }
};
