<?php

use App\Domain\Calendar\DayResolutionException;
use App\Domain\Calendar\DayResolver;
use App\Domain\Calendar\LocalDate;
use App\Infrastructure\FrozenClock;
use Tests\Support\DomainFixtures as F;

/** contract-fixtures/domain/day_resolution.json */
function dayFixture(): array
{
    return F::load('day_resolution');
}

function resolverFor(string $calendar, string $now): DayResolver
{
    return new DayResolver(F::timeline(dayFixture()['calendars'][$calendar]), new FrozenClock($now));
}

it('resolves the business date', function (array $case) {
    $resolver = resolverFor($case['calendar'], $case['now']);
    $hint = isset($case['local_date_hint']) ? LocalDate::fromString($case['local_date_hint']) : null;

    try {
        $resolution = $resolver->resolve(F::instant($case['occurred_at']), $case['captured_timezone'] ?? null, $hint);
    } catch (DayResolutionException $e) {
        expect($case['expect'])->toHaveKey('error')
            ->and($e->reason)->toBe($case['expect']['error']);
        if (isset($case['expect']['calendar'])) {
            expect([$e->entry?->timezone, $e->entry?->dayStartOffsetMinutes, $e->entry?->effectiveAt->format('Y-m-d\TH:i:s\Z')])
                ->toBe(array_values($case['expect']['calendar']));
        }

        return;
    }

    expect($case['expect'])->not->toHaveKey('error', 'expected an error, got '.$resolution->localDate)
        ->and($resolution->localDate->toString())->toBe($case['expect']['local_date']);
    if (array_key_exists('hint_matches', $case['expect'])) {
        expect($resolution->hintMatches)->toBe($case['expect']['hint_matches']);
    }
})->with(fn () => F::named(dayFixture()['resolve']));

it('computes local day boundaries', function (array $case) {
    $timeline = F::timeline(dayFixture()['calendars'][$case['calendar']]);
    $date = LocalDate::fromString($case['date']);

    expect($timeline->startOfLocalDay($date)->format('Y-m-d\TH:i:s\Z'))->toBe($case['starts_at'])
        ->and($timeline->endOfLocalDay($date)->format('Y-m-d\TH:i:s\Z'))->toBe($case['ends_at']);
})->with(function () {
    $out = [];
    foreach (dayFixture()['start_of_day'] as $case) {
        $out["{$case['calendar']} {$case['date']}"] = [$case];
    }

    return $out;
});

it('validates explicit backdates', function (array $case) {
    $resolver = resolverFor($case['calendar'], $case['now']);

    try {
        $at = isset($case['occurred_at']) ? F::instant($case['occurred_at']) : null;
        $resolver->validateBackdate(LocalDate::fromString($case['date']), $at);
        $outcome = 'ok';
    } catch (DayResolutionException $e) {
        $outcome = $e->reason;
    }

    expect($outcome)->toBe($case['expect']);
})->with(fn () => F::named(dayFixture()['backdate']));

it('pins the windows to the fixture rules', function () {
    $rules = dayFixture()['rules'];

    expect(DayResolver::FUTURE_TOLERANCE_SECONDS)->toBe($rules['future_tolerance_seconds'])
        ->and(DayResolver::MAX_OFFLINE_AGE_SECONDS)->toBe($rules['max_offline_age_seconds'])
        ->and(DayResolver::MAX_BACKDATE_DAYS)->toBe($rules['max_backdate_days']);
});

it('event dates never go backwards across a whole DST year (property)', function (string $calendar) {
    $timeline = F::timeline(dayFixture()['calendars'][$calendar]);
    $t = F::instant('2026-01-01T12:00:00Z');
    $previous = $timeline->localDateAt($t);

    // Every 15 minutes through 2026, plus the boundary itself must belong to its own date.
    for ($i = 0; $i < 365 * 96; $i++) {
        $t = $t->modify('+15 minutes');
        $date = $timeline->localDateAt($t);
        expect($date->isBefore($previous))->toBeFalse("went backwards at {$t->format('c')}");
        expect($date->daysUntil($previous) >= -1)->toBeTrue();
        $previous = $date;
    }
    $d = LocalDate::fromString('2026-10-25');
    expect($timeline->localDateAt($timeline->startOfLocalDay($d))->toString())->toBe('2026-10-25');
    foreach (dayFixture()['start_of_day'] as $case) {
        if ($case['calendar'] === $calendar) {
            $start = $timeline->startOfLocalDay(LocalDate::fromString($case['date']));
            expect($timeline->localDateAt($start)->toString())->toBe($case['date']);
        }
    }
})->with(['la', 'paris', 'la_offset_120', 'paris_offset_150', 'la_then_paris', 'paris_then_la']);
