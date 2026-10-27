import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/features/debts/data/debt_repository.dart';
import 'package:personal_finance/features/installments/data/installment_repository.dart';
import 'package:personal_finance/features/transactions/data/transaction_repository.dart';
import 'package:personal_finance/features/wishlist/data/wishlist_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository txRepo;
  late DebtRepository debtRepo;
  late InstallmentRepository installmentRepo;
  late WishlistRepository wishlistRepo;

  setUp(() async {
    db = AppDatabase.inMemory(userId: 'user-anzhel-uuid');
    await db.ensureDefaultCategoriesSeeded();
    txRepo = TransactionRepository(db);
    debtRepo = DebtRepository(db);
    installmentRepo = InstallmentRepository(db);
    wishlistRepo = WishlistRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('creating an expense while offline inserts local_transactions and sync_outbox atomically', () async {
    final categories = await db.getActiveCategories(kind: 'expense');
    expect(categories, isNotEmpty);

    final txId = await txRepo.createTransaction(
      type: 'expense',
      amount: 45000,
      categoryId: categories.first.id,
      transactionDate: '2026-10-17',
      title: 'Kopi Susu',
    );

    final txs = await db.getActiveTransactions();
    expect(txs.length, 1);
    expect(txs.first.id, txId);
    expect(txs.first.amount, 45000);
    expect(txs.first.syncStatus, 'pending_create');

    final outbox = await db.getPendingOutboxItems();
    expect(outbox.length, 1);
    expect(outbox.first.entityType, 'transaction');
    expect(outbox.first.entityId, txId);
    expect(outbox.first.operationType, 'create');
  });

  test('recording partial debt payment inserts debt_payment, linked transaction, updates remainingAmount, and queues record_debt_payment', () async {
    final debtId = await debtRepo.createDebt(
      direction: 'payable',
      counterpartyName: 'Budi',
      principalAmount: 1000000,
      startDate: '2026-10-01',
      dueDate: '2026-10-25',
      title: 'Pinjaman Modal',
    );

    final paymentResult = await debtRepo.recordPayment(
      debtId: debtId,
      amount: 250000,
      paymentDate: '2026-10-17',
      notes: 'Cicil pertama',
    );

    final debt = await db.getDebtById(debtId);
    expect(debt, isNotNull);
    expect(debt!.remainingAmount, 750000);
    expect(debt.status, 'active');

    final payments = await db.getDebtPayments(debtId);
    expect(payments.length, 1);
    expect(payments.first.id, paymentResult.paymentId);
    expect(payments.first.amount, 250000);
    expect(payments.first.linkedTransactionId, paymentResult.transactionId);

    final txs = await db.getActiveTransactions();
    expect(txs.length, 1);
    expect(txs.first.id, paymentResult.transactionId);
    expect(txs.first.sourceType, 'debt_payment');
    expect(txs.first.amount, 250000);
    expect(txs.first.type, 'expense');

    final outbox = await db.getPendingOutboxItems();
    expect(outbox.map((o) => o.operationType).toList(), ['create', 'record_debt_payment']);
  });

  test('reversing a transaction marks original reversed, creates compensating entry, and queues reverse_transaction', () async {
    final categories = await db.getActiveCategories(kind: 'expense');
    expect(categories.first.id, startsWith('00000000-0000-4000-8000-'));
    final originalId = await txRepo.createTransaction(
      type: 'expense',
      amount: 120000,
      categoryId: categories.first.id,
      transactionDate: '2026-10-17',
      title: 'Salah Input Makan',
    );

    final reversalId = await txRepo.reverseTransaction(
      originalTransactionId: originalId,
      reversalDate: '2026-10-17',
      notes: 'Koreksi nominal',
    );

    final original = await db.getTransactionById(originalId);
    expect(original!.status, 'reversed');

    final reversal = await db.getTransactionById(reversalId);
    expect(reversal!.status, 'active');
    expect(reversal.type, 'income');
    expect(reversal.amount, 120000);
    expect(reversal.reversalOfTransactionId, originalId);

    final summaryAfterReversal = await txRepo.getMonthlySummary('2026-10');
    expect(summaryAfterReversal.totalIncome, 0);
    expect(summaryAfterReversal.totalExpense, 0);
    expect(summaryAfterReversal.netAmount, 0);

    final outbox = await db.getPendingOutboxItems();
    expect(outbox.map((o) => o.operationType).toList(), ['create', 'reverse_transaction']);
  });

  test('creating installment plan and paying first term updates installment and creates linked transaction', () async {
    final planId = await installmentRepo.createPlanWithSchedule(
      title: 'Kredit Laptop',
      vendorName: 'Toko Komputer',
      totalAmount: 6000000,
      installmentCount: 7,
      frequency: 'monthly',
      startDate: '2026-08-17',
    );

    final terms = await db.getInstallmentsForPlan(planId);
    expect(terms.length, 7);
    expect(terms.first.plannedAmount, 857142);
    expect(terms.last.plannedAmount, 857148);

    await installmentRepo.recordPayment(
      installmentId: terms.first.id,
      amount: 857142,
      paymentDate: '2026-08-17',
    );

    final updatedTerms = await db.getInstallmentsForPlan(planId);
    expect(updatedTerms.first.paidAmount, 857142);
    expect(updatedTerms.first.status, 'paid');

    final wishlistId = await wishlistRepo.createWishlistItem(
      itemName: 'Monitor 27 Inch',
      targetAmount: 3200000,
      priority: 'medium',
      savedAmount: 500000,
    );
    final items = await db.getActiveWishlistItems();
    expect(items.any((w) => w.id == wishlistId && w.savedAmount == 500000), isTrue);
  });

  test('reversing a debt_payment transaction restores debt remainingAmount and queues reverse_debt_payment', () async {
    final debtId = await debtRepo.createDebt(
      direction: 'payable',
      counterpartyName: 'Budi',
      principalAmount: 1000000,
      startDate: '2026-10-01',
      title: 'Pinjaman Modal',
    );

    final paymentResult = await debtRepo.recordPayment(
      debtId: debtId,
      amount: 1000000,
      paymentDate: '2026-10-17',
    );
    expect((await db.getDebtById(debtId))!.remainingAmount, 0);
    expect((await db.getDebtById(debtId))!.status, 'paid');

    await txRepo.reverseTransaction(
      originalTransactionId: paymentResult.transactionId,
      reversalDate: '2026-10-18',
      notes: 'Salah input pelunasan',
    );

    final restoredDebt = await db.getDebtById(debtId);
    expect(restoredDebt!.remainingAmount, 1000000);
    expect(restoredDebt.status, 'active');

    final payments = await db.getDebtPayments(debtId);
    expect(payments, isEmpty);
    final rawPaymentRows = db.select(
      'SELECT status FROM local_debt_payments WHERE debt_id = ?',
      [debtId],
    );
    expect(rawPaymentRows.single['status'], 'reversed');

    final outbox = await db.getPendingOutboxItems();
    expect(outbox.last.operationType, 'reverse_debt_payment');
    expect(outbox.last.entityId, paymentResult.paymentId);
  });

  test('reversing an installment_payment transaction restores installment paidAmount and plan status', () async {
    final planId = await installmentRepo.createPlanWithSchedule(
      title: 'Kredit HP',
      totalAmount: 1000000,
      installmentCount: 1,
      frequency: 'monthly',
      startDate: '2026-10-01',
    );

    final terms = await db.getInstallmentsForPlan(planId);
    await installmentRepo.recordPayment(
      installmentId: terms.single.id,
      amount: 1000000,
      paymentDate: '2026-10-17',
    );
    expect((await db.getInstallmentsForPlan(planId)).single.status, 'paid');

    final activeTxs = await db.getActiveTransactions();
    await txRepo.reverseTransaction(
      originalTransactionId: activeTxs.single.id,
      reversalDate: '2026-10-18',
      notes: 'Batal bayar termin',
    );

    final restoredTerm = (await db.getInstallmentsForPlan(planId)).single;
    expect(restoredTerm.paidAmount, 0);
    expect(restoredTerm.status, 'pending');

    final outbox = await db.getPendingOutboxItems();
    expect(outbox.last.operationType, 'reverse_installment_payment');

    final customCatId = await txRepo.createCustomCategory(
      name: 'Kopi & Matcha',
      kind: 'expense',
      iconKey: 'fork_knife',
    );
    final categories = await db.getActiveCategories(kind: 'expense');
    expect(categories.any((c) => c.id == customCatId && c.name == 'Kopi & Matcha'), isTrue);

    final txId = await txRepo.createTransaction(
      type: 'expense',
      amount: 35000,
      transactionDate: '2026-10-18',
      categoryId: customCatId,
      title: 'Kopi Pagi',
    );

    await txRepo.updateTransaction(
      transactionId: txId,
      amount: 48000,
      transactionDate: '2026-10-19',
      categoryId: customCatId,
      title: 'Kopi Pagi + Pastry',
      notes: 'Meeting klien',
    );

    final updatedTx = await db.getTransactionById(txId);
    expect(updatedTx!.amount, 48000);
    expect(updatedTx.title, 'Kopi Pagi + Pastry');
    expect(updatedTx.transactionDate, '2026-10-19');
    expect(updatedTx.version, 2);

    final tempDir = await Directory.systemTemp.createTemp('pf_db_key_test_');
    try {
      final db1 = AppDatabase.openFile(
        userId: 'user-anzhel-uuid',
        directoryPath: tempDir.path,
        encryptionKey: 'correct-key-123',
      );
      await db1.close();

      expect(
        () => AppDatabase.openFile(
          userId: 'user-anzhel-uuid',
          directoryPath: tempDir.path,
          encryptionKey: 'tampered-key-999',
        ),
        throwsStateError,
      );

      final db2 = AppDatabase.openFile(
        userId: 'user-anzhel-uuid',
        directoryPath: tempDir.path,
        encryptionKey: 'correct-key-123',
      );
      await db2.close();
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });
}
