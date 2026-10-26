<?php

use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\Log;

/*
 * A54 and invariant 11: production logs go to stderr at warning level, and no log line carries a
 * request body, a password, a token, a reset code or an email. Two checks: every Log call in
 * app/ (its context keys and values), and the exception report of a database error, whose
 * message would otherwise include the SQL bindings.
 */

it('logs no body, password, token, code, email or exception message from app/', function () {
    $forbidden = '/(\$request|->all\(\)|->input\(|getMessage\(\)|[\'"](password|token|code|email|body|secret|reset_code|push_token)[\'"]\s*=>)/i';
    $offenders = [];
    $files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator(app_path()));
    foreach ($files as $file) {
        if (! $file->isFile() || $file->getExtension() !== 'php') {
            continue;
        }
        $code = (string) file_get_contents($file->getPathname());
        // Each Log:: call with everything up to the end of its statement.
        preg_match_all('/Log::(?:debug|info|notice|warning|error|critical|alert|emergency|withContext)\s*\((.*?)\);/s', $code, $calls);
        foreach ($calls[1] as $call) {
            if (preg_match($forbidden, $call)) {
                $offenders[] = $file->getFilename().': '.trim(preg_replace('/\s+/', ' ', $call));
            }
        }
    }
    expect($offenders)->toBe([]);
});

it('reports a database error without its SQL bindings', function () {
    $lines = [];
    Log::listen(function ($message) use (&$lines) {
        $lines[] = $message->message.' '.json_encode($message->context);
    });
    $error = new QueryException('pgsql', 'select * from users where email = ?', ['maya.chen@example.com'], new PDOException('SQLSTATE[08006] connection failure'));

    report($error);

    $logged = implode("\n", $lines);
    expect($logged)->not->toBe('')
        ->and($logged)->not->toContain('maya.chen@example.com')
        ->and($logged)->not->toContain('select * from users');
});

it('writes production logs to stderr at warning level', function () {
    $env = file_get_contents(base_path('../render.yaml'));
    expect($env)->toContain('key: LOG_CHANNEL')
        ->and($env)->toMatch('/key: LOG_CHANNEL\s+value: stderr/')
        ->and($env)->toMatch('/key: LOG_LEVEL\s+value: warning/')
        ->and($env)->toMatch('/key: APP_DEBUG\s+value: "?false"?/');
});
