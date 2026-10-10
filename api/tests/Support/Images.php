<?php

namespace Tests\Support;

use GdImage;

/**
 * Phase 3b: test images built in code at test time (no binary fixtures). Small helpers only:
 * GD for real pixels, pack() for headers and metadata segments.
 */
final class Images
{
    /**
     * A JPEG of $width × $height. Without a painter it is one flat colour.
     *
     * @param  (callable(GdImage): void)|null  $paint
     */
    public static function jpeg(int $width, int $height, ?callable $paint = null): string
    {
        $image = self::canvas($width, $height, $paint);
        ob_start();
        imagejpeg($image, null, 90);

        return (string) ob_get_clean();
    }

    public static function png(int $width, int $height): string
    {
        $image = self::canvas($width, $height, null);
        ob_start();
        imagepng($image);

        return (string) ob_get_clean();
    }

    /**
     * Inserts, right after SOI, an EXIF APP1 (orientation, plus a GPS IFD when $gps) and an XMP
     * APP1 naming GPS fields, the way a phone camera writes them.
     */
    public static function withMetadata(string $jpeg, int $orientation = 1, bool $gps = true): string
    {
        // Little-endian TIFF: header, IFD0 at 8 with Orientation and the GPS IFD pointer.
        $entries = [pack('vvVv', 0x0112, 3, 1, $orientation)."\0\0"];
        $ifd0Size = 2 + 12 * ($gps ? 2 : 1) + 4;
        $gpsOffset = 8 + $ifd0Size;
        if ($gps) {
            $entries[] = pack('vvVV', 0x8825, 4, 1, $gpsOffset);
        }
        $tiff = 'II'.pack('vV', 42, 8).pack('v', count($entries)).implode('', $entries).pack('V', 0);
        if ($gps) {
            // GPSVersionID 2.2.0.0 and GPSLatitudeRef "N", both inline.
            $tiff .= pack('v', 2).pack('vvV', 0x0000, 1, 4)."\x02\x02\x00\x00".pack('vvV', 0x0001, 2, 2)."N\0\0\0".pack('V', 0);
        }
        $exif = self::segment(0xE1, "Exif\0\0".$tiff);
        $xmp = self::segment(0xE1, "http://ns.adobe.com/xap/1.0/\0".'<x:xmpmeta xmlns:x="adobe:ns:meta/"><exif:GPSLatitude>5,33.0N</exif:GPSLatitude></x:xmpmeta>');

        return substr($jpeg, 0, 2).$exif.$xmp.substr($jpeg, 2);
    }

    /** Inserts a raw APP1 right after SOI, with $declaredLength in its length field. */
    public static function withRawApp1(string $jpeg, string $data, ?int $declaredLength = null): string
    {
        return substr($jpeg, 0, 2)."\xFF\xE1".pack('n', $declaredLength ?? strlen($data) + 2).$data.substr($jpeg, 2);
    }

    /** Appends arbitrary bytes after the image (a polyglot file). */
    public static function withTrailer(string $image, string $trailer): string
    {
        return $image.$trailer;
    }

    /** A PNG signature and IHDR claiming $width × $height, followed by almost nothing. */
    public static function pngHeaderClaiming(int $width, int $height): string
    {
        $ihdr = pack('NNCCCCC', $width, $height, 8, 2, 0, 0, 0);
        $chunk = pack('N', strlen($ihdr)).'IHDR'.$ihdr.pack('N', crc32('IHDR'.$ihdr));

        return "\x89PNG\r\n\x1A\n".$chunk.pack('N', 0).'IDAT'.pack('N', crc32('IDAT'));
    }

    /** RGB of the pixel at fractions ($fx, $fy) of the image. @return array{int, int, int} */
    public static function rgbAt(string $bytes, float $fx, float $fy): array
    {
        $image = imagecreatefromstring($bytes);
        assert($image instanceof GdImage);
        $c = imagecolorat($image, (int) (imagesx($image) * $fx), (int) (imagesy($image) * $fy));

        return [($c >> 16) & 0xFF, ($c >> 8) & 0xFF, $c & 0xFF];
    }

    private static function segment(int $marker, string $data): string
    {
        return "\xFF".chr($marker).pack('n', strlen($data) + 2).$data;
    }

    /** @param (callable(GdImage): void)|null $paint */
    private static function canvas(int $width, int $height, ?callable $paint): GdImage
    {
        $image = imagecreatetruecolor($width, $height);
        assert($image instanceof GdImage);
        imagefill($image, 0, 0, (int) imagecolorallocate($image, 40, 120, 70));
        if ($paint !== null) {
            $paint($image);
        }

        return $image;
    }
}
