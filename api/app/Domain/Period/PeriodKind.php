<?php

namespace App\Domain\Period;

enum PeriodKind: string
{
    /** daily, weekdays, interval: one scheduled local date, key d:YYYY-MM-DD (A3). */
    case Day = 'day';

    /** weekly_count: Monday-Sunday local week, key w:<Monday> (A3). */
    case Week = 'week';
}
