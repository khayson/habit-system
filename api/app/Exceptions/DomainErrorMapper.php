<?php

namespace App\Exceptions;

use App\Domain\Calendar\DayResolutionException;
use App\Domain\Habit\InvalidHabitValue;
use App\Domain\Habit\UnknownHabitType;
use App\Domain\Habit\UnsupportedOperation;
use Throwable;

/**
 * The one place domain exceptions become API error codes (A28, docs/api-error-codes.md). The
 * HTTP renderer and /sync acks both go through it. Messages are fixed and user-safe; domain
 * exception text never reaches the client.
 */
final class DomainErrorMapper
{
    /** code => message, for every code this mapper can emit. */
    public const array CODES = [
        'future_event' => 'This check-in is dated in the future. Check the device clock and try again.',
        'event_too_old' => 'This check-in is more than 90 days old, so it can no longer be synced.',
        'timezone_context_mismatch' => 'This check-in used a different time zone. Review it before it is saved.',
        'backdate_future' => 'That date has not happened yet.',
        'backdate_too_old' => 'Past check-ins can go back up to 30 days.',
        'unsupported_type' => 'This app version cannot use that kind of habit. Update the app to continue.',
        'unsupported_operation' => 'This change is not supported for this habit.',
        'invalid_value' => 'Check the value and try again.',
    ];

    /** Null when the exception is not a domain error. */
    public static function toApiException(Throwable $e): ?ApiException
    {
        $code = match (true) {
            $e instanceof DayResolutionException => $e->reason,
            $e instanceof UnknownHabitType => 'unsupported_type',
            $e instanceof UnsupportedOperation => 'unsupported_operation',
            $e instanceof InvalidHabitValue => 'invalid_value',
            default => null,
        };
        if ($code === null) {
            return null;
        }
        if (! isset(self::CODES[$code])) {
            // A domain reason without an API code is a bug: fail loudly as a server error.
            return null;
        }

        return new ApiException(422, $code, self::CODES[$code]);
    }
}
