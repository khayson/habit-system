<?php

use App\Domain\Calendar\CalendarEntry;
use App\Domain\Calendar\CalendarHistory;
use App\Domain\Calendar\LocalDate;
use App\Infrastructure\FrozenClock;
use App\Support\UtcTime;
use Tests\Support\DomainFixtures;

/*
 * D1 / A26: contract-fixtures/domain/calendar_changes.json.
 */

$fixture = DomainFixtures::load('calendar_changes');

it('rejects histories whose dates would go backwards, and resolves the rest', function (array $case) {
    if (! $case['valid']) {
        expect(fn () => DomainFixtures::timeline($case['calendar']))
            ->toThrow(InvalidArgumentException::class, 'would move dates backwards');

        return;
    }
    $timeline = DomainFixtures::timeline($case['calendar']);
    foreach ($case['dates'] as [$instant, $date]) {
        expect($timeline->localDateAt(DomainFixtures::instant($instant))->toString())->toBe($date, $instant);
    }
    $zeroLength = [];
    for ($d = LocalDate::fromString('2026-03-01'); ! $d->isAfter(LocalDate::fromString('2026-06-30')); $d = $d->addDays(1)) {
        if ($timeline->isZeroLength($d)) {
            $zeroLength[] = $d->toString();
        }
    }
    expect($zeroLength)->toBe($case['zero_length']);
})->with(DomainFixtures::named($fixture['monotonic']));

it('appends a change at the next local day start in the old calendar', function (array $case) {
    $history = new CalendarHistory(new FrozenClock($case['now']));
    $change = $history->appendChange(
        DomainFixtures::timeline($case['calendar']),
        $case['change']['timezone'],
        $case['change']['day_start_offset_minutes'],
    );

    expect($change->changed)->toBe($case['expect']['changed'])
        ->and(array_map(fn (CalendarEntry $e) => [
            'effective_at' => UtcTime::format($e->effectiveAt),
            'timezone' => $e->timezone,
            'day_start_offset_minutes' => $e->dayStartOffsetMinutes,
        ], $change->timeline->entries))->toBe($case['expect']['calendar']);
})->with(DomainFixtures::named($fixture['append_change']));
