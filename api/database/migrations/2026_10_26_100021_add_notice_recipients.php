<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * A57: a notice goes to everyone or to chosen people. The audience is explicit, so a notice for
 * people whose accounts are later purged reaches nobody rather than everyone. Recipient rows
 * belong to the account and are purged with it (AccountPurger).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('notices', function (Blueprint $table) {
            $table->text('audience')->default('everyone');
        });
        DB::statement("ALTER TABLE notices ADD CONSTRAINT notices_audience CHECK (audience IN ('everyone', 'people'))");

        Schema::create('notice_recipients', function (Blueprint $table) {
            $table->foreignUuid('notice_id')->constrained('notices')->cascadeOnDelete();
            $table->foreignUuid('user_id')->constrained('users')->restrictOnDelete();
            $table->primary(['notice_id', 'user_id']);
            $table->index('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notice_recipients');
        DB::statement('ALTER TABLE notices DROP CONSTRAINT notices_audience');
        Schema::table('notices', function (Blueprint $table) {
            $table->dropColumn('audience');
        });
    }
};
