<?php

use App\Application\Admin\Totp;

/*
 * A58: the one-time codes match RFC 6238's SHA-1 test vectors (the last six digits), so any
 * authenticator app agrees with the server.
 */

// RFC 6238, appendix B: the ASCII secret "12345678901234567890" in base32.
const RFC_SECRET = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

it('matches the RFC 6238 vectors', function (int $time, string $code) {
    expect(Totp::code(RFC_SECRET, intdiv($time, 30)))->toBe($code);
})->with([
    [59, '287082'],
    [1111111109, '081804'],
    [1111111111, '050471'],
    [1234567890, '005924'],
    [2000000000, '279037'],
]);

it('accepts one step of drift either way and nothing further', function () {
    $now = 1_234_567_890;
    $step = intdiv($now, 30);
    expect(Totp::matchStep(RFC_SECRET, Totp::code(RFC_SECRET, $step - 1), $now))->toBe($step - 1)
        ->and(Totp::matchStep(RFC_SECRET, Totp::code(RFC_SECRET, $step + 1), $now))->toBe($step + 1)
        ->and(Totp::matchStep(RFC_SECRET, Totp::code(RFC_SECRET, $step - 2), $now))->toBeNull()
        ->and(Totp::matchStep(RFC_SECRET, '12345', $now))->toBeNull()
        ->and(Totp::matchStep(RFC_SECRET, 'abcdef', $now))->toBeNull();
});

it('makes a fresh 32-character base32 secret and an otpauth link', function () {
    $secret = Totp::newSecret();
    expect($secret)->toMatch('/^[A-Z2-7]{32}$/')
        ->and(Totp::uri($secret, 'me@example.test'))->toStartWith('otpauth://totp/')->toContain("secret={$secret}");
});
