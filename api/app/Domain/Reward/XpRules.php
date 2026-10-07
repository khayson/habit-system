<?php

namespace App\Domain\Reward;

use InvalidArgumentException;

/**
 * 10 XP per completed habit-day through one stable entitlement (amendments 0.2):
 * completion +10; reversal -10; recompletion +10 only after a reversal; anything else 0.
 * Toggling therefore nets zero, and partial progress or later increments earn nothing.
 */
final class XpRules
{
    public const int XP_PER_COMPLETION = 10;

    public const int XP_PER_LEVEL = 100;

    /**
     * @param  XpEntitlement|null  $current  the habit-day's entitlement, if one was ever created
     * @param  bool  $completed  whether the habit-day now meets its effective target
     */
    public function transition(?XpEntitlement $current, bool $completed): XpTransition
    {
        if ($current === null) {
            return $completed
                ? new XpTransition(new XpEntitlement(XpEntitlementState::Active, 1), self::XP_PER_COMPLETION, 'completion')
                : new XpTransition(null, 0, null);
        }

        return match (true) {
            $current->state === XpEntitlementState::Active && ! $completed => new XpTransition(
                new XpEntitlement(XpEntitlementState::Reversed, $current->revision + 1), -self::XP_PER_COMPLETION, 'reversal',
            ),
            $current->state === XpEntitlementState::Reversed && $completed => new XpTransition(
                new XpEntitlement(XpEntitlementState::Active, $current->revision + 1), self::XP_PER_COMPLETION, 'recompletion',
            ),
            default => new XpTransition($current, 0, null),
        };
    }

    /** level = 1 + floor(xp / 100); progress = xp mod 100; next threshold = 100 x level. */
    public function level(int $xp): LevelProgress
    {
        if ($xp < 0) {
            throw new InvalidArgumentException('XP is never negative.');
        }
        $level = 1 + intdiv($xp, self::XP_PER_LEVEL);

        return new LevelProgress($xp, $level, $xp % self::XP_PER_LEVEL, self::XP_PER_LEVEL * $level);
    }
}
