<?php

namespace App\Http\Middleware;

use App\Models\Device;
use App\Support\ApiErrorResponse;
use Closure;
use Illuminate\Http\Request;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpFoundation\Response;

class EnsureActiveDeviceToken
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user || ! $user->is_active) {
            return ApiErrorResponse::make(
                'UNAUTHENTICATED',
                'Sesi tidak valid atau akun tidak aktif.',
                [],
                401
            );
        }

        $accessToken = $user->currentAccessToken();
        if (! $accessToken instanceof PersonalAccessToken) {
            return ApiErrorResponse::make(
                'UNAUTHENTICATED',
                'Token akses tidak valid.',
                [],
                401
            );
        }

        if ($accessToken->expires_at && $accessToken->expires_at->isPast()) {
            $accessToken->delete();
            return ApiErrorResponse::make(
                'UNAUTHENTICATED',
                'Token akses telah kedaluwarsa.',
                [],
                401
            );
        }

        $abilities = $accessToken->abilities ?? [];
        $deviceId = null;
        foreach ($abilities as $ability) {
            if (is_string($ability) && str_starts_with($ability, 'device:')) {
                $deviceId = substr($ability, strlen('device:'));
                break;
            }
        }

        if ($deviceId) {
            $device = Device::where('id', $deviceId)
                ->where('user_id', $user->id)
                ->first();

            if (! $device || $device->revoked_at !== null) {
                $accessToken->delete();
                return ApiErrorResponse::make(
                    'UNAUTHENTICATED',
                    'Perangkat ini telah dicabut aksesnya.',
                    [],
                    401
                );
            }

            $device->update(['last_seen_at' => now()]);
        }

        return $next($request);
    }
}
