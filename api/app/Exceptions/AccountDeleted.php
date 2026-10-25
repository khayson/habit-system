<?php

namespace App\Exceptions;

/**
 * A49: the account was deleted after this request authenticated. Raised under the user lock, so a
 * writer that waited for a deletion to commit writes nothing; answered as an ended session (401).
 */
final class AccountDeleted extends ApiException
{
    public function __construct()
    {
        parent::__construct(401, 'unauthenticated', 'Sign in to continue.');
    }
}
