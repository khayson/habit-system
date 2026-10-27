<?php

use App\Application\Admin\EmailCampaigns;
use App\Application\Admin\Totp;
use App\Jobs\PurgeAccountJob;
use App\Mail\AnnouncementMail;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * A58: Khay Studios' admin page. Sign-in by email, password and a one-time code; account
 * details and actions without ever showing habit data; notices; an audit of every action.
 */

const ADMIN_EMAIL = 'admin@example.test';
const ADMIN_PASSWORD = 'a long admin password for tests';

function configureAdmin(): string
{
    $secret = Totp::newSecret();
    config([
        'admin.email' => ADMIN_EMAIL,
        'admin.password_hash' => Hash::make(ADMIN_PASSWORD),
        'admin.totp_secret' => $secret,
    ]);
    Cache::forget('admin:totp:last-step');

    return $secret;
}

/** The code an authenticator shows at the frozen clock's time. */
function adminCode(string $secret, string $at): string
{
    return Totp::code($secret, intdiv((int) strtotime($at), Totp::STEP));
}

function adminSignIn(object $test, string $secret, string $at = '2026-10-26T10:00:00Z'): void
{
    $test->freezeClock($at);
    $test->post('/admin/login', ['email' => ADMIN_EMAIL, 'password' => ADMIN_PASSWORD, 'code' => adminCode($secret, $at)])
        ->assertRedirect('/admin');
}

it('is a plain 404 everywhere until all three settings exist', function () {
    config(['admin.email' => '', 'admin.password_hash' => '', 'admin.totp_secret' => '']);
    $this->get('/admin/login')->assertNotFound();
    $this->get('/admin')->assertNotFound();
    $this->post('/admin/login', ['email' => 'x', 'password' => 'y', 'code' => '123456'])->assertNotFound();
});

it('sends a visitor to sign-in, with strict headers and a CSRF token on the form', function () {
    configureAdmin();
    $this->get('/admin')->assertRedirect('/admin/login');
    $this->get('/admin/accounts')->assertRedirect('/admin/login');

    $page = $this->get('/admin/login')->assertOk();
    $page->assertHeader('X-Frame-Options', 'DENY')->assertHeader('Cache-Control', 'no-store, private')
        ->assertSee('name="_token"', false);
    expect($page->headers->get('Content-Security-Policy'))->toContain("default-src 'none'")->toContain("frame-ancestors 'none'");
    $cookie = collect($page->headers->getCookies())->firstWhere(fn ($c) => $c->getName() === 'habit_admin');
    expect($cookie?->getPath())->toBe('/admin')
        ->and($cookie?->isHttpOnly())->toBeTrue()
        ->and($cookie?->getSameSite())->toBe('strict');
});

it('refuses a wrong email, password or code with one neutral answer; the right three sign in', function (array $wrong) {
    $secret = configureAdmin();
    $this->freezeClock('2026-10-26T10:00:00Z');
    $good = ['email' => ADMIN_EMAIL, 'password' => ADMIN_PASSWORD, 'code' => adminCode($secret, '2026-10-26T10:00:00Z')];

    $this->from('/admin/login')->post('/admin/login', [...$good, ...$wrong])
        ->assertRedirect('/admin/login')->assertSessionHasErrors(['login' => 'Those details did not work.']);
    $this->get('/admin')->assertRedirect('/admin/login');
    expect(DB::table('admin_actions')->count())->toBe(0);
})->with([
    'email' => [['email' => 'someone@example.test']],
    'password' => [['password' => 'not the password']],
    'code' => [['code' => '000000']],
    'stale code' => [['code' => adminCode('JBSWY3DPEHPK3PXP', '2026-10-26T10:00:00Z')]],
]);

it('signs in, shows the system numbers and audits the sign-in', function () {
    $secret = configureAdmin();
    adminSignIn($this, $secret);

    $this->get('/admin')->assertOk()->assertSee('Live accounts')->assertSee('Run the timer now');
    expect(DB::table('admin_actions')->pluck('action')->all())->toBe(['admin.sign_in']);
});

