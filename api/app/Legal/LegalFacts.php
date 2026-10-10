<?php

namespace App\Legal;

/**
 * A33: docs/legal/facts.json. Known keys only, each a string, an integer or null (not filled in
 * yet). Pure (no DB, no facades).
 */
final readonly class LegalFacts
{
    public const array KEYS = [
        'app_name', 'publisher', 'contact_email', 'postal_address', 'governing_law',
        'hosting_provider', 'hosting_region', 'minimum_age', 'log_retention_days',
    ];

    /** @param array<string, string|int|null> $values */
    private function __construct(private array $values) {}

    public static function fromJson(string $json): self
    {
        $data = json_decode($json, true);
        if (! is_array($data) || array_is_list($data) && $data !== []) {
            throw new LegalBuildException('facts.json: expected a JSON object.');
        }
        $unknown = array_diff(array_keys($data), self::KEYS);
        $missing = array_diff(self::KEYS, array_keys($data));
        if ($unknown !== []) {
            throw new LegalBuildException('facts.json: unknown key(s): '.implode(', ', $unknown).'.');
        }
        if ($missing !== []) {
            throw new LegalBuildException('facts.json: missing key(s): '.implode(', ', $missing).'.');
        }
        $values = [];
        foreach ($data as $key => $value) {
            if (! is_string($value) && ! is_int($value) && $value !== null) {
                throw new LegalBuildException("facts.json: {$key} must be a string, an integer or null.");
            }
            $values[(string) $key] = is_string($value) ? trim($value) : $value;
        }

        return new self($values);
    }

    public function has(string $key): bool
    {
        return array_key_exists($key, $this->values);
    }

    /** Null while the fact is not filled in. */
    public function get(string $key): ?string
    {
        $value = $this->values[$key] ?? null;

        return $value === null || $value === '' ? null : (string) $value;
    }

    /** @return list<string> facts still null (or empty) */
    public function missing(): array
    {
        return array_values(array_filter(self::KEYS, fn (string $key) => $this->get($key) === null));
    }
}
