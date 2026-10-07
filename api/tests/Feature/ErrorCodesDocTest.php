<?php

use App\Exceptions\ApiExceptionRenderer;
use App\Exceptions\DomainErrorMapper;

/*
 * docs/api-error-codes.md is contract. Its "Active codes" table, the golden fixtures and the
 * renderer must agree.
 */

/**
 * @return array<string, array{status: string, fixture: string}>
 */
function documentedActiveCodes(): array
{
    $doc = (string) file_get_contents(dirname(__DIR__, 3).'/docs/api-error-codes.md');
    $section = explode('## Reserved codes', explode('## Active codes', $doc)[1])[0];
    preg_match_all('/^\| `([a-z_]+)` \| ([^|]+) \|.*\| `([a-z0-9_]+\.json)` \|$/m', $section, $m, PREG_SET_ORDER);

    $codes = [];
    foreach ($m as [, $code, $status, $fixture]) {
        $codes[$code] = ['status' => trim($status), 'fixture' => $fixture];
    }

    return $codes;
}

/**
 * @return array<string, array{code: string, status: int}>
 */
function errorFixtures(): array
{
    $fixtures = [];
    foreach (glob(contractFixturePath('envelope/error_*.json')) ?: [] as $path) {
        $fixture = json_decode((string) file_get_contents($path), true, flags: JSON_THROW_ON_ERROR);
        $fixtures[basename($path)] = ['code' => $fixture['body']['error']['code'], 'status' => $fixture['status']];
    }

    return $fixtures;
}

it('documents every error fixture, and every documented code has its fixture', function () {
    $doc = documentedActiveCodes();
    $fixtures = errorFixtures();

    expect($doc)->not->toBeEmpty();
    expect(array_column($doc, 'fixture'))->toEqualCanonicalizing(array_keys($fixtures));

    foreach ($doc as $code => $row) {
        expect($fixtures[$row['fixture']]['code'])->toBe($code, "{$row['fixture']} code");
        expect($row['status'])->toContain((string) $fixtures[$row['fixture']]['status']);
    }
});

it('has one fixture per code', function () {
    $codes = array_column(errorFixtures(), 'code');

    expect($codes)->toBe(array_values(array_unique($codes)));
});

it('documents every code the renderer can emit', function () {
    $renderer = new ReflectionClassConstant(ApiExceptionRenderer::class, 'HTTP_CODES');
    $emitted = array_merge(
        array_column($renderer->getValue(), 0),
        array_keys(DomainErrorMapper::CODES),
        ['validation_failed', 'server_error', 'http_error', 'version_conflict', 'idempotency_mismatch', 'resource_deleted', 'cursor_expired'],
    );

    expect(array_diff($emitted, array_keys(documentedActiveCodes())))->toBe([]);
});
