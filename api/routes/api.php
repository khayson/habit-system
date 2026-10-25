<?php

use App\Http\Controllers\Api\V1\AccountController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\AvatarController;
use App\Http\Controllers\Api\V1\ExportController;
use App\Http\Controllers\Api\V1\HabitController;
use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\InsightsController;
use App\Http\Controllers\Api\V1\PasswordResetController;
use App\Http\Controllers\Api\V1\RewardsController;
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
    Route::get('/rewards', [RewardsController::class, 'rewards'])->name('rewards');
    Route::get('/freezes', [RewardsController::class, 'freezes'])->name('freezes');
    Route::get('/insights', [InsightsController::class, 'show'])->name('insights');
    Route::get('/exports', [ExportController::class, 'index'])->name('exports.index');
    Route::get('/exports/{export}', [ExportController::class, 'show'])->name('exports.show');
    Route::get('/exports/{export}/download', [ExportController::class, 'download'])->name('exports.download');
    // A20: the caller's own photo only.
    Route::delete('/me/avatar', [AvatarController::class, 'delete'])->name('me.avatar.delete');
    Route::get('/me/avatar/{size}', [AvatarController::class, 'show'])->name('me.avatar.show');
});

// A20: 10 uploads per hour per user (config api.rate_limits.avatar_uploads_per_hour).
// A48: requesting an export is limited per hour; reading jobs and downloading use the api limit.
Route::post('/exports', [ExportController::class, 'store'])->middleware(['auth:sanctum', 'throttle:exports'])->name('exports.store');

Route::put('/me/avatar', [AvatarController::class, 'put'])->middleware(['auth:sanctum', 'throttle:avatar-upload'])->name('me.avatar.put');

Route::post('/sync', [SyncController::class, 'sync'])->middleware(['auth:sanctum', 'throttle:sync'])->name('sync');

// A50: reset by a 6-digit code; per IP and per email per hour (config api.rate_limits).
Route::middleware('throttle:password-reset')->group(function () {
    Route::post('/auth/forgot-password', [PasswordResetController::class, 'forgot'])->name('auth.forgot-password');
    Route::post('/auth/reset-password', [PasswordResetController::class, 'reset'])->name('auth.reset-password');
});

// A49: deleting the account checks the password under the login limits; the status is read with
// the receipt (not a session), so it sits outside auth:sanctum.
Route::delete('/me', [AccountController::class, 'destroy'])->middleware(['auth:sanctum', 'throttle:account-delete'])->name('me.destroy');
Route::get('/account-deletions/{deletion}', [AccountController::class, 'show'])->middleware('throttle:api')->name('account-deletions.show');
