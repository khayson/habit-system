<?php

use App\Http\Controllers\Admin\AdminController;
use App\Http\Middleware\Admin\EnsureAdmin;
use Illuminate\Support\Facades\Route;

/*
 * A58: Khay Studios' admin page (the web middleware group: the /admin cookie session, CSRF,
 * strict headers). Never under /api/v1, never for app accounts.
 */
Route::prefix('admin')->group(function () {
    Route::get('/login', [AdminController::class, 'loginForm'])->name('admin.login');
    Route::post('/login', [AdminController::class, 'login']);

    Route::middleware(EnsureAdmin::class)->group(function () {
        Route::get('/', [AdminController::class, 'dashboard'])->name('admin.dashboard');
        Route::post('/logout', [AdminController::class, 'logout']);
        Route::post('/server/tick', [AdminController::class, 'runTick']);
        Route::post('/server/retry-jobs', [AdminController::class, 'retryJobs']);
        Route::get('/health', [AdminController::class, 'health'])->name('admin.health');
        Route::post('/health/failed/{uuid}/retry', [AdminController::class, 'retryJob']);
        Route::post('/health/failed/{uuid}/forget', [AdminController::class, 'forgetJob']);
        Route::post('/health/failed/forget-all', [AdminController::class, 'forgetAllJobs']);
        Route::get('/activity', [AdminController::class, 'activity'])->name('admin.activity');
        Route::get('/accounts', [AdminController::class, 'accounts'])->name('admin.accounts');
        Route::get('/accounts/{id}', [AdminController::class, 'account'])->name('admin.account');
        Route::post('/accounts/{id}/sign-out', [AdminController::class, 'signOut']);
        Route::post('/accounts/{id}/suspend', [AdminController::class, 'suspend']);
        Route::post('/accounts/{id}/resume', [AdminController::class, 'resume']);
        Route::post('/accounts/{id}/delete', [AdminController::class, 'delete']);
        Route::get('/notices', [AdminController::class, 'notices'])->name('admin.notices');
        Route::post('/notices', [AdminController::class, 'publishNotice']);
        Route::post('/notices/{id}/retire', [AdminController::class, 'retireNotice']);
    });
});
