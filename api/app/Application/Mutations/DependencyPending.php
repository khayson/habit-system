<?php

namespace App\Application\Mutations;

use RuntimeException;

/**
 * The mutation refers to an entity this user does not have (yet), e.g. a log before its habit.
 * Retriable: nothing is written and no receipt is stored. A foreign id looks exactly the same
 * as a missing one (invariant 2).
 */
final class DependencyPending extends RuntimeException {}
