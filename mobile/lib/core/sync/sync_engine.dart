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
  final Future<bool> Function()? onEnsureAuth;
  final Uuid _uuid;

  SyncEngine({
    required this.db,
    required this.apiGateway,
    required this.clientDeviceId,
    this.onEnsureAuth,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  static Duration calculateBackoffDelay(int retryCount) {
    final cappedRetry = retryCount.clamp(0, 8);
    final baseSeconds = min(300, 1 << cappedRetry);
    return Duration(seconds: baseSeconds);
  }

  Future<SyncRunResult> synchronize() async {
    if (onEnsureAuth != null) {
      await onEnsureAuth!();
    }

    var pushedCount = 0;
    var pulledCount = 0;
    var conflictsCount = 0;

    final pending = await db.getPendingOutboxItems();
    for (var offset = 0; offset < pending.length; offset += 100) {
      final batch = pending.skip(offset).take(100).toList();
      final operationsPayload = batch.map(_serializeOutboxForPush).toList();

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

      final pushBody =
          (pushResponse['data'] as Map<String, dynamic>?) ?? pushResponse;
      final rawResults = (pushBody['results'] as List<dynamic>?) ?? const [];
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
            final newVersion =
                (raw['entity_version'] as int?) ?? (raw['new_version'] as int?);
            _markEntitySynced(
              entityType: outboxItem.entityType,
              entityId: outboxItem.entityId,
              newVersion: newVersion,
            );
            db.execute('DELETE FROM sync_outbox WHERE operation_id = ?', [opId]);
            pushedCount++;
          } else if (status == 'conflict') {
            final serverState =
                (raw['server_state'] as Map<String, dynamic>?) ??
                    (raw['conflict_server_state'] as Map<String, dynamic>?) ??
                    <String, dynamic>{};
            await db.recordSyncConflict(
              id: _uuid.v4(),
              operationId: opId,
              entityType: outboxItem.entityType,
              entityId: outboxItem.entityId,
              localPayload: outboxItem.payload,
              serverPayload: serverState,
            );
            db.execute('DELETE FROM sync_outbox WHERE operation_id = ?', [opId]);
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

      final pullBody =
          (pullResponse['data'] as Map<String, dynamic>?) ?? pullResponse;
      final changes = (pullBody['changes'] as List<dynamic>?) ?? const [];
      final nextCursor = (pullBody['next_cursor'] ?? cursor ?? '0').toString();
      final hasMore = (pullBody['has_more'] as bool?) ?? false;

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

  Future<void> resolveConflictUseServer(String conflictId) async {
    final conflicts = await db.getSyncConflicts();
    final conflict = conflicts.where((c) => c.id == conflictId).firstOrNull;
    if (conflict == null) return;

    await db.transaction(() async {
      _applyPulledChange({
        'entity_type': conflict.entityType,
        'entity_id': conflict.entityId,
        'operation': 'upsert',
        'entity_version': conflict.serverPayload['version'] ?? 1,
        'payload': conflict.serverPayload,
      });
      db.execute('DELETE FROM sync_conflicts WHERE id = ?', [conflictId]);
    });
  }

  Future<void> resolveConflictUseLocal(String conflictId) async {
    final conflicts = await db.getSyncConflicts();
    final conflict = conflicts.where((c) => c.id == conflictId).firstOrNull;
    if (conflict == null) return;

    final serverVersion = (conflict.serverPayload['version'] as int?) ?? 1;
    final mergedLocal = <String, dynamic>{
      ...conflict.serverPayload,
      ...conflict.localPayload,
      if (conflict.localPayload['item_name'] != null)
        'title': conflict.localPayload['item_name'],
      if (conflict.localPayload['target_amount'] != null)
        'target_price': conflict.localPayload['target_amount'],
      if (conflict.localPayload['counterparty_name'] != null)
        'counterparty': conflict.localPayload['counterparty_name'],
      if (conflict.localPayload['amount'] != null)
        'amount_minor': conflict.localPayload['amount'],
      'id': conflict.entityId,
      'version': serverVersion,
    };

    await db.transaction(() async {
      _applyPulledChange({
        'entity_type': conflict.entityType,
        'entity_id': conflict.entityId,
        'operation': 'upsert',
        'entity_version': serverVersion,
        'payload': mergedLocal,
      });
      db.enqueueOutbox(
        operationId: _uuid.v4(),
        entityType: conflict.entityType,
        entityId: conflict.entityId,
        operationType: 'update',
        baseVersion: serverVersion,
        payload: conflict.localPayload,
      );
      db.execute('DELETE FROM sync_conflicts WHERE id = ?', [conflictId]);
    });
  }

  Map<String, dynamic> _serializeOutboxForPush(SyncOutboxItem item) {
    var serverEntityType = item.entityType;
    var serverEntityId = item.entityId;
    var serverAction = item.operationType;
    if (serverAction == 'create' || serverAction == 'update') {
      serverAction = 'upsert';
    }

    final rawPayload = Map<String, dynamic>.from(item.payload);
    Map<String, dynamic> normalizedPayload = rawPayload;

    if (item.entityType == 'transaction' ||
        item.entityType == 'financial_transaction') {
      serverEntityType = 'financial_transaction';
      if (item.operationType == 'reverse_transaction') {
        serverAction = 'reverse_transaction';
        normalizedPayload = {
          ...rawPayload,
          'transaction_id': item.entityId,
          'reason': rawPayload['notes'] ?? rawPayload['reason'] ?? 'Koreksi',
        };
      } else {
        final title = rawPayload['title'] as String?;
        final notes = rawPayload['notes'] as String?;
        final combinedNote =
            (title != null && title.isNotEmpty && notes != null && notes.isNotEmpty)
                ? '$title - $notes'
                : (title ?? notes);
        normalizedPayload = {
          ...rawPayload,
          'amount_minor': rawPayload['amount_minor'] ?? rawPayload['amount'],
          'note': rawPayload['note'] ?? combinedNote,
        };
      }
    } else if (item.operationType == 'reverse_debt_payment') {
      serverEntityType = 'debt_payment';
      serverAction = 'reverse_debt_payment';
      normalizedPayload = {
        ...rawPayload,
        'debt_payment_id': rawPayload['debt_payment_id'] ?? item.entityId,
        'reason': rawPayload['reason'] ?? 'Koreksi pembayaran hutang',
      };
    } else if (item.operationType == 'reverse_installment_payment') {
      serverEntityType = 'installment_payment';
      serverAction = 'reverse_installment_payment';
      normalizedPayload = {
        ...rawPayload,
        'installment_payment_id':
            rawPayload['installment_payment_id'] ?? item.entityId,
        'reason': rawPayload['reason'] ?? 'Koreksi pembayaran cicilan',
      };
    } else if (item.entityType == 'debt' &&
        item.operationType == 'record_debt_payment') {
      serverEntityType = 'debt_payment';
      serverEntityId = (rawPayload['payment_id'] as String?) ?? item.entityId;
      serverAction = 'record_debt_payment';
      normalizedPayload = {
        ...rawPayload,
        'id': serverEntityId,
        'debt_id': item.entityId,
        'transaction_id': rawPayload['linked_transaction_id'],
        'amount': rawPayload['amount'],
        'paid_at': rawPayload['payment_date'],
        'category_id': rawPayload['category_id'],
        'note': rawPayload['notes'],
      };
    } else if (item.entityType == 'debt') {
      normalizedPayload = {
        ...rawPayload,
        'counterparty':
            rawPayload['counterparty'] ?? rawPayload['counterparty_name'],
        'note': rawPayload['note'] ?? rawPayload['title'] ?? rawPayload['notes'],
      };
    } else if (item.entityType == 'installment_plan') {
      final rawTerms = (rawPayload['installments'] as List<dynamic>?) ?? const [];
      final mappedTerms = rawTerms.map((t) {
        if (t is! Map<String, dynamic>) return t;
        return {
          ...t,
          'sequence_no': t['sequence_no'] ?? t['installment_number'],
        };
      }).toList();
      normalizedPayload = {
        ...rawPayload,
        'note': rawPayload['note'] ?? rawPayload['notes'],
        'installments': mappedTerms,
      };
    } else if (item.entityType == 'installment' &&
        item.operationType == 'record_installment_payment') {
      serverEntityType = 'installment_payment';
      serverEntityId = (rawPayload['payment_id'] as String?) ?? item.entityId;
      serverAction = 'record_installment_payment';
      normalizedPayload = {
        ...rawPayload,
        'id': serverEntityId,
        'installment_id': item.entityId,
        'transaction_id': rawPayload['linked_transaction_id'],
        'amount': rawPayload['amount'],
        'paid_at': rawPayload['payment_date'],
        'note': rawPayload['notes'],
      };
    } else if (item.entityType == 'wishlist') {
      final rawStatus = (rawPayload['status'] as String?) ?? 'planned';
      final validStatus = rawStatus == 'ready_to_buy' ? 'saving' : rawStatus;
      normalizedPayload = {
        ...rawPayload,
        'title': rawPayload['title'] ?? rawPayload['item_name'],
        'target_price':
            rawPayload['target_price'] ?? rawPayload['target_amount'],
        'saved_amount': rawPayload['saved_amount'] ?? 0,
        'note': rawPayload['note'] ?? rawPayload['notes'],
        'status': validStatus,
      };
    }

    return <String, dynamic>{
      'operation_id': item.operationId,
      'entity_type': serverEntityType,
      'entity_id': serverEntityId,
      'action': serverAction,
      'operation': item.operationType,
      'base_version': item.baseVersion,
      'client_created_at': item.createdAt,
      'client_timestamp': item.createdAt,
      'payload': normalizedPayload,
    };
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
      case 'financial_transaction':
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
    final changeType = (change['operation'] as String?) ??
        (change['change_type'] as String?) ??
        'upsert';
    final data = (change['payload'] as Map<String, dynamic>?) ??
        (change['data'] as Map<String, dynamic>?) ??
        const {};
    final nowIso = DateTime.now().toUtc().toIso8601String();

    if (changeType == 'tombstone' || changeType == 'archive') {
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
            data['kind'] ?? data['type'] ?? 'expense',
            data['icon_key'] ?? 'receipt',
            data['color_hex'] ?? '#0F766E',
            (data['is_system'] == true || data['is_system'] == 1) ? 1 : 0,
            (data['is_archived'] == true ||
                    data['is_archived'] == 1 ||
                    data['archived_at'] != null)
                ? 1
                : 0,
            data['version'] ?? change['entity_version'] ?? 1,
            data['created_at'] ?? nowIso,
            data['updated_at'] ?? nowIso,
          ],
        );
        break;
      case 'transaction':
      case 'financial_transaction':
        final rawStatus = (data['status'] as String?) ?? 'active';
        final localStatus = rawStatus == 'posted' ? 'active' : rawStatus;
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
            data['amount_minor'] ?? data['amount'] ?? 1,
            (data['transaction_date'] as String? ?? nowIso).substring(0, 10),
            data['title'] ?? data['note'],
            data['notes'] ?? data['note'],
            localStatus,
            data['reverses_transaction_id'] ?? data['reversal_of_transaction_id'],
            data['version'] ?? change['entity_version'] ?? 1,
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
            data['counterparty'] ?? data['counterparty_name'] ?? '-',
            data['title'] ?? data['note'],
            data['notes'] ?? data['note'],
            data['principal_amount'] ?? 1,
            data['remaining_amount'] ?? data['principal_amount'] ?? 0,
            (data['start_date'] as String? ?? nowIso).substring(0, 10),
            data['due_date'] != null
                ? (data['due_date'] as String).substring(0, 10)
                : null,
            data['status'] ?? 'active',
            data['version'] ?? change['entity_version'] ?? 1,
            data['created_at'] ?? nowIso,
            data['updated_at'] ?? nowIso,
          ],
        );
        break;
      case 'debt_payment':
        final rawStatus = (data['status'] as String?) ?? 'active';
        db.execute(
          '''
          INSERT OR REPLACE INTO local_debt_payments (
            id, user_id, debt_id, linked_transaction_id, amount, payment_date,
            notes, status, version, sync_status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'synced', ?, ?)
          ''',
          [
            data['id'] ?? entityId,
            data['user_id'] ?? db.userId,
            data['debt_id'] ?? '',
            data['transaction_id'] ?? data['linked_transaction_id'],
            data['amount'] ?? 1,
            (data['paid_at'] as String? ??
                    data['payment_date'] as String? ??
                    nowIso)
                .substring(0, 10),
            data['note'] ?? data['notes'],
            rawStatus == 'posted' ? 'active' : rawStatus,
            data['version'] ?? change['entity_version'] ?? 1,
            data['created_at'] ?? nowIso,
            data['updated_at'] ?? nowIso,
          ],
        );
        break;
      case 'installment_plan':
        db.execute(
          '''
          INSERT OR REPLACE INTO local_installment_plans (
            id, user_id, title, vendor_name, category_id, total_amount,
            installment_count, frequency, start_date, notes, status, version, sync_status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'synced', ?, ?)
          ''',
          [
            data['id'] ?? entityId,
            data['user_id'] ?? db.userId,
            data['title'] ?? 'Cicilan',
            data['vendor_name'],
            data['category_id'],
            data['total_amount'] ?? 1,
            data['installment_count'] ?? 1,
            data['frequency'] ?? 'monthly',
            (data['start_date'] as String? ?? nowIso).substring(0, 10),
            data['note'] ?? data['notes'],
            data['status'] ?? 'active',
            data['version'] ?? change['entity_version'] ?? 1,
            data['created_at'] ?? nowIso,
            data['updated_at'] ?? nowIso,
          ],
        );
        break;
      case 'installment':
        final planned = (data['planned_amount'] as int?) ?? 1;
        final remaining = data['remaining_amount'] as int?;
        final paid = (data['paid_amount'] as int?) ??
            (remaining != null ? max(0, planned - remaining) : 0);
        db.execute(
          '''
          INSERT OR REPLACE INTO local_installments (
            id, user_id, plan_id, installment_number, due_date,
            planned_amount, paid_amount, status, paid_at, version, sync_status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'synced', ?, ?)
          ''',
          [
            data['id'] ?? entityId,
            data['user_id'] ?? db.userId,
            data['plan_id'] ?? '',
            data['sequence_no'] ?? data['installment_number'] ?? 1,
            (data['due_date'] as String? ?? nowIso).substring(0, 10),
            planned,
            paid,
            data['status'] ?? 'pending',
            data['paid_at'],
            data['version'] ?? change['entity_version'] ?? 1,
            data['created_at'] ?? nowIso,
            data['updated_at'] ?? nowIso,
          ],
        );
        break;
      case 'installment_payment':
        final rawStatus = (data['status'] as String?) ?? 'active';
        db.execute(
          '''
          INSERT OR REPLACE INTO local_installment_payments (
            id, user_id, installment_id, linked_transaction_id, amount,
            payment_date, notes, status, version, sync_status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'synced', ?, ?)
          ''',
          [
            data['id'] ?? entityId,
            data['user_id'] ?? db.userId,
            data['installment_id'] ?? '',
            data['transaction_id'] ?? data['linked_transaction_id'],
            data['amount'] ?? 1,
            (data['paid_at'] as String? ??
                    data['payment_date'] as String? ??
                    nowIso)
                .substring(0, 10),
            data['note'] ?? data['notes'],
            rawStatus == 'posted' ? 'active' : rawStatus,
            data['version'] ?? change['entity_version'] ?? 1,
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
            data['title'] ?? data['item_name'] ?? 'Item',
            data['category_id'],
            data['target_price'] ?? data['target_amount'] ?? 1,
            data['saved_amount'] ?? 0,
            data['priority'] ?? 'medium',
            data['target_date'] != null
                ? (data['target_date'] as String).substring(0, 10)
                : null,
            data['url_or_reference'],
            data['note'] ?? data['notes'],
            data['status'] ?? 'planned',
            data['version'] ?? change['entity_version'] ?? 1,
            data['created_at'] ?? nowIso,
            data['updated_at'] ?? nowIso,
          ],
        );
        break;
    }
  }
}
