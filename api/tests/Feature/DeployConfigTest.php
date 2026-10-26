<?php

/*
 * A54: the deploy files hold no secret. Every secret in render.yaml is `sync: false` with no
 * value (Render asks for it); the image runs as a non-root user, migrates as it starts, and
 * leaves tests, .env and vendor-dev out.
 */

const DEPLOY_SECRETS = [
    'APP_KEY', 'APP_URL', 'DB_URL', 'R2_ENDPOINT', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY',
    'MAIL_USERNAME', 'MAIL_PASSWORD', 'MAIL_FROM_ADDRESS', 'EXPORT_SIGNING_KEYS', 'TICK_SECRET',
];

it('asks Render for every secret and stores none', function () {
    $yaml = (string) file_get_contents(base_path('../render.yaml'));
    foreach (DEPLOY_SECRETS as $key) {
        expect($yaml)->toMatch("/- key: {$key}\\s+sync: false\\n/", $key);
    }
    expect($yaml)->toContain('plan: free')
        ->and($yaml)->toContain('region: frankfurt')
        ->and($yaml)->toContain('healthCheckPath: /api/v1/health')
        ->and($yaml)->not->toMatch('/postgres(ql)?:\/\/|sk_|xkeysib-|BEGIN [A-Z ]*KEY/');
});

it('builds a production image that runs as a non-root user and migrates at start', function () {
    $dockerfile = (string) file_get_contents(base_path('Dockerfile'));
    $start = (string) file_get_contents(base_path('docker/start.sh'));
    $ignore = (string) file_get_contents(base_path('.dockerignore'));
    expect($dockerfile)->toContain('FROM php:8.4-fpm-alpine')
        ->and($dockerfile)->toContain('--no-dev')
        ->and($dockerfile)->toMatch('/^USER app$/m')
        ->and($start)->toContain('php artisan config:cache')
        ->and($start)->toContain('php artisan migrate --force')
        ->and($start)->toContain('${PORT:-10000}')
        // Render mounts an empty /tmp at run time: the start script makes nginx's folders itself.
        ->and($start)->toMatch('#mkdir -p /tmp/nginx\n.*/tmp/nginx/nginx\.conf#s')
        ->and($start)->not->toContain("\r");
    foreach (['.env', 'vendor', 'tests', 'phpunit.xml'] as $path) {
        expect($ignore)->toMatch('/^'.preg_quote($path, '/').'$/m', $path);
    }
});
