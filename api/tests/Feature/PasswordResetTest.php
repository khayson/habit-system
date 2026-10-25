<?php

use App\Application\Accounts\ResetCodeHasher;
use App\Mail\PasswordResetCodeMail;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Queue;
use Illuminate\Testing\TestResponse;

uses(RefreshDatabase::class);

/*
 * A50: POST /auth/forgot-password and POST /auth/reset-password, against
 * contract-fixtures/auth/forgot_password.json and reset_password.json. Mail is faked; the email
 * is sent after the response, which the test client runs on terminate.
 */

beforeEach(function () {
    Mail::fake();
    $this->freezeClock('2026-05-28T17:22:00Z');
    config(['api.rate_limits.password_reset_per_hour_per_email' => 1000, 'api.rate_limits.password_reset_per_hour_per_ip' => 1000]);
    $this->maya = $this->registerUser('Maya Chen', 'maya.chen@example.com');
});

/** Counts every code hash, so the unknown-email path can be shown to do the same work. */
final class CountingHasher extends ResetCodeHasher
{
    public int $calls = 0;

    public function hash(string $code): string
    {
        $this->calls++;

        return parent::hash($code);
    }
}

function forgot(object $test, string $email): TestResponse
{
    app('auth')->forgetGuards();
    $test->flushHeaders();

    return $test->postJson('/api/v1/auth/forgot-password', ['email' => $email]);
}

function resetWith(object $test, string $email, string $code, string $password = 'a-new-12-plus-character-password', ?string $confirm = null): TestResponse
{
    app('auth')->forgetGuards();
    $test->flushHeaders();

    return $test->postJson('/api/v1/auth/reset-password', [
        'email' => $email, 'reset_token' => $code, 'password' => $password, 'password_confirmation' => $confirm ?? $password,
    ]);
}

/** The code in the last mail sent to $email. */
function sentCode(string $email): string
{
    $mails = Mail::sent(PasswordResetCodeMail::class, fn (PasswordResetCodeMail $m) => $m->hasTo($email));
    expect($mails)->not->toBeEmpty();

    return $mails->last()->code;
}

function assertInvalidCode(TestResponse $response): void
{
    $fixture = contractFixture('auth/reset_password.json')['invalid_code'];
    $response->assertStatus($fixture['status']);
    assertMatchesContract($fixture['body'], $response->json());
}

function bodyWithoutMeta(TestResponse $response): array
{
    return ['status' => $response->status(), 'data' => $response->json('data')];
}

it('answers every email with the same 202 and emails a code only to a live account outside its cooldown', function () {
    $fixture = contractFixture('auth/forgot_password.json');
    $sam = $this->registerUser('Sam', 'sam@example.com');
    Queue::fake();
    app('auth')->forgetGuards();
    $this->withToken($sam['token'])->deleteJson('/api/v1/me', ['password' => 'correct horse battery staple'])->assertStatus(202);

    $known = forgot($this, $fixture['request']['email']);
    $cooled = forgot($this, $fixture['request']['email']);
    $unknown = forgot($this, 'nobody@example.com');
    $deleted = forgot($this, 'sam@example.com');

    $known->assertStatus($fixture['accepted']['status']);
    assertMatchesContract($fixture['accepted']['body'], $known->json());
    expect(bodyWithoutMeta($cooled))->toBe(bodyWithoutMeta($known))
        ->and(bodyWithoutMeta($unknown))->toBe(bodyWithoutMeta($known))
        ->and(bodyWithoutMeta($deleted))->toBe(bodyWithoutMeta($known));
    Mail::assertSentCount(1);
    expect(sentCode('maya.chen@example.com'))->toMatch('/^\d{6}$/');
});

it('stores only an HMAC of the code, valid for 15 minutes', function () {
    forgot($this, 'maya.chen@example.com');
    $code = sentCode('maya.chen@example.com');
    $row = DB::table('password_reset_codes')->first();

    expect($row->code_hash)->toBe(hash_hmac('sha256', $code, (string) config('app.key')))
        ->and($row->code_hash)->not->toContain($code)
        ->and(substr((string) $row->expires_at, 0, 16))->toBe('2026-05-28 17:37');
});

