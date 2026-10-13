<?php

use Illuminate\Support\Facades\DB;
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

    if ($expected === '{{cursor_or_null}}' && $actual === null) {
        // A last page has no next cursor.
        return;
    }

    if (is_string($expected) && preg_match('/^\{\{(\w+)\}\}$/', $expected, $m)) {
        $pattern = match ($m[1]) {
            'uuid' => UUID_PATTERN,
            'timestamp', 'time' => UTC_TIMESTAMP_PATTERN,
            'int' => '/^[1-9]\d*$/',
            'date' => '/^\d{4}-\d{2}-\d{2}$/',
            'cursor', 'cursor_or_null' => CURSOR_PATTERN,
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

/**
 * Invariant 7 (A39 to A41): the cached reward numbers are reconstructable from the append-only
 * ledgers, each entitlement's ledger nets to its state with one row per revision, every usage
 * points at its ledger rows, and the latest journaled reward_state carries the cached numbers at
 * reward_version.
 */
function assertLedgersMatchCaches(string $userId): void
{
    $db = DB::table(...);
    $user = $db('users')->where('id', $userId)->sole();
    expect((int) $user->xp)->toBe((int) $db('xp_ledger')->where('user_id', $userId)->sum('delta'), 'xp = sum(xp_ledger)')
        ->and((int) $user->freeze_balance)->toBe((int) $db('freeze_ledger')->where('user_id', $userId)->sum('delta'), 'freeze_balance = sum(freeze_ledger)')
        ->and((int) $user->freeze_balance)->toBeGreaterThanOrEqual(0)->toBeLessThanOrEqual(2);

    foreach ($db('xp_entitlements')->where('user_id', $userId)->get() as $e) {
        $rows = $db('xp_ledger')->where('entitlement_id', $e->id)->orderBy('entitlement_revision')->get();
        expect((int) $rows->sum('delta'))->toBe($e->state === 'active' ? 10 : 0, "entitlement {$e->log_date} nets to its state")
            ->and($rows->pluck('entitlement_revision')->map(fn ($r) => (int) $r)->all())->toBe(range(1, (int) $e->revision), 'one row per revision');
    }
    foreach ($db('freeze_usage')->where('user_id', $userId)->get() as $u) {
        expect($db('freeze_ledger')->where('id', $u->spend_ledger_id)->value('kind'))->toBe('spend');
        if ($u->state === 'refunded') {
            expect($db('freeze_ledger')->where('id', $u->refund_ledger_id)->value('kind'))->toBe('refund');
        }
    }

    $journaled = $db('server_changes')->where('user_id', $userId)->where('entity_type', 'reward_state')->orderByDesc('seq')->first();
    if ((int) $user->reward_version === 0) {
        expect($journaled)->toBeNull();

        return;
    }
    $payload = json_decode((string) $journaled->payload, true, flags: JSON_THROW_ON_ERROR);
    expect((int) $journaled->version)->toBe((int) $user->reward_version)
        ->and($payload['xp'])->toBe((int) $user->xp)
        ->and($payload['freeze_balance'])->toBe((int) $user->freeze_balance);
}
