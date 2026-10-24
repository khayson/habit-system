<?php

namespace App\Domain\Export;

enum ManifestCheck: string
{
    case Valid = 'valid';
    case BadSignature = 'signature';
    case UnknownKid = 'unknown_kid';
}
