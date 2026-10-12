<?php

/*
 * Writer processes for the concurrency tests: each applies its mutations through the real
 * MutationApplier in its own PHP process (tests/Concurrency/writer.php), against the test database.
 */

/** @return array{0: resource, 1: array<int, resource>} */
function startWriter(string $userId, int $index, array $mutations, string $now): array
{
    $file = tempnam(sys_get_temp_dir(), 'habit-writer-');
    file_put_contents($file, json_encode($mutations, JSON_THROW_ON_ERROR));
    $env = array_merge(getenv(), [
        'APP_ENV' => 'testing',
        'DB_CONNECTION' => 'pgsql',
        'DB_HOST' => (string) config('database.connections.pgsql.host'),
        'DB_PORT' => (string) config('database.connections.pgsql.port'),
        'DB_DATABASE' => (string) config('database.connections.pgsql.database'),
        'DB_USERNAME' => (string) config('database.connections.pgsql.username'),
        'DB_PASSWORD' => (string) config('database.connections.pgsql.password'),
    ]);
    $process = proc_open(
        [PHP_BINARY, base_path('tests/Concurrency/writer.php'), $userId, sprintf('01970000-0000-7000-8000-%012d', $index), $file, $now],
        [1 => ['pipe', 'w'], 2 => ['pipe', 'w']],
        $pipes,
        base_path(),
        $env,
    );
    if (! is_resource($process)) {
        throw new RuntimeException('Could not start writer');
    }
    stream_set_blocking($pipes[1], false);
    stream_set_blocking($pipes[2], false);

    return [$process, $pipes];
}

/**
 * A closer process (tests/Concurrency/closer.php): PeriodCloser::closeUser $runs times.
 *
 * @return array{0: resource, 1: array<int, resource>}
 */
function startCloser(string $userId, int $runs, string $now): array
{
    $env = array_merge(getenv(), [
        'APP_ENV' => 'testing',
        'DB_CONNECTION' => 'pgsql',
        'DB_HOST' => (string) config('database.connections.pgsql.host'),
        'DB_PORT' => (string) config('database.connections.pgsql.port'),
        'DB_DATABASE' => (string) config('database.connections.pgsql.database'),
        'DB_USERNAME' => (string) config('database.connections.pgsql.username'),
        'DB_PASSWORD' => (string) config('database.connections.pgsql.password'),
    ]);
    $process = proc_open(
        [PHP_BINARY, base_path('tests/Concurrency/closer.php'), $userId, (string) $runs, $now],
        [1 => ['pipe', 'w'], 2 => ['pipe', 'w']],
        $pipes,
        base_path(),
        $env,
    );
    if (! is_resource($process)) {
        throw new RuntimeException('Could not start closer');
    }

    return [$process, $pipes];
}

/**
 * Waits for a writer or closer and returns its stdout; fails the test on a non-zero exit.
 *
 * @param  array{0: resource, 1: array<int, resource>}  $child
 */
function finishProcess(array $child): string
{
    [$process, $pipes] = $child;
    stream_set_blocking($pipes[1], true);
    stream_set_blocking($pipes[2], true);
    $out = (string) stream_get_contents($pipes[1]);
    $errors = (string) stream_get_contents($pipes[2]);
    expect(proc_close($process))->toBe(0, "child failed: {$errors}");

    return $out;
}
