<?php

namespace App\Domain\Habit;

/** How values roll up in insights (EXPANSION_PLAN §2). */
enum Aggregation: string
{
    case Count = 'count';
    case Sum = 'sum';
}
