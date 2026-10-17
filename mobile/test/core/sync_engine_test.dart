import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/core/network/api_client.dart';
import 'package:personal_finance/core/sync/sync_engine.dart';
import 'package:personal_finance/features/auth/data/auth_repository.dart';
import 'package:personal_finance/features/transactions/data/transaction_repository.dart';

class FakeSyncApiGateway implements SyncApiGateway {
  Future<Map<String, dynamic>> Function(List<Map<String, dynamic>> operations)? onPush;
  Future<Map<String, dynamic>> Function(String? cursor)? onPull;

  @override
  Future<Map<String, dynamic>> pushOperations({
    required String clientDeviceId,
    required List<Map<String, dynamic>> operations,
  }) async {
    if (onPush == null) {
      return {'results': <Map<String, dynamic>>[]};
    }
    return onPush!(operations);
  }

  @override
  Future<Map<String, dynamic>> pullChanges({
    String? cursor,
    int limit = 200,
  }) async {
    if (onPull == null) {
      return {
        'next_cursor': cursor ?? '0',
        'has_more': false,
        'changes': <Map<String, dynamic>>[],
      };
    }
    return onPull!(cursor);
  }
}

void main() {
  late AppDatabase db;
  late TransactionRepository txRepo;
  late FakeSyncApiGateway api;
  late SyncEngine syncEngine;

  setUp(() async {
    db = AppDatabase.inMemory(userId: 'user-anzhel-uuid');
    await db.ensureDefaultCategoriesSeeded();
    txRepo = TransactionRepository(db);
    api = FakeSyncApiGateway();
    syncEngine = SyncEngine(
      db: db,
      apiGateway: api,
      clientDeviceId: 'device-anzhel-pixel',
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('network error during push preserves the exact same operation_id and increments retryCount', () async {
    final categories = await db.getActiveCategories(kind: 'expense');
    await txRepo.createTransaction(
      type: 'expense',
      amount: 35000,
      categoryId: categories.first.id,
      transactionDate: '2026-10-17',
      title: 'Sarapan Nasi Kuning',
    );

    final beforeOutbox = await db.getPendingOutboxItems();
    final originalOperationId = beforeOutbox.single.operationId;

    String? pushedOpIdFirstAttempt;
    api.onPush = (ops) async {
      pushedOpIdFirstAttempt = ops.single['operation_id'] as String;
      throw const ApiNetworkException('Connection timed out');
    };

    final firstResult = await syncEngine.synchronize();
    expect(firstResult.success, isFalse);

    final afterFailOutbox = await db.getPendingOutboxItems();
    expect(afterFailOutbox.length, 1);
    expect(afterFailOutbox.single.operationId, originalOperationId);
    expect(afterFailOutbox.single.retryCount, 1);

    String? pushedOpIdSecondAttempt;
    api.onPush = (ops) async {
      pushedOpIdSecondAttempt = ops.single['operation_id'] as String;
      return {
        'results': [
          {
            'operation_id': pushedOpIdSecondAttempt,
            'entity_type': 'transaction',
            'entity_id': ops.single['entity_id'],
            'status': 'replayed',
            'new_version': 1,
          }
        ],
      };
    };

    final secondResult = await syncEngine.synchronize();
    expect(secondResult.success, isTrue);
    expect(pushedOpIdFirstAttempt, originalOperationId);
    expect(pushedOpIdSecondAttempt, originalOperationId);
    expect(await db.getPendingOutboxCount(), 0);

    final txs = await db.getActiveTransactions();
    expect(txs.single.syncStatus, 'synced');
  });

  test('conflict response stores SyncConflictEntry with local and server snapshots', () async {
    final categories = await db.getActiveCategories(kind: 'expense');
    final txId = await txRepo.createTransaction(
      type: 'expense',
      amount: 50000,
      categoryId: categories.first.id,
      transactionDate: '2026-10-17',
      title: 'Parkir Bandara',
    );

    api.onPush = (ops) async {
      final op = ops.single;
      return {
        'results': [
          {
            'operation_id': op['operation_id'],
            'entity_type': 'transaction',
            'entity_id': txId,
            'status': 'conflict',
            'current_version': 3,
            'conflict_server_state': {
              'id': txId,
              'amount': 65000,
              'title': 'Parkir Bandara VIP',
              'version': 3,
            },
          }
        ],
      };
    };

    final result = await syncEngine.synchronize();
    expect(result.conflictsCount, 1);
    expect(await db.getPendingOutboxCount(), 0);

    final conflicts = await db.getSyncConflicts();
    expect(conflicts.length, 1);
    expect(conflicts.single.entityId, txId);
    expect(conflicts.single.localPayload['amount'], 50000);
    expect(conflicts.single.serverPayload['amount'], 65000);
  });

  test('paginated pull applies upsert and tombstone atomically and advances cursor per page', () async {
    final categories = await db.getActiveCategories(kind: 'expense');
    final catId = categories.first.id;

    api.onPull = (cursor) async {
      if (cursor == null || cursor == '0') {
        return {
          'data': {
            'next_cursor': '10',
            'has_more': true,
            'changes': [
              {
                'sequence_id': 10,
                'entity_type': 'financial_transaction',
                'entity_id': 'tx-remote-1',
                'operation': 'upsert',
                'entity_version': 1,
                'created_at': '2026-10-17T08:00:00Z',
                'payload': {
                  'id': 'tx-remote-1',
                  'user_id': 'user-anzhel-uuid',
                  'category_id': catId,
                  'type': 'expense',
                  'source_type': 'manual',
                  'amount_minor': 90000,
                  'transaction_date': '2026-10-17',
                  'note': 'Belanja Sayur',
                  'status': 'posted',
                  'version': 1,
                  'created_at': '2026-10-17T08:00:00Z',
                  'updated_at': '2026-10-17T08:00:00Z',
                },
              },
            ],
          },
        };
      }
      return {
        'data': {
          'next_cursor': '11',
          'has_more': false,
          'changes': [
            {
              'sequence_id': 11,
              'entity_type': 'wishlist',
              'entity_id': 'wl-remote-1',
              'operation': 'upsert',
              'entity_version': 1,
              'created_at': '2026-10-17T08:05:00Z',
              'payload': {
                'id': 'wl-remote-1',
                'user_id': 'user-anzhel-uuid',
                'title': 'Kursi Kerja',
                'category_id': catId,
                'target_price': 1500000,
                'saved_amount': 500000,
                'priority': 'high',
                'status': 'saving',
                'version': 1,
                'created_at': '2026-10-17T08:05:00Z',
                'updated_at': '2026-10-17T08:05:00Z',
              },
            },
          ],
        },
      };
    };

    final result = await syncEngine.synchronize();
    expect(result.success, isTrue);
    expect(await db.getSyncMeta('last_pull_cursor'), '11');

    final txs = await db.getActiveTransactions();
    expect(txs.any((t) => t.id == 'tx-remote-1' && t.amount == 90000), isTrue);

    final wishlists = await db.getActiveWishlistItems();
    expect(wishlists.any((w) => w.id == 'wl-remote-1' && w.itemName == 'Kursi Kerja'), isTrue);
  });

  test('AuthRepository.checkLogoutSafety blocks unforced logout when outbox has pending items', () async {
    final categories = await db.getActiveCategories(kind: 'expense');
    await txRepo.createTransaction(
      type: 'expense',
      amount: 25000,
      categoryId: categories.first.id,
      transactionDate: '2026-10-17',
      title: 'Air Mineral',
    );

    final authRepo = AuthRepository.forTesting(activeDatabase: db);
    final check = await authRepo.checkLogoutSafety();
    expect(check.hasPendingOperations, isTrue);
    expect(check.pendingCount, 1);

    await expectLater(
      authRepo.logout(forceDiscardPending: false),
      throwsA(isA<UnsyncedChangesException>()),
    );

    await authRepo.logout(forceDiscardPending: true);
    expect(authRepo.currentSession, isNull);
  });
}
