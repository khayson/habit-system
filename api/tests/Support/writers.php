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
