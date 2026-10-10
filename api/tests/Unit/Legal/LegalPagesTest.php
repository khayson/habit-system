<?php

use App\Legal\LegalBuildException;
use App\Legal\LegalDocument;
use App\Legal\LegalFacts;
use App\Legal\PageBuilder;

/*
 * A33: the public Terms and Privacy pages, built from the real docs/legal files. Structure,
 * no scripts or external resources, readable type, and WCAG contrast in both palettes.
 */

function legalDir(): string
{
    return dirname(__DIR__, 4).'/docs/legal';
}

/** @return array{terms: LegalDocument, privacy: LegalDocument} */
function realDocuments(): array
{
    return [
        'terms' => LegalDocument::parse('terms', (string) file_get_contents(legalDir().'/terms.md')),
        'privacy' => LegalDocument::parse('privacy', (string) file_get_contents(legalDir().'/privacy.md')),
    ];
}

function realFacts(): LegalFacts
{
    return LegalFacts::fromJson((string) file_get_contents(legalDir().'/facts.json'));
}

/** @return array<string, string> */
function builtPages(): array
{
    return (new PageBuilder)->build(realDocuments(), realFacts(), false)['files'];
}

function dom(string $html): DOMDocument
{
    $dom = new DOMDocument;
    libxml_use_internal_errors(true);
    $dom->loadHTML($html, LIBXML_NOERROR);
    libxml_clear_errors();

    return $dom;
}

function filledFacts(array $overrides = []): LegalFacts
{
    $facts = json_decode((string) file_get_contents(legalDir().'/facts.json'), true);
    foreach ($facts as $key => $value) {
        $facts[$key] ??= "value of {$key}";
    }

    return LegalFacts::fromJson((string) json_encode([...$facts, ...$overrides]));
}

function finalDocument(string $slug, string $body = "# Title\n\nText for {{app_name}}.\n"): LegalDocument
{
    return LegalDocument::parse($slug, "---\ntitle: T\nversion: 2026-10-10\neffective: 2026-10-10\nstatus: final\n---\n{$body}");
}

it('writes the four pages', function () {
    expect(array_keys(builtPages()))->toEqualCanonicalizing(['index.html', 'terms/index.html', 'privacy/index.html', '404.html']);
});

it('gives every page the required structure', function (string $path) {
    $html = builtPages()[$path];
    $dom = dom($html);
    $xpath = new DOMXPath($dom);

    expect($dom->documentElement?->getAttribute('lang'))->toBe('en')
        ->and(trim($xpath->evaluate('string(//title)')))->not->toBe('')
        ->and($xpath->query('//meta[@name="viewport"]')->length)->toBe(1)
        ->and($xpath->query('//h1')->length)->toBe(1)
        ->and($xpath->query('//a[@class="skip" and @href="#main"]')->length)->toBe(1)
        ->and($xpath->query('//main[@id="main"]')->length)->toBe(1)
        ->and($xpath->query('//style')->length)->toBe(1)
        ->and($xpath->query('//script')->length)->toBe(0)
        ->and($xpath->query('//link')->length)->toBe(0, 'no external stylesheet or web font');

    // Headings never skip a level.
    $previous = 0;
    foreach ($xpath->query('//h1|//h2|//h3|//h4|//h5|//h6') as $heading) {
        $level = (int) substr($heading->nodeName, 1);
        expect($level)->toBeLessThanOrEqual($previous + 1, "{$path}: <{$heading->nodeName}> after h{$previous}");
        $previous = $level;
    }

    // Footer nav: Terms, Privacy, Home, all relative.
    $nav = [];
    foreach ($xpath->query('//footer//nav//a') as $a) {
        $nav[trim($a->textContent)] = $a->getAttribute('href');
    }
    expect(array_keys($nav))->toBe(['Terms', 'Privacy', 'Home']);
    foreach ($nav as $href) {
        expect($href)->not->toMatch('#^[a-z]+:#i')->not->toStartWith('/');
    }

    // No external URL anywhere except mailto:.
    foreach ($xpath->query('//@href|//@src') as $attribute) {
        $value = $attribute->nodeValue ?? '';
        if (preg_match('#^[a-z][a-z0-9+.-]*:#i', $value)) {
            expect($value)->toStartWith('mailto:');
        }
        expect($value)->not->toStartWith('//');
    }
})->with(['index.html', 'terms/index.html', 'privacy/index.html', '404.html']);

it('shows the version and effective date on each document page', function (string $slug) {
    $text = dom(builtPages()["{$slug}/index.html"])->textContent;
    $document = realDocuments()[$slug];

    expect($text)->toContain("Version {$document->version}")->toContain("Effective {$document->effective}");
})->with(['terms', 'privacy']);

it('reads well: system fonts, 16 px text, about 70ch lines, focus, print, no sideways scroll', function () {
    $css = PageBuilder::css();

    expect($css)->toContain('font:1rem/1.6 system-ui')
        ->and($css)->toContain('max-width:70ch')
        ->and($css)->toContain(':focus-visible{outline:3px solid var(--focus)')
        ->and($css)->toContain('@media print')
        ->and($css)->toContain('.table-wrap{overflow-x:auto')
        ->and($css)->not->toContain('@import')
        ->and($css)->not->toContain('@font-face')
        ->and($css)->not->toContain('url(');
    // Nothing wider than a 320 px screen, and no text below 16 px (1rem).
    preg_match_all('/(?:min-)?width:(\d+)px/', $css, $widths);
    foreach ($widths[1] as $px) {
        expect((int) $px)->toBeLessThanOrEqual(320);
    }
    preg_match_all('/font-size:([\d.]+)(rem|px)/', $css, $sizes, PREG_SET_ORDER);
    foreach ($sizes as [$all, $value, $unit]) {
        expect($unit === 'rem' ? (float) $value * 16 : (float) $value)->toBeGreaterThanOrEqual(16, $all);
    }
    // The privacy table scrolls inside its own wrapper.
    expect(builtPages()['privacy/index.html'])->toContain('<div class="table-wrap"><table>');
});

