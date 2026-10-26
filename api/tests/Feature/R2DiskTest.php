<?php

use Illuminate\Support\Facades\Storage;
use League\Flysystem\AwsS3V3\AwsS3V3Adapter;

/*
 * A54: photos and exports live in the private Cloudflare R2 bucket habit-files, through an r2
 * disk on the S3 driver. Configuration only: never the real bucket. The API streams objects to
 * their owner (A20, A48) and never makes a public or presigned URL.
 */

it('configures r2 as a private, path-style S3 disk from the environment', function () {
    $disk = config('filesystems.disks.r2');
    expect($disk['driver'])->toBe('s3')
        ->and($disk['region'])->toBe('auto')
        ->and($disk['use_path_style_endpoint'])->toBeTrue()
        ->and($disk['visibility'])->toBe('private')
        ->and($disk)->not->toHaveKey('url')
        ->and($disk['throw'])->toBeFalse();
    foreach (['key', 'secret', 'bucket', 'endpoint'] as $key) {
        expect($disk)->toHaveKey($key);
    }
});

it('builds the endpoint from the account id and reads the bucket from env', function () {
    $config = require base_path('config/filesystems.php');
    expect($config['disks']['r2']['endpoint'])->toBe(env('R2_ENDPOINT'))
        ->and($config['disks']['r2']['bucket'])->toBe(env('R2_BUCKET', 'habit-files'));
});

it('resolves the r2 disk with the S3 adapter, without contacting anyone', function () {
    config([
        'filesystems.disks.r2.key' => 'test-key',
        'filesystems.disks.r2.secret' => 'test-secret',
        'filesystems.disks.r2.endpoint' => 'https://0123456789abcdef.r2.cloudflarestorage.com',
    ]);
    $adapter = Storage::disk('r2')->getAdapter();
    expect($adapter)->toBeInstanceOf(AwsS3V3Adapter::class);
});

it('stores and streams photos and exports through whatever disk is configured (r2 in production)', function () {
    config(['api.avatar_disk' => 'r2', 'api.export_disk' => 'r2']);
    Storage::fake('r2');
    expect(Storage::disk(config('api.avatar_disk'))->put('avatars/x.jpg', 'jpg'))->toBeTrue()
        ->and(Storage::disk(config('api.export_disk'))->get('avatars/x.jpg'))->toBe('jpg');
});

it('never asks the storage for a public or temporary URL', function () {
    $offenders = [];
    $files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator(app_path()));
    foreach ($files as $file) {
        if ($file->isFile() && $file->getExtension() === 'php') {
            $code = (string) file_get_contents($file->getPathname());
            if (preg_match('/->(temporaryUrl|temporaryUploadUrl|url)\s*\(/', $code) && str_contains($code, 'Storage')) {
                $offenders[] = $file->getFilename();
            }
        }
    }
    expect($offenders)->toBe([]);
});
