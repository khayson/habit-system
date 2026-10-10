<?php

namespace App\Application\Accounts;

use RuntimeException;

/**
 * A20: the country codes profile.update accepts. Read from the server's copy,
 * api/resources/countries.json (config api.countries_path), which scripts/gen-countries.php
 * writes byte for byte equal to contract-fixtures/profile/countries.json and the app's asset.
 */
final class Countries
{
    /** @var array<string, string>|null code => English name */
    private static ?array $byCode = null;

    public static function isCode(string $code): bool
    {
        return array_key_exists($code, self::all());
    }

    /** @return array<string, string> */
    public static function all(): array
    {
        if (self::$byCode === null) {
            $path = config()->string('api.countries_path');
            $json = @file_get_contents($path);
            $rows = is_string($json) ? json_decode($json, true) : null;
            if (! is_array($rows) || $rows === []) {
                throw new RuntimeException("The country list is missing or unreadable: {$path}");
            }
            $byCode = [];
            foreach ($rows as $row) {
                $byCode[(string) $row['code']] = (string) $row['name'];
            }
            self::$byCode = $byCode;
        }

        return self::$byCode;
    }
}
