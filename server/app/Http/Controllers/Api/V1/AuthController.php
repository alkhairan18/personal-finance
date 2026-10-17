<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Device;
use App\Models\User;
use App\Support\ApiErrorResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;

class AuthController extends Controller
{
    public function login(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'username' => ['required', 'string', 'max:100'],
            'password' => ['required', 'string'],
            'device_id' => ['required', 'uuid'],
            'device_name' => ['nullable', 'string', 'max:120'],
        ]);

        $throttleKey = 'login:' . strtolower($validated['username']) . '|' . $request->ip();
        if (RateLimiter::tooManyAttempts($throttleKey, 5)) {
            return ApiErrorResponse::make(
                'RATE_LIMITED',
                'Terlalu banyak percobaan login. Silakan coba beberapa saat lagi.',
                [],
                429
            );
        }

        $usernameOrEmail = strtolower(trim($validated['username']));
        $user = User::whereRaw('LOWER(username) = ?', [$usernameOrEmail])
            ->orWhereRaw('LOWER(email) = ?', [$usernameOrEmail])
            ->first();

        if (! $user || ! $user->is_active || ! Hash::check($validated['password'], $user->password)) {
            RateLimiter::hit($throttleKey, 60);
            return ApiErrorResponse::make(
                'UNAUTHENTICATED',
                'Username atau password tidak sesuai.',
                [],
                401
            );
        }

        RateLimiter::clear($throttleKey);

        $existingDevice = Device::find($validated['device_id']);
        if ($existingDevice && $existingDevice->user_id !== $user->id) {
            return ApiErrorResponse::make(
                'FORBIDDEN',
                'ID perangkat tidak dapat digunakan untuk akun ini.',
                [],
                403
            );
        }

        $device = Device::updateOrCreate(
            ['id' => $validated['device_id']],
            [
                'user_id' => $user->id,
                'device_name' => $validated['device_name'] ?? 'Android pribadi',
                'last_seen_at' => now(),
                'revoked_at' => null,
            ]
        );

        $expiresAt = now()->addDays(30)->utc();
        $newToken = $user->createToken(
            $device->device_name ?? 'Android pribadi',
            ['sync', 'device:' . $device->id],
            $expiresAt
        );

        return response()->json([
            'data' => [
                'token' => $newToken->plainTextToken,
                'token_type' => 'Bearer',
                'expires_at' => $expiresAt->toIso8601ZuluString(),
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'username' => $user->username,
                ],
            ],
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        return response()->json([
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'username' => $user->username,
                ],
            ],
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()?->currentAccessToken()?->delete();

        return response()->json([
            'data' => [
                'logged_out' => true,
            ],
        ]);
    }
}
