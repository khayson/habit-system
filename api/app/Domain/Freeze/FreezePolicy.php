<?php

namespace App\Domain\Freeze;

use DateTimeInterface;

/** Auto-freeze opt-in history. Prospective: an opt-in never reaches back to earlier misses. */
final readonly class FreezePolicy
{
    /** @var list<FreezePolicyVersion> */
    public array $versions;

    /**
     * @param  list<FreezePolicyVersion>  $versions
     */
    public function __construct(array $versions)
    {
        usort($versions, fn (FreezePolicyVersion $a, FreezePolicyVersion $b) => $a->effectiveAt <=> $b->effectiveAt);
        $this->versions = $versions;
    }

    public function enabledAt(DateTimeInterface $instant): bool
    {
        $enabled = false;
        foreach ($this->versions as $version) {
            if ($version->effectiveAt <= $instant) {
                $enabled = $version->enabled;
            }
        }

        return $enabled;
    }
}
