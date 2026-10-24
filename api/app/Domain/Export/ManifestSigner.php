<?php

namespace App\Domain\Export;

use InvalidArgumentException;

/**
 * A16 / A48: signs and verifies an export manifest. The signature is HMAC-SHA256 over the
 * canonical JSON of the manifest without `signature`, so it binds user_id, snapshot_seq and every
 * file hash. Keys rotate by kid; a manifest under a kid this server no longer holds fails.
 */
final readonly class ManifestSigner
{
    /**
     * @param  array<string, string>  $keys  kid => secret
     */
    public function __construct(private array $keys, private string $currentKid) {}

    /**
     * Parses EXPORT_SIGNING_KEYS ("kid:secret,kid2:secret2").
     *
     * @return array<string, string>
     */
    public static function parseKeys(string $config): array
    {
        $keys = [];
        foreach (array_filter(array_map(trim(...), explode(',', $config))) as $pair) {
            [$kid, $secret] = array_pad(explode(':', $pair, 2), 2, '');
            if ($kid !== '' && $secret !== '') {
                $keys[$kid] = $secret;
            }
        }

        return $keys;
    }

    /**
     * @param  array<string, mixed>  $manifest  without kid or signature
     * @return array<string, mixed> the manifest with kid and signature
     */
    public function sign(array $manifest): array
    {
        $secret = $this->keys[$this->currentKid] ?? throw new InvalidArgumentException('No signing key for the current kid.');
        $manifest['kid'] = $this->currentKid;
        unset($manifest['signature']);
        $manifest['signature'] = hash_hmac('sha256', CanonicalJson::encode($manifest), $secret);

        return $manifest;
    }

    /** @param array<string, mixed> $manifest */
    public function verify(array $manifest): ManifestCheck
    {
        $kid = $manifest['kid'] ?? null;
        $signature = $manifest['signature'] ?? null;
        if (! is_string($kid) || ! isset($this->keys[$kid])) {
            return ManifestCheck::UnknownKid;
        }
        if (! is_string($signature)) {
            return ManifestCheck::BadSignature;
        }
        unset($manifest['signature']);
        $expected = hash_hmac('sha256', CanonicalJson::encode($manifest), $this->keys[$kid]);

        return hash_equals($expected, $signature) ? ManifestCheck::Valid : ManifestCheck::BadSignature;
    }
}
