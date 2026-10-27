<?php

namespace Tests\Feature\Api\V1;

use App\Models\Debt;
use App\Models\DebtPayment;
use App\Models\FinancialTransaction;
use App\Models\User;
use App\Models\Wishlist;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class SyncPushPullTest extends TestCase
{
    use RefreshDatabase;

    private function loginUser(User $user): array
    {
        $deviceId = (string) Str::uuid();
        $res = $this->postJson('/api/v1/auth/login', [
            'username' => $user->username,
            'password' => 'SecretPass123!',
            'device_id' => $deviceId,
            'device_name' => 'Android Device',
        ])->assertOk();

        return [$res->json('data.token'), $deviceId];
    }

    public function test_idempotent_push_of_debt_payment_replays_without_duplicate_transactions(): void
    {
        $anzhel = User::factory()->create([
            'username' => 'anzhel',
            'password' => bcrypt('SecretPass123!'),
        ]);
        [$token, $deviceId] = $this->loginUser($anzhel);

        $debtId = (string) Str::uuid();
        $paymentId = (string) Str::uuid();
        $createDebtOpId = (string) Str::uuid();
        $payDebtOpId = (string) Str::uuid();

        $payload = [
            'device_id' => $deviceId,
            'operations' => [
                [
                    'operation_id' => $createDebtOpId,
                    'entity_type' => 'debt',
                    'entity_id' => $debtId,
                    'action' => 'upsert',
                    'base_version' => null,
                    'client_created_at' => '2026-10-17T02:00:00Z',
                    'payload' => [
                        'direction' => 'payable',
                        'counterparty' => 'Budi Santoso',
                        'principal_amount' => 1000000,
                        'start_date' => '2026-10-01',
                        'due_date' => '2026-10-25',
                        'note' => 'Pinjaman modal',
                    ],
                ],
                [
                    'operation_id' => $payDebtOpId,
                    'entity_type' => 'debt_payment',
                    'entity_id' => $paymentId,
                    'action' => 'record_debt_payment',
                    'base_version' => null,
                    'client_created_at' => '2026-10-17T02:01:00Z',
                    'payload' => [
                        'debt_id' => $debtId,
                        'amount' => 250000,
                        'paid_at' => '2026-10-17T02:01:00Z',
                        'note' => 'Cicilan pertama',
                    ],
                ],
            ],
        ];

        $first = $this->withToken($token)->postJson('/api/v1/sync/push', $payload)->assertOk();
        $this->assertSame('applied', $first->json('data.results.0.status'));
        $this->assertSame('applied', $first->json('data.results.1.status'));

        // Retry exact same batch (simulating network timeout retry)
        $second = $this->withToken($token)->postJson('/api/v1/sync/push', $payload)->assertOk();
        $this->assertSame('replayed', $second->json('data.results.0.status'));
        $this->assertSame('replayed', $second->json('data.results.1.status'));

        $this->assertSame(1, DebtPayment::where('debt_id', $debtId)->count());
        $this->assertSame(1, FinancialTransaction::where('user_id', $anzhel->id)->count());
        $this->assertSame(750000, Debt::findOrFail($debtId)->remainingAmount());
    }

    public function test_version_conflict_on_mutable_entity_returns_conflict_and_server_snapshot(): void
    {
        $anzhel = User::factory()->create([
            'username' => 'anzhel',
            'password' => bcrypt('SecretPass123!'),
        ]);
        [$token, $deviceId] = $this->loginUser($anzhel);

        $wishlistId = (string) Str::uuid();
        Wishlist::create([
            'id' => $wishlistId,
            'user_id' => $anzhel->id,
            'title' => 'Headphone Sony',
            'target_price' => 4299000,
            'priority' => 'high',
            'status' => 'saving',
            'version' => 2,
        ]);

        $res = $this->withToken($token)->postJson('/api/v1/sync/push', [
            'device_id' => $deviceId,
            'operations' => [
                [
                    'operation_id' => (string) Str::uuid(),
                    'entity_type' => 'wishlist',
                    'entity_id' => $wishlistId,
                    'action' => 'upsert',
                    'base_version' => 1, // stale version!
                    'client_created_at' => '2026-10-17T02:05:00Z',
                    'payload' => [
                        'title' => 'Headphone Bose',
                        'target_price' => 3500000,
                        'priority' => 'medium',
                        'status' => 'planned',
                    ],
                ],
            ],
        ])->assertOk();

        $this->assertSame('conflict', $res->json('data.results.0.status'));
        $this->assertSame(2, $res->json('data.results.0.entity_version'));
        $this->assertSame('Headphone Sony', $res->json('data.results.0.conflict_server_state.title'));
        $this->assertSame('Headphone Sony', Wishlist::findOrFail($wishlistId)->title);
    }

    public function test_cross_account_idor_attempts_are_rejected_and_isolated(): void
    {
        $anzhel = User::factory()->create([
            'username' => 'anzhel',
            'password' => bcrypt('SecretPass123!'),
        ]);
        $wina = User::factory()->create([
            'username' => 'wina',
            'password' => bcrypt('SecretPass123!'),
        ]);

        $winaDebt = Debt::create([
            'id' => (string) Str::uuid(),
            'user_id' => $wina->id,
            'direction' => 'payable',
            'counterparty' => 'Toko Emas',
            'principal_amount' => 2000000,
            'start_date' => '2026-10-01',
            'status' => 'active',
            'version' => 1,
        ]);

        [$anzhelToken, $anzhelDevice] = $this->loginUser($anzhel);

        $res = $this->withToken($anzhelToken)->postJson('/api/v1/sync/push', [
            'device_id' => $anzhelDevice,
            'operations' => [
                [
                    'operation_id' => (string) Str::uuid(),
                    'entity_type' => 'debt',
                    'entity_id' => $winaDebt->id,
                    'action' => 'upsert',
                    'base_version' => 1,
                    'payload' => [
                        'user_id' => $wina->id,
                        'direction' => 'payable',
                        'counterparty' => 'Hacked Counterparty',
                        'principal_amount' => 100,
                        'start_date' => '2026-10-01',
                    ],
                ],
                [
                    'operation_id' => (string) Str::uuid(),
                    'entity_type' => 'debt_payment',
                    'entity_id' => (string) Str::uuid(),
                    'action' => 'record_debt_payment',
                    'base_version' => null,
                    'payload' => [
                        'debt_id' => $winaDebt->id,
                        'amount' => 500000,
                    ],
                ],
            ],
        ])->assertOk();

        $this->assertSame('rejected', $res->json('data.results.0.status'));
        $this->assertSame('rejected', $res->json('data.results.1.status'));
        $this->assertSame('Toko Emas', $winaDebt->fresh()->counterparty);
        $this->assertSame(2000000, $winaDebt->fresh()->remainingAmount());
    }

    public function test_cursor_pull_paginates_and_returns_only_authenticated_user_changes(): void
    {
        $anzhel = User::factory()->create([
            'username' => 'anzhel',
            'password' => bcrypt('SecretPass123!'),
        ]);
        $wina = User::factory()->create([
            'username' => 'wina',
            'password' => bcrypt('SecretPass123!'),
        ]);

        [$anzhelToken, $anzhelDevice] = $this->loginUser($anzhel);
        [$winaToken, $winaDevice] = $this->loginUser($wina);

        // Push 3 items for Anzhel
        $ops = [];
        for ($i = 1; $i <= 3; $i++) {
            $ops[] = [
                'operation_id' => (string) Str::uuid(),
                'entity_type' => 'wishlist',
                'entity_id' => (string) Str::uuid(),
                'action' => 'upsert',
                'base_version' => null,
                'payload' => [
                    'title' => "Item Anzhel {$i}",
                    'target_price' => 100000 * $i,
                    'priority' => 'medium',
                    'status' => 'planned',
                ],
            ];
        }
        $this->withToken($anzhelToken)->postJson('/api/v1/sync/push', [
            'device_id' => $anzhelDevice,
            'operations' => $ops,
        ])->assertOk();

        // Push 1 item for Wina
        $this->app['auth']->forgetGuards();
        $this->withToken($winaToken)->postJson('/api/v1/sync/push', [
            'device_id' => $winaDevice,
            'operations' => [
                [
                    'operation_id' => (string) Str::uuid(),
                    'entity_type' => 'wishlist',
                    'entity_id' => (string) Str::uuid(),
                    'action' => 'upsert',
                    'base_version' => null,
                    'payload' => [
                        'title' => 'Item Wina Rahasia',
                        'target_price' => 500000,
                        'priority' => 'high',
                        'status' => 'planned',
                    ],
                ],
            ],
        ])->assertOk();

        // Pull page 1 (limit=2) as Anzhel
        $this->app['auth']->forgetGuards();
        $page1 = $this->withToken($anzhelToken)->getJson('/api/v1/sync/pull?limit=2')->assertOk();
        $this->assertCount(2, $page1->json('data.changes'));
        $this->assertTrue($page1->json('data.has_more'));
        $nextCursor = $page1->json('data.next_cursor');
        $this->assertNotEmpty($nextCursor);

        // Pull page 2 using next_cursor
        $page2 = $this->withToken($anzhelToken)->getJson('/api/v1/sync/pull?limit=2&cursor=' . urlencode($nextCursor))->assertOk();
        $this->assertCount(1, $page2->json('data.changes'));
        $this->assertFalse($page2->json('data.has_more'));
        $this->assertSame('Item Anzhel 3', $page2->json('data.changes.0.payload.title'));
    }

    public function test_wishlist_saved_amount_persists_through_push_and_pull(): void
    {
        $anzhel = User::factory()->create([
            'username' => 'anzhel',
            'password' => bcrypt('SecretPass123!'),
        ]);
        [$token, $deviceId] = $this->loginUser($anzhel);

        $wishlistId = (string) Str::uuid();
        $this->withToken($token)->postJson('/api/v1/sync/push', [
            'device_id' => $deviceId,
            'operations' => [
                [
                    'operation_id' => (string) Str::uuid(),
                    'entity_type' => 'wishlist',
                    'entity_id' => $wishlistId,
                    'action' => 'upsert',
                    'base_version' => null,
                    'payload' => [
                        'title' => 'Kamera Mirrorless',
                        'target_price' => 3000000,
                        'saved_amount' => 1500000,
                        'priority' => 'high',
                        'status' => 'saving',
                    ],
                ],
            ],
        ])->assertOk();

        $pull = $this->withToken($token)->getJson('/api/v1/sync/pull')->assertOk();
        $this->assertSame(1500000, $pull->json('data.changes.0.payload.saved_amount'));
    }

    public function test_manual_transaction_and_custom_category_can_be_updated_via_sync_push(): void
    {
        $anzhel = User::factory()->create([
            'username' => 'anzhel',
            'password' => bcrypt('SecretPass123!'),
        ]);
        [$token, $deviceId] = $this->loginUser($anzhel);

        $catId = (string) Str::uuid();
        $txId = (string) Str::uuid();

        $createRes = $this->withToken($token)->postJson('/api/v1/sync/push', [
            'device_id' => $deviceId,
            'operations' => [
                [
                    'operation_id' => (string) Str::uuid(),
                    'entity_type' => 'category',
                    'entity_id' => $catId,
                    'action' => 'upsert',
                    'base_version' => null,
                    'payload' => [
                        'name' => 'Kopi & Matcha',
                        'type' => 'expense',
                        'icon_key' => 'fork_knife',
                    ],
                ],
                [
                    'operation_id' => (string) Str::uuid(),
                    'entity_type' => 'financial_transaction',
                    'entity_id' => $txId,
                    'action' => 'upsert',
                    'base_version' => null,
                    'payload' => [
                        'type' => 'expense',
                        'amount_minor' => 35000,
                        'transaction_date' => '2026-10-20',
                        'category_id' => $catId,
                        'note' => 'Kopi Pagi',
                    ],
                ],
            ],
        ])->assertOk();

        $this->assertSame('applied', $createRes->json('data.results.0.status'));
        $this->assertSame('applied', $createRes->json('data.results.1.status'));

        $updateRes = $this->withToken($token)->postJson('/api/v1/sync/push', [
            'device_id' => $deviceId,
            'operations' => [
                [
                    'operation_id' => (string) Str::uuid(),
                    'entity_type' => 'financial_transaction',
                    'entity_id' => $txId,
                    'action' => 'upsert',
                    'base_version' => 1,
                    'payload' => [
                        'type' => 'expense',
                        'amount_minor' => 45000,
                        'transaction_date' => '2026-10-21',
                        'category_id' => $catId,
                        'note' => 'Kopi Pagi + Croissant',
                    ],
                ],
            ],
        ])->assertOk();

        $this->assertSame('applied', $updateRes->json('data.results.0.status'));
        $updatedTx = FinancialTransaction::findOrFail($txId);
        $this->assertSame(45000, (int) $updatedTx->amount_minor);
        $this->assertSame('Kopi Pagi + Croissant', $updatedTx->note);
    }
}
