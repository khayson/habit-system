<?php

namespace App\Legal;

/**
 * A33: one docs/legal/*.md file. Front matter is strict: exactly title, version, effective and
 * status; dates are real YYYY-MM-DD dates; status is draft or final. Pure (no DB, no facades).
 */
final readonly class LegalDocument
{
    public const array KEYS = ['title', 'version', 'effective', 'status'];

    private function __construct(
        public string $slug,
        public string $title,
        public string $version,
        public string $effective,
        public string $status,
        public string $body,
    ) {}

    public static function parse(string $slug, string $markdown): self
    {
        $text = str_replace("\r\n", "\n", $markdown);
        if (! preg_match('/\A---\n(.*?)\n---\n(.*)\z/s', $text, $m)) {
            throw new LegalBuildException("{$slug}: missing front matter (--- ... ---).");
        }
        $fields = [];
        foreach (explode("\n", trim($m[1])) as $line) {
            if (! preg_match('/^([a-z_]+):\s*(.*)$/', $line, $kv)) {
                throw new LegalBuildException("{$slug}: unreadable front matter line \"{$line}\".");
            }
            if (array_key_exists($kv[1], $fields)) {
                throw new LegalBuildException("{$slug}: front matter key \"{$kv[1]}\" appears twice.");
            }
            $fields[$kv[1]] = trim($kv[2]);
        }
        $unknown = array_diff(array_keys($fields), self::KEYS);
        $missing = array_diff(self::KEYS, array_keys($fields));
        if ($unknown !== []) {
            throw new LegalBuildException("{$slug}: unknown front matter key(s): ".implode(', ', $unknown).'.');
        }
        if ($missing !== []) {
            throw new LegalBuildException("{$slug}: missing front matter key(s): ".implode(', ', $missing).'.');
        }
        foreach (['version', 'effective'] as $key) {
            if (! self::isDate($fields[$key])) {
                throw new LegalBuildException("{$slug}: {$key} must be a real YYYY-MM-DD date, got \"{$fields[$key]}\".");
            }
        }
        if (! in_array($fields['status'], ['draft', 'final'], true)) {
            throw new LegalBuildException("{$slug}: status must be draft or final, got \"{$fields['status']}\".");
        }
        if ($fields['title'] === '') {
            throw new LegalBuildException("{$slug}: title is empty.");
        }

        return new self($slug, $fields['title'], $fields['version'], $fields['effective'], $fields['status'], $m[2]);
    }

    public static function isDate(string $value): bool
    {
        if (! preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $value, $d)) {
            return false;
        }

        return checkdate((int) $d[2], (int) $d[3], (int) $d[1]);
    }
}
