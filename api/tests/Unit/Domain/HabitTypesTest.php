<?php

use App\Domain\Calendar\LocalDate;
use App\Domain\Habit\ActiveRange;
use App\Domain\Habit\DefinitionVersion;
use App\Domain\Habit\Frequency;
use App\Domain\Habit\HabitSchedule;
use App\Domain\Habit\HabitType;
use App\Domain\Habit\HabitTypeRegistry;
use App\Domain\Habit\InvalidHabitValue;
use App\Domain\Habit\LogState;
use App\Domain\Habit\Types\BinaryType;
use App\Domain\Habit\UnknownHabitType;
use App\Domain\Habit\UnsupportedOperation;
use App\Domain\Period\PeriodEngine;
use App\Domain\Period\PeriodStatus;
use Tests\Support\DomainFixtures as F;
use Tests\Support\FakeChecklistType;

/** contract-fixtures/domain/progress.json (the server half; the app runs the same file). */
function types(): HabitTypeRegistry
{
    return HabitTypeRegistry::withBuiltins();
}

function isCompleteWire(string $type, mixed $value, mixed $target): bool
{
    return types()->get($type)->isComplete(new LogState(types()->get($type)->parseValue($value)), F::definition($type, $target, types()));
}

it('reproduces Today 3/5, then 4/5 after meditation', function () {
    $fixture = F::load('progress');
    $count = fn (array $habits) => [
        count(array_filter($habits, fn ($h) => isCompleteWire($h['type'], $h['value'], $h['target']))),
        count($habits),
    ];

    expect($count($fixture['today']['habits']))->toBe([$fixture['today']['expect']['complete'], $fixture['today']['expect']['total']]);

    $after = array_map(fn ($h) => array_key_exists($h['id'], $fixture['after']['changes'])
        ? [...$h, 'value' => $fixture['after']['changes'][$h['id']]] : $h, $fixture['today']['habits']);
    expect($count($after))->toBe([$fixture['after']['expect']['complete'], $fixture['after']['expect']['total']]);
});

it('applies log operations with exact values', function (array $case) {
    $type = types()->get($case['type']);
    $definition = F::definition($case['type'], $case['target'], types());
    $current = new LogState($type->parseValue($case['value']));

    $result = array_key_exists('increment', $case)
        ? $type->apply('log.increment', $current, $case['increment'], $definition)
        : $type->apply('log.set_value', $current, $case['set'], $definition);

    expect($type->formatValue($result->value))->toBe($case['result'])
        ->and($type->isComplete($result, $definition))->toBe($case['complete']);
})->with(fn () => F::named(F::load('progress')['values']));

it('rejects malformed values', function (array $case) {
    expect(fn () => types()->get($case['type'])->parseValue($case['value']))->toThrow(InvalidHabitValue::class);
})->with(function () {
    $out = [];
    foreach (F::load('progress')['invalid_values'] as $case) {
        $out["{$case['type']}: {$case['reason']}"] = [$case];
    }

    return $out;
});

it('registers exactly the three spec types', function () {
    expect(types()->keys())->toBe(['binary', 'quantity', 'duration']);
});

it('rejects unknown types and duplicate registration', function () {
    expect(fn () => types()->get('checklist'))->toThrow(UnknownHabitType::class)
        ->and(types()->has('checklist'))->toBeFalse()
        ->and(fn () => types()->register(new BinaryType))->toThrow(InvalidArgumentException::class);
});

it('lists canonical operations only (A27)', function (string $type, array $operations) {
    expect(types()->get($type)->operations())->toBe($operations);
})->with([
    ['binary', ['log.set_value']],
    ['quantity', ['log.set_value', 'log.increment']],
    ['duration', ['log.set_value', 'log.increment']],
]);

it('normalises spec aliases for their own type only (A27)', function (string $type, string $operation, ?string $canonical) {
    if ($canonical === null) {
        expect(fn () => types()->canonicalOperation($type, $operation))->toThrow(UnsupportedOperation::class);

        return;
    }
    expect(types()->canonicalOperation($type, $operation))->toBe($canonical);
})->with([
    'binary canonical' => ['binary', 'log.set_value', 'log.set_value'],
    'binary alias' => ['binary', 'log.set_binary', 'log.set_value'],
    'quantity alias' => ['quantity', 'log.increment_quantity', 'log.increment'],
    'duration alias' => ['duration', 'log.increment_duration', 'log.increment'],
    'binary has no increment' => ['binary', 'log.increment', null],
    'binary alias on quantity' => ['quantity', 'log.set_binary', null],
    'duration alias on quantity' => ['quantity', 'log.increment_duration', null],
    'quantity alias on duration' => ['duration', 'log.increment_quantity', null],
    'quantity alias on binary' => ['binary', 'log.increment_quantity', null],
    'no checklist items on built-ins' => ['duration', 'log.set_item', null],
    'unknown operation' => ['quantity', 'log.explode', null],
]);

