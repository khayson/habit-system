<?php

use App\Domain\Habit\HabitType;
use App\Domain\Habit\HabitTypeRegistry;
use App\Domain\Habit\InvalidHabitValue;
use App\Domain\Habit\Types\BinaryType;
use App\Domain\Habit\UnknownHabitType;
use App\Domain\Habit\UnsupportedOperation;
use Tests\Support\DomainFixtures as F;

/** contract-fixtures/domain/progress.json (the server half; the app runs the same file). */
function types(): HabitTypeRegistry
{
    return HabitTypeRegistry::withBuiltins();
}

it('reproduces Today 3/5, then 4/5 after meditation', function () {
    $fixture = F::load('progress');
    $count = function (array $habits) {
        $complete = 0;
        foreach ($habits as $h) {
            $type = types()->get($h['type']);
            $complete += $type->isComplete($type->parseValue($h['value']), $type->parseTarget($h['target'])) ? 1 : 0;
        }

        return [$complete, count($habits)];
    };

    expect($count($fixture['today']['habits']))->toBe([$fixture['today']['expect']['complete'], $fixture['today']['expect']['total']]);

    $after = array_map(fn ($h) => array_key_exists($h['id'], $fixture['after']['changes'])
        ? [...$h, 'value' => $fixture['after']['changes'][$h['id']]] : $h, $fixture['today']['habits']);
    expect($count($after))->toBe([$fixture['after']['expect']['complete'], $fixture['after']['expect']['total']]);
});

it('applies log operations with exact values', function (array $case) {
    $type = types()->get($case['type']);
    $current = $type->parseValue($case['value']);

    $result = array_key_exists('increment', $case)
        ? $type->apply("log.increment_{$case['type']}", $current, $case['increment'])
        : $type->apply('log.set_binary', $current, $case['set']);

    expect($type->formatValue($result))->toBe($case['result'])
        ->and($type->isComplete($result, $type->parseTarget($case['target'])))->toBe($case['complete']);
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

it('rejects operations a type does not support', function (string $type, string $operation) {
    expect(fn () => types()->get($type)->apply($operation, 0, 1))->toThrow(UnsupportedOperation::class);
})->with([
    ['binary', 'log.increment'],
    ['binary', 'log.increment_quantity'],
    ['quantity', 'log.set_binary'],
    ['quantity', 'log.increment_duration'],
    ['duration', 'log.increment_quantity'],
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
    $op = $type === 'quantity' ? 'log.increment_quantity' : 'log.increment_duration';
    expect(fn () => types()->get($type)->apply($op, 0, $delta))->toThrow(InvalidHabitValue::class);
})->with([['quantity', '0.000'], ['duration', 0]]);

it('round-trips quantity wire values', function (string $wire, string $canonical) {
    $type = types()->get('quantity');

    expect($type->formatValue($type->parseValue($wire)))->toBe($canonical);
})->with([['250', '250.000'], ['0.5', '0.500'], ['1.25', '1.250'], ['999999999.999', '999999999.999'], ['0', '0.000']]);

it('every type declares its strategy completely', function (HabitType $type) {
    expect($type->operations())->not->toBeEmpty()
        ->and($type->operations())->toContain('log.set_value');
})->with(fn () => array_map(fn ($k) => [types()->get($k)], types()->keys()));
