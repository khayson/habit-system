<?php

namespace App\Legal;

/**
 * A54: docs/legal/download.json, what the download page links to. The releases URL is the
 * GitHub Releases page (https); each APK has its ABI, its asset file name and, once a release
 * is built, its SHA-256 (null before the first release). Pure.
 */
final readonly class DownloadInfo
{
    /** @param list<array{abi: string, file: string, sha256: ?string}> $apks */
    private function __construct(public string $releasesUrl, public array $apks) {}

    public static function fromJson(string $json): self
    {
        $data = json_decode($json, true);
        if (! is_array($data) || ! is_string($data['releases_url'] ?? null) || ! is_array($data['apks'] ?? null)) {
            throw new LegalBuildException('download.json: expected releases_url and apks.');
        }
        $url = rtrim($data['releases_url'], '/');
        if (! preg_match('#^https://github\.com/[\w.-]+/[\w.-]+/releases$#', $url)) {
            throw new LegalBuildException('download.json: releases_url must be an https GitHub Releases URL.');
        }
        $apks = [];
        foreach ($data['apks'] as $apk) {
            $abi = $apk['abi'] ?? null;
            $file = $apk['file'] ?? null;
            $sha = $apk['sha256'] ?? null;
            if (! is_string($abi) || ! is_string($file) || ! preg_match('/^[\w.-]+\.apk$/', $file)) {
                throw new LegalBuildException('download.json: each APK needs an abi and a file name ending in .apk.');
            }
            if ($sha !== null && (! is_string($sha) || ! preg_match('/^[0-9a-f]{64}$/', $sha))) {
                throw new LegalBuildException("download.json: {$file} sha256 must be 64 lower-case hex digits or null.");
            }
            $apks[] = ['abi' => $abi, 'file' => $file, 'sha256' => $sha];
        }

        return new self($url, $apks);
    }

    /** The asset of the latest release, so the link never goes stale. */
    public function latest(string $file): string
    {
        return "{$this->releasesUrl}/latest/download/{$file}";
    }

    public function file(string $abi): ?string
    {
        foreach ($this->apks as $apk) {
            if ($apk['abi'] === $abi) {
                return $apk['file'];
            }
        }

        return null;
    }
}
