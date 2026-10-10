<?php

namespace App\Domain\Avatar;

use DomainException;

/** A photo the pipeline will not process: 413 when the upload is too big, 422 otherwise. */
final class AvatarRejected extends DomainException
{
    public function __construct(public readonly int $status, string $message)
    {
        parent::__construct($message);
    }

    public static function tooLarge(): self
    {
        return new self(413, 'This photo is larger than 5 MB.');
    }

    public static function unusable(string $message = 'Choose a JPEG, PNG or WebP photo.'): self
    {
        return new self(422, $message);
    }
}
