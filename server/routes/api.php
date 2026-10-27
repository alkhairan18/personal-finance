<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\SyncController;
use App\Http\Middleware\EnsureActiveDeviceToken;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::get('/health', HealthController::class);
    Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:15,1');
    Route::post('/auth/register', [AuthController::class, 'register'])->middleware('throttle:10,1');

    Route::middleware(['auth:sanctum', EnsureActiveDeviceToken::class])->group(function () {
        Route::get('/auth/me', [AuthController::class, 'me']);
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::post('/sync/push', [SyncController::class, 'push']);
        Route::get('/sync/pull', [SyncController::class, 'pull']);
    });
});
