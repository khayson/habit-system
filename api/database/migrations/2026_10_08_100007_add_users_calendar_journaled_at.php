<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * H5: the effective_at of the in-force calendar entry as last published in the user entity, so
 * the closer can tell a pending change has come into force without reading the journal. No
 * production data exists yet, so no backfill: null means "nothing published", never stale.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestampTz('calendar_journaled_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('calendar_journaled_at');
        });
    }
};
