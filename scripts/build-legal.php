<?php

/*
 * A33: builds the public Terms of Service and Privacy Policy pages from docs/legal.
 *
 *   php scripts/build-legal.php --out=<dir> [--publish [--allow-draft]]
 *
 * Writes index.html, terms/index.html, privacy/index.html, 404.html and (A54) the download page
 * download/index.html. Without --publish, a fact not filled in or a draft document is a warning
 * (the gap shows as [[name]]). With --publish, either fails, unless --allow-draft: then every
 * draft page says so. Any failure exits non-zero.
 */

use App\Legal\DownloadInfo;
use App\Legal\LegalBuildException;
use App\Legal\LegalDocument;
use App\Legal\LegalFacts;
use App\Legal\PageBuilder;

$root = dirname(__DIR__);
require $root.'/api/vendor/autoload.php';

$options = getopt('', ['out:', 'publish', 'allow-draft']);
$out = $options['out'] ?? null;
$publish = array_key_exists('publish', $options);
$allowDraft = array_key_exists('allow-draft', $options);
if (! is_string($out) || $out === '') {
    fwrite(STDERR, "Usage: php scripts/build-legal.php --out=<dir> [--publish]\n");
    exit(2);
}

try {
    $read = function (string $file) use ($root): string {
        $text = @file_get_contents("{$root}/docs/legal/{$file}");
        if ($text === false) {
            throw new LegalBuildException("docs/legal/{$file} is missing.");
        }

        return $text;
    };
    $documents = [
        'terms' => LegalDocument::parse('terms', $read('terms.md')),
        'privacy' => LegalDocument::parse('privacy', $read('privacy.md')),
    ];
    $facts = LegalFacts::fromJson($read('facts.json'));
    $builder = new PageBuilder;
    $result = $builder->build($documents, $facts, $publish, $allowDraft);
    $result['files']['download/index.html'] = $builder->downloadPage($facts, DownloadInfo::fromJson($read('download.json')));

    foreach ($result['files'] as $path => $html) {
        $target = rtrim($out, '/\\').'/'.$path;
        if (! is_dir(dirname($target)) && ! mkdir(dirname($target), 0777, true) && ! is_dir(dirname($target))) {
            throw new LegalBuildException('Cannot create '.dirname($target).'.');
        }
        if (file_put_contents($target, $html) === false) {
            throw new LegalBuildException("Cannot write {$target}.");
        }
    }
    foreach ($result['warnings'] as $warning) {
        fwrite(STDERR, "warning: {$warning}\n");
    }
    fwrite(STDOUT, 'Built '.count($result['files'])." pages in {$out}".($publish ? ' (publish)' : '')."\n");
    exit(0);
} catch (LegalBuildException $e) {
    fwrite(STDERR, "error: {$e->getMessage()}\n");
    exit(1);
}
