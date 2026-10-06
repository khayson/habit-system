<?php

use App\Http\Controllers\Api\V1\HealthController;
use Illuminate\Support\Facades\Route;

// Prefix /api/v1 is set in bootstrap/app.php; the `api` group applies the `api` rate limiter.

Route::get('/health', HealthController::class)->name('health');
