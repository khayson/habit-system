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

// Only TimezoneTimeline computes day instants, and only PeriodEngine::bounds() asks it for
// period instants (A26, R4). Anything else that derives a day start/end is a second, drifting
// definition of a day.
const DAY_BOUNDARY_CALL = '/\b(startOfLocalDay|endOfLocalDay)\s*\(/';
const AD_HOC_DAY_MATH = '/->\s*(startOf(Day|Week|Month)|endOf(Day|Week|Month)|setTime)\s*\(|modify\s*\(\s*[\'"][^\'"]*\b(midnight|today|tomorrow|yesterday|noon)\b|getTransitions\s*\(/i';

it('detects day-boundary computations (guard self-test)', function (string $code, bool $call, bool $adHoc) {
    expect(preg_match(DAY_BOUNDARY_CALL, $code) === 1)->toBe($call)
        ->and(preg_match(AD_HOC_DAY_MATH, $code) === 1)->toBe($adHoc);
})->with([
    ['$t->startOfLocalDay($d)', true, false],
    ['$timeline->endOfLocalDay($d);', true, false],
    ['$now->startOfDay()', false, true],
    ['$x->setTime(0, 0)', false, true],
    ["\$x->modify('tomorrow midnight')", false, true],
    ['$zone->getTransitions($a, $b)', false, true],
    ["\$x->modify('+1 day')", false, false],
    ['$date->addDays(1)', false, false],
]);

it('computes day and period instants only in TimezoneTimeline and PeriodEngine::bounds() (R4)', function () {
    $sources = phpSources('app');
    $timeline = 'app'.DIRECTORY_SEPARATOR.'Domain'.DIRECTORY_SEPARATOR.'Calendar'.DIRECTORY_SEPARATOR.'TimezoneTimeline.php';
    $engine = 'app'.DIRECTORY_SEPARATOR.'Domain'.DIRECTORY_SEPARATOR.'Period'.DIRECTORY_SEPARATOR.'PeriodEngine.php';

    $callers = array_diff(offenders($sources, DAY_BOUNDARY_CALL), [$timeline, $engine]);
    $adHoc = array_diff(offenders($sources, AD_HOC_DAY_MATH), [$timeline]);

    expect(array_values($callers))->toBe([])->and(array_values($adHoc))->toBe([]);

    // Inside PeriodEngine, only bounds() may ask for instants.
    preg_match_all('/function\s+(\w+)\s*\([^)]*\)[^{]*\{((?:[^{}]|\{(?2)\})*)\}/', $sources[$engine], $methods, PREG_SET_ORDER);
    $using = array_map(fn ($m) => $m[1], array_filter($methods, fn ($m) => preg_match(DAY_BOUNDARY_CALL, $m[2]) === 1));
    expect(array_values($using))->toBe(['bounds']);
});