it('never accepts the same code twice', function () {
    $secret = configureAdmin();
    adminSignIn($this, $secret);
    $this->post('/admin/logout')->assertRedirect('/admin/login');

    $this->from('/admin/login')->post('/admin/login', [
        'email' => ADMIN_EMAIL, 'password' => ADMIN_PASSWORD, 'code' => adminCode($secret, '2026-10-26T10:00:00Z'),
    ])->assertSessionHasErrors('login');
});

it('throttles sign-in tries per IP', function () {
    configureAdmin();
    $this->freezeClock('2026-10-26T10:00:00Z');
    foreach (range(1, 5) as $_) {
        $this->from('/admin/login')->post('/admin/login', ['email' => ADMIN_EMAIL, 'password' => 'wrong', 'code' => '000000']);
    }
    $this->from('/admin/login')->post('/admin/login', ['email' => ADMIN_EMAIL, 'password' => 'wrong', 'code' => '000000'])
        ->assertSessionHasErrors(['login' => 'Too many tries. Wait a minute, then try again.']);
});

it('ends the session after 30 minutes idle', function () {
    $secret = configureAdmin();
    adminSignIn($this, $secret);
    $this->freezeClock('2026-10-26T10:29:00Z');
    $this->get('/admin')->assertOk();
    $this->freezeClock('2026-10-26T11:00:00Z');
    $this->get('/admin')->assertRedirect('/admin/login');
});

it('lists and shows accounts without any habit data', function () {
    $secret = configureAdmin();
    $this->freezeClock('2026-05-28T17:22:00Z');
    $maya = $this->registerUser('Maya Chen', 'maya@example.test');
    $this->sync($maya['token'], [M::habitCreate((string) Str::uuid7(), overrides: ['name' => 'Secret morning swim'])])
        ->assertJsonPath('data.acks.0.status', 'accepted');
    adminSignIn($this, $secret);

    $this->get('/admin/accounts?q=maya')->assertOk()->assertSee('maya@example.test')->assertSee('active');
    $this->get('/admin/accounts?q=nobody')->assertOk()->assertDontSee('maya@example.test');
    $this->get("/admin/accounts/{$maya['id']}")->assertOk()
        ->assertSee('maya@example.test')->assertSee('America/Los_Angeles')
        ->assertDontSee('Secret morning swim');
    $this->get('/admin/accounts/not-a-uuid')->assertNotFound();
});

it('suspends: signed out, sign-in refused with account_suspended; resume lets them back', function () {
    $secret = configureAdmin();
    $maya = $this->registerUser('Maya Chen', 'maya@example.test');
    adminSignIn($this, $secret);

    $this->post("/admin/accounts/{$maya['id']}/suspend")->assertRedirect();
    app('auth')->forgetGuards();
    $this->withToken($maya['token'])->getJson('/api/v1/me')->assertUnauthorized();
    $login = ['email' => 'maya@example.test', 'password' => 'correct horse battery staple', 'device_name' => 'Pixel'];
    $fixture = contractFixture('envelope/error_403_account_suspended.json');
    $refused = $this->postJson('/api/v1/auth/login', $login)->assertStatus($fixture['status']);
    assertMatchesContract($fixture['body'], $refused->json());
    // A wrong password never reveals the suspension.
    $this->postJson('/api/v1/auth/login', [...$login, 'password' => 'wrong password here'])->assertStatus(422);

    $this->post("/admin/accounts/{$maya['id']}/resume")->assertRedirect();
    $this->postJson('/api/v1/auth/login', $login)->assertOk();
    expect(DB::table('admin_actions')->pluck('action')->all())->toContain('account.suspend', 'account.resume');
});

