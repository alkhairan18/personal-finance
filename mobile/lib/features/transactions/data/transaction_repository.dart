import 'dart:math';

import 'package:personal_finance/core/database/app_database.dart';
import 'package:uuid/uuid.dart';

class MonthlySummary {
  final int totalIncome;
  final int totalExpense;

  const MonthlySummary({
    required this.totalIncome,
    required this.totalExpense,
  });

  int get netAmount => totalIncome - totalExpense;
}

class TransactionRepository {
  final AppDatabase db;
  final Uuid _uuid;

  TransactionRepository(this.db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  Future<String> createTransaction({
    required String type,
    required int amount,
    required String transactionDate,
    String? categoryId,
    String? title,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero');
    }

    final txId = _uuid.v4();
    final opId = _uuid.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await db.transaction(() async {
      db.execute(
        '''
        INSERT INTO local_transactions (
          id, user_id, category_id, type, source_type, amount, transaction_date,
          title, notes, status, reversal_of_transaction_id, version, sync_status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, 'manual', ?, ?, ?, ?, 'active', NULL, 1, 'pending_create', ?, ?)
        ''',
        [
          txId,
          db.userId,
          categoryId,
          type,
          amount,
          transactionDate,
          title,
          notes,
          nowIso,
          nowIso,
        ],
      );

      db.enqueueOutbox(
        operationId: opId,
        entityType: 'transaction',
        entityId: txId,
        operationType: 'create',
        baseVersion: null,
        payload: {
          'type': type,
          'source_type': 'manual',
          'amount': amount,
          'transaction_date': transactionDate,
          'category_id': categoryId,
          'title': title,
          'notes': notes,
        },
      );
    });

    return txId;
  }

  Future<void> updateTransaction({
    required String transactionId,
    required int amount,
    required String transactionDate,
    String? type,
    String? categoryId,
    String? title,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero');
    }

    final existing = await db.getTransactionById(transactionId);
    if (existing == null) {
      throw StateError('Transaction not found');
    }
    if (existing.status != 'active') {
      throw StateError('Only active transactions can be updated');
    }

    final opId = _uuid.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final newVersion = existing.version + 1;
    final resolvedType = type ?? existing.type;
    final resolvedCategory = categoryId ?? existing.categoryId;

    await db.transaction(() async {
      db.execute(
        '''
        UPDATE local_transactions
        SET type = ?, amount = ?, transaction_date = ?, category_id = ?,
            title = ?, notes = ?, version = ?, sync_status = 'pending_update', updated_at = ?
        WHERE id = ? AND user_id = ?
        ''',
        [
          resolvedType,
          amount,
          transactionDate,
          resolvedCategory,
          title,
          notes,
          newVersion,
          nowIso,
          transactionId,
          db.userId,
        ],
      );

      db.enqueueOutbox(
        operationId: opId,
        entityType: 'transaction',
        entityId: transactionId,
        operationType: 'update',
        baseVersion: existing.version,
        payload: {
          'type': resolvedType,
          'source_type': existing.sourceType,
          'amount': amount,
          'transaction_date': transactionDate,
          'category_id': resolvedCategory,
          'title': title,
          'notes': notes,
        },
      );
    });
  }

  Future<String> createCustomCategory({
    required String name,
    required String kind,
    String iconKey = 'receipt',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Nama kategori wajib diisi');
    }

    final catId = _uuid.v4();
    final opId = _uuid.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await db.transaction(() async {
      db.execute(
        '''
        INSERT INTO local_categories (
          id, user_id, name, kind, icon_key, color_hex, is_system, is_archived, version, sync_status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, '#0F766E', 0, 0, 1, 'pending_create', ?, ?)
        ''',
        [
          catId,
          db.userId,
          trimmed,
          kind,
          iconKey,
          nowIso,
          nowIso,
        ],
      );

      db.enqueueOutbox(
        operationId: opId,
        entityType: 'category',
        entityId: catId,
        operationType: 'create',
        baseVersion: null,
        payload: {
          'name': trimmed,
          'kind': kind,
          'type': kind,
          'icon_key': iconKey,
        },
      );
    });

    return catId;
  }

  Future<String> reverseTransaction({
    required String originalTransactionId,
    required String reversalDate,
    String? notes,
  }) async {
    final original = await db.getTransactionById(originalTransactionId);
    if (original == null) {
      throw StateError('Original transaction not found');
    }
    if (original.status != 'active') {
      throw StateError('Only active transactions can be reversed');
    }

    final reversalId = _uuid.v4();
    final opId = _uuid.v4();
    final oppositeType = original.type == 'expense' ? 'income' : 'expense';
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final reversalTitle = 'Koreksi: ${original.title ?? 'Transaksi'}';

    await db.transaction(() async {
      db.execute(
        '''
        UPDATE local_transactions
        SET status = 'reversed', version = version + 1, sync_status = 'pending_update', updated_at = ?
        WHERE id = ? AND user_id = ?
        ''',
        [nowIso, originalTransactionId, db.userId],
      );

      db.execute(
        '''
        INSERT INTO local_transactions (
          id, user_id, category_id, type, source_type, amount, transaction_date,
          title, notes, status, reversal_of_transaction_id, version, sync_status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, 'reversal', ?, ?, ?, ?, 'active', ?, 1, 'pending_create', ?, ?)
        ''',
        [
          reversalId,
          db.userId,
          original.categoryId,
          oppositeType,
          original.amount,
          reversalDate,
          reversalTitle,
          notes,
          originalTransactionId,
          nowIso,
          nowIso,
        ],
      );

      if (original.sourceType == 'debt_payment') {
        final paymentRows = db.select(
          '''
          SELECT * FROM local_debt_payments
          WHERE linked_transaction_id = ? AND user_id = ? AND status = 'active'
          LIMIT 1
          ''',
          [originalTransactionId, db.userId],
        );
        if (paymentRows.isNotEmpty) {
          final paymentRow = paymentRows.first;
          final paymentId = paymentRow['id'] as String;
          final debtId = paymentRow['debt_id'] as String;
          final payAmount = paymentRow['amount'] as int;

          db.execute(
            '''
            UPDATE local_debt_payments
            SET status = 'reversed', version = version + 1, sync_status = 'pending_update', updated_at = ?
            WHERE id = ? AND user_id = ?
            ''',
            [nowIso, paymentId, db.userId],
          );

          final debtRows = db.select(
            'SELECT * FROM local_debts WHERE id = ? AND user_id = ? LIMIT 1',
            [debtId, db.userId],
          );
          if (debtRows.isNotEmpty) {
            final currentRem = debtRows.first['remaining_amount'] as int;
            final principal = debtRows.first['principal_amount'] as int;
            final restoredRem = min(principal, currentRem + payAmount);
            db.execute(
              '''
              UPDATE local_debts
              SET remaining_amount = ?, status = 'active', version = version + 1, sync_status = 'pending_update', updated_at = ?
              WHERE id = ? AND user_id = ?
              ''',
              [restoredRem, nowIso, debtId, db.userId],
            );
          }

          db.enqueueOutbox(
            operationId: opId,
            entityType: 'debt_payment',
            entityId: paymentId,
            operationType: 'reverse_debt_payment',
            baseVersion: (paymentRow['version'] as int?) ?? 1,
            payload: {
              'debt_payment_id': paymentId,
              'reversal_transaction_id': reversalId,
              'reason': notes ?? 'Koreksi pembayaran hutang',
            },
          );
          return;
        }
      } else if (original.sourceType == 'installment_payment') {
        final paymentRows = db.select(
          '''
          SELECT * FROM local_installment_payments
          WHERE linked_transaction_id = ? AND user_id = ? AND status = 'active'
          LIMIT 1
          ''',
          [originalTransactionId, db.userId],
        );
        if (paymentRows.isNotEmpty) {
          final paymentRow = paymentRows.first;
          final paymentId = paymentRow['id'] as String;
          final installmentId = paymentRow['installment_id'] as String;
          final payAmount = paymentRow['amount'] as int;

          db.execute(
            '''
            UPDATE local_installment_payments
            SET status = 'reversed', version = version + 1, sync_status = 'pending_update', updated_at = ?
            WHERE id = ? AND user_id = ?
            ''',
            [nowIso, paymentId, db.userId],
          );

          final termRows = db.select(
            'SELECT * FROM local_installments WHERE id = ? AND user_id = ? LIMIT 1',
            [installmentId, db.userId],
          );
          if (termRows.isNotEmpty) {
            final currentPaid = termRows.first['paid_amount'] as int;
            final planId = termRows.first['plan_id'] as String;
            final restoredPaid = max(0, currentPaid - payAmount);
            final restoredStatus = restoredPaid > 0 ? 'partial' : 'pending';
            db.execute(
              '''
              UPDATE local_installments
              SET paid_amount = ?, status = ?, paid_at = NULL, version = version + 1, sync_status = 'pending_update', updated_at = ?
              WHERE id = ? AND user_id = ?
              ''',
              [restoredPaid, restoredStatus, nowIso, installmentId, db.userId],
            );

            db.execute(
              '''
              UPDATE local_installment_plans
              SET status = 'active', version = version + 1, updated_at = ?
              WHERE id = ? AND user_id = ? AND status = 'completed'
              ''',
              [nowIso, planId, db.userId],
            );
          }

          db.enqueueOutbox(
            operationId: opId,
            entityType: 'installment_payment',
            entityId: paymentId,
            operationType: 'reverse_installment_payment',
            baseVersion: (paymentRow['version'] as int?) ?? 1,
            payload: {
              'installment_payment_id': paymentId,
              'reversal_transaction_id': reversalId,
              'reason': notes ?? 'Koreksi pembayaran cicilan',
            },
          );
          return;
        }
      }

      db.enqueueOutbox(
        operationId: opId,
        entityType: 'transaction',
        entityId: originalTransactionId,
        operationType: 'reverse_transaction',
        baseVersion: original.version,
        payload: {
          'reversal_transaction_id': reversalId,
          'reversal_date': reversalDate,
          'notes': notes,
        },
      );
    });

    return reversalId;
  }

  Future<MonthlySummary> getMonthlySummary(String yearMonth) async {
    final txs = await db.getActiveTransactions(yearMonth: yearMonth);
    var income = 0;
    var expense = 0;
    for (final tx in txs) {
      if (tx.type == 'income') {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }
    }
    return MonthlySummary(totalIncome: income, totalExpense: expense);
  }
}
