<?php

namespace App\Legal;

use League\CommonMark\Environment\Environment;
use League\CommonMark\Extension\CommonMark\CommonMarkCoreExtension;
use League\CommonMark\Extension\Table\TableExtension;
use League\CommonMark\MarkdownConverter;

/**
 * A33: turns docs/legal into static pages: index.html, terms/index.html, privacy/index.html and
 * 404.html. No scripts, no external resources (only mailto: links), system fonts, one inline
 * stylesheet in the app's colour roles (light and dark by prefers-color-scheme). Pure: no DB,
 * no facades, no clock.
 *
 * {{name}} tokens are replaced from facts, HTML-escaped; an unknown token fails the build. A
 * null fact or a draft document is a warning (the gap shows as [[name]]), and fails with
 * $publish.
 */
final class PageBuilder
{
    /**
     * The app's colour roles (app/lib/config/habit_tokens.dart) as the pages use them. `link`
     * is the app's primary; `warning` marks a fact not filled in yet.
     */
    public const array PALETTES = [
        'light' => [
            'background' => '#FAFAFA', 'surface' => '#FFFFFF', 'ink' => '#323B35', 'muted' => '#647269',
            'border' => '#E6EBE7', 'link' => '#2F7B45', 'focus' => '#236899', 'warning' => '#A85816',
        ],
        'dark' => [
            'background' => '#142018', 'surface' => '#1D2D22', 'ink' => '#EEF6EE', 'muted' => '#B8C8BC',
            'border' => '#53685A', 'link' => '#8BD799', 'focus' => '#A1D7F3', 'warning' => '#ECCC93',
        ],
    ];

    /** Text colours and the backgrounds they are read on; every pair must reach 4.5:1. */
    public const array TEXT_PAIRS = [
        ['ink', 'background'], ['muted', 'background'], ['link', 'background'], ['warning', 'background'],
        ['ink', 'surface'], ['muted', 'surface'], ['link', 'surface'],
    ];

    /** @var list<string> */
    private array $warnings = [];

    private MarkdownConverter $markdown;

    public function __construct()
    {
        $environment = new Environment(['html_input' => 'escape', 'allow_unsafe_links' => false]);
        $environment->addExtension(new CommonMarkCoreExtension);
        $environment->addExtension(new TableExtension);
        $this->markdown = new MarkdownConverter($environment);
    }

    /**
     * @param  array{terms: LegalDocument, privacy: LegalDocument}  $documents
     * @return array{files: array<string, string>, warnings: list<string>}
     */
    public function build(array $documents, LegalFacts $facts, bool $publish, bool $allowDraft = false): array
    {
        $this->warnings = [];
        $problems = [];
        foreach ($documents as $document) {
            if ($document->status !== 'final') {
                $problems[] = "{$document->slug}: status is {$document->status}, not final";
            }
        }
        foreach ($facts->missing() as $key) {
            $problems[] = "facts.json: {$key} is not filled in";
        }
        // ASSUMPTION(7a-draft-pages): A54 publishes the pages for testers before every fact is
        // filled; they then say plainly, on every page, that they are drafts.
        if ($publish && ! $allowDraft && $problems !== []) {
            throw new LegalBuildException("Cannot publish:\n- ".implode("\n- ", $problems));
        }
        foreach ($problems as $problem) {
            $this->warnings[] = $problem;
        }

        $appName = $facts->get('app_name') ?? 'Habit System';
        $draft = $problems === [] ? '' : '<p class="draft" role="note"><strong>Draft: this document is not final yet.</strong> '
            .'Some details, such as the contact address, are still to be added. The final version will say so here.</p>';
        $files = [];
        foreach ($documents as $slug => $document) {
            $body = $this->fill($this->markdown->convert($document->body)->getContent(), $facts, $document->slug);
            $body = str_replace(['<table>', '</table>'], ['<div class="table-wrap"><table>', '</table></div>'], $body);
            $meta = '<p class="meta">Version '.self::e($document->version).' · Effective '.self::e($document->effective).'</p>';
            $files["{$slug}/index.html"] = $this->page(
                title: $document->title.' · '.$appName,
                main: $this->insertAfterH1($body, $meta.$draft),
                appName: $appName,
                root: '../',
            );
        }

        $list = '';
        foreach ($documents as $slug => $document) {
            $list .= '<li><a href="'.$slug.'/">'.self::e($document->title).'</a> <span class="meta">· version '
                .self::e($document->version).'</span></li>';
        }
        $files['index.html'] = $this->page(
            title: $appName,
            main: '<h1>'.self::e($appName).'</h1>'.$draft.'<ul class="docs">'.$list.'</ul>',
            appName: $appName,
            root: '',
        );
        $files['404.html'] = $this->page(
            title: 'Page not found · '.$appName,
            main: '<h1>Page not found</h1><p><a href="./">Go to the home page</a></p>',
            appName: $appName,
            root: '',
        );

        return ['files' => $files, 'warnings' => array_values(array_unique($this->warnings))];
    }