it('signs every device out and leaves the data alone', function () {
    $secret = configureAdmin();
    $this->freezeClock('2026-05-28T17:22:00Z');
    $maya = $this->registerUser('Maya Chen', 'maya@example.test');
    $this->sync($maya['token'], [M::habitCreate((string) Str::uuid7())])->assertJsonPath('data.acks.0.status', 'accepted');
    adminSignIn($this, $secret);

    $this->post("/admin/accounts/{$maya['id']}/sign-out")->assertRedirect();
    expect(DB::table('personal_access_tokens')->where('tokenable_id', $maya['id'])->count())->toBe(0)
        ->and(DB::table('habits')->where('user_id', $maya['id'])->count())->toBe(1);
});

it('deletes only after the email is typed exactly', function () {
    Queue::fake();
    $secret = configureAdmin();
    $maya = $this->registerUser('Maya Chen', 'maya@example.test');
    adminSignIn($this, $secret);

    $this->from("/admin/accounts/{$maya['id']}")
        ->post("/admin/accounts/{$maya['id']}/delete", ['confirm_email' => 'maya@example'])
        ->assertSessionHasErrors(['delete' => "Type the account's email exactly to delete it."]);
    expect(DB::table('account_deletions')->count())->toBe(0);

    $this->post("/admin/accounts/{$maya['id']}/delete", ['confirm_email' => 'Maya@Example.test'])->assertRedirect('/admin/accounts');
    expect(DB::table('account_deletions')->where('user_id', $maya['id'])->count())->toBe(1)
        ->and(DB::table('users')->where('id', $maya['id'])->value('deleted_at'))->not->toBeNull();
    Queue::assertPushed(PurgeAccountJob::class);
});

it('publishes a notice to one person from the form; only they see it', function () {
    $secret = configureAdmin();
    $maya = $this->registerUser('Maya Chen', 'maya@example.test');
    $kofi = $this->registerUser('Kofi', 'kofi@example.test');
    adminSignIn($this, $secret);

    $this->get('/admin/notices?to=maya%40example.test')->assertOk()->assertSee('maya@example.test');
    $this->post('/admin/notices', ['title' => 'Hello Maya', 'body' => 'Thanks for testing.', 'to' => "maya@example.test\n", 'ends' => '2026-11-01T09:00'])
        ->assertRedirect('/admin/notices');
    $this->from('/admin/notices')->post('/admin/notices', ['title' => '', 'body' => 'x'])
        ->assertSessionHasErrors(['notice' => 'The title needs 1 to 60 characters.']);

    app('auth')->forgetGuards();
    expect($this->withToken($maya['token'])->getJson('/api/v1/notices')->json('data.0.title'))->toBe('Hello Maya')
        ->and($this->withToken($maya['token'])->getJson('/api/v1/notices')->json('data.0.ends_at'))->toBe('2026-11-01T09:00:00Z');
    app('auth')->forgetGuards();
    expect($this->withToken($kofi['token'])->getJson('/api/v1/notices')->json('data'))->toBe([]);
    expect(DB::table('admin_actions')->pluck('action')->all())->toContain('notice.publish');
});

it('runs the timer from the page and audits it', function () {
    $secret = configureAdmin();
    adminSignIn($this, $secret);
    $this->from('/admin')->post('/admin/server/tick')->assertRedirect('/admin')->assertSessionHas('status');
    expect(DB::table('admin_actions')->pluck('action')->all())->toContain('server.tick');
});

it('never gives the API a session cookie', function () {
    configureAdmin();
    $response = $this->getJson('/api/v1/health')->assertOk();
    expect(collect($response->headers->getCookies())->map->getName()->all())->toBe([]);
});

