import 'dart:math';

import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/core/network/api_client.dart';
import 'package:uuid/uuid.dart';

class SyncRunResult {
  final bool success;
  final int pushedCount;
  final int pulledCount;
  final int conflictsCount;
  final String? errorMessage;

  const SyncRunResult({
    required this.success,
    this.pushedCount = 0,
    this.pulledCount = 0,
    this.conflictsCount = 0,
    this.errorMessage,
  });
}

class SyncEngine {
  final AppDatabase db;
  final SyncApiGateway apiGateway;
  final String clientDeviceId;
  final Uuid _uuid;

  SyncEngine({
    required this.db,
    required this.apiGateway,
    required this.clientDeviceId,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  static Duration calculateBackoffDelay(int retryCount) {
    final cappedRetry = retryCount.clamp(0, 8);
    final baseSeconds = min(300, 1 << cappedRetry);
    return Duration(seconds: baseSeconds);
  }

  Future<SyncRunResult> synchronize() async {
    var pushedCount = 0;
    var pulledCount = 0;
    var conflictsCount = 0;

    final pending = await db.getPendingOutboxItems();
    for (var offset = 0; offset < pending.length; offset += 100) {
      final batch = pending.skip(offset).take(100).toList();
      final operationsPayload = batch
          .map(
            (item) => <String, dynamic>{
              'operation_id': item.operationId,
              'entity_type': item.entityType,
              'entity_id': item.entityId,
              'operation': item.operationType,
              'base_version': item.baseVersion,
              'client_timestamp': item.createdAt,
              'payload': item.payload,
            },
          )
          .toList();

      Map<String, dynamic> pushResponse;
      try {
        pushResponse = await apiGateway.pushOperations(
          clientDeviceId: clientDeviceId,
          operations: operationsPayload,
        );
      } on ApiNetworkException catch (e) {
        await db.transaction(() async {
          for (final item in batch) {
            db.execute(
              'UPDATE sync_outbox SET retry_count = retry_count + 1, last_error = ? WHERE operation_id = ?',
              [e.message, item.operationId],
            );
          }
        });
        return SyncRunResult(
          success: false,
          pushedCount: pushedCount,
          pulledCount: pulledCount,
          conflictsCount: conflictsCount,
          errorMessage: e.message,
        );
      } catch (e) {
        await db.transaction(() async {
          for (final item in batch) {
            db.execute(
              'UPDATE sync_outbox SET retry_count = retry_count + 1, last_error = ? WHERE operation_id = ?',
              [e.toString(), item.operationId],
            );
          }
        });
        return SyncRunResult(
          success: false,
          pushedCount: pushedCount,
          pulledCount: pulledCount,
          conflictsCount: conflictsCount,
          errorMessage: e.toString(),
        );
      }

      final rawResults = (pushResponse['results'] as List<dynamic>?) ?? const [];
      final byOpId = <String, SyncOutboxItem>{
        for (final item in batch) item.operationId: item,
      };

      await db.transaction(() async {
        for (final raw in rawResults) {
          if (raw is! Map<String, dynamic>) continue;
          final opId = raw['operation_id'] as String?;
          if (opId == null) continue;
          final outboxItem = byOpId[opId];
          if (outboxItem == null) continue;

          final status = raw['status'] as String? ?? 'applied';
          if (status == 'applied' || status == 'replayed') {
            final newVersion = raw['new_version'] as int?;
            _markEntitySynced(
              entityType: outboxItem.entityType,
              entityId: outboxItem.entityId,
              newVersion: newVersion,
            );
            db.execute('DELETE FROM sync_outbox WHERE operation_id = ?', [opId]);
            pushedCount++;
          } else if (status == 'conflict') {
            final serverState = (raw['conflict_server_state'] as Map<String, dynamic>?) ??
                <String, dynamic>{};
            await db.recordSyncConflict(
              id: _uuid.v4(),
              operationId: opId,
              entityType: outboxItem.entityType,
              entityId: outboxItem.entityId,
              localPayload: outboxItem.payload,
              serverPayload: serverState,
            );
            conflictsCount++;
          } else if (status == 'rejected') {
            db.execute('DELETE FROM sync_outbox WHERE operation_id = ?', [opId]);
          }
        }
      });
    }

    var cursor = await db.getSyncMeta('last_pull_cursor');
    var pageGuard = 0;
    while (pageGuard < 50) {
      pageGuard++;
      Map<String, dynamic> pullResponse;
      try {
        pullResponse = await apiGateway.pullChanges(cursor: cursor);
      } catch (e) {
        return SyncRunResult(
          success: false,
          pushedCount: pushedCount,
          pulledCount: pulledCount,
          conflictsCount: conflictsCount,
          errorMessage: e.toString(),
        );
      }

      final changes = (pullResponse['changes'] as List<dynamic>?) ?? const [];
      final nextCursor = (pullResponse['next_cursor'] ?? cursor ?? '0').toString();
      final hasMore = (pullResponse['has_more'] as bool?) ?? false;

      await db.transaction(() async {
        for (final rawChange in changes) {
          if (rawChange is! Map<String, dynamic>) continue;
          _applyPulledChange(rawChange);
          pulledCount++;
        }
        await db.setSyncMeta('last_pull_cursor', nextCursor);
        await db.setSyncMeta(
          'last_sync_at',
          DateTime.now().toUtc().toIso8601String(),
        );
      });

      cursor = nextCursor;
      if (!hasMore) {
        break;
      }
    }

    return SyncRunResult(
      success: true,
      pushedCount: pushedCount,
      pulledCount: pulledCount,
      conflictsCount: conflictsCount,
    );
  }

  void _markEntitySynced({
    required String entityType,
    required String entityId,
    int? newVersion,
  }) {
    final table = _tableNameForEntity(entityType);
    if (table == null) return;
    if (newVersion != null) {
      db.execute(
        "UPDATE $table SET sync_status = 'synced', version = ? WHERE id = ?",
        [newVersion, entityId],
      );
    } else {
      db.execute(
        "UPDATE $table SET sync_status = 'synced' WHERE id = ?",
        [entityId],
      );
    }
  }

  String? _tableNameForEntity(String entityType) {
    switch (entityType) {
      case 'category':
        return 'local_categories';
      case 'transaction':
        return 'local_transactions';
      case 'debt':
        return 'local_debts';
      case 'debt_payment':
        return 'local_debt_payments';
      case 'installment_plan':
        return 'local_installment_plans';
      case 'installment':
        return 'local_installments';
      case 'installment_payment':
        return 'local_installment_payments';
      case 'wishlist':
        return 'local_wishlists';
      default:
        return null;
    }
  }

  void _applyPulledChange(Map<String, dynamic> change) {
    final entityType = change['entity_type'] as String? ?? '';
    final entityId = change['entity_id'] as String? ?? '';
    final changeType = change['change_type'] as String? ?? 'upsert';
    final data = (change['data'] as Map<String, dynamic>?) ?? const {};
    final nowIso = DateTime.now().toUtc().toIso8601String();

    if (changeType == 'tombstone') {
      final table = _tableNameForEntity(entityType);
      if (table == null) return;
      if (entityType == 'category') {
        db.execute(
          "UPDATE local_categories SET is_archived = 1, sync_status = 'synced' WHERE id = ?",
          [entityId],
        );
      } else {
        db.execute(
          "UPDATE $table SET status = 'archived', sync_status = 'synced' WHERE id = ?",
          [entityId],
        );
      }
      return;
    }

    switch (entityType) {
      case 'category':
        db.execute(
          '''
          INSERT OR REPLACE INTO local_categories (
            id, user_id, name, kind, icon_key, color_hex, is_system, is_archived, version, sync_status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'synced', ?, ?)
          ''',
          [
            data['id'] ?? entityId,
            data['user_id'],
            data['name'] ?? 'Kategori',
            data['kind'] ?? 'expense',
            data['icon_key'] ?? 'receipt',
            data['color_hex'] ?? '#0F766E',
            (data['is_system'] == true || data['is_system'] == 1) ? 1 : 0,
            (data['is_archived'] == true || data['is_archived'] == 1) ? 1 : 0,
            data['version'] ?? 1,
            data['created_at'] ?? nowIso,
            data['updated_at'] ?? nowIso,
          ],
        );
        break;
      case 'transaction':
        db.execute(
          '''
          INSERT OR REPLACE INTO local_transactions (
            id, user_id, category_id, type, source_type, amount, transaction_date,
            title, notes, status, reversal_of_transaction_id, version, sync_status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'synced', ?, ?)
          ''',
          [
            data['id'] ?? entityId,
            data['user_id'] ?? db.userId,
            data['category_id'],
            data['type'] ?? 'expense',
            data['source_type'] ?? 'manual',
            data['amount'] ?? 1,
            (data['transaction_date'] as String? ?? nowIso).substring(0, 10),
            data['title'],
            data['notes'],
            data['status'] ?? 'active',
            data['reversal_of_transaction_id'],
            data['version'] ?? 1,
            data['created_at'] ?? nowIso,
            data['updated_at'] ?? nowIso,
          ],
        );
        break;
      case 'debt':
        db.execute(
          '''
          INSERT OR REPLACE INTO local_debts (
            id, user_id, direction, counterparty_name, title, notes,
            principal_amount, remaining_amount, start_date, due_date,
            status, version, sync_status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'synced', ?, ?)
          ''',
          [
            data['id'] ?? entityId,
            data['user_id'] ?? db.userId,
            data['direction'] ?? 'payable',
            data['counterparty_name'] ?? '-',
            data['title'],
            data['notes'],
            data['principal_amount'] ?? 1,
            data['remaining_amount'] ?? 0,
            (data['start_date'] as String? ?? nowIso).substring(0, 10),
            data['due_date'] != null
                ? (data['due_date'] as String).substring(0, 10)
                : null,
            data['status'] ?? 'active',
            data['version'] ?? 1,
            data['created_at'] ?? nowIso,
            data['updated_at'] ?? nowIso,
          ],
        );
        break;
      case 'wishlist':
        db.execute(
          '''
          INSERT OR REPLACE INTO local_wishlists (
            id, user_id, item_name, category_id, target_amount, saved_amount,
            priority, target_date, url_or_reference, notes, status, version, sync_status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'synced', ?, ?)
          ''',
          [
            data['id'] ?? entityId,
            data['user_id'] ?? db.userId,
            data['item_name'] ?? 'Item',
            data['category_id'],
            data['target_amount'] ?? 1,
            data['saved_amount'] ?? 0,
            data['priority'] ?? 'medium',
            data['target_date'] != null
                ? (data['target_date'] as String).substring(0, 10)
                : null,
            data['url_or_reference'],
            data['notes'],
            data['status'] ?? 'planned',
            data['version'] ?? 1,
            data['created_at'] ?? nowIso,
            data['updated_at'] ?? nowIso,
          ],
        );
        break;
    }
  }
}