    /**
     * A54: download/index.html, beside the legal pages. The buttons point at the latest
     * release's assets, so the page never goes stale; the SHA-256 lines come from
     * download.json. No script, font, image or tracker.
     */
    public function downloadPage(LegalFacts $facts, DownloadInfo $download): string
    {
        $appName = $facts->get('app_name') ?? 'Habit System';
        $arm64 = $download->file('arm64-v8a') ?? throw new LegalBuildException('download.json: no arm64-v8a APK.');
        $arm32 = $download->file('armeabi-v7a');
        $rows = '';
        $pending = false;
        foreach ($download->apks as $apk) {
            $pending = $pending || $apk['sha256'] === null;
            $rows .= '<tr><td>'.self::e($apk['file']).'</td><td><code>'
                .($apk['sha256'] === null ? '–' : self::e($apk['sha256'])).'</code></td></tr>';
        }
        $main = '<h1>'.self::e($appName).'</h1>'
            .'<p>A calm habit tracker for Android. Check in on your routines in a tap, see your streaks and '
            .'progress, and keep going offline: everything syncs to your own account when you are back online. '
            .'No ads, no social feed.</p>'
            .'<p><a class="button" href="'.self::e($download->latest($arm64)).'">Download for Android</a></p>'
            .($arm32 === null ? '' : '<p class="meta">An older phone? Get <a href="'.self::e($download->latest($arm32)).'">the 32-bit version</a>. '
                .'Or see <a href="'.self::e($download->releasesUrl.'/latest').'">every release</a>.</p>')
            .'<h2>How to install</h2><ol>'
            .'<li>Open the download on your phone. The file ends in <code>.apk</code>.</li>'
            .'<li>If Android asks, allow your browser or Files app to <strong>Install unknown apps</strong> '
            .'(Settings, Apps, Special app access, Install unknown apps), then go back.</li>'
            .'<li>Tap <strong>Install</strong>, then <strong>Open</strong>.</li>'
            .'<li>Later versions install the same way, over this one. Your habits stay.</li>'
            .'</ol>'
            .'<h2>Good to know</h2>'
            .'<p>Password reset emails can land in your spam folder. If one has not arrived after a few minutes, look there.</p>'
            .'<p>Read the <a href="../privacy/">Privacy</a> policy and the <a href="../terms/">Terms</a> before you create an account.</p>'
            .'<h2>Check the file (optional)</h2>'
            .'<p>Each file\'s SHA-256 fingerprint'.($pending ? ' (for a file not listed here yet, it is listed in the release notes)' : '').':</p>'
            .'<div class="table-wrap"><table><thead><tr><th>File</th><th>SHA-256</th></tr></thead><tbody>'.$rows.'</tbody></table></div>';

        return $this->page(title: 'Download · '.$appName, main: $main, appName: $appName, root: '../');
    }

    private function fill(string $html, LegalFacts $facts, string $slug): string
    {
        return (string) preg_replace_callback('/\{\{\s*([A-Za-z0-9_]+)\s*\}\}/', function (array $m) use ($facts, $slug): string {
            $key = $m[1];
            if (! $facts->has($key)) {
                throw new LegalBuildException("{$slug}: unknown token {{{$key}}}.");
            }
            $value = $facts->get($key);
            if ($value === null) {
                return '<span class="missing">[['.self::e($key).']]</span>';
            }

            return self::e($value);
        }, $html);
    }

