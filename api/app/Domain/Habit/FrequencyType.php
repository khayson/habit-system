<?php

namespace App\Domain\Habit;

enum FrequencyType: string
{
    case Daily = 'daily';
    case Weekdays = 'weekdays';
    case WeeklyCount = 'weekly_count';
    case Interval = 'interval';
}
