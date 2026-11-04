import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:personal_finance/core/database/app_database.dart';
import 'package:uuid/uuid.dart';

class BackupExportService {
  const BackupExportService._();

  static const Uuid _uuid = Uuid();

  static Future<String> generateBackupJsonString(AppDatabase db) async {
    final snapshot = await db.exportSnapshotMap();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(snapshot);
  }

  static Future<File> exportJsonBackupToFile({
    required AppDatabase db,
    required String directoryPath,
  }) async {
    final jsonContent = await generateBackupJsonString(db);
    final dateTag = DateTime.now().toIso8601String().substring(0, 10);
    final sanitizedUser = db.userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filePath =
        p.join(directoryPath, 'backup_${sanitizedUser}_$dateTag.json');
    final file = File(filePath);
    return file.writeAsString(jsonContent);
  }

  static Future<void> restoreFromJsonString(
    AppDatabase db,
    String jsonContent, {
    bool enqueueForSync = true,
  }) async {
    final decoded = jsonDecode(jsonContent);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Format JSON cadangan tidak valid.');
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final transactions =
        (decoded['transactions'] as List<dynamic>?) ?? const [];
    final debts = (decoded['debts'] as List<dynamic>?) ?? const [];
    final debtPayments =
        (decoded['debt_payments'] as List<dynamic>?) ?? const [];
    final installmentPlans =
        (decoded['installment_plans'] as List<dynamic>?) ?? const [];
    final installments =
        (decoded['installments'] as List<dynamic>?) ?? const [];
    final installmentPayments =
        (decoded['installment_payments'] as List<dynamic>?) ?? const [];
    final wishlists = (decoded['wishlists'] as List<dynamic>?) ?? const [];
    final budgets = (decoded['budgets'] as List<dynamic>?) ?? const [];
    final targetSyncStatus = enqueueForSync ? 'pending' : 'synced';

    await db.transaction(() async {
      for (final raw in transactions) {
        if (raw is! Map<String, dynamic>) continue;
        final id = (raw['id'] as String?) ?? _uuid.v4();
        db.execute(
          '''
          INSERT OR REPLACE INTO local_transactions (
            id, user_id, category_id, type, source_type, amount, transaction_date,
            title, notes, status, reversal_of_transaction_id, version, sync_status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            id,
            db.userId,
            raw['category_id'],
            raw['type'] ?? 'expense',
            raw['source_type'] ?? 'manual',
            raw['amount'] ?? 1,
            raw['transaction_date'] ?? nowIso.substring(0, 10),
            raw['title'],
            raw['notes'],
            raw['status'] ?? 'active',
            raw['reversal_of_transaction_id'],
            raw['version'] ?? 1,
            targetSyncStatus,
            raw['created_at'] ?? nowIso,
            raw['updated_at'] ?? nowIso,
          ],
        );
        if (enqueueForSync) {
          db.enqueueOutbox(
            operationId: _uuid.v4(),
            entityType: 'transaction',
            entityId: id,
            operationType: 'create',
            baseVersion: null,
            payload: {
              'id': id,
              'type': raw['type'] ?? 'expense',
              'source_type': raw['source_type'] ?? 'manual',
              'amount': raw['amount'] ?? 1,
              'transaction_date':
                  raw['transaction_date'] ?? nowIso.substring(0, 10),
              'category_id': raw['category_id'],
              'title': raw['title'],
              'notes': raw['notes'],
            },
          );
        }
      }

      for (final raw in debts) {
        if (raw is! Map<String, dynamic>) continue;
        final id = (raw['id'] as String?) ?? _uuid.v4();
        db.execute(
          '''
          INSERT OR REPLACE INTO local_debts (
            id, user_id, direction, counterparty_name, title, notes,
            principal_amount, remaining_amount, start_date, due_date,
            status, version, sync_status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            id,
            db.userId,
            raw['direction'] ?? 'payable',
            raw['counterparty_name'] ?? '-',
            raw['title'],
            raw['notes'],
            raw['principal_amount'] ?? 1,
            raw['remaining_amount'] ?? 0,
            raw['start_date'] ?? nowIso.substring(0, 10),
            raw['due_date'],
            raw['status'] ?? 'active',
            raw['version'] ?? 1,
            targetSyncStatus,
            raw['created_at'] ?? nowIso,
            raw['updated_at'] ?? nowIso,
          ],
        );
        if (enqueueForSync) {
          db.enqueueOutbox(
            operationId: _uuid.v4(),
            entityType: 'debt',
            entityId: id,
            operationType: 'create',
            baseVersion: null,
            payload: {
              'id': id,
              'direction': raw['direction'] ?? 'payable',
              'counterparty_name': raw['counterparty_name'] ?? '-',
              'title': raw['title'],
              'notes': raw['notes'],
              'principal_amount': raw['principal_amount'] ?? 1,
              'remaining_amount': raw['remaining_amount'] ?? 0,
              'start_date': raw['start_date'] ?? nowIso.substring(0, 10),
              'due_date': raw['due_date'],
              'status': raw['status'] ?? 'active',
            },
          );
        }
      }

      for (final raw in debtPayments) {
        if (raw is! Map<String, dynamic>) continue;
        db.execute(
          '''
          INSERT OR REPLACE INTO local_debt_payments (
            id, user_id, debt_id, linked_transaction_id, amount, payment_date,
            notes, status, version, sync_status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            raw['id'],
            db.userId,
            raw['debt_id'],
            raw['linked_transaction_id'],
            raw['amount'] ?? 1,
            raw['payment_date'] ?? nowIso.substring(0, 10),
            raw['notes'],
            raw['status'] ?? 'active',
            raw['version'] ?? 1,
            raw['sync_status'] ?? 'synced',
            raw['created_at'] ?? nowIso,
            raw['updated_at'] ?? nowIso,
          ],
        );
      }

      for (final raw in installmentPlans) {
        if (raw is! Map<String, dynamic>) continue;
        final id = (raw['id'] as String?) ?? _uuid.v4();
        db.execute(
          '''
          INSERT OR REPLACE INTO local_installment_plans (
            id, user_id, title, vendor_name, category_id, total_amount,
            installment_count, frequency, start_date, notes, status, version, sync_status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            id,
            db.userId,
            raw['title'] ?? 'Cicilan',
            raw['vendor_name'],
            raw['category_id'],
            raw['total_amount'] ?? 1,
            raw['installment_count'] ?? 1,
            raw['frequency'] ?? 'monthly',
            raw['start_date'] ?? nowIso.substring(0, 10),
            raw['notes'],
            raw['status'] ?? 'active',
            raw['version'] ?? 1,
            targetSyncStatus,
            raw['created_at'] ?? nowIso,
            raw['updated_at'] ?? nowIso,
          ],
        );
        if (enqueueForSync) {
          db.enqueueOutbox(
            operationId: _uuid.v4(),
            entityType: 'installment_plan',
            entityId: id,
            operationType: 'create',
            baseVersion: null,
            payload: {
              'id': id,
              'title': raw['title'] ?? 'Cicilan',
              'vendor_name': raw['vendor_name'],
              'category_id': raw['category_id'],
              'total_amount': raw['total_amount'] ?? 1,
              'installment_count': raw['installment_count'] ?? 1,
              'frequency': raw['frequency'] ?? 'monthly',
              'start_date': raw['start_date'] ?? nowIso.substring(0, 10),
              'notes': raw['notes'],
              'status': raw['status'] ?? 'active',
            },
          );
        }
      }

      for (final raw in installments) {
        if (raw is! Map<String, dynamic>) continue;
        db.execute(
          '''
          INSERT OR REPLACE INTO local_installments (
            id, user_id, plan_id, installment_number, due_date,
            planned_amount, paid_amount, status, paid_at, version, sync_status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            raw['id'],
            db.userId,
            raw['plan_id'],
            raw['installment_number'] ?? 1,
            raw['due_date'] ?? nowIso.substring(0, 10),
            raw['planned_amount'] ?? 1,
            raw['paid_amount'] ?? 0,
            raw['status'] ?? 'pending',
            raw['paid_at'],
            raw['version'] ?? 1,
            raw['sync_status'] ?? 'synced',
            raw['created_at'] ?? nowIso,
            raw['updated_at'] ?? nowIso,
          ],
        );
      }

      for (final raw in installmentPayments) {
        if (raw is! Map<String, dynamic>) continue;
        db.execute(
          '''
          INSERT OR REPLACE INTO local_installment_payments (
            id, user_id, installment_id, linked_transaction_id, amount,
            payment_date, notes, status, version, sync_status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            raw['id'],
            db.userId,
            raw['installment_id'],
            raw['linked_transaction_id'],
            raw['amount'] ?? 1,
            raw['payment_date'] ?? nowIso.substring(0, 10),
            raw['notes'],
            raw['status'] ?? 'active',
            raw['version'] ?? 1,
            raw['sync_status'] ?? 'synced',
            raw['created_at'] ?? nowIso,
            raw['updated_at'] ?? nowIso,
          ],
        );
      }

      for (final raw in wishlists) {
        if (raw is! Map<String, dynamic>) continue;
        final id = (raw['id'] as String?) ?? _uuid.v4();
        db.execute(
          '''
          INSERT OR REPLACE INTO local_wishlists (
            id, user_id, item_name, category_id, target_amount, saved_amount,
            priority, target_date, url_or_reference, notes, status, version, sync_status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            id,
            db.userId,
            raw['item_name'] ?? 'Item',
            raw['category_id'],
            raw['target_amount'] ?? 1,
            raw['saved_amount'] ?? 0,
            raw['priority'] ?? 'medium',
            raw['target_date'],
            raw['url_or_reference'],
            raw['notes'],
            raw['status'] ?? 'planned',
            raw['version'] ?? 1,
            targetSyncStatus,
            raw['created_at'] ?? nowIso,
            raw['updated_at'] ?? nowIso,
          ],
        );
        if (enqueueForSync) {
          db.enqueueOutbox(
            operationId: _uuid.v4(),
            entityType: 'wishlist',
            entityId: id,
            operationType: 'create',
            baseVersion: null,
            payload: {
              'id': id,
              'item_name': raw['item_name'] ?? 'Item',
              'category_id': raw['category_id'],
              'target_amount': raw['target_amount'] ?? 1,
              'saved_amount': raw['saved_amount'] ?? 0,
              'priority': raw['priority'] ?? 'medium',
              'target_date': raw['target_date'],
              'url_or_reference': raw['url_or_reference'],
              'notes': raw['notes'],
              'status': raw['status'] ?? 'planned',
            },
          );
        }
      }

      for (final raw in budgets) {
        if (raw is! Map<String, dynamic>) continue;
        final id = (raw['id'] as String?) ?? _uuid.v4();
        db.execute(
          '''
          INSERT OR REPLACE INTO local_budgets (
            id, user_id, category_id, period_month, limit_amount,
            status, version, sync_status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            id,
            db.userId,
            raw['category_id'] ?? '00000000-0000-4000-8000-000000000001',
            raw['period_month'] ?? nowIso.substring(0, 7),
            raw['limit_amount'] ?? 1,
            raw['status'] ?? 'active',
            raw['version'] ?? 1,
            targetSyncStatus,
            raw['created_at'] ?? nowIso,
            raw['updated_at'] ?? nowIso,
          ],
        );
        if (enqueueForSync) {
          db.enqueueOutbox(
            operationId: _uuid.v4(),
            entityType: 'budget',
            entityId: id,
            operationType: 'create',
            baseVersion: null,
            payload: {
              'id': id,
              'category_id':
                  raw['category_id'] ?? '00000000-0000-4000-8000-000000000001',
              'period_month': raw['period_month'] ?? nowIso.substring(0, 7),
              'limit_amount': raw['limit_amount'] ?? 1,
              'status': raw['status'] ?? 'active',
            },
          );
        }
      }
    });
  }
}
