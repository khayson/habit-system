<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\AvatarController;
use App\Http\Controllers\Api\V1\HabitController;
use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\SyncController;
use Illuminate\Support\Facades\Route;

// Prefix /api/v1 is set in bootstrap/app.php. Throttles come after auth:sanctum so authenticated
// limits are keyed by user, not by a shared carrier IP.

Route::get('/health', HealthController::class)->middleware('throttle:api')->name('health');

Route::middleware('throttle:auth')->group(function () {
    Route::post('/auth/register', [AuthController::class, 'register'])->name('auth.register');
    Route::post('/auth/login', [AuthController::class, 'login'])->name('auth.login');
});

Route::middleware(['auth:sanctum', 'throttle:api'])->group(function () {
    Route::post('/auth/logout', [AuthController::class, 'logout'])->name('auth.logout');
    Route::post('/auth/logout-all', [AuthController::class, 'logoutAll'])->name('auth.logout-all');
    Route::post('/auth/refresh', [AuthController::class, 'refresh'])->name('auth.refresh');
    Route::get('/me', [AuthController::class, 'me'])->name('me');
    Route::get('/sync/bootstrap', [SyncController::class, 'bootstrap'])->name('sync.bootstrap');
    Route::get('/habits/{habit}/heatmap', [HabitController::class, 'heatmap'])->name('habits.heatmap');
    // A20: the caller's own photo only.
    Route::delete('/me/avatar', [AvatarController::class, 'delete'])->name('me.avatar.delete');
    Route::get('/me/avatar/{size}', [AvatarController::class, 'show'])->name('me.avatar.show');
});

// A20: 10 uploads per hour per user (config api.rate_limits.avatar_uploads_per_hour).
Route::put('/me/avatar', [AvatarController::class, 'put'])->middleware(['auth:sanctum', 'throttle:avatar-upload'])->name('me.avatar.put');

Route::post('/sync', [SyncController::class, 'sync'])->middleware(['auth:sanctum', 'throttle:sync'])->name('sync');