it('a mangled password hash in the settings refuses sign-in calmly, never a server error', function (string $hash) {
    $secret = configureAdmin();
    config(['admin.password_hash' => $hash]);
    $this->freezeClock('2026-10-26T10:00:00Z');

    $this->from('/admin/login')->post('/admin/login', [
        'email' => ADMIN_EMAIL, 'password' => ADMIN_PASSWORD, 'code' => adminCode($secret, '2026-10-26T10:00:00Z'),
    ])->assertRedirect('/admin/login')->assertSessionHasErrors('login');
})->with([
    'prefix pasted too' => ['ADMIN_PASSWORD_HASH=$2y$12$abcdefghijklmnopqrstuuJ8m0p7Qm5bq8Zl0Yw1x2y3z4A5B6C7D'],
    'quoted' => ['"$2y$12$abcdefghijklmnopqrstuuJ8m0p7Qm5bq8Zl0Yw1x2y3z4A5B6C7D"'],
    'cut short' => ['$2y$12$abcdefghij'],
    'not a hash' => ['my password'],
]);

it('reads settings pasted with their "KEY=" prefix, quotes or spaces as meant', function () {
    $secret = Totp::newSecret();
    $hash = Hash::make(ADMIN_PASSWORD);
    $env = [
        'ADMIN_EMAIL' => ' ADMIN_EMAIL=Admin@Example.test ',
        'ADMIN_PASSWORD_HASH' => '"ADMIN_PASSWORD_HASH='.$hash.'"',
        'ADMIN_TOTP_SECRET' => "'".$secret."'",
    ];
    foreach ($env as $key => $value) {
        putenv("{$key}={$value}");
        $_ENV[$key] = $_SERVER[$key] = $value;
    }
    try {
        config(['admin' => require config_path('admin.php')]);
    } finally {
        foreach (array_keys($env) as $key) {
            putenv($key);
            unset($_ENV[$key], $_SERVER[$key]);
        }
    }
    expect(config('admin.email'))->toBe(ADMIN_EMAIL)
        ->and(config('admin.password_hash'))->toBe($hash)
        ->and(config('admin.totp_secret'))->toBe($secret);
    Cache::forget('admin:totp:last-step');

    adminSignIn($this, $secret);
    $this->get('/admin')->assertOk();
});

it('reads the hash in the base64 form admin:setup prints, which has no "$" to lose', function () {
    $hash = Hash::make(ADMIN_PASSWORD);
    putenv('ADMIN_PASSWORD_HASH=base64:'.base64_encode($hash));
    $_ENV['ADMIN_PASSWORD_HASH'] = $_SERVER['ADMIN_PASSWORD_HASH'] = 'base64:'.base64_encode($hash);
    try {
        $admin = require config_path('admin.php');
    } finally {
        putenv('ADMIN_PASSWORD_HASH');
        unset($_ENV['ADMIN_PASSWORD_HASH'], $_SERVER['ADMIN_PASSWORD_HASH']);
    }
    expect($admin['password_hash'])->toBe($hash);
});

it('shows trends, health, filtered accounts and the activity log, all counts and no habit data', function () {
    Queue::fake();
    $secret = configureAdmin();
    $this->freezeClock('2026-05-28T17:22:00Z');
    $maya = $this->registerUser('Maya Chen', 'maya@example.test');
    $kofi = $this->registerUser('Kofi', 'kofi@example.test');
    $this->sync($maya['token'], [M::habitCreate((string) Str::uuid7(), overrides: ['name' => 'Secret morning swim'])])
        ->assertJsonPath('data.acks.0.status', 'accepted');
    adminSignIn($this, $secret, '2026-05-29T09:00:00Z');
    $this->post("/admin/accounts/{$kofi['id']}/suspend");

    $this->get('/admin')->assertOk()
        ->assertSee('Live accounts')->assertSee('Sign-ups')->assertSee('Active accounts per day')
        ->assertSeeText('2 sign-ups this week')->assertDontSee('Secret morning swim');
    $this->get('/admin/health')->assertOk()->assertSee('Failed jobs')->assertSee('No failed jobs.');
    $this->get('/admin/accounts?status=suspended')->assertOk()->assertSee('kofi@example.test')->assertDontSee('maya@example.test');
    $this->get('/admin/accounts?status=active&sort=email')->assertOk()->assertSee('maya@example.test')->assertDontSee('kofi@example.test');
    $this->get('/admin/activity?action=account.suspend')->assertOk()->assertSee('account.suspend')->assertDontSee('admin.sign_in</b>', false);
});

