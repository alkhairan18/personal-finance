import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/core/sync/sync_engine.dart';
import 'package:personal_finance/features/auth/data/auth_repository.dart';
import 'package:personal_finance/features/debts/data/debt_repository.dart';
import 'package:personal_finance/features/installments/data/installment_repository.dart';
import 'package:personal_finance/features/transactions/data/transaction_repository.dart';
import 'package:personal_finance/features/wishlist/data/wishlist_repository.dart';

final authRepositoryProvider = ChangeNotifierProvider<AuthRepository>((ref) {
  return AuthRepository();
});

final activeDatabaseProvider = ChangeNotifierProvider<AppDatabase?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.activeDatabase;
});

final selectedMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
});

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryFilterProvider = StateProvider<String?>((ref) => null);
final isSyncingProvider = StateProvider<bool>((ref) => false);

final transactionRepositoryProvider = Provider<TransactionRepository?>((ref) {
  final db = ref.watch(activeDatabaseProvider);
  if (db == null) return null;
  return TransactionRepository(db);
});

final debtRepositoryProvider = Provider<DebtRepository?>((ref) {
  final db = ref.watch(activeDatabaseProvider);
  if (db == null) return null;
  return DebtRepository(db);
});

final installmentRepositoryProvider = Provider<InstallmentRepository?>((ref) {
  final db = ref.watch(activeDatabaseProvider);
  if (db == null) return null;
  return InstallmentRepository(db);
});

final wishlistRepositoryProvider = Provider<WishlistRepository?>((ref) {
  final db = ref.watch(activeDatabaseProvider);
  if (db == null) return null;
  return WishlistRepository(db);
});

final syncEngineProvider = Provider<SyncEngine?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final db = ref.watch(activeDatabaseProvider);
  final session = authRepo.currentSession;
  if (db == null || session == null) return null;
  return SyncEngine(
    db: db,
    apiGateway: authRepo.apiClient,
    clientDeviceId: session.deviceId,
  );
});
