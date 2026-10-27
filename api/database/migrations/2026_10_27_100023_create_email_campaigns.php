<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * A59: service announcement emails. A campaign is what Khay Studios writes and to whom; a
 * delivery is one recipient's copy (never twice: UNIQUE campaign + user). Delivery rows belong
 * to the account and are purged with it. users.service_emails_stopped_at records a one-click stop.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestampTz('service_emails_stopped_at')->nullable();
        });

        Schema::create('email_campaigns', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->text('subject');
            $table->text('body');
            $table->jsonb('audience');
            $table->text('status')->default('draft');
            $table->timestampTz('scheduled_at')->nullable();
            $table->timestampTz('started_at')->nullable();
            $table->timestampTz('finished_at')->nullable();
            $table->integer('total')->default(0);
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');
            $table->index(['status', 'scheduled_at']);
        });
        DB::statement('ALTER TABLE email_campaigns ADD CONSTRAINT email_campaigns_subject_length CHECK (char_length(subject) BETWEEN 1 AND 120)');
        DB::statement('ALTER TABLE email_campaigns ADD CONSTRAINT email_campaigns_body_length CHECK (char_length(body) BETWEEN 1 AND 5000)');
        DB::statement("ALTER TABLE email_campaigns ADD CONSTRAINT email_campaigns_status CHECK (status IN ('draft', 'scheduled', 'sending', 'sent', 'cancelled'))");

        Schema::create('email_deliveries', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('campaign_id')->constrained('email_campaigns')->cascadeOnDelete();
            $table->foreignUuid('user_id')->constrained('users')->restrictOnDelete();
            $table->text('status')->default('queued');
            $table->text('error')->nullable();
            $table->timestampTz('sent_at')->nullable();
            $table->unique(['campaign_id', 'user_id']);
            $table->index(['status', 'sent_at']);
            $table->index('user_id');
        });
        DB::statement("ALTER TABLE email_deliveries ADD CONSTRAINT email_deliveries_status CHECK (status IN ('queued', 'sent', 'failed', 'skipped'))");
    }

    public function down(): void
    {
        Schema::dropIfExists('email_deliveries');
        Schema::dropIfExists('email_campaigns');
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('service_emails_stopped_at');
        });
    }
};