it('retries and removes one failed job, by type only', function () {
    $secret = configureAdmin();
    DB::table('failed_jobs')->insert([
        'uuid' => '01900000-0000-7000-8000-0000000000f1', 'connection' => 'database', 'queue' => 'default',
        'payload' => json_encode(['displayName' => 'App\Jobs\PurgeAccountJob', 'data' => ['secret' => 'never shown']]),
        'exception' => "RuntimeException: maya@example.test broke\n#0 trace", 'failed_at' => '2026-10-26 10:00:00',
    ]);
    adminSignIn($this, $secret);

    $this->get('/admin/health')->assertOk()->assertSee('PurgeAccountJob')->assertSee('RuntimeException')
        ->assertDontSee('never shown')->assertDontSee('maya@example.test');
    $this->post('/admin/health/failed/01900000-0000-7000-8000-0000000000f1/forget')->assertRedirect();
    expect(DB::table('failed_jobs')->count())->toBe(0)
        ->and(DB::table('admin_actions')->pluck('action')->all())->toContain('server.forget_job');
});

/** Three people: Maya (active), Kofi (no activity), Ama (stopped announcements); Esi suspended. */
function emailPeople(object $test): array
{
    $test->freezeClock('2026-05-28T17:22:00Z');
    $people = [];
    foreach (['Maya Chen' => 'maya', 'Kofi Boateng' => 'kofi', 'Ama Owusu' => 'ama', 'Esi Mensah' => 'esi'] as $name => $key) {
        $people[$key] = $test->registerUser($name, "{$key}@example.test");
    }
    $test->sync($people['maya']['token'], [M::habitCreate((string) Str::uuid7())])->assertJsonPath('data.acks.0.status', 'accepted');
    DB::table('users')->where('id', $people['ama']['id'])->update(['service_emails_stopped_at' => '2026-05-28 17:00:00+00']);
    DB::table('users')->where('id', $people['esi']['id'])->update(['suspended_at' => '2026-05-28 17:00:00+00']);

    return $people;
}

it('previews with the reach and a real name, and sends a test only to the admin', function () {
    Mail::fake();
    $secret = configureAdmin();
    emailPeople($this);
    adminSignIn($this, $secret, '2026-05-28T18:00:00Z');

    $this->post('/admin/emails/preview', ['subject' => 'Hello {first_name}', 'body' => "Hi {name},\n\nNews.", 'audience' => 'everyone'])
        ->assertOk()->assertSeeText('2 people now')->assertSee('Hello Maya')->assertSee('Hi Maya Chen,');
    $this->post('/admin/emails', ['action' => 'test', 'subject' => 'Hello {first_name}', 'body' => 'Hi {name}'])->assertRedirect();

    Mail::assertSent(AnnouncementMail::class, fn (AnnouncementMail $m) => $m->hasTo(ADMIN_EMAIL) && $m->userId === null);
    Mail::assertSentCount(1);
});

it('sends to the audience only, personalised, with a stop link, and never twice', function () {
    Mail::fake();
    $secret = configureAdmin();
    emailPeople($this);
    adminSignIn($this, $secret, '2026-05-28T18:00:00Z');

    $this->post('/admin/emails', ['action' => 'now', 'subject' => 'Update for {first_name}', 'body' => 'Hi {name}', 'audience' => 'everyone'])
        ->assertRedirect();
    $campaigns = app(EmailCampaigns::class);
    expect($campaigns->sendDue())->toBe(2)->and($campaigns->sendDue())->toBe(0);

    Mail::assertSent(AnnouncementMail::class, fn (AnnouncementMail $m) => $m->hasTo('maya@example.test')
        && $m->subjectLine === 'Update for Maya' && $m->text === 'Hi Maya Chen'
        && str_contains((string) $m->headers()->text['List-Unsubscribe'], '/emails/stop/'));
    Mail::assertSent(AnnouncementMail::class, fn (AnnouncementMail $m) => $m->hasTo('kofi@example.test'));
    Mail::assertNotSent(AnnouncementMail::class, fn (AnnouncementMail $m) => $m->hasTo('ama@example.test') || $m->hasTo('esi@example.test'));
    expect(DB::table('email_campaigns')->value('status'))->toBe('sent');
});

