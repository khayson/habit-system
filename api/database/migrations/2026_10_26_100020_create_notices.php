<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * A57: short plain-text notices Khay Studios publishes with artisan and the app shows in Today's
 * carousel. The same for every account; no owner and no personal data.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notices', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->text('title');
            $table->text('body');
            $table->timestampTz('starts_at');
            $table->timestampTz('ends_at')->nullable();
            $table->timestampTz('created_at');
            $table->index('starts_at');
        });
        DB::statement('ALTER TABLE notices ADD CONSTRAINT notices_title_length CHECK (char_length(title) BETWEEN 1 AND 60)');
        DB::statement('ALTER TABLE notices ADD CONSTRAINT notices_body_length CHECK (char_length(body) BETWEEN 1 AND 280)');
        DB::statement('ALTER TABLE notices ADD CONSTRAINT notices_ends_after_start CHECK (ends_at IS NULL OR ends_at > starts_at)');
    }

    public function down(): void
    {
        Schema::dropIfExists('notices');
    }
};
