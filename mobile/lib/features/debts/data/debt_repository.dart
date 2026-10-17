import 'package:personal_finance/core/database/app_database.dart';
import 'package:uuid/uuid.dart';

class DebtPaymentRecordResult {
  final String paymentId;
  final String transactionId;
  final int newRemainingAmount;

  const DebtPaymentRecordResult({
    required this.paymentId,
    required this.transactionId,
    required this.newRemainingAmount,
  });
}

class DebtRepository {
  final AppDatabase db;
  final Uuid _uuid;

  DebtRepository(this.db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  Future<String> createDebt({
    required String direction,
    required String counterpartyName,
    required int principalAmount,
    required String startDate,
    String? dueDate,
    String? title,
    String? notes,
  }) async {
    if (principalAmount <= 0) {
      throw ArgumentError('principalAmount must be greater than zero');
    }

    final debtId = _uuid.v4();
    final opId = _uuid.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await db.transaction(() async {
      db.execute(
        '''
        INSERT INTO local_debts (
          id, user_id, direction, counterparty_name, title, notes,
          principal_amount, remaining_amount, start_date, due_date,
          status, version, sync_status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', 1, 'pending_create', ?, ?)
        ''',
        [
          debtId,
          db.userId,
          direction,
          counterpartyName,
          title,
          notes,
          principalAmount,
          principalAmount,
          startDate,
          dueDate,
          nowIso,
          nowIso,
        ],
      );

      db.enqueueOutbox(
        operationId: opId,
        entityType: 'debt',
        entityId: debtId,
        operationType: 'create',
        baseVersion: null,
        payload: {
          'direction': direction,
          'counterparty_name': counterpartyName,
          'title': title,
          'notes': notes,
          'principal_amount': principalAmount,
          'remaining_amount': principalAmount,
          'start_date': startDate,
          'due_date': dueDate,
          'status': 'active',
        },
      );
    });

    return debtId;
  }

  Future<DebtPaymentRecordResult> recordPayment({
    required String debtId,
    required int amount,
    required String paymentDate,
    String? categoryId,
    String? notes,
  }) async {
    final debt = await db.getDebtById(debtId);
    if (debt == null) {
      throw StateError('Debt not found');
    }
    if (amount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero');
    }
    if (amount > debt.remainingAmount) {
      throw StateError('Nominal pembayaran melebihi sisa kewajiban');
    }

    final paymentId = _uuid.v4();
    final txId = _uuid.v4();
    final opId = _uuid.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final txType = debt.direction == 'payable' ? 'expense' : 'income';
    final txTitle = debt.direction == 'payable'
        ? 'Bayar Hutang: ${debt.counterpartyName}'
        : 'Terima Piutang: ${debt.counterpartyName}';
    final newRemaining = debt.remainingAmount - amount;
    final newStatus = newRemaining == 0 ? 'paid' : 'active';

    await db.transaction(() async {
      db.execute(
        '''
        INSERT INTO local_transactions (
          id, user_id, category_id, type, source_type, amount, transaction_date,
          title, notes, status, reversal_of_transaction_id, version, sync_status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, 'debt_payment', ?, ?, ?, ?, 'active', NULL, 1, 'pending_create', ?, ?)
        ''',
        [
          txId,
          db.userId,
          categoryId,
          txType,
          amount,
          paymentDate,
          txTitle,
          notes,
          nowIso,
          nowIso,
        ],
      );

      db.execute(
        '''
        INSERT INTO local_debt_payments (
          id, user_id, debt_id, linked_transaction_id, amount, payment_date,
          notes, status, version, sync_status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 'active', 1, 'pending_create', ?, ?)
        ''',
        [
          paymentId,
          db.userId,
          debtId,
          txId,
          amount,
          paymentDate,
          notes,
          nowIso,
          nowIso,
        ],
      );

      db.execute(
        '''
        UPDATE local_debts
        SET remaining_amount = ?, status = ?, version = version + 1, sync_status = 'pending_update', updated_at = ?
        WHERE id = ? AND user_id = ?
        ''',
        [
          newRemaining,
          newStatus,
          nowIso,
          debtId,
          db.userId,
        ],
      );

      db.enqueueOutbox(
        operationId: opId,
        entityType: 'debt',
        entityId: debtId,
        operationType: 'record_debt_payment',
        baseVersion: debt.version,
        payload: {
          'payment_id': paymentId,
          'linked_transaction_id': txId,
          'amount': amount,
          'payment_date': paymentDate,
          'category_id': categoryId,
          'notes': notes,
        },
      );
    });

    return DebtPaymentRecordResult(
      paymentId: paymentId,
      transactionId: txId,
      newRemainingAmount: newRemaining,
    );
  }
}
