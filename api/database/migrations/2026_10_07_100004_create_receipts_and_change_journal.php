<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * A18 migration 4: idempotency receipts and the per-user change journal.
 * A1: seq is allocated per user under the user-row lock (users.change_seq), so commit order
 * equals seq order and `seq > cursor` pulls never skip a row. No global identity.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->bigInteger('change_seq')->default(0);
        });
        DB::statement('ALTER TABLE users ADD CONSTRAINT users_change_seq_non_negative CHECK (change_seq >= 0)');

        Schema::create('mutation_receipts', function (Blueprint $table) {
            $table->foreignUuid('user_id')->constrained('users')->restrictOnDelete();
            $table->uuid('mutation_id');
            $table->uuid('device_id')->nullable();
            $table->string('operation', 48);
            $table->char('payload_hash', 64);
            $table->jsonb('result');
            $table->timestampTz('committed_at');
            $table->primary(['user_id', 'mutation_id']);
        });

        Schema::create('server_changes', function (Blueprint $table) {
            $table->foreignUuid('user_id')->constrained('users')->restrictOnDelete();
            $table->bigInteger('seq');
            $table->string('entity_type', 32);
            $table->uuid('entity_id');
            $table->string('operation', 8);
            $table->bigInteger('version');
            $table->jsonb('payload');
            $table->timestampTz('created_at');
            $table->primary(['user_id', 'seq']);
        });
        DB::statement("ALTER TABLE server_changes ADD CONSTRAINT server_changes_operation CHECK (operation IN ('upsert', 'delete'))");
        DB::statement('ALTER TABLE server_changes ADD CONSTRAINT server_changes_seq_positive CHECK (seq >= 1)');
    }

    public function down(): void
    {
        Schema::dropIfExists('server_changes');
        Schema::dropIfExists('mutation_receipts');
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('change_seq');
        });
    }
};
