<?php

it('returns the health envelope from the contract fixture', function () {
    $fixture = contractFixture('envelope/success_health.json');

    $response = $this->getJson('/api/v1/health');

    $response->assertStatus($fixture['status']);
    assertMatchesContract($fixture['body'], $response->json());
});

it('reports server_time from the injected clock in UTC with Z', function () {
    $this->freezeClock('2026-05-28T10:22:00-07:00');

    $this->getJson('/api/v1/health')
        ->assertOk()
        ->assertJsonPath('meta.server_time', '2026-05-28T17:22:00Z');
});

it('issues a fresh server-generated v7 request id per request, echoed in X-Request-Id', function () {
    $first = $this->getJson('/api/v1/health', ['X-Request-Id' => 'client-chosen']);
    $second = $this->getJson('/api/v1/health');

    $id = $first->json('meta.request_id');
    expect($id)->toMatch(UUID_V7_PATTERN)
        ->and($first->headers->get('X-Request-Id'))->toBe($id)
        ->and($second->json('meta.request_id'))->not->toBe($id);
});

it('answers JSON even without an Accept header', function () {
    $this->get('/api/v1/health')
        ->assertOk()
        ->assertHeader('Content-Type', 'application/json');
});
