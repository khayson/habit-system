<?php

namespace App\Http\Controllers;

use App\Domain\Clock;
use App\Support\UtcTime;
use Illuminate\Contracts\View\View;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Str;

/**
 * A59: the "stop these emails" link in every announcement (a signed URL, also the RFC 8058
 * one-click POST), and "turn them back on". Nothing else about the account is shown or changed.
 */
final readonly class EmailPreferenceController
{
    public function __construct(private Clock $clock) {}

    public function stop(string $user): View
    {
        if (Str::isUuid($user)) {
            DB::table('users')->where('id', $user)->whereNull('service_emails_stopped_at')
                ->update(['service_emails_stopped_at' => UtcTime::format($this->clock->now())]);
        }

        return view('emails.stopped', ['startUrl' => URL::signedRoute('emails.start', ['user' => $user])]);
    }

    public function start(string $user): View
    {
        if (Str::isUuid($user)) {
            DB::table('users')->where('id', $user)->update(['service_emails_stopped_at' => null]);
        }

        return view('emails.started', ['stopUrl' => URL::signedRoute('emails.stop', ['user' => $user])]);
    }
}