    private function insertAfterH1(string $html, string $meta): string
    {
        $pos = strpos($html, '</h1>');

        return $pos === false ? $meta.$html : substr($html, 0, $pos + 5).$meta.substr($html, $pos + 5);
    }

    private function page(string $title, string $main, string $appName, string $root): string
    {
        $home = $root === '' ? './' : $root;

        return '<!doctype html>'."\n"
            .'<html lang="en"><head><meta charset="utf-8">'
            .'<meta name="viewport" content="width=device-width, initial-scale=1">'
            .'<title>'.self::e($title).'</title>'
            .'<style>'.self::css().'</style></head>'
            .'<body><a class="skip" href="#main">Skip to content</a>'
            .'<header><p class="brand">'.self::e($appName).'</p></header>'
            .'<main id="main">'.$main.'</main>'
            .'<footer><nav aria-label="Legal"><ul>'
            .'<li><a href="'.$root.'terms/">Terms</a></li>'
            .'<li><a href="'.$root.'privacy/">Privacy</a></li>'
            .'<li><a href="'.$home.'">Home</a></li>'
            .'</ul></nav></footer></body></html>'."\n";
    }

    public static function css(): string
    {
        $vars = fn (array $p) => implode('', array_map(
            fn (string $role, string $hex) => "--{$role}:{$hex};",
            array_keys($p),
            $p,
        ));

        return ':root{color-scheme:light dark;'.$vars(self::PALETTES['light']).'}'
            .'@media (prefers-color-scheme:dark){:root{'.$vars(self::PALETTES['dark']).'}}'
            .'*{box-sizing:border-box}'
            .'body{margin:0;background:var(--background);color:var(--ink);'
            .'font:1rem/1.6 system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif;'
            .'overflow-wrap:break-word}'
            .'header,main,footer{max-width:70ch;margin:0 auto;padding:0 1rem}'
            .'.brand{color:var(--muted);margin:1.5rem 0 0}'
            .'h1{font-size:2rem;line-height:1.25;margin:1rem 0 .5rem}'
            .'h2{font-size:1.25rem;line-height:1.35;margin:2rem 0 .5rem}'
            .'.meta{color:var(--muted)}'
            .'a{color:var(--link);text-underline-offset:.15em}'
            .':focus-visible{outline:3px solid var(--focus);outline-offset:2px}'
            .'.skip{position:absolute;left:-9999px;top:0}'
            .'.skip:focus{left:1rem;top:1rem;background:var(--surface);color:var(--link);padding:.5rem 1rem}'
            .'.table-wrap{overflow-x:auto;max-width:100%}'
            .'table{border-collapse:collapse;width:100%}'
            .'th,td{border:1px solid var(--border);padding:.5rem;text-align:left;vertical-align:top}'
            .'th{background:var(--surface)}'
            .'.missing{color:var(--warning);font-weight:600}'
            .'.draft{border-left:4px solid var(--warning);padding:.5rem 1rem;background:var(--surface)}'
            .'.button{display:inline-block;min-height:44px;line-height:44px;padding:0 1.5rem;border-radius:22px;'
            .'background:var(--link);color:var(--background);font-weight:600;text-decoration:none}'
            .'code{overflow-wrap:anywhere}'
            .'footer{margin-top:3rem;padding-bottom:2rem;border-top:1px solid var(--border)}'
            .'footer ul{list-style:none;padding:0;display:flex;flex-wrap:wrap;gap:1.5rem}'
            .'footer a{display:inline-block;min-height:44px;line-height:44px}'
            .'@media print{.skip,footer{display:none}body{background:#fff;color:#000}a{color:#000}'
            .'header,main{max-width:none}}';
    }

    private static function e(string $value): string
    {
        return htmlspecialchars($value, ENT_QUOTES | ENT_HTML5, 'UTF-8');
    }
}
