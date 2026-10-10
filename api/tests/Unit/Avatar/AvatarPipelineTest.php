<?php

use App\Domain\Avatar\AvatarPipeline;
use App\Domain\Avatar\AvatarRejected;
use App\Domain\Avatar\JpegOrientation;
use Tests\Support\Images;

/*
 * A20: the avatar pipeline. Every input is built in code (Tests\Support\Images).
 */

function pipeline(int $memoryLimit = -1): AvatarPipeline
{
    return new AvatarPipeline($memoryLimit, fn (): int => memory_get_usage(), true);
}

function rejection(callable $run): AvatarRejected
{
    try {
        $run();
    } catch (AvatarRejected $e) {
        return $e;
    }
    throw new RuntimeException('expected AvatarRejected');
}

it('has WebP in this GD (else the pipeline falls back to JPEG)', function () {
    expect(gd_info()['WebP Support'] ?? false)->toBeTrue();
});

it('re-encodes JPEG, PNG and WebP into 96, 160 and 320 px WebP squares; the hash is the largest', function (string $input) {
    $out = pipeline()->process($input);

    expect(array_keys($out->sizes))->toBe(['sm', 'md', 'lg'])
        ->and([$out->extension, $out->contentType])->toBe(['webp', 'image/webp'])
        ->and($out->sha256)->toBe(hash('sha256', $out->sizes['lg']));
    foreach (['sm' => 96, 'md' => 160, 'lg' => 320] as $size => $px) {
        $info = getimagesizefromstring($out->sizes[$size]);
        expect([$info[0], $info[1], $info['mime']])->toBe([$px, $px, 'image/webp'])
            ->and($out->sizes[$size])->not->toBe($input);
    }
})->with([
    'jpeg 400x300' => fn () => Images::jpeg(400, 300),
    'png 300x500' => fn () => Images::png(300, 500),
    'webp 200x200' => function () {
        $image = imagecreatetruecolor(200, 200);
        ob_start();
        imagewebp($image);

        return (string) ob_get_clean();
    },
]);

it('strips EXIF, GPS and XMP from every output', function () {
    $input = Images::withMetadata(Images::jpeg(400, 300), orientation: 1, gps: true);
    expect($input)->toContain('Exif')->toContain('GPS')->toContain('ns.adobe.com/xap');

    foreach (pipeline()->process($input)->sizes as $bytes) {
        expect($bytes)->not->toContain('Exif')->not->toContain('GPS')
            ->not->toContain('xap')->not->toContain('xmpmeta')->not->toContain('XMP');
    }
});

it('turns an orientation 6 photo upright', function () {
    // Stored landscape with a red band along the top; orientation 6 means "rotate 90° clockwise
    // to display", which puts the band on the right.
    $input = Images::withMetadata(Images::jpeg(300, 200, function (GdImage $image) {
        imagefilledrectangle($image, 0, 0, 299, 49, (int) imagecolorallocate($image, 220, 20, 20));
    }), orientation: 6, gps: false);
    expect(JpegOrientation::read($input))->toBe(6);

    $lg = pipeline()->process($input)->sizes['lg'];
    [$rightRed] = Images::rgbAt($lg, 0.95, 0.5);
    [$leftRed] = Images::rgbAt($lg, 0.05, 0.5);
    [$topRed] = Images::rgbAt($lg, 0.5, 0.05);

    expect($rightRed)->toBeGreaterThan(150)
        ->and($leftRed)->toBeLessThan(100)
        ->and($topRed)->toBeLessThan(100, 'not left as stored');
});

it('displays every EXIF orientation upright', function (int $orientation, string $expected) {
    // Stored quadrants: top-left red, top-right green, bottom-left blue, bottom-right yellow.
    $input = Images::withMetadata(Images::jpeg(200, 200, function (GdImage $image) {
        foreach ([[0, 0, 220, 30, 30], [100, 0, 30, 200, 30], [0, 100, 30, 30, 220], [100, 100, 230, 220, 30]] as [$x, $y, $r, $g, $b]) {
            imagefilledrectangle($image, $x, $y, $x + 99, $y + 99, (int) imagecolorallocate($image, $r, $g, $b));
        }
    }), orientation: $orientation, gps: false);
    $lg = pipeline()->process($input)->sizes['lg'];

    $seen = '';
    foreach ([[0.25, 0.25], [0.75, 0.25], [0.25, 0.75], [0.75, 0.75]] as [$fx, $fy]) {
        [$r, $g, $b] = Images::rgbAt($lg, $fx, $fy);
        $seen .= match (true) {
            $r > 150 && $g > 150 => 'Y',
            $r > 150 => 'R',
            $g > 150 => 'G',
            default => 'B',
        };
    }

    expect($seen)->toBe($expected, "orientation {$orientation}: displayed TL TR BL BR");
})->with([
    [1, 'RGBY'], [2, 'GRYB'], [3, 'YBGR'], [4, 'BYRG'],
    [5, 'RBGY'], [6, 'BRYG'], [7, 'YGBR'], [8, 'GYRB'],
]);