it('rejects operations a type does not support, even if called directly', function (string $type, string $operation) {
    $definition = F::definition($type, $type === 'quantity' ? '1.000' : 1, types());

    expect(fn () => types()->get($type)->apply($operation, LogState::empty(), 1, $definition))->toThrow(UnsupportedOperation::class);
})->with([
    ['binary', 'log.increment'],
    ['binary', 'log.set_binary'],
    ['quantity', 'log.increment_quantity'],
    ['duration', 'log.set_item'],
]);

it('enforces target rules', function (string $type, mixed $target) {
    expect(fn () => types()->get($type)->parseTarget($target))->toThrow(InvalidHabitValue::class);
})->with([
    'binary target is fixed at 1' => ['binary', 0],
    'zero quantity' => ['quantity', '0.000'],
    'zero duration (design 24)' => ['duration', 0],
]);

it('requires positive increments', function (string $type, mixed $delta) {
    $definition = F::definition($type, $type === 'quantity' ? '1.000' : 1, types());

    expect(fn () => types()->get($type)->apply('log.increment', LogState::empty(), $delta, $definition))->toThrow(InvalidHabitValue::class);
})->with([['quantity', '0.000'], ['duration', 0]]);

it('round-trips quantity wire values', function (string $wire, string $canonical) {
    $type = types()->get('quantity');

    expect($type->formatValue($type->parseValue($wire)))->toBe($canonical);
})->with([['250', '250.000'], ['0.5', '0.500'], ['1.25', '1.250'], ['999999999.999', '999999999.999'], ['0', '0.000']]);

it('every type declares its strategy completely', function (HabitType $type) {
    expect($type->operations())->toContain('log.set_value');
    foreach ($type->operationAliases() as $canonical) {
        expect($type->operations())->toContain($canonical);
    }
})->with(fn () => array_map(fn ($k) => [types()->get($k)], types()->keys()));

it('fits a non-scalar type (checklist) without engine changes (R2, A21)', function () {
    $types = HabitTypeRegistry::withBuiltins();
    $types->register(new FakeChecklistType);
    $definition = new DefinitionVersion(1, LocalDate::fromString('2026-05-01'), 'checklist', 3, null, 'health', Frequency::daily(), ['items' => ['a', 'b', 'c']]);
    $schedule = new HabitSchedule('01970000-0000-7000-8000-0000000000ff', [$definition], [new ActiveRange(LocalDate::fromString('2026-05-01'))]);

    $op = $types->canonicalOperation('checklist', 'log.set_item');
    $type = $types->get('checklist');
    $day1 = LogState::empty();
    foreach (['a', 'b', 'c'] as $item) {
        $day1 = $type->apply($op, $day1, ['item_id' => $item, 'done' => true], $definition);
    }
    $day2 = $type->apply($op, LogState::empty(), ['item_id' => 'a', 'done' => true], $definition);
    $day2 = $type->apply($op, $day2, ['item_id' => 'b', 'done' => true], $definition);
    $day2 = $type->apply($op, $day2, ['item_id' => 'b', 'done' => false], $definition);

    $engine = new PeriodEngine($types);
    $periods = $engine->periods($schedule, LocalDate::fromString('2026-05-01'), LocalDate::fromString('2026-05-02'));
    $statuses = array_map(fn ($e) => $e->status, $engine->evaluate($periods, ['2026-05-01' => $day1, '2026-05-02' => $day2], LocalDate::fromString('2026-05-03')));

    expect([$day1->value, $day2->value])->toBe([3, 1])
        ->and($day2->detail)->toBe(['items' => ['a' => true, 'b' => false]])
        ->and($statuses)->toBe([PeriodStatus::Complete, PeriodStatus::Missed])
        ->and(fn () => $type->apply($op, $day1, ['item_id' => 'zzz', 'done' => true], $definition))->toThrow(InvalidHabitValue::class);
});

it('serialises frequencies canonically and round-trips them (S3)', function (string $type, array $config, array $canonical) {
    $frequency = Frequency::fromArray($type, $config);

    expect($frequency->toArray())->toBe($canonical)
        ->and(Frequency::fromArray($type, $frequency->toArray())->toArray())->toBe($canonical);
})->with([
    'daily drops unknown keys' => ['daily', ['junk' => 1], []],
    'weekdays sorted' => ['weekdays', ['days' => [5, 1, 3], 'extra' => 'x'], ['days' => [1, 3, 5]]],
    'weekly count' => ['weekly_count', ['count' => 3, 'pad' => [1, 2]], ['count' => 3]],
    'interval' => ['interval', ['anchor_date' => '2026-05-01', 'every_n_days' => 2], ['every_n_days' => 2, 'anchor_date' => '2026-05-01']],
]);
