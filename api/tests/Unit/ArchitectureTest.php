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

/**
 * PHP files under a path of the api app, keyed by relative path, comments stripped.
 *
 * @return array<string, string>
 */
function phpSources(string $relativeDir): array
{
    $root = dirname(__DIR__, 2);
    $dir = $root.'/'.$relativeDir;
    $sources = [];
    if (! is_dir($dir)) {
        return $sources;
    }
    foreach (new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir)) as $file) {
        if ($file->getExtension() !== 'php') {
            continue;
        }
        $code = '';
        foreach (token_get_all((string) file_get_contents($file->getPathname())) as $token) {
            if (is_array($token) && in_array($token[0], [T_COMMENT, T_DOC_COMMENT], true)) {
                continue;
            }
            $code .= is_array($token) ? $token[1] : $token;
        }
        $sources[substr($file->getPathname(), strlen($root) + 1)] = $code;
    }

    return $sources;
}

/**
 * @param  array<string, string>  $sources
 * @return list<string>
 */
function offenders(array $sources, string $pattern): array
{
    return array_keys(array_filter($sources, fn (string $code) => preg_match($pattern, $code) === 1));
}

// Implicit "now" in any spelling. Domain code receives an injected Clock instead.
const IMPLICIT_CLOCK = '/new\s+\\\\?DateTime(Immutable)?\s*(\(\s*(["\']now["\'])?\s*\)|;)'
    .'|\\\\?Carbon(Immutable)?\s*::\s*(now|today|yesterday|tomorrow|parse)\s*\(/i';

const WHOLE_PAYLOAD = '/(\$request|request\(\))\s*->\s*(all|input|post|json)\(\s*\)|Request::all\(/';

const MASS_ASSIGNMENT_OFF = '/::unguard\s*\(|->unguard\s*\(|\$guarded\s*=\s*\[\s*\]/';

it('detects implicit clocks (guard self-test)', function (string $code, bool $hit) {
    expect(preg_match(IMPLICIT_CLOCK, $code) === 1)->toBe($hit);
})->with([
    ['$a = new DateTimeImmutable();', true],
    ['$a = new \DateTime;', true],
    ["\$a = new DateTimeImmutable('now');", true],
    ['$a = Carbon::now();', true],
    ['$a = \Carbon\CarbonImmutable::parse($x);', true],
    ['$a = CarbonImmutable :: today();', true],
    ["\$a = new DateTimeImmutable('2026-05-28T00:00:00Z');", false],
    ['$a = $this->clock->now();', false],
    ['$a = CarbonImmutable::createFromFormat($f, $v);', false],
]);

it('keeps app/Domain free of implicit clocks', function () {
    expect(offenders(phpSources('app/Domain'), IMPLICIT_CLOCK))->toBe([]);
});

it('detects disabled mass-assignment protection (guard self-test)', function (string $code, bool $hit) {
    expect(preg_match(MASS_ASSIGNMENT_OFF, $code) === 1)->toBe($hit);
})->with([
    ['Model::unguard();', true],
    ['protected $guarded = [];', true],
    ['protected $guarded = [ ];', true],
    ["protected \$guarded = ['*'];", false],
    ["protected \$fillable = ['name'];", false],
]);

it('never disables mass-assignment protection (invariant 1)', function () {
    expect(offenders(phpSources('app'), MASS_ASSIGNMENT_OFF))->toBe([]);
});

it('never reads whole request payloads (invariant 1)', function () {
    expect(offenders(phpSources('app'), WHOLE_PAYLOAD))->toBe([]);
});
