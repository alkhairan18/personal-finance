import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/app/providers/app_providers.dart';
import 'package:personal_finance/app/shell/main_shell_screen.dart';
import 'package:personal_finance/app/theme/swiss_ledger_theme.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/features/auth/data/auth_repository.dart';

void main() {
  late AppDatabase db;
  late AuthRepository authRepo;

  setUp(() async {
    db = AppDatabase.inMemory(userId: 'user-anzhel-uuid');
    await db.ensureDefaultCategoriesSeeded();
    authRepo = AuthRepository.forTesting(activeDatabase: db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestableShell() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => authRepo),
      ],
      child: MaterialApp(
        theme: SwissLedgerTheme.light(),
        home: const MainShellScreen(),
      ),
    );
  }

  testWidgets(
    'Quick-Add numpad records Rp 45.000 expense, updates Buku Kas immediately, and shows pending outbox count',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableShell());
      await tester.pumpAndSettle();

      expect(find.text('Anzhel'), findsOneWidget);
      expect(find.text('Buku Kas'), findsWidgets);

      // Tap center + Catat button
      await tester.tap(find.byKey(const Key('nav_quick_add_button')));
      await tester.pumpAndSettle();

      // Press 4, 5, .000 on custom integer numpad
      await tester.tap(find.byKey(const Key('numpad_key_4')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('numpad_key_5')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('numpad_key_000')));
      await tester.pump();

      expect(find.text('45.000'), findsOneWidget);

      // Enter optional note/title
      await tester.enterText(
        find.byKey(const Key('quick_add_title_field')),
        'Kopi Susu Pagi',
      );
      await tester.pump();

      // Tap Simpan Transaksi
      await tester.tap(find.byKey(const Key('quick_add_submit_button')));
      await tester.pumpAndSettle();

      // Verify Buku Kas shows the new expense and pending outbox badge
      expect(find.text('Kopi Susu Pagi'), findsOneWidget);
      expect(find.text('-Rp 45.000'), findsWidgets);
      expect(find.textContaining('1 antrean'), findsOneWidget);

      // Verify Month Navigation buttons exist
      expect(find.byKey(const Key('buku_kas_prev_month_button')), findsOneWidget);
      expect(find.byKey(const Key('buku_kas_next_month_button')), findsOneWidget);
    },
  );
}
