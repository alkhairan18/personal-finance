<?php

namespace App\Support;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Str;

class ApiErrorResponse
{
    public static function make(
        string $code,
        string $message,
        array $details = [],
        int $status = 400,
        ?string $requestId = null
    ): JsonResponse {
        return response()->json([
            'error' => [
                'code' => $code,
                'message' => $message,
                'details' => (object) $details,
                'request_id' => $requestId ?? (string) Str::uuid(),
            ],
        ], $status);
    }
}