it('targets active, inactive and new accounts over rolling days', function () {
    emailPeople($this);
    $this->freezeClock('2026-05-28T18:00:00Z');
    $c = app(EmailCampaigns::class);
    $emails = fn (array $a) => $c->recipients($a)->orderBy('email')->pluck('email')->all();

    expect($emails(['type' => 'active', 'days' => 7]))->toBe(['maya@example.test'])
        ->and($emails(['type' => 'new', 'days' => 1]))->toBe(['kofi@example.test', 'maya@example.test']);
    $this->freezeClock('2026-06-20T18:00:00Z');
    expect($emails(['type' => 'inactive', 'days' => 14]))->toBe(['kofi@example.test', 'maya@example.test'])
        ->and($emails(['type' => 'active', 'days' => 14]))->toBe([]);
});

it('keeps under the daily cap and carries on the next day by itself', function () {
    Mail::fake();
    config(['admin.email_daily_limit' => 1]);
    emailPeople($this);
    $this->freezeClock('2026-05-28T18:00:00Z');
    $c = app(EmailCampaigns::class);
    $c->save('Hi', 'Body', ['type' => 'everyone'], CarbonImmutable::parse('2026-05-28T18:00:00Z'));

    expect($c->sendDue())->toBe(1)->and($c->sendDue())->toBe(0)
        ->and(DB::table('email_campaigns')->value('status'))->toBe('sending');
    $this->freezeClock('2026-05-29T18:01:00Z');
    expect($c->sendDue())->toBe(1)->and(DB::table('email_campaigns')->value('status'))->toBe('sent');
});

it('a failed send records the error class only; stopping skips the rest', function () {
    emailPeople($this);
    $this->freezeClock('2026-05-28T18:00:00Z');
    $c = app(EmailCampaigns::class);
    Mail::shouldReceive('to')->andThrow(new RuntimeException('smtp said no to maya@example.test'));
    $id = $c->save('Hi', 'Body', ['type' => 'everyone'], CarbonImmutable::parse('2026-05-28T18:00:00Z'));
    config(['admin.email_batch' => 1]);
    $c->sendDue();

    expect(DB::table('email_deliveries')->where('status', 'failed')->value('error'))->toBe('RuntimeException')
        ->and($c->cancel($id))->toBeTrue()
        ->and(DB::table('email_deliveries')->where('status', 'skipped')->count())->toBe(1)
        ->and(DB::table('email_campaigns')->value('status'))->toBe('cancelled');
});

it('the stop link works signed (GET and one-click POST), never unsigned, and can be undone', function () {
    $people = emailPeople($this);
    $id = $people['maya']['id'];
    $this->get("/emails/stop/{$id}")->assertForbidden();

    $this->get(URL::signedRoute('emails.stop', ['user' => $id]))->assertOk()->assertSee("You won't get announcement emails", false);
    expect(DB::table('users')->where('id', $id)->value('service_emails_stopped_at'))->not->toBeNull();

    $this->get(URL::signedRoute('emails.start', ['user' => $id]))->assertOk()->assertSee('Announcement emails are on');
    expect(DB::table('users')->where('id', $id)->value('service_emails_stopped_at'))->toBeNull();

    $this->post(URL::signedRoute('emails.stop', ['user' => $id]), ['List-Unsubscribe' => 'One-Click'])->assertOk();
    expect(DB::table('users')->where('id', $id)->value('service_emails_stopped_at'))->not->toBeNull();
});
