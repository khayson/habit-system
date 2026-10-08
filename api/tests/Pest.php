<?php

use PHPUnit\Framework\Assert;
use Tests\TestCase;

pest()->extend(TestCase::class)->in('Feature');

const UUID_PATTERN = '/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/';
const UUID_V7_PATTERN = '/^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/';
const UTC_TIMESTAMP_PATTERN = '/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/';

/** A signed sync cursor: base64url payload, a dot, base64url signature. */
const CURSOR_PATTERN = '/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/';

function contractFixturePath(string $relative = ''): string
{
    return dirname(__DIR__, 2).'/contract-fixtures'.($relative === '' ? '' : '/'.$relative);
}

/**
 * @return array<string, mixed>
 */
function contractFixture(string $relative): array
{
    $json = file_get_contents(contractFixturePath($relative));
    Assert::assertIsString($json, "Missing fixture {$relative}");

    return json_decode($json, true, flags: JSON_THROW_ON_ERROR);
}

/**
 * Asserts $actual equals $expected, where placeholder strings in $expected match by format.
 * Keys must match exactly: no missing and no extra keys at any level.
 */
function assertMatchesContract(mixed $expected, mixed $actual, string $path = '$'): void
{
    if ($expected === '{{seq}}') {
        // A journal position: a non-negative JSON integer.
        Assert::assertIsInt($actual, "{$path} should be an integer");
        Assert::assertGreaterThanOrEqual(0, $actual, "{$path} must not be negative");

        return;
    }

    if (is_string($expected) && preg_match('/^\{\{(\w+)\}\}$/', $expected, $m)) {
        $pattern = match ($m[1]) {
            'uuid' => UUID_PATTERN,
            'timestamp' => UTC_TIMESTAMP_PATTERN,
            'int' => '/^[1-9]\d*$/',
            'cursor' => CURSOR_PATTERN,
            default => throw new InvalidArgumentException("Unknown placeholder {$expected} at {$path}"),
        };
        Assert::assertIsString($actual, "{$path} should be a string");
        Assert::assertMatchesRegularExpression($pattern, $actual, "{$path} format");

        return;
    }

    if (is_array($expected)) {
        Assert::assertIsArray($actual, "{$path} should be an object/array");
        Assert::assertEqualsCanonicalizing(array_keys($expected), array_keys($actual), "{$path} keys");
        foreach ($expected as $key => $value) {
            assertMatchesContract($value, $actual[$key], "{$path}.{$key}");
        }

        return;
    }

    Assert::assertSame($expected, $actual, $path);
}

/** @return array<string, mixed> a contract-fixtures/sync file */
function syncFixtureFile(string $name): array
{
    return json_decode((string) file_get_contents(contractFixturePath("sync/{$name}.json")), true, flags: JSON_THROW_ON_ERROR);
}
