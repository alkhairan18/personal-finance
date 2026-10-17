<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\DomainValidationException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\SyncPushRequest;
use App\Models\User;
use App\Services\Sync\SyncPullService;
use App\Services\Sync\SyncPushService;
use App\Support\ApiErrorResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SyncController extends Controller
{
    public function __construct(
        private readonly SyncPushService $pushService,
        private readonly SyncPullService $pullService
    ) {}

    public function push(SyncPushRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $validated = $request->validated();

        $results = $this->pushService->processBatch(
            $user,
            (string) $validated['device_id'],
            $validated['operations']
        );

        return response()->json([
            'data' => [
                'results' => $results,
            ],
        ]);
    }

    public function pull(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $cursor = $request->query('cursor');
        $limit = (int) $request->query('limit', 500);

        try {
            $data = $this->pullService->pull(
                $user,
                is_string($cursor) ? $cursor : null,
                $limit
            );

            return response()->json([
                'data' => $data,
            ]);
        } catch (DomainValidationException $e) {
            return ApiErrorResponse::make(
                $e->errorCode,
                $e->getMessage(),
                $e->details,
                $e->errorCode === 'BAD_REQUEST' ? 400 : 422
            );
        }
    }
}
