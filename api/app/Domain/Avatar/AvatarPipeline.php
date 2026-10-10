<?php

namespace App\Domain\Avatar;

use finfo;
use GdImage;

/**
 * A20: turns an uploaded photo into three re-encoded squares (96 / 160 / 320 px). Pure: no DB,
 * no facades, no clock; GD and finfo only.
 *
 * Order: size cap → type by content (finfo; extension and client MIME are never seen) → header
 * dimensions read without decoding → pixel cap → memory estimate → decode → EXIF orientation
 * (JPEG) → centre square → resample → encode. Encoding from pixels drops every metadata segment
 * and anything appended to the file; the original bytes are never returned.
 *
 * ASSUMPTION(A3b-avatar-format): WebP; JPEG only where GD has no WebP (the extension follows).
 */
final readonly class AvatarPipeline
{
    public const int MAX_BYTES = 5 * 1024 * 1024;

    public const int MAX_PIXELS = 25_000_000;

    /**
     * Memory estimate per pixel. GD holds a truecolor pixel in 4 bytes (measured: a 25 MP decode
     * takes 97.7 MB); one more covers the small resampled copies. A 90° turn (orientations 5 to
     * 8) needs a second full copy (measured peak 195 MB), so it counts 9.
     */
    public const int BYTES_PER_PIXEL = 5;

    public const int ROTATED_BYTES_PER_PIXEL = 9;

    public const array SIZES = ['sm' => 96, 'md' => 160, 'lg' => 320];

    private const array TYPES = [
        'image/jpeg' => IMAGETYPE_JPEG,
        'image/png' => IMAGETYPE_PNG,
        'image/webp' => IMAGETYPE_WEBP,
    ];

    /**
     * @param  int  $memoryLimit  bytes; -1 means no limit
     * @param  \Closure(): int  $memoryUsage  bytes in use now
     */
    public function __construct(
        private int $memoryLimit,
        private \Closure $memoryUsage,
        private bool $webp,
    ) {}

    /** The limits of this PHP process. */
    public static function forRuntime(): self
    {
        return new self(
            self::parseBytes((string) ini_get('memory_limit')),
            fn (): int => memory_get_usage(),
            (bool) (gd_info()['WebP Support'] ?? false),
        );
    }

    public function process(string $bytes): AvatarImages
    {
        if (strlen($bytes) > self::MAX_BYTES) {
            throw AvatarRejected::tooLarge();
        }
        $mime = (new finfo(FILEINFO_MIME_TYPE))->buffer($bytes);
        $type = self::TYPES[$mime] ?? throw AvatarRejected::unusable();

        // Header only: no pixel is decoded yet.
        $info = @getimagesizefromstring($bytes);
        if ($info === false || $info[2] !== $type || $info[0] < 1 || $info[1] < 1) {
            throw AvatarRejected::unusable();
        }
        [$width, $height] = [(int) $info[0], (int) $info[1]];
        if ($width * $height > self::MAX_PIXELS) {
            throw AvatarRejected::unusable('This photo has too many pixels. Choose one under 25 megapixels.');
        }
        $orientation = $type === IMAGETYPE_JPEG ? JpegOrientation::read($bytes) : 1;
        $perPixel = $orientation >= 5 ? self::ROTATED_BYTES_PER_PIXEL : self::BYTES_PER_PIXEL;
        if ($this->memoryLimit !== -1 && $width * $height * $perPixel > $this->memoryLimit - ($this->memoryUsage)()) {
            throw AvatarRejected::unusable('This photo is too large to process. Choose a smaller one.');
        }

        $image = @imagecreatefromstring($bytes);
        if ($image === false) {
            throw AvatarRejected::unusable('This photo could not be read. Choose another.');
        }
        $image = self::orient($image, $orientation);

        $side = min(imagesx($image), imagesy($image));
        $x = intdiv(imagesx($image) - $side, 2);
        $y = intdiv(imagesy($image) - $side, 2);
        $sizes = [];
        foreach (self::SIZES as $name => $px) {
            $sizes[$name] = $this->encode($image, $x, $y, $side, $px);
        }
        unset($image);

        return new AvatarImages(
            $sizes,
            hash('sha256', $sizes['lg']),
            $this->webp ? 'webp' : 'jpg',
            $this->webp ? 'image/webp' : 'image/jpeg',
        );
    }

    /** Applies EXIF orientation 2..8 so the result displays upright. Only 5..8 copy the image. */
    private static function orient(GdImage $image, int $orientation): GdImage
    {
        if (in_array($orientation, [2, 5, 7], true)) {
            imageflip($image, IMG_FLIP_HORIZONTAL);
        }
        if ($orientation === 4) {
            imageflip($image, IMG_FLIP_VERTICAL);
        }
        if ($orientation === 3) {
            imageflip($image, IMG_FLIP_BOTH); // 180° in place, no second copy
        }
        // A quarter turn needs a copy; imagerotate turns counter-clockwise.
        $angle = match ($orientation) {
            6, 7 => 270,
            5, 8 => 90,
            default => 0,
        };
        if ($angle !== 0) {
            $rotated = imagerotate($image, $angle, 0);
            if ($rotated !== false) {
                $image = $rotated;
            }
        }

        return $image;
    }

    /** @param positive-int $px */
    private function encode(GdImage $source, int $x, int $y, int $side, int $px): string
    {
        $target = imagecreatetruecolor($px, $px);
        if ($this->webp) {
            imagealphablending($target, false);
            imagesavealpha($target, true);
            imagefill($target, 0, 0, (int) imagecolorallocatealpha($target, 0, 0, 0, 127));
        } else {
            imagefill($target, 0, 0, (int) imagecolorallocate($target, 255, 255, 255));
        }
        imagecopyresampled($target, $source, 0, 0, $x, $y, $px, $px, $side, $side);

        ob_start();
        $this->webp ? imagewebp($target, null, 85) : imagejpeg($target, null, 85);

        return (string) ob_get_clean();
    }

    /** "512M" → bytes; "-1" stays -1. */
    public static function parseBytes(string $value): int
    {
        $value = trim($value);
        if ($value === '' || $value === '-1') {
            return -1;
        }
        $number = (int) $value;

        return match (strtoupper(substr($value, -1))) {
            'G' => $number * 1024 ** 3,
            'M' => $number * 1024 ** 2,
            'K' => $number * 1024,
            default => $number,
        };
    }
}
