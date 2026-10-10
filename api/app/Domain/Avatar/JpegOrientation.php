<?php

namespace App\Domain\Avatar;

/**
 * Reads the EXIF orientation tag (1..8) of a JPEG without ext-exif. Bounded: walks segment
 * headers only until SOS, reads at most 64 KB of an APP1, checks every length and offset, and
 * never throws. Anything malformed, truncated or absent is orientation 1. JPEG only: WebP and
 * PNG orientation is ignored.
 */
final class JpegOrientation
{
    private const int MAX_APP1 = 65536;

    private const int MAX_SEGMENTS = 512;

    private const int MAX_IFD_ENTRIES = 256;

    public static function read(string $bytes): int
    {
        $length = strlen($bytes);
        if ($length < 4 || $bytes[0] !== "\xFF" || $bytes[1] !== "\xD8") {
            return 1;
        }
        $pos = 2;
        for ($i = 0; $i < self::MAX_SEGMENTS && $pos + 4 <= $length; $i++) {
            if ($bytes[$pos] !== "\xFF") {
                return 1;
            }
            $marker = ord($bytes[$pos + 1]);
            if ($marker === 0xFF) {
                $pos++; // fill byte

                continue;
            }
            if ($marker === 0x01 || ($marker >= 0xD0 && $marker <= 0xD7)) {
                $pos += 2; // markers without a length

                continue;
            }
            if ($marker === 0xDA || $marker === 0xD9) {
                return 1; // image data starts (or ends): no orientation before it
            }
            $segment = self::u16($bytes, $pos + 2, false);
            if ($segment < 2 || $pos + 2 + $segment > $length) {
                return 1;
            }
            if ($marker === 0xE1 && $segment - 2 <= self::MAX_APP1) {
                $data = substr($bytes, $pos + 4, $segment - 2);
                if (str_starts_with($data, "Exif\0\0")) {
                    return self::fromTiff(substr($data, 6)) ?? 1;
                }
            }
            $pos += 2 + $segment;
        }

        return 1;
    }

    private static function fromTiff(string $tiff): ?int
    {
        $length = strlen($tiff);
        if ($length < 8) {
            return null;
        }
        $little = match (substr($tiff, 0, 2)) {
            'II' => true,
            'MM' => false,
            default => null,
        };
        if ($little === null || self::u16($tiff, 2, $little) !== 42) {
            return null;
        }
        $ifd = self::u32($tiff, 4, $little);
        if ($ifd < 8 || $ifd + 2 > $length) {
            return null;
        }
        $count = min(self::u16($tiff, $ifd, $little), self::MAX_IFD_ENTRIES);
        for ($i = 0; $i < $count; $i++) {
            $entry = $ifd + 2 + 12 * $i;
            if ($entry + 12 > $length) {
                return null;
            }
            if (self::u16($tiff, $entry, $little) === 0x0112) {
                // SHORT (type 3), one value, stored in the first two bytes of the value field.
                if (self::u16($tiff, $entry + 2, $little) !== 3) {
                    return null;
                }
                $value = self::u16($tiff, $entry + 8, $little);

                return $value >= 1 && $value <= 8 ? $value : null;
            }
        }

        return null;
    }

    /** -1 when the read would leave the buffer (unpack would warn or throw). */
    private static function u16(string $b, int $at, bool $little): int
    {
        if ($at < 0 || $at + 2 > strlen($b)) {
            return -1;
        }
        $v = unpack($little ? 'v' : 'n', $b, $at);

        return is_array($v) ? (int) $v[1] : -1;
    }

    private static function u32(string $b, int $at, bool $little): int
    {
        if ($at < 0 || $at + 4 > strlen($b)) {
            return -1;
        }
        $v = unpack($little ? 'V' : 'N', $b, $at);

        return is_array($v) ? (int) $v[1] : -1;
    }
}
