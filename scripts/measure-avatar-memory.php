<?php

/*
 * Phase 3b (S4): measures how much memory the avatar pipeline really takes per input type, to
 * set AvatarPipeline's bytes-per-pixel estimates.
 *
 *   php scripts/measure-avatar-memory.php [--size=5000] [--types=jpeg,jpeg-progressive,...]
 *
 * Each measurement runs in a fresh PHP process (a high-water mark only grows). The input is
 * written to a temp file by one child; another child loads only that file, notes its memory,
 * runs the pipeline, and notes the peak. Growth = peak - before.
 *   Linux:   VmHWM from /proc/self/status (resident high-water mark: GD plus libjpeg, libpng
 *            and libwebp buffers).
 *   Windows: the child's PeakWorkingSet64 (read by the parent while the child waits).
 * Prints one line per type: growth in MB and bytes per pixel. Internal modes: --make, --measure.
 */

$root = dirname(__DIR__);
require $root.'/api/vendor/autoload.php';

use App\Domain\Avatar\AvatarPipeline;

const TYPES = ['jpeg', 'jpeg-progressive', 'png-rgba', 'png-interlaced', 'webp'];

$options = getopt('', ['size::', 'types::', 'make:', 'measure:', 'out:', 'load-only']);
$size = (int) ($options['size'] ?? 5000);

/** Resident high-water mark in bytes (Linux), or null elsewhere. */
function hwm(): ?int
{
    $status = @file_get_contents('/proc/self/status');
    if (! is_string($status) || ! preg_match('/^VmHWM:\s+(\d+)\s+kB/m', $status, $m)) {
        return null;
    }

    return (int) $m[1] * 1024;
}

// Child: write one input of $type to --out.
if (isset($options['make'])) {
    $image = imagecreatetruecolor($size, $size);
    $png = str_starts_with($options['make'], 'png');
    if ($options['make'] === 'png-rgba') {
        imagealphablending($image, false);
        imagesavealpha($image, true);
        imagefill($image, 0, 0, (int) imagecolorallocatealpha($image, 30, 90, 160, 40));
    } else {
        imagefill($image, 0, 0, (int) imagecolorallocate($image, 30, 90, 160));
    }
    for ($i = 0; $i < 40; $i++) {
        $c = (int) imagecolorallocatealpha($image, ($i * 37) % 256, ($i * 71) % 256, ($i * 13) % 256, $png ? 20 : 0);
        imagefilledellipse($image, ($i * 997) % $size, ($i * 613) % $size, intdiv($size, 6), intdiv($size, 9), $c);
    }
    if (in_array($options['make'], ['jpeg-progressive', 'png-interlaced'], true)) {
        imageinterlace($image, true);
    }
    match (true) {
        str_starts_with($options['make'], 'jpeg') => imagejpeg($image, $options['out'], 85),
        $png => imagepng($image, $options['out'], 9),
        default => imagewebp($image, $options['out'], 80),
    };
    exit(0);
}

// Child: measure the pipeline on one file.
if (isset($options['measure'])) {
    $bytes = (string) file_get_contents($options['measure']);
    $before = hwm() ?? 0;
    if (! isset($options['load-only'])) {
        (new AvatarPipeline(-1, fn (): int => memory_get_usage(), true))->process($bytes);
    }
    $after = hwm();
    if ($after !== null) {
        echo json_encode(['before' => $before, 'after' => $after, 'file_bytes' => strlen($bytes)]), "\n";
        exit(0);
    }
    // Windows: say we are done and wait for the parent to read the peak working set.
    echo json_encode(['pid' => getmypid(), 'file_bytes' => strlen($bytes)]), "\n";
    fflush(STDOUT);
    fgets(STDIN);
    exit(0);
}

$types = isset($options['types']) ? explode(',', (string) $options['types']) : TYPES;
$php = escapeshellarg(PHP_BINARY);
$self = escapeshellarg(__FILE__);
$results = [];
foreach ($types as $type) {
    $file = tempnam(sys_get_temp_dir(), 'avm');
    exec("{$php} -d memory_limit=-1 {$self} --size={$size} --make={$type} --out=".escapeshellarg($file), $_, $code);
    if ($code !== 0) {
        fwrite(STDERR, "error: could not build {$type}\n");
        exit(1);
    }
    $process = proc_open("{$php} -d memory_limit=-1 {$self} --measure=".escapeshellarg($file), [0 => ['pipe', 'r'], 1 => ['pipe', 'w']], $pipes);
    $line = json_decode((string) fgets($pipes[1]), true);
    if (isset($line['pid'])) {
        // Windows: the child's peak working set, minus a child that only loaded the file.
        $peak = (int) trim((string) shell_exec('powershell -NoProfile -Command "(Get-Process -Id '.(int) $line['pid'].').PeakWorkingSet64"'));
        fwrite($pipes[0], "\n");
        $baseline = baselinePeak($php, $file);
        $growth = $peak - $baseline;
        $method = 'PeakWorkingSet64';
    } else {
        $growth = $line['after'] - $line['before'];
        $method = 'VmHWM';
    }
    fclose($pipes[0]);
    fclose($pipes[1]);
    proc_close($process);
    unlink($file);
    $results[$type] = ['growth' => $growth, 'per_pixel' => $growth / ($size * $size), 'method' => $method, 'file_bytes' => $line['file_bytes']];
    printf("%-17s %7.1f MB  %5.2f B/px  (%s, %dx%d, file %.1f MB)\n", $type, $growth / 1048576, $growth / ($size * $size), $method, $size, $size, $line['file_bytes'] / 1048576);
}

/** Windows: the peak working set of a child that loads the file and does nothing else. */
function baselinePeak(string $php, string $file): int
{
    $process = proc_open("{$php} -d memory_limit=-1 ".escapeshellarg(__FILE__).' --load-only --measure='.escapeshellarg($file), [0 => ['pipe', 'r'], 1 => ['pipe', 'w']], $pipes);
    $pid = (int) (json_decode((string) fgets($pipes[1]), true)['pid'] ?? 0);
    $peak = (int) trim((string) shell_exec('powershell -NoProfile -Command "(Get-Process -Id '.$pid.').PeakWorkingSet64"'));
    fwrite($pipes[0], "\n");
    fclose($pipes[0]);
    fclose($pipes[1]);
    proc_close($process);

    return $peak;
}
