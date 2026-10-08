<?php

/*
 * Mutation check (R5): applies each mutant in tests/Mutation/mutants.php, runs the domain suite,
 * and expects it to fail. Files are always restored, even on interruption.
 *
 *   php tests/Mutation/run.php
 *
 * Exit 0 when every mutant is killed, 1 when any survives or a mutant no longer applies.
 */

$root = dirname(__DIR__, 2);
chdir($root);

/** @var list<array{name: string, file: string, search: string, replace: string, tests?: string}> $mutants */
$mutants = require __DIR__.'/mutants.php';
$originals = [];

$restore = function () use (&$originals): void {
    foreach ($originals as $file => $content) {
        file_put_contents($file, $content);
    }
    $originals = [];
};
register_shutdown_function($restore);
if (function_exists('pcntl_signal')) {
    pcntl_signal(SIGINT, function () use ($restore) {
        $restore();
        exit(130);
    });
}

$survivors = 0;
foreach ($mutants as $i => $mutant) {
    $file = $mutant['file'];
    $source = (string) file_get_contents($file);
    $occurrences = substr_count($source, $mutant['search']);
    if ($occurrences !== 1) {
        fwrite(STDOUT, sprintf("STALE     %s (snippet found %d times in %s)\n", $mutant['name'], $occurrences, $file));
        $survivors++;

        continue;
    }

    $originals[$file] = $source;
    file_put_contents($file, str_replace($mutant['search'], $mutant['replace'], $source));
    // Domain mutants run the pure domain suite; application mutants name the (PostgreSQL)
    // feature tests that must kill them.
    $tests = $mutant['tests'] ?? 'tests/Unit/Domain';
    $command = escapeshellarg(PHP_BINARY).' vendor/bin/pest '.$tests.' --no-coverage';
    exec($command.' 2>&1', $output, $exit);
    $restore();

    $killed = $exit !== 0;
    $survivors += $killed ? 0 : 1;
    fwrite(STDOUT, sprintf("%-9s %s\n", $killed ? 'KILLED' : 'SURVIVED', $mutant['name']));
}

fwrite(STDOUT, sprintf("\n%d mutants, %d killed, %d survived or stale\n", count($mutants), count($mutants) - $survivors, $survivors));
exit($survivors === 0 && count($mutants) >= 8 ? 0 : 1);
