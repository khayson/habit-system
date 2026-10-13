<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 5.2a (5.1 review L1): GET /freezes joins usages on their ledger rows, and deleting a
 * ledger row cascades to its usage. PostgreSQL does not index a referencing column by itself.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('freeze_usage', function (Blueprint $table) {
            $table->index('spend_ledger_id');
            $table->index('refund_ledger_id');
        });
    }

    public function down(): void
    {
        Schema::table('freeze_usage', function (Blueprint $table) {
            $table->dropIndex(['spend_ledger_id']);
            $table->dropIndex(['refund_ledger_id']);
        });
    }
};
