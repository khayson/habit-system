<?php

namespace App\Legal;

use RuntimeException;

/** A33: the legal pages cannot be built (or published) as they stand. */
final class LegalBuildException extends RuntimeException {}
