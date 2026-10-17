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
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, 1, 'pending_create', ?, ?)
        ''',
        [
          reversalId,
          db.userId,
          original.categoryId,
          oppositeType,
          original.sourceType,
          original.amount,
          reversalDate,
          reversalTitle,
          notes,
          originalTransactionId,
          nowIso,
          nowIso,
        ],
      );

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
