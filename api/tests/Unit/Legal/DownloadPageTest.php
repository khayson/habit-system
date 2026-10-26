<?php

use App\Legal\DownloadInfo;
use App\Legal\LegalBuildException;
use App\Legal\LegalDocument;
use App\Legal\LegalFacts;
use App\Legal\PageBuilder;

/*
 * A54: the download page beside the legal pages (GitHub Pages), and draft legal pages that say
 * so. The page links to the latest GitHub Release's APKs so it never goes stale, says how to
 * install an APK and that reset emails can land in spam, links to Privacy and Terms, and lists
 * each APK's SHA-256 from docs/legal/download.json. No trackers, scripts or fonts.
 */

function downloadDir(): string
{
    return dirname(__DIR__, 4).'/docs/legal';
}

function downloadFacts(): LegalFacts
{
    return LegalFacts::fromJson((string) file_get_contents(downloadDir().'/facts.json'));
}

function realDownload(): DownloadInfo
{
    return DownloadInfo::fromJson((string) file_get_contents(downloadDir().'/download.json'));
}

function downloadDom(string $html): DOMXPath
{
    $dom = new DOMDocument;
    libxml_use_internal_errors(true);
    $dom->loadHTML($html, LIBXML_NOERROR);
    libxml_clear_errors();

    return new DOMXPath($dom);
}

it('links the button to the latest release\'s arm64 APK and offers the 32-bit one', function () {
    $html = (new PageBuilder)->downloadPage(downloadFacts(), realDownload());
    $xpath = downloadDom($html);
    $hrefs = [];
    foreach ($xpath->query('//main//a') as $a) {
        $hrefs[trim(preg_replace('/\s+/', ' ', $a->textContent))] = $a->getAttribute('href');
    }
    expect($hrefs['Download for Android'])->toBe('https://github.com/khayson/habit-system/releases/latest/download/app-arm64-v8a-release.apk')
        ->and($hrefs['the 32-bit version'])->toBe('https://github.com/khayson/habit-system/releases/latest/download/app-armeabi-v7a-release.apk')
        ->and($hrefs['every release'])->toBe('https://github.com/khayson/habit-system/releases/latest')
        ->and($hrefs['Privacy'])->toBe('../privacy/')
        ->and($hrefs['Terms'])->toBe('../terms/');
});

it('says what the app does, how to install an APK, and that reset emails can land in spam', function () {
    $html = (new PageBuilder)->downloadPage(downloadFacts(), realDownload());
    $text = preg_replace('/\s+/', ' ', strip_tags($html));
    expect($text)->toContain('Habit System')
        ->and($text)->toContain('Install unknown apps')
        ->and($text)->toContain('spam folder')
        ->and(downloadDom($html)->query('//h1')->length)->toBe(1)
        ->and(downloadDom($html)->query('//ol/li')->length)->toBeGreaterThanOrEqual(3);
});

it('lists each APK\'s SHA-256, or says where to find it before the first release', function () {
    $info = DownloadInfo::fromJson(json_encode([
        'releases_url' => 'https://github.com/khayson/habit-system/releases',
        'apks' => [
            ['abi' => 'arm64-v8a', 'file' => 'app-arm64-v8a-release.apk', 'sha256' => str_repeat('a', 64)],
            ['abi' => 'armeabi-v7a', 'file' => 'app-armeabi-v7a-release.apk', 'sha256' => null],
        ],
    ]));
    $html = (new PageBuilder)->downloadPage(downloadFacts(), $info);
    expect($html)->toContain(str_repeat('a', 64))
        ->and($html)->toContain('app-armeabi-v7a-release.apk')
        ->and(strip_tags($html))->toContain('listed in the release notes');
});

it('loads no script, font, image or tracker, and links only to GitHub and its own pages', function () {
    $xpath = downloadDom((new PageBuilder)->downloadPage(downloadFacts(), realDownload()));
    expect($xpath->query('//script|//link|//img|//iframe')->length)->toBe(0);
    foreach ($xpath->query('//@href|//@src') as $attribute) {
        $value = $attribute->nodeValue ?? '';
        if (preg_match('#^[a-z][a-z0-9+.-]*:#i', $value)) {
            expect($value)->toStartWith('https://github.com/khayson/habit-system/');
        }
    }
});

it('reads download.json strictly', function () {
    expect(fn () => DownloadInfo::fromJson('{"releases_url":"http://github.com/x/y/releases","apks":[]}'))
        ->toThrow(LegalBuildException::class, 'https');
    expect(fn () => DownloadInfo::fromJson('{"releases_url":"https://github.com/x/y/releases","apks":[{"abi":"arm64-v8a","file":"a.apk","sha256":"xyz"}]}'))
        ->toThrow(LegalBuildException::class, 'sha256');
});

it('marks draft legal pages as drafts, and publishes them only when drafts are allowed', function () {
    $documents = [
        'terms' => LegalDocument::parse('terms', (string) file_get_contents(downloadDir().'/terms.md')),
        'privacy' => LegalDocument::parse('privacy', (string) file_get_contents(downloadDir().'/privacy.md')),
    ];
    expect(fn () => (new PageBuilder)->build($documents, downloadFacts(), true))->toThrow(LegalBuildException::class);

    $files = (new PageBuilder)->build($documents, downloadFacts(), true, allowDraft: true)['files'];
    foreach (['terms/index.html', 'privacy/index.html', 'index.html'] as $path) {
        expect(strip_tags($files[$path]))->toContain('Draft: this document is not final yet');
    }
});
