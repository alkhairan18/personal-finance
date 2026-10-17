import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/core/finance/installment_calculator.dart';
import 'package:uuid/uuid.dart';

class InstallmentRepository {
  final AppDatabase db;
  final Uuid _uuid;

  InstallmentRepository(this.db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  Future<String> createPlanWithSchedule({
    required String title,
    String? vendorName,
    String? categoryId,
    required int totalAmount,
    required int installmentCount,
    required String frequency,
    required String startDate,
    String? notes,
  }) async {
    final parsedStart = DateTime.parse(startDate);
    final schedule = InstallmentCalculator.generateSchedule(
      totalAmount: totalAmount,
      count: installmentCount,
      frequency: frequency,
      startDate: parsedStart,
    );

    final planId = _uuid.v4();
    final opId = _uuid.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final termsPayload = <Map<String, dynamic>>[];

    await db.transaction(() async {
      db.execute(
        '''
        INSERT INTO local_installment_plans (
          id, user_id, title, vendor_name, category_id, total_amount,
          installment_count, frequency, start_date, notes, status, version, sync_status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', 1, 'pending_create', ?, ?)
        ''',
        [
          planId,
          db.userId,
          title,
          vendorName,
          categoryId,
          totalAmount,
          installmentCount,
          frequency,
          startDate,
          notes,
          nowIso,
          nowIso,
        ],
      );

      for (final term in schedule) {
        final termId = _uuid.v4();
        db.execute(
          '''
          INSERT INTO local_installments (
            id, user_id, plan_id, installment_number, due_date,
            planned_amount, paid_amount, status, paid_at, version, sync_status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pending', NULL, 1, 'pending_create', ?, ?)
          ''',
          [
            termId,
            db.userId,
            planId,
            term.installmentNumber,
            term.dueDateIso,
            term.plannedAmount,
            nowIso,
            nowIso,
          ],
        );

        termsPayload.add({
          'id': termId,
          'installment_number': term.installmentNumber,
          'due_date': term.dueDateIso,
          'planned_amount': term.plannedAmount,
        });
      }

      db.enqueueOutbox(
        operationId: opId,
        entityType: 'installment_plan',
        entityId: planId,
        operationType: 'create',
        baseVersion: null,
        payload: {
          'title': title,
          'vendor_name': vendorName,
          'category_id': categoryId,
          'total_amount': totalAmount,
          'installment_count': installmentCount,
          'frequency': frequency,
          'start_date': startDate,
          'notes': notes,
          'installments': termsPayload,
        },
      );
    });

    return planId;
  }

  Future<String> recordPayment({
    required String installmentId,
    required int amount,
    required String paymentDate,
    String? notes,
  }) async {
    final installment = await db.getInstallmentById(installmentId);
    if (installment == null) {
      throw StateError('Installment term not found');
    }
    final remaining = installment.plannedAmount - installment.paidAmount;
    if (amount <= 0 || amount > remaining) {
      throw StateError('Nominal pembayaran melebihi sisa cicilan');
    }

    final paymentId = _uuid.v4();
    final txId = _uuid.v4();
    final opId = _uuid.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final newPaid = installment.paidAmount + amount;
    final newStatus = newPaid >= installment.plannedAmount ? 'paid' : 'partial';

    await db.transaction(() async {
      final planRows = db.select(
        'SELECT * FROM local_installment_plans WHERE id = ? AND user_id = ? LIMIT 1',
        [installment.planId, db.userId],
      );
      final planTitle = planRows.isNotEmpty ? (planRows.first['title'] as String) : 'Cicilan';
      final planCatId = planRows.isNotEmpty ? (planRows.first['category_id'] as String?) : null;

      db.execute(
        '''
        INSERT INTO local_transactions (
          id, user_id, category_id, type, source_type, amount, transaction_date,
          title, notes, status, reversal_of_transaction_id, version, sync_status, created_at, updated_at
        ) VALUES (?, ?, ?, 'expense', 'installment_payment', ?, ?, ?, ?, 'active', NULL, 1, 'pending_create', ?, ?)
        ''',
        [
          txId,
          db.userId,
          planCatId,
          amount,
          paymentDate,
          'Cicilan $planTitle #${installment.installmentNumber}',
          notes,
          nowIso,
          nowIso,
        ],
      );

      db.execute(
        '''
        INSERT INTO local_installment_payments (
          id, user_id, installment_id, linked_transaction_id, amount,
          payment_date, notes, status, version, sync_status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 'active', 1, 'pending_create', ?, ?)
        ''',
        [
          paymentId,
          db.userId,
          installmentId,
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
        UPDATE local_installments
        SET paid_amount = ?, status = ?, paid_at = ?, version = version + 1, sync_status = 'pending_update', updated_at = ?
        WHERE id = ? AND user_id = ?
        ''',
        [
          newPaid,
          newStatus,
          newStatus == 'paid' ? nowIso : null,
          nowIso,
          installmentId,
          db.userId,
        ],
      );

      final unpaidRows = db.select(
        '''
        SELECT COUNT(*) AS cnt FROM local_installments
        WHERE plan_id = ? AND user_id = ? AND status != 'paid' AND status != 'archived'
        ''',
        [installment.planId, db.userId],
      );
      final unpaidCount = (unpaidRows.first['cnt'] as int?) ?? 0;
      if (unpaidCount == 0) {
        db.execute(
          '''
          UPDATE local_installment_plans
          SET status = 'completed', version = version + 1, updated_at = ?
          WHERE id = ? AND user_id = ?
          ''',
          [nowIso, installment.planId, db.userId],
        );
      }

      db.enqueueOutbox(
        operationId: opId,
        entityType: 'installment',
        entityId: installmentId,
        operationType: 'record_installment_payment',
        baseVersion: installment.version,
        payload: {
          'payment_id': paymentId,
          'linked_transaction_id': txId,
          'amount': amount,
          'payment_date': paymentDate,
          'notes': notes,
        },
      );
    });

    return paymentId;
  }
}
