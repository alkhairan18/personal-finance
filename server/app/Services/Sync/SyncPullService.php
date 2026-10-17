<?php

namespace App\Services\Sync;

use App\Exceptions\DomainValidationException;
use App\Models\SyncChange;
use App\Models\User;

class SyncPullService
{
    public function pull(User $user, ?string $cursor, int $limit = 500): array
    {
        $clampedLimit = max(1, min(500, $limit));
        $lastSeq = $this->decodeCursor($cursor);

        $rows = SyncChange::where('user_id', $user->id)
            ->where('sequence_id', '>', $lastSeq)
            ->orderBy('sequence_id', 'asc')
            ->limit($clampedLimit + 1)
            ->get();

        $hasMore = $rows->count() > $clampedLimit;
        $pageRows = $hasMore ? $rows->slice(0, $clampedLimit) : $rows;

        $changes = [];
        $nextSeq = $lastSeq;

        foreach ($pageRows as $row) {
            $nextSeq = (int) $row->sequence_id;
            $changes[] = [
                'sequence' => (int) $row->sequence_id,
                'entity_type' => $row->entity_type,
                'entity_id' => $row->entity_id,
                'operation' => $row->operation,
                'entity_version' => $row->entity_version !== null ? (int) $row->entity_version : null,
                'payload' => $row->payload,
                'changed_at' => $row->created_at?->utc()->toIso8601ZuluString(),
            ];
        }

        return [
            'changes' => $changes,
            'next_cursor' => $this->encodeCursor($nextSeq),
            'has_more' => $hasMore,
        ];
    }

    private function decodeCursor(?string $cursor): int
    {
        if ($cursor === null || trim($cursor) === '') {
            return 0;
        }

        $decoded = base64_decode($cursor, true);
        if ($decoded === false) {
            throw new DomainValidationException('Format cursor sinkronisasi tidak valid.', [
                'cursor' => ['Cursor tidak valid.'],
            ], 'BAD_REQUEST');
        }

        $json = json_decode($decoded, true);
        if (! is_array($json) || ! isset($json['seq']) || ! is_int($json['seq']) || $json['seq'] < 0) {
            throw new DomainValidationException('Isi cursor sinkronisasi tidak valid.', [
                'cursor' => ['Cursor tidak valid.'],
            ], 'BAD_REQUEST');
        }

        return $json['seq'];
    }

    private function encodeCursor(int $seq): string
    {
        return base64_encode((string) json_encode(['seq' => $seq]));
    }
}
