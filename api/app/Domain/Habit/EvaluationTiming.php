<?php

namespace App\Domain\Habit;

/** When a habit-day's success is decided (EXPANSION_PLAN §2). */
enum EvaluationTiming: string
{
    case Immediate = 'immediate';
    case AtPeriodClose = 'at_period_close';
}
