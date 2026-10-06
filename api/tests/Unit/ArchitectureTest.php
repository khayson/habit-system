<?php

arch('domain classes are pure: no framework I/O, no implicit clock')
    ->expect('App\Domain')
    ->not->toUse([
        'Illuminate\Support\Facades',
        'Illuminate\Database',
        'Illuminate\Http',
        'now',
        'today',
        'time',
        'date',
    ]);

arch('no debugging helpers ship')
    ->expect(['dd', 'dump', 'ray', 'var_dump', 'print_r'])
    ->not->toBeUsed();

it('never reads whole request payloads (invariant 1)', function () {
    $offenders = [];
    $files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator(dirname(__DIR__, 2).'/app'));

    foreach ($files as $file) {
        if ($file->getExtension() !== 'php') {
            continue;
        }
        $source = (string) file_get_contents($file->getPathname());
        if (preg_match('/(\$request|request\(\))\s*->\s*(all|input|post|json)\(\s*\)|Request::all\(/', $source)) {
            $offenders[] = $file->getPathname();
        }
    }

    expect($offenders)->toBe([]);
});