it('keeps the first code during the 60-second cooldown and replaces it after', function () {
    forgot($this, 'maya.chen@example.com');
    $first = sentCode('maya.chen@example.com');
    $this->freezeClock('2026-05-28T17:22:59Z');
    forgot($this, 'maya.chen@example.com');
    Mail::assertSentCount(1);

    $this->freezeClock('2026-05-28T17:23:00Z');
    forgot($this, 'maya.chen@example.com');
    Mail::assertSentCount(2);
    $second = sentCode('maya.chen@example.com');
    if ($second !== $first) {
        assertInvalidCode(resetWith($this, 'maya.chen@example.com', $first));
    }
    resetWith($this, 'maya.chen@example.com', $second)->assertNoContent();
});

it('accepts a code inside the cooldown window', function () {
    forgot($this, 'maya.chen@example.com');
    $first = sentCode('maya.chen@example.com');
    $this->freezeClock('2026-05-28T17:22:30Z');
    forgot($this, 'maya.chen@example.com');
    resetWith($this, 'maya.chen@example.com', $first)->assertNoContent();
});

it('does the same hashing work for an unknown email on both routes', function () {
    $hasher = new CountingHasher;
    app()->instance(ResetCodeHasher::class, $hasher);

    forgot($this, 'nobody@example.com')->assertStatus(202);
    expect($hasher->calls)->toBe(1);
    assertInvalidCode(resetWith($this, 'nobody@example.com', '123456'));
    expect($hasher->calls)->toBe(2);
    Mail::assertNothingSent();
});

it('resets: 204 with no body, every session revoked, the new password signs in and the old one does not', function () {
    $fixture = contractFixture('auth/reset_password.json');
    $other = $this->postJson('/api/v1/auth/login', ['email' => 'maya.chen@example.com', 'password' => 'correct horse battery staple', 'device_name' => 'tablet'])->json('data.token');
    forgot($this, 'maya.chen@example.com');

    $response = resetWith($this, $fixture['request']['email'], sentCode('maya.chen@example.com'), $fixture['request']['password']);

    $response->assertStatus($fixture['reset']['status']);
    expect($response->getContent())->toBe('')
        ->and(DB::table('personal_access_tokens')->where('tokenable_id', $this->maya['id'])->count())->toBe(0);
    foreach ([$this->maya['token'], $other] as $token) {
        app('auth')->forgetGuards();
        $this->withToken($token)->getJson('/api/v1/me')->assertUnauthorized();
        app('auth')->forgetGuards();
        $this->sync($token)->assertUnauthorized();
    }
    app('auth')->forgetGuards();
    $this->flushHeaders();
    $this->postJson('/api/v1/auth/login', ['email' => 'maya.chen@example.com', 'password' => $fixture['request']['password'], 'device_name' => 'phone'])->assertOk();
    $this->postJson('/api/v1/auth/login', ['email' => 'maya.chen@example.com', 'password' => 'correct horse battery staple', 'device_name' => 'phone'])->assertStatus(422);
});

it('counts wrong tries: four wrong then the right code works', function () {
    forgot($this, 'maya.chen@example.com');
    $code = sentCode('maya.chen@example.com');
    $wrong = $code === '000000' ? '000001' : '000000';
    foreach (range(1, 4) as $_) {
        assertInvalidCode(resetWith($this, 'maya.chen@example.com', $wrong));
    }
    expect((int) DB::table('password_reset_codes')->value('attempts'))->toBe(4);
    resetWith($this, 'maya.chen@example.com', $code)->assertNoContent();
});

it('counts wrong tries: the fifth wrong makes the right code fail', function () {
    forgot($this, 'maya.chen@example.com');
    $code = sentCode('maya.chen@example.com');
    $wrong = $code === '000000' ? '000001' : '000000';
    foreach (range(1, 5) as $_) {
        assertInvalidCode(resetWith($this, 'maya.chen@example.com', $wrong));
    }
    assertInvalidCode(resetWith($this, 'maya.chen@example.com', $code));
});

it('refuses an expired code, a used code and another account\'s code', function () {
    $this->registerUser('Sam', 'sam@example.com');
    forgot($this, 'maya.chen@example.com');
    forgot($this, 'sam@example.com');
    $mayaCode = sentCode('maya.chen@example.com');
    $samCode = sentCode('sam@example.com');

    if ($samCode !== $mayaCode) {
        assertInvalidCode(resetWith($this, 'maya.chen@example.com', $samCode));
    }
    $this->freezeClock('2026-05-28T17:37:00Z');
    assertInvalidCode(resetWith($this, 'sam@example.com', $samCode));

    $this->freezeClock('2026-05-28T17:36:59Z');
    resetWith($this, 'maya.chen@example.com', $mayaCode)->assertNoContent();
    assertInvalidCode(resetWith($this, 'maya.chen@example.com', $mayaCode, 'yet-another-long-password'));
});

