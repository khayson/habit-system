<?php

use App\Models\Model;
use App\Models\User;

it('generates UUIDv7 primary keys from the base model', function () {
    $model = new class extends Model {};

    expect($model->newUniqueId())->toMatch(UUID_V7_PATTERN)
        ->and($model->getKeyType())->toBe('string')
        ->and($model->getIncrementing())->toBeFalse();
});

it('generates UUIDv7 keys for users', function () {
    expect((new User)->newUniqueId())->toMatch(UUID_V7_PATTERN);
});

it('orders keys by creation time', function () {
    $model = new class extends Model {};

    $first = $model->newUniqueId();
    usleep(2000);
    $second = $model->newUniqueId();

    expect(strcmp($first, $second))->toBeLessThan(0);
});

it('keeps mass assignment closed by default', function () {
    $model = new class extends Model {};

    expect($model->getGuarded())->toBe(['*'])->and($model->getFillable())->toBe([]);
});
