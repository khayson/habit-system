<?php

namespace App\Domain\Period;

enum PeriodStatus: string
{
    case Complete = 'complete';

    /** Closed, failed, covered by a freeze: continuity kept, never a completion. */
    case Protected = 'protected';

    case Missed = 'missed';

    /** Open (current or future): never a failure. */
    case Pending = 'pending';
}
