import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:uuid/uuid.dart';

class BudgetRepository {
  final AppDatabase db;
  final Uuid _uuid;

  BudgetRepository(this.db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static String deterministicBudgetId({
    required String userId,
    required String categoryId,
    required String periodMonth,
  }) {
    final raw =
        'pf-budget-v1:${userId.trim()}:${categoryId.trim()}:${periodMonth.trim()}';
    final hex = sha256.convert(utf8.encode(raw)).toString();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-4'
        '${hex.substring(13, 16)}-8'
        '${hex.substring(17, 20)}-'
        '${hex.substring(20, 32)}';
  }

  Future<String> upsertBudget({
    required String categoryId,
    required String periodMonth,
    required int limitAmount,
  }) async {
    if (limitAmount <= 0) {
      throw ArgumentError('Nominal anggaran harus lebih dari Rp 0');
    }
    final budgetId = deterministicBudgetId(
      userId: db.userId,
      categoryId: categoryId,
      periodMonth: periodMonth,
    );
    final existing = await db.getBudgetById(budgetId);
    final opId = _uuid.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final nextVersion = existing != null ? existing.version + 1 : 1;

    await db.transaction(() async {
      db.execute(
        '''
        INSERT INTO local_budgets (
          id, user_id, category_id, period_month, limit_amount,
          status, version, sync_status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, 'active', ?, 'pending', ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          limit_amount = excluded.limit_amount,
          status = 'active',
          version = excluded.version,
          sync_status = 'pending',
          updated_at = excluded.updated_at
        ''',
        [
          budgetId,
          db.userId,
          categoryId,
          periodMonth,
          limitAmount,
          nextVersion,
          existing?.createdAt.isNotEmpty == true ? existing!.createdAt : nowIso,
          nowIso,
        ],
      );

      db.enqueueOutbox(
        operationId: opId,
        entityType: 'budget',
        entityId: budgetId,
        operationType: existing != null ? 'update' : 'create',
        baseVersion: existing?.version,
        payload: {
          'id': budgetId,
          'category_id': categoryId,
          'period_month': periodMonth,
          'limit_amount': limitAmount,
          'status': 'active',
        },
      );
    });

    return budgetId;
  }

  Future<void> archiveBudget(String budgetId) async {
    final existing = await db.getBudgetById(budgetId);
    if (existing == null) return;
    final opId = _uuid.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final nextVersion = existing.version + 1;

    await db.transaction(() async {
      db.execute(
        '''
        UPDATE local_budgets
        SET status = 'archived', version = ?, sync_status = 'pending', updated_at = ?
        WHERE id = ? AND user_id = ?
        ''',
        [nextVersion, nowIso, budgetId, db.userId],
      );

      db.enqueueOutbox(
        operationId: opId,
        entityType: 'budget',
        entityId: budgetId,
        operationType: 'archive',
        baseVersion: existing.version,
        payload: {
          'id': budgetId,
          'category_id': existing.categoryId,
          'period_month': existing.periodMonth,
          'limit_amount': existing.limitAmount,
          'status': 'archived',
        },
      );
    });
  }
}
