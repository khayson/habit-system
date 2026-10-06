<?php

use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

it('runs PHP, Laravel and the PostgreSQL session in UTC', function () {
    expect(config('app.timezone'))->toBe('UTC')
        ->and(date_default_timezone_get())->toBe('UTC')
        ->and(now()->getTimezone()->getName())->toBe('UTC');

    expect(DB::connection()->getDriverName())->toBe('pgsql')
        ->and(DB::selectOne('show timezone')->TimeZone)->toBe('UTC');
});

it('runs on PostgreSQL 16 or newer', function () {
    $versionNum = (int) DB::selectOne('show server_version_num')->server_version_num;

    expect($versionNum)->toBeGreaterThanOrEqual(160000);
});

it('round-trips timestamptz without shifting the instant', function () {
    $row = DB::selectOne("select ('2026-05-29T06:30:00Z'::timestamptz) as at");

    expect(CarbonImmutable::parse($row->at)->utc()->format('Y-m-d\TH:i:s\Z'))->toBe('2026-05-29T06:30:00Z');
});