it('reads a broken APP1 as orientation 1 and still decodes the photo', function (Closure $build) {
    $input = $build(Images::jpeg(120, 80));

    expect(JpegOrientation::read($input))->toBe(1);
    expect(pipeline()->process($input)->sizes)->toHaveCount(3);
})->with([
    'truncated TIFF in APP1' => fn (string $jpeg) => Images::withRawApp1($jpeg, "Exif\0\0II".pack('vV', 42, 8).pack('v', 5)),
    'IFD offset past the end' => fn (string $jpeg) => Images::withRawApp1($jpeg, "Exif\0\0II".pack('vV', 42, 4000)),
]);

it('reads orientation 1 from a segment whose length runs past the file, or from non-JPEG bytes', function () {
    $jpeg = Images::jpeg(40, 40);

    expect(JpegOrientation::read(Images::withRawApp1($jpeg, "Exif\0\0", declaredLength: 0xFFFF)))->toBe(1)
        ->and(JpegOrientation::read(substr(Images::withMetadata($jpeg, 6, false), 0, 30)))->toBe(1)
        ->and(JpegOrientation::read(Images::png(10, 10)))->toBe(1)
        ->and(JpegOrientation::read(''))->toBe(1);
});

it('refuses an upload over 5 MB with 413', function () {
    $input = Images::withTrailer(Images::jpeg(50, 50), str_repeat("\0", AvatarPipeline::MAX_BYTES));
    expect(strlen($input))->toBeGreaterThan(AvatarPipeline::MAX_BYTES);

    expect(rejection(fn () => pipeline()->process($input))->status)->toBe(413);
});

it('refuses more than 25 megapixels from the header alone, before decoding', function (int $width, int $height) {
    $e = rejection(fn () => pipeline()->process(Images::pngHeaderClaiming($width, $height)));

    expect([$e->status, $e->getMessage()])->toBe([422, 'This photo has too many pixels. Choose one under 25 megapixels.']);
})->with([
    'just over the cap' => [5001, 5000],
    '60000 x 60000 with a tiny body' => [60000, 60000],
]);

it('refuses a photo whose decoded size would not fit in memory, without a fatal error', function () {
    $tight = pipeline(memory_get_usage() + 1024 * 1024);

    $e = rejection(fn () => $tight->process(Images::jpeg(1000, 1000)));

    expect([$e->status, $e->getMessage()])->toBe([422, 'This photo is too large to process. Choose a smaller one.']);
});

it('counts the rotated copy in the memory estimate for orientations 5 to 8', function () {
    $plain = Images::jpeg(1000, 1000);
    $rotated = Images::withMetadata($plain, orientation: 6, gps: false);
    // Room for one decoded copy (5 bytes a pixel) but not for a rotated second one (9).
    $budget = fn () => pipeline(memory_get_usage() + 1000 * 1000 * 7);

    expect($budget()->process($plain)->sizes)->toHaveCount(3);
    expect(rejection(fn () => $budget()->process($rotated))->getMessage())
        ->toBe('This photo is too large to process. Choose a smaller one.');
});

it('decodes a photo exactly at the pixel cap', function () {
    $input = Images::jpeg(5000, 5000);
    expect(5000 * 5000)->toBe(AvatarPipeline::MAX_PIXELS);

    expect(AvatarPipeline::forRuntime()->process($input)->sizes)->toHaveCount(3);
});

it('re-encodes a polyglot: none of the appended bytes survive', function () {
    $trailer = "PK\x03\x04".str_repeat("\0", 26).'payload.php<?php echo 1; ?>';
    $input = Images::withTrailer(Images::jpeg(200, 200), $trailer);

    foreach (pipeline()->process($input)->sizes as $bytes) {
        expect($bytes)->not->toBe($input)->not->toContain("PK\x03\x04")->not->toContain('<?php');
    }
});

it('refuses files that are not a JPEG, PNG or WebP photo, whatever they claim', function (string $input) {
    expect(rejection(fn () => pipeline()->process($input))->status)->toBe(422);
})->with([
    'php text' => '<?php echo 1;',
    'plain text' => 'not a photo',
    'gif' => function () {
        $image = imagecreatetruecolor(10, 10);
        ob_start();
        imagegif($image);

        return (string) ob_get_clean();
    },
    'jpeg header, garbage body' => "\xFF\xD8\xFF\xE0".str_repeat('x', 200),
]);

it('reads memory_limit values', function () {
    expect(AvatarPipeline::parseBytes('512M'))->toBe(512 * 1024 * 1024)
        ->and(AvatarPipeline::parseBytes('1G'))->toBe(1024 ** 3)
        ->and(AvatarPipeline::parseBytes('-1'))->toBe(-1)
        ->and(AvatarPipeline::parseBytes('65536'))->toBe(65536);
});