it('applies registration\'s password rules: short, mismatched, compromised', function () {
    $fixture = contractFixture('auth/reset_password.json')['weak_password'];
    forgot($this, 'maya.chen@example.com');
    $code = sentCode('maya.chen@example.com');

    $short = resetWith($this, 'maya.chen@example.com', $code, 'too-short');
    $short->assertStatus($fixture['status']);
    assertMatchesContract($fixture['body'], $short->json());
    resetWith($this, 'maya.chen@example.com', $code, 'a-new-12-plus-character-password', 'a-different-12-character-one')
        ->assertStatus(422)->assertJsonStructure(['error' => ['fields' => ['password']]]);

    config(['auth.password_breach_check' => true]);
    $breached = 'password12345678';
    $sha1 = strtoupper(sha1($breached));
    Http::fake(['api.pwnedpasswords.com/range/'.substr($sha1, 0, 5) => Http::response(substr($sha1, 5).":12345\r\nAAAA:1", 200)]);
    resetWith($this, 'maya.chen@example.com', $code, $breached)->assertStatus(422)->assertJsonStructure(['error' => ['fields' => ['password']]]);

    // Rejected passwords cost no try: the code still works.
    expect((int) DB::table('password_reset_codes')->value('attempts'))->toBe(0);
    config(['auth.password_breach_check' => false]);
    resetWith($this, 'maya.chen@example.com', $code)->assertNoContent();
});

it('sends a plain email: the code, its 15 minutes, the reassurance, and no link', function () {
    forgot($this, 'maya.chen@example.com');
    $mail = Mail::sent(PasswordResetCodeMail::class)->last();
    $html = $mail->render();
    $text = view('mail.reset-code-text', ['code' => $mail->code])->render();

    foreach ([$html, $text] as $body) {
        expect($body)->toContain($mail->code)
            ->toContain('It expires in 15 minutes.')
            ->toContain('If you did not ask for this, you can ignore this email; your password has not changed.')
            ->not->toContain('http')
            ->not->toContain('href');
    }
});

// 6.4 review L1: a ceiling on guessing over days. Ten wrong tries in a rolling 24 hours stop
// new codes for that account (the same 202) until the first of them is 24 hours old.
it('stops new codes after ten wrong tries in 24 hours, until the first of them ages out', function () {
    $wrongTries = function (int $n) {
        forgot($this, 'maya.chen@example.com');
        $code = sentCode('maya.chen@example.com');
        $wrong = $code === '000000' ? '000001' : '000000';
        foreach (range(1, $n) as $_) {
            assertInvalidCode(resetWith($this, 'maya.chen@example.com', $wrong));
        }
    };
    $wrongTries(5);
    $this->freezeClock('2026-05-28T17:30:00Z');
    $wrongTries(4);
    $this->freezeClock('2026-05-28T17:40:00Z');
    $wrongTries(1);
    expect(DB::table('password_reset_failures')->count())->toBe(10);

    $this->freezeClock('2026-05-28T18:00:00Z');
    $sent = Mail::sent(PasswordResetCodeMail::class)->count();
    $blocked = forgot($this, 'maya.chen@example.com');
    $unknown = forgot($this, 'nobody@example.com');
    expect(bodyWithoutMeta($blocked))->toBe(bodyWithoutMeta($unknown))
        ->and(Mail::sent(PasswordResetCodeMail::class)->count())->toBe($sent);

    $this->freezeClock('2026-05-29T17:21:59Z');
    forgot($this, 'maya.chen@example.com');
    expect(Mail::sent(PasswordResetCodeMail::class)->count())->toBe($sent);

    // The first wrong try (17:22 on the 28th) is 24 hours old: nine remain, codes flow again.
    $this->freezeClock('2026-05-29T17:22:01Z');
    forgot($this, 'maya.chen@example.com');
    expect(Mail::sent(PasswordResetCodeMail::class)->count())->toBe($sent + 1);
});
