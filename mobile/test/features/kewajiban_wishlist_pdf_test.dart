import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/app/providers/app_providers.dart';
import 'package:personal_finance/app/shell/main_shell_screen.dart';
import 'package:personal_finance/app/theme/swiss_ledger_theme.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/features/auth/data/auth_repository.dart';
import 'package:personal_finance/features/debts/data/debt_repository.dart';
import 'package:personal_finance/features/installments/data/installment_repository.dart';
import 'package:personal_finance/features/reports/data/backup_export_service.dart';
import 'package:personal_finance/features/reports/data/pdf_report_generator.dart';
import 'package:personal_finance/features/transactions/data/transaction_repository.dart';
import 'package:personal_finance/features/wishlist/data/wishlist_repository.dart';

void main() {
  late AppDatabase db;
  late AuthRepository authRepo;
  late InstallmentRepository installmentRepo;
  late DebtRepository debtRepo;
  late WishlistRepository wishlistRepo;
  late TransactionRepository txRepo;

  setUp(() async {
    db = AppDatabase.inMemory(userId: 'user-anzhel-uuid');
    await db.ensureDefaultCategoriesSeeded();
    authRepo = AuthRepository.forTesting(activeDatabase: db);
    installmentRepo = InstallmentRepository(db);
    debtRepo = DebtRepository(db);
    wishlistRepo = WishlistRepository(db);
    txRepo = TransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
    '7-term installment plan renders in Kewajiban tab and Wishlist purchase does not alter cash balance',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final planId = await installmentRepo.createPlanWithSchedule(
        title: 'Kredit Kamera 7 Bulan',
        vendorName: 'Toko Kamera',
        totalAmount: 6000000,
        installmentCount: 7,
        frequency: 'monthly',
        startDate: '2026-08-17',
      );

      final terms = await db.getInstallmentsForPlan(planId);
      expect(terms.length, 7);
      expect(terms[0].plannedAmount, 857142);
      expect(terms[6].plannedAmount, 857148);

      // Pay first term (857142)
      await installmentRepo.recordPayment(
        installmentId: terms[0].id,
        amount: 857142,
        paymentDate: '2026-08-17',
      );

      // Create and mark a wishlist item purchased - must NOT alter cash balance
      final wishlistId = await wishlistRepo.createWishlistItem(
        itemName: 'Meja Kerja Kayu',
        targetAmount: 2400000,
        savedAmount: 1000000,
        priority: 'high',
      );
      await wishlistRepo.markPurchased(wishlistId);

      // Cash balance should reflect ONLY the 1 installment payment (-Rp 857.142), NOT the wishlist item
      final allTxs = await db.getActiveTransactions();
      expect(allTxs.length, 1);
      expect(allTxs.single.amount, 857142);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) => authRepo),
          ],
          child: MaterialApp(
            theme: SwissLedgerTheme.light(),
            home: const MainShellScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Kewajiban tab
      await tester.tap(find.byKey(const Key('nav_tab_kewajiban')));
      await tester.pumpAndSettle();

      // Switch to Cicilan sub-tab inside KewajibanScreen
      await tester.tap(find.byKey(const Key('kewajiban_subtab_cicilan')));
      await tester.pumpAndSettle();

      expect(find.text('Kredit Kamera 7 Bulan'), findsOneWidget);
      expect(find.textContaining('1/7'), findsWidgets);

      // Navigate to Wishlist tab
      await tester.tap(find.byKey(const Key('nav_tab_wishlist')));
      await tester.pumpAndSettle();

      expect(find.text('Meja Kerja Kayu'), findsOneWidget);
    },
  );

  test(
    'PdfReportGenerator.generatePeriodReport produces valid %PDF- bytes offline and BackupExportService exports valid JSON',
    () async {
      final cats = await db.getActiveCategories(kind: 'expense');
      await txRepo.createTransaction(
        type: 'expense',
        amount: 125000,
        categoryId: cats.first.id,
        transactionDate: '2026-10-17',
        title: 'Makan Siang Tim',
      );
      await debtRepo.createDebt(
        direction: 'payable',
        counterpartyName: 'Andi',
        principalAmount: 500000,
        startDate: '2026-10-01',
        dueDate: '2026-10-28',
        title: 'Pinjaman Darurat',
      );

      final pdfBytes = await PdfReportGenerator.generatePeriodReport(
        db: db,
        accountDisplayName: 'Anzhel',
        periodLabel: '2026-10',
      );

      expect(pdfBytes.length, greaterThan(500));
      final headerAscii = ascii.decode(pdfBytes.sublist(0, 5));
      expect(headerAscii, '%PDF-');

      final backupJson = await BackupExportService.generateBackupJsonString(db);
      final decoded = jsonDecode(backupJson) as Map<String, dynamic>;
      expect(decoded['user_id'], 'user-anzhel-uuid');
      expect((decoded['transactions'] as List).length, 1);
      expect((decoded['debts'] as List).length, 1);
    },
  );
}