it('keeps every text and background pair at 4.5:1 or more, light and dark', function (string $palette) {
    $luminance = function (string $hex): float {
        $channel = function (int $c): float {
            $s = $c / 255;

            return $s <= 0.03928 ? $s / 12.92 : (($s + 0.055) / 1.055) ** 2.4;
        };
        [$r, $g, $b] = array_map(hexdec(...), str_split(ltrim($hex, '#'), 2));

        return 0.2126 * $channel((int) $r) + 0.7152 * $channel((int) $g) + 0.0722 * $channel((int) $b);
    };
    foreach (PageBuilder::TEXT_PAIRS as [$text, $background]) {
        $a = $luminance(PageBuilder::PALETTES[$palette][$text]);
        $b = $luminance(PageBuilder::PALETTES[$palette][$background]);
        $ratio = (max($a, $b) + 0.05) / (min($a, $b) + 0.05);
        expect($ratio)->toBeGreaterThanOrEqual(4.5, "{$palette}: {$text} on {$background} is ".round($ratio, 2).':1');
    }
})->with(['light', 'dark']);

it('uses the app\'s colour roles (habit_tokens.dart)', function () {
    $dart = (string) file_get_contents(dirname(__DIR__, 4).'/app/lib/config/habit_tokens.dart');
    $map = ['background' => 'background', 'surface' => 'surface', 'ink' => 'ink', 'muted' => 'muted',
        'border' => 'border', 'link' => 'primary', 'focus' => 'focus', 'warning' => 'warningInk'];
    foreach (['light', 'dark'] as $palette) {
        preg_match('/static const '.$palette.' = HabitTokens\((.*?)\);/s', $dart, $block);
        foreach ($map as $role => $token) {
            preg_match('/\b'.$token.': Color\(0xFF([0-9A-F]{6})\)/', $block[1] ?? '', $m);
            expect('#'.($m[1] ?? '?'))->toBe(PageBuilder::PALETTES[$palette][$role], "{$palette}.{$role}");
        }
    }
});

it('replaces facts HTML-escaped, shows a missing one, and fails on an unknown token', function () {
    $documents = ['terms' => finalDocument('terms', "# T\n\nBy {{publisher}} for {{contact_email}}.\n"), 'privacy' => finalDocument('privacy')];

    $built = (new PageBuilder)->build($documents, filledFacts(['publisher' => '<b>Khay</b>', 'contact_email' => null]), false);
    expect($built['files']['terms/index.html'])->toContain('By &lt;b&gt;Khay&lt;/b&gt;')
        ->toContain('[[contact_email]]')
        ->and($built['warnings'])->toContain('facts.json: contact_email is not filled in');

    $unknown = ['terms' => finalDocument('terms', "# T\n\n{{nobody}}\n"), 'privacy' => finalDocument('privacy')];
    expect(fn () => (new PageBuilder)->build($unknown, filledFacts(), false))
        ->toThrow(LegalBuildException::class, 'unknown token {{nobody}}');
});

it('publishes only when every fact is filled and both documents are final', function () {
    $final = ['terms' => finalDocument('terms'), 'privacy' => finalDocument('privacy')];
    expect((new PageBuilder)->build($final, filledFacts(), true)['warnings'])->toBe([]);

    expect(fn () => (new PageBuilder)->build($final, filledFacts(['hosting_region' => null]), true))
        ->toThrow(LegalBuildException::class, 'hosting_region is not filled in');
    expect(fn () => (new PageBuilder)->build(realDocuments(), filledFacts(), true))
        ->toThrow(LegalBuildException::class, 'status is draft');
});

it('reads front matter strictly', function (string $front, string $message) {
    expect(fn () => LegalDocument::parse('terms', "---\n{$front}\n---\n# T\n"))
        ->toThrow(LegalBuildException::class, $message);
})->with([
    'unknown key' => ["title: T\nversion: 2026-10-10\neffective: 2026-10-10\nstatus: final\nauthor: me", 'unknown front matter key(s): author'],
    'missing key' => ["title: T\nversion: 2026-10-10\nstatus: final", 'missing front matter key(s): effective'],
    'impossible date' => ["title: T\nversion: 2026-02-30\neffective: 2026-10-10\nstatus: final", 'version must be a real YYYY-MM-DD date'],
    'unknown status' => ["title: T\nversion: 2026-10-10\neffective: 2026-10-10\nstatus: approved", 'status must be draft or final'],
]);

it('reads facts strictly', function () {
    $facts = json_decode((string) file_get_contents(legalDir().'/facts.json'), true);

    expect(fn () => LegalFacts::fromJson((string) json_encode([...$facts, 'phone' => '1'])))
        ->toThrow(LegalBuildException::class, 'unknown key(s): phone');
    unset($facts['publisher']);
    expect(fn () => LegalFacts::fromJson((string) json_encode($facts)))
        ->toThrow(LegalBuildException::class, 'missing key(s): publisher');
});
