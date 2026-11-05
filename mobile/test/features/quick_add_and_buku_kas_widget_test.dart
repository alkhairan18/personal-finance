import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/app/providers/app_providers.dart';
import 'package:personal_finance/app/shell/main_shell_screen.dart';
import 'package:personal_finance/app/theme/swiss_ledger_theme.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/core/network/api_client.dart';
import 'package:personal_finance/core/sync/sync_engine.dart';
import 'package:personal_finance/features/auth/data/auth_repository.dart';
import 'package:personal_finance/features/auth/presentation/login_screen.dart';

class _FakeAutoSyncGateway implements SyncApiGateway {
  int pushCallCount = 0;

  @override
  Future<Map<String, dynamic>> pushOperations({
    required String clientDeviceId,
    required List<Map<String, dynamic>> operations,
  }) async {
    pushCallCount++;
    return {
      'results': operations
          .map(
            (op) => {
              'operation_id': op['operation_id'],
              'entity_type': op['entity_type'],
              'entity_id': op['entity_id'],
              'status': 'applied',
              'entity_version': 1,
            },
          )
          .toList(),
    };
  }

  @override
  Future<Map<String, dynamic>> pullChanges({
    String? cursor,
    int limit = 200,
  }) async {
    return {
      'next_cursor': cursor ?? '0',
      'has_more': false,
      'changes': <Map<String, dynamic>>[],
    };
  }
}

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

  Widget buildTestableShell({
    bool? enableAutoSync,
    SyncEngine? customSyncEngine,
  }) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => authRepo),
        if (customSyncEngine != null)
          syncEngineProvider.overrideWith((ref) => customSyncEngine),
      ],
      child: MaterialApp(
        theme: SwissLedgerTheme.light(),
        home: MainShellScreen(enableAutoSync: enableAutoSync),
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

      // Test LoginScreen Daftar Baru tab for any user
      final multiUserAuthRepo = AuthRepository(inMemoryMode: true);
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            authRepositoryProvider.overrideWith((ref) => multiUserAuthRepo),
          ],
          child: MaterialApp(
            theme: SwissLedgerTheme.light(),
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('auth_mode_register_tab')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('register_display_name_field')),
        'Budi Santoso',
      );
      await tester.enterText(
        find.byKey(const Key('login_username_field')),
        'budi_santoso',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'PasswordKuat123!',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(multiUserAuthRepo.currentSession?.username, 'budi_santoso');
      expect(multiUserAuthRepo.currentSession?.displayName, 'Budi Santoso');
      await multiUserAuthRepo.logout(forceDiscardPending: true);
    },
  );

  testWidgets(
    'Auto-sync runs automatically right after inputting data and displays Data Anda Sudah Diterima notification',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeGateway = _FakeAutoSyncGateway();
      final customSyncEngine = SyncEngine(
        db: db,
        apiGateway: fakeGateway,
        clientDeviceId: 'device-anzhel-pixel',
      );

      await tester.pumpWidget(
        buildTestableShell(
          enableAutoSync: true,
          customSyncEngine: customSyncEngine,
        ),
      );
      await tester.pumpAndSettle();

      // Tap center + Catat button
      await tester.tap(find.byKey(const Key('nav_quick_add_button')));
      await tester.pumpAndSettle();

      // Input Rp 50.000
      await tester.tap(find.byKey(const Key('numpad_key_5')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('numpad_key_0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('numpad_key_000')));
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('quick_add_title_field')),
        'Makan Malam Otomatis',
      );
      await tester.pump();

      // Submit without tapping the sync button manually
      await tester.tap(find.byKey(const Key('quick_add_submit_button')));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(await db.getPendingOutboxCount(), 0);
      expect(find.text('Tersinkron'), findsOneWidget);
      expect(find.text('Data Anda Sudah Diterima'), findsOneWidget);
    },
  );
}
