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
     * is the app's accent, its text-action colour (A56); `warning` marks a fact not filled in yet.
     */
    public const array PALETTES = [
        'light' => [
            'background' => '#F7F2EF', 'surface' => '#FFFFFF', 'ink' => '#1E1F22', 'muted' => '#646464',
            'border' => '#ECE4DE', 'link' => '#682E08', 'focus' => '#292C31', 'warning' => '#87470A',
        ],
        'dark' => [
            'background' => '#1A1411', 'surface' => '#262019', 'ink' => '#F7F2EF', 'muted' => '#C2B8B0',
            'border' => '#3E342D', 'link' => '#E8A070', 'focus' => '#F7F2EF', 'warning' => '#FFD9A0',
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
                main: '<article class="doc">'.$this->insertAfterH1($body, $meta.$draft).'</article>',
                appName: $appName,
                root: '../',
            );
        }

        $files['index.html'] = $this->page(
            title: $appName.' · A calm habit tracker',
            main: $this->home($appName, $documents, $draft),
            appName: $appName,
            root: '',
        );
        $files['404.html'] = $this->page(
            title: 'Page not found · '.$appName,
            main: '<section class="doc"><h1>Page not found</h1><p>That page is not here. <a href="./">Go to the home page</a>.</p></section>',
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
        $main = '<section class="hero small"><div class="hero-text">'
            .'<p class="eyebrow">Android · free</p>'
            .'<h1>Download '.self::e($appName).'</h1>'
            .'<p class="lead">A calm habit tracker. Check in on your routines in a tap, see your streaks and '
            .'progress, and keep going offline: everything syncs to your own account when you are back online. '
            .'No ads, no social feed.</p>'
            .'<p class="actions"><a class="button" href="'.self::e($download->latest($arm64)).'">Download for Android</a></p>'
            .($arm32 === null ? '' : '<p class="meta">An older phone? Get <a href="'.self::e($download->latest($arm32)).'">the 32-bit version</a>. '
                .'Or see <a href="'.self::e($download->releasesUrl.'/latest').'">every release</a>.</p>')
            .'</div></section>'
            .'<section class="band"><h2>How to install</h2><ol class="steps">'
            .'<li><span class="step" aria-hidden="true">1</span><div><h3>Open the file</h3><p>Open the download on your phone. The file ends in <code>.apk</code>.</p></div></li>'
            .'<li><span class="step" aria-hidden="true">2</span><div><h3>Allow the install</h3><p>If Android asks, allow your browser or Files app to <strong>Install unknown apps</strong> '
            .'(Settings, Apps, Special app access, Install unknown apps), then go back.</p></div></li>'
            .'<li><span class="step" aria-hidden="true">3</span><div><h3>Install and open</h3><p>Tap <strong>Install</strong>, then <strong>Open</strong>.</p></div></li>'
            .'<li><span class="step" aria-hidden="true">4</span><div><h3>Later updates</h3><p>Later versions install the same way, over this one. Your habits stay.</p></div></li>'
            .'</ol></section>'
            .'<section class="band"><h2>Good to know</h2><div class="cards two">'
            .'<div class="card"><h3>Reset emails</h3><p>Password reset emails can land in your spam folder. If one has not arrived after a few minutes, look there.</p></div>'
            .'<div class="card"><h3>Before you sign up</h3><p>Read the <a href="../privacy/">Privacy</a> policy and the <a href="../terms/">Terms</a> before you create an account.</p></div>'
            .'</div></section>'
            .'<section class="band"><h2>Check the file (optional)</h2>'
            .'<p>Each file\'s SHA-256 fingerprint'.($pending ? ' (for a file not listed here yet, it is listed in the release notes)' : '').':</p>'
            .'<div class="table-wrap"><table><thead><tr><th>File</th><th>SHA-256</th></tr></thead><tbody>'.$rows.'</tbody></table></div></section>';

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

    /**
     * The site's home page: what the app is, a drawn glimpse of Today (no image), what it does,
     * the privacy promise, and the documents. No script, font, image or tracker.
     *
     * @param  array<string, LegalDocument>  $documents
     */
    private function home(string $appName, array $documents, string $draft): string
    {
        $docs = '';
        foreach ($documents as $slug => $document) {
            $docs .= '<a class="card link" href="'.$slug.'/"><h3>'.self::e($document->title).'</h3>'
                .'<p class="meta">Version '.self::e($document->version).'</p></a>';
        }
        $icon = fn (string $path) => '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="'.$path.'"/></svg>';
        $icons = [
            'check' => 'M5 12l4 4 10-10', 'chart' => 'M5 19V11M12 19V5M19 19v-6', 'cloud' => 'M7 18h10a4 4 0 0 0 0-8 6 6 0 0 0-11.5 1.5A3.3 3.3 0 0 0 7 18z',
            'calendar' => 'M4 6h16v14H4zM4 10h16M9 3v4M15 3v4', 'bell' => 'M6 16V11a6 6 0 0 1 12 0v5l2 2H4zM10 20h4', 'export' => 'M12 4v11M7 10l5 5 5-5M5 20h14',
            'drop' => 'M12 3s6 6.5 6 11a6 6 0 0 1-12 0c0-4.5 6-11 6-11z', 'leaf' => 'M5 19c0-8 6-14 14-14 0 8-6 14-14 14zM5 19l7-7', 'book' => 'M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2zM4 5v16',
        ];
        $feature = fn (string $tile, string $iconKey, string $title, string $text) => '<div class="card feature"><span class="tile '.$tile.'" aria-hidden="true">'.$icon($icons[$iconKey]).'</span>'
            .'<h3>'.$title.'</h3><p>'.$text.'</p></div>';
        $row = fn (string $tile, string $iconKey, string $name, string $line, bool $done) => '<div class="row"><span class="dot'.($done ? ' done' : '').'"></span>'
            .'<span class="tile '.$tile.'">'.$icon($icons[$iconKey]).'</span><span><b>'.$name.'</b><br><span class="meta">'.$line.'</span></span></div>';

        return '<section class="hero"><div class="hero-text">'
            .'<p class="eyebrow">For Android</p>'
            .'<h1>'.self::e($appName).'</h1>'
            .$draft
            .'<p class="lead">A calm habit tracker. Check in with a tap, watch your streaks grow, and keep going '
            .'offline. Your routines, at your pace.</p>'
            .'<p class="actions"><a class="button" href="download/">Download for Android</a> <a class="button ghost" href="privacy/">How we treat your data</a></p>'
            .'</div>'
            .'<div class="phone" role="img" aria-label="A drawing of the Today screen: three habits, two of them checked in.">'
            .'<p class="phone-title">Good morning</p>'
            .'<div class="week"><span>M</span><span class="on">T</span><span>W</span><span>T</span><span>F</span><span>S</span><span>S</span></div>'
            .$row('peach', 'drop', 'Drink water', '2 of 2 L · streak 6 days', true)
            .$row('lime', 'leaf', 'Meditate', '10 min · streak 4 days', true)
            .$row('pink', 'book', 'Read', '0 of 20 pages', false)
            .'</div></section>'
            .'<section class="band"><h2>What it does</h2><div class="cards three">'
            .$feature('peach', 'check', 'One-tap check-ins', 'Yes or no, an amount, or a timer: each habit records the way you do it.')
            .$feature('lime', 'chart', 'Streaks and insights', 'See your consistency by week and month, with a gentle summary you can share if you want to.')
            .$feature('pink', 'cloud', 'Works offline', 'Everything is saved on your phone first and syncs to your own account when you are back online.')
            .$feature('lime', 'calendar', 'Your schedule', 'Every day, chosen days, a number of times a week, or every few days.')
            .$feature('peach', 'bell', 'Gentle reminders', 'Reminders are scheduled on your phone. No pressure, no guilt.')
            .$feature('pink', 'export', 'Yours to take', 'Export everything you have recorded, or delete your account, from inside the app.')
            .'</div></section>'
            .'<section class="band promise"><h2>Private by design</h2>'
            .'<p>No ads, no social feed and no tracking in the app. Your habits are visible only to you. '
            .'Read exactly what we keep, and why, in the privacy policy.</p></section>'
            .'<section class="band"><h2>Documents</h2><div class="cards two">'.$docs.'</div></section>';
    }

    private function page(string $title, string $main, string $appName, string $root): string
    {
        $home = $root === '' ? './' : $root;
        $logo = '<svg width="32" height="32" viewBox="0 0 48 48" aria-hidden="true"><circle cx="24" cy="24" r="24" fill="#2F7B45"/>'
            .'<rect x="13" y="13" width="22" height="9" rx="4" fill="#E7F4E7" transform="rotate(-8 24 17)"/>'
            .'<rect x="12" y="18" width="24" height="9" rx="4" fill="#8BD799"/><rect x="11" y="23" width="26" height="14" rx="5" fill="#fff"/>'
            .'<path d="M17 30l4 4 9-9" stroke="#2F7B45" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>';

        return '<!doctype html>'."\n"
            .'<html lang="en"><head><meta charset="utf-8">'
            .'<meta name="viewport" content="width=device-width, initial-scale=1">'
            .'<title>'.self::e($title).'</title>'
            .'<style>'.self::css().'</style></head>'
            .'<body><a class="skip" href="#main">Skip to content</a>'
            .'<header class="site"><a class="brand" href="'.$home.'">'.$logo.'<span>'.self::e($appName).'</span></a>'
            .'<nav aria-label="Site"><a href="'.$root.'download/">Download</a></nav></header>'
            .'<main id="main">'.$main.'</main>'
            .'<footer><nav aria-label="Legal"><ul>'
            .'<li><a href="'.$root.'terms/">Terms</a></li>'
            .'<li><a href="'.$root.'privacy/">Privacy</a></li>'
            .'<li><a href="'.$home.'">Home</a></li>'
            .'</ul></nav><p class="meta">Made by Khay Studios. This site sets no cookies and runs no trackers.</p></footer></body></html>'."\n";
    }

    public static function css(): string
    {
        $vars = fn (array $p) => implode('', array_map(
            fn (string $role, string $hex) => "--{$role}:{$hex};",
            array_keys($p),
            $p,
        ));

        // The app's pastel tiles and orange (A56), as decoration beside text only.
        return ':root{color-scheme:light dark;'.$vars(self::PALETTES['light']).'--peach:#FFD5BC;--lime:#E5EFBA;--pink:#FFDEF8;--orange:#FF7616;--dark:#292C31;--peach-ink:#B14E0C;--lime-ink:#5A7016;--pink-ink:#A33A8B}'
            .'@media (prefers-color-scheme:dark){:root{'.$vars(self::PALETTES['dark']).'--peach:#4A2E1E;--lime:#343F1C;--pink:#47253F;--orange:#FF8A3D;--dark:#F7F2EF;--peach-ink:#FFB98A;--lime-ink:#C9DB7E;--pink-ink:#F2A8DD}}'
            .'*{box-sizing:border-box}'
            .'body{margin:0;background:var(--background);color:var(--ink);'
            .'font:1rem/1.6 system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif;'
            .'overflow-wrap:break-word}'
            .'header.site,main,footer{max-width:72rem;margin:0 auto;padding:0 1.25rem}'
            .'header.site{display:flex;align-items:center;justify-content:space-between;gap:1rem;padding-top:1rem;padding-bottom:1rem}'
            .'.brand{display:inline-flex;align-items:center;gap:.6rem;color:var(--ink);font-weight:800;text-decoration:none;min-height:44px}'
            .'header.site nav a{display:inline-flex;align-items:center;min-height:44px;padding:0 1.1rem;border-radius:999px;background:var(--surface);color:var(--ink);font-weight:700;text-decoration:none}'
            .'h1{font-size:2.5rem;line-height:1.15;margin:.5rem 0 .75rem;letter-spacing:-.01em}'
            .'h2{font-size:1.5rem;line-height:1.3;margin:0 0 1rem}'
            .'h3{font-size:1.125rem;line-height:1.35;margin:.25rem 0 .35rem}'
            .'.meta{color:var(--muted)}'
            .'a{color:var(--link);text-underline-offset:.15em}'
            .':focus-visible{outline:3px solid var(--focus);outline-offset:2px}'
            .'.skip{position:absolute;left:-9999px;top:0}'
            .'.skip:focus{left:1rem;top:1rem;background:var(--surface);color:var(--link);padding:.5rem 1rem}'
            .'.doc{max-width:70ch;margin:1rem auto 0;background:var(--surface);border-radius:1.5rem;padding:1.5rem 1.5rem 2rem}'
            .'.doc h2{margin-top:2rem}'
            .'.doc .meta{display:inline-block;background:var(--background);border-radius:999px;padding:.15rem .8rem}'
            .'.hero{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(18rem,100%),1fr));gap:2rem;align-items:center;padding:2rem 0 3rem}'
            .'.hero.small{grid-template-columns:1fr;padding-bottom:1rem}'
            .'.eyebrow{display:inline-block;margin:0;padding:.2rem .8rem;border-radius:999px;background:var(--lime);color:var(--ink);font-weight:700}'
            .'.lead{font-size:1.25rem;color:var(--ink);max-width:36rem}'
            .'.actions{display:flex;flex-wrap:wrap;gap:.75rem;margin:1.25rem 0}'
            .'.button{display:inline-flex;align-items:center;min-height:48px;padding:0 1.6rem;border-radius:999px;'
            .'background:var(--orange);color:#1E1F22;font-weight:700;text-decoration:none}'
            .'.button.ghost{background:var(--surface);color:var(--ink)}'
            .'.phone{justify-self:center;width:100%;max-width:22rem;background:var(--background);border:.6rem solid var(--dark);border-radius:2.5rem;padding:1.25rem 1rem 1.5rem;box-shadow:0 1.5rem 3rem rgba(30,31,34,.12)}'
            .'.phone-title{font-size:1.5rem;font-weight:800;margin:.25rem .25rem .75rem}'
            .'.week{display:grid;grid-template-columns:repeat(7,1fr);gap:.3rem;margin-bottom:1rem}'
            .'.week span{display:grid;place-items:center;aspect-ratio:1;border-radius:50%;background:var(--surface);font-weight:700}'
            .'.week .on{background:var(--dark);color:var(--background)}'
            .'.row{display:flex;align-items:center;gap:.75rem;background:var(--surface);border-radius:1.25rem;padding:.75rem;margin-top:.6rem}'
            .'.dot{flex:none;width:1.4rem;height:1.4rem;border-radius:50%;border:2px solid var(--muted)}'
            .'.dot.done{border:0;background:var(--orange)}'
            .'.tile{flex:none;display:inline-grid;place-items:center;width:2.75rem;height:2.75rem;border-radius:.9rem}'
            .'.tile svg{width:1.4rem;height:1.4rem;fill:none;stroke:currentColor;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}'
            .'.tile.peach{background:var(--peach);color:var(--peach-ink)}.tile.lime{background:var(--lime);color:var(--lime-ink)}.tile.pink{background:var(--pink);color:var(--pink-ink)}'
            .'.band{padding:2rem 0}'
            .'.cards{display:grid;gap:1rem}'
            .'.cards.three{grid-template-columns:repeat(auto-fit,minmax(min(20rem,100%),1fr))}'
            .'.cards.two{grid-template-columns:repeat(auto-fit,minmax(min(20rem,100%),1fr))}'
            .'.card{background:var(--surface);border-radius:1.5rem;padding:1.25rem 1.5rem}'
            .'.card p{margin:.25rem 0 0}'
            .'.card.link{display:block;color:var(--ink);text-decoration:none}'
            .'.card.link h3{color:var(--link);text-decoration:underline;text-underline-offset:.15em}'
            .'.feature .tile{margin-bottom:.5rem}'
            .'.promise{background:var(--surface);border-radius:1.5rem;padding:2rem 1.5rem;margin:1rem 0}'
            .'.promise p{max-width:70ch;margin:0}'
            .'.steps{list-style:none;padding:0;margin:0;display:grid;gap:1rem;grid-template-columns:repeat(auto-fit,minmax(min(15rem,100%),1fr))}'
            .'.steps li{display:flex;gap:1rem;background:var(--surface);border-radius:1.5rem;padding:1.25rem}'
            .'.steps p{margin:0}'
            .'.step{flex:none;display:grid;place-items:center;width:2.5rem;height:2.5rem;border-radius:50%;background:var(--dark);color:var(--background);font-weight:800}'
            .'.table-wrap{overflow-x:auto;max-width:100%}'
            .'table{border-collapse:collapse;width:100%;background:var(--surface)}'
            .'th,td{border:1px solid var(--border);padding:.5rem;text-align:left;vertical-align:top}'
            .'th{background:var(--background)}'
            .'.missing{color:var(--warning);font-weight:600}'
            .'.draft{border-left:4px solid var(--warning);padding:.5rem 1rem;background:var(--background);border-radius:.5rem}'
            .'code{overflow-wrap:anywhere}'
            .'footer{margin-top:3rem;padding-bottom:2rem;border-top:1px solid var(--border)}'
            .'footer ul{list-style:none;padding:0;display:flex;flex-wrap:wrap;gap:1.5rem}'
            .'footer a{display:inline-block;min-height:44px;line-height:44px}'
            .'@media print{.skip,footer,header.site nav,.phone{display:none}body{background:#fff;color:#000}a{color:#000}'
            .'header.site,main,.doc{max-width:none}.doc{padding:0}}';
    }

    private static function e(string $value): string
    {
        return htmlspecialchars($value, ENT_QUOTES | ENT_HTML5, 'UTF-8');
    }
}
