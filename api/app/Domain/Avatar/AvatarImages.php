<?php

namespace App\Domain\Avatar;

/** The pipeline's output: re-encoded squares by size, and the sha256 of the largest. */
final readonly class AvatarImages
{
    /** @param array<'sm'|'md'|'lg', string> $sizes */
    public function __construct(
        public array $sizes,
        public string $sha256,
        public string $extension,
        public string $contentType,
    ) {}
}
