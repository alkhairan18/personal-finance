import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;

class LocalCategory {
  final String id;
  final String? userId;
  final String name;
  final String kind;
  final String iconKey;
  final String colorHex;
  final bool isSystem;
  final bool isArchived;
  final int version;

  const LocalCategory({
    required this.id,
    this.userId,
    required this.name,
    required this.kind,
    required this.iconKey,
    required this.colorHex,
    required this.isSystem,
    required this.isArchived,
    required this.version,
  });

  factory LocalCategory.fromRow(sql.Row row) {
    return LocalCategory(
      id: row['id'] as String,
      userId: row['user_id'] as String?,
      name: row['name'] as String,
      kind: row['kind'] as String,
      iconKey: (row['icon_key'] as String?) ?? 'receipt',
      colorHex: (row['color_hex'] as String?) ?? '#0F766E',
      isSystem: (row['is_system'] as int? ?? 0) == 1,
      isArchived: (row['is_archived'] as int? ?? 0) == 1,
      version: (row['version'] as int?) ?? 1,
    );
  }
}

class LocalTransaction {
  final String id;
  final String userId;
  final String? categoryId;
  final String type;
  final String sourceType;
  final int amount;
  final String transactionDate;
  final String? title;
  final String? notes;
  final String status;
  final String? reversalOfTransactionId;
  final int version;
  final String syncStatus;
  final String createdAt;
  final String updatedAt;

  const LocalTransaction({
    required this.id,
    required this.userId,
    this.categoryId,
    required this.type,
    required this.sourceType,
    required this.amount,
    required this.transactionDate,
    this.title,
    this.notes,
    required this.status,
    this.reversalOfTransactionId,
    required this.version,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LocalTransaction.fromRow(sql.Row row) {
    return LocalTransaction(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      categoryId: row['category_id'] as String?,
      type: row['type'] as String,
      sourceType: (row['source_type'] as String?) ?? 'manual',
      amount: row['amount'] as int,
      transactionDate: row['transaction_date'] as String,
      title: row['title'] as String?,
      notes: row['notes'] as String?,
      status: (row['status'] as String?) ?? 'active',
      reversalOfTransactionId: row['reversal_of_transaction_id'] as String?,
      version: (row['version'] as int?) ?? 1,
      syncStatus: (row['sync_status'] as String?) ?? 'synced',
      createdAt: (row['created_at'] as String?) ?? '',
      updatedAt: (row['updated_at'] as String?) ?? '',
    );
  }
}

class LocalDebt {
  final String id;
  final String userId;
  final String direction;
  final String counterpartyName;
  final String? title;
  final String? notes;
  final int principalAmount;
  final int remainingAmount;
  final String startDate;
  final String? dueDate;
  final String status;
  final int version;
  final String syncStatus;
  final String updatedAt;

  const LocalDebt({
    required this.id,
    required this.userId,
    required this.direction,
    required this.counterpartyName,
    this.title,
    this.notes,
    required this.principalAmount,
    required this.remainingAmount,
    required this.startDate,
    this.dueDate,
    required this.status,
    required this.version,
    required this.syncStatus,
    required this.updatedAt,
  });

  factory LocalDebt.fromRow(sql.Row row) {
    return LocalDebt(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      direction: row['direction'] as String,
      counterpartyName: row['counterparty_name'] as String,
      title: row['title'] as String?,
      notes: row['notes'] as String?,
      principalAmount: row['principal_amount'] as int,
      remainingAmount: row['remaining_amount'] as int,
      startDate: row['start_date'] as String,
      dueDate: row['due_date'] as String?,
      status: (row['status'] as String?) ?? 'active',
      version: (row['version'] as int?) ?? 1,
      syncStatus: (row['sync_status'] as String?) ?? 'synced',
      updatedAt: (row['updated_at'] as String?) ?? '',
    );
  }
}

class LocalDebtPayment {
  final String id;
  final String userId;
  final String debtId;
  final String? linkedTransactionId;
  final int amount;
  final String paymentDate;
  final String? notes;
  final String status;
  final int version;
  final String syncStatus;

  const LocalDebtPayment({
    required this.id,
    required this.userId,
    required this.debtId,
    this.linkedTransactionId,
    required this.amount,
    required this.paymentDate,
    this.notes,
    required this.status,
    required this.version,
    required this.syncStatus,
  });

  factory LocalDebtPayment.fromRow(sql.Row row) {
    return LocalDebtPayment(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      debtId: row['debt_id'] as String,
      linkedTransactionId: row['linked_transaction_id'] as String?,
      amount: row['amount'] as int,
      paymentDate: row['payment_date'] as String,
      notes: row['notes'] as String?,
      status: (row['status'] as String?) ?? 'active',
      version: (row['version'] as int?) ?? 1,
      syncStatus: (row['sync_status'] as String?) ?? 'synced',
    );
  }
}

class LocalInstallmentPlan {
  final String id;
  final String userId;
  final String title;
  final String? vendorName;
  final String? categoryId;
  final int totalAmount;
  final int installmentCount;
  final String frequency;
  final String startDate;
  final String? notes;
  final String status;
  final int version;
  final String syncStatus;

  const LocalInstallmentPlan({
    required this.id,
    required this.userId,
    required this.title,
    this.vendorName,
    this.categoryId,
    required this.totalAmount,
    required this.installmentCount,
    required this.frequency,
    required this.startDate,
    this.notes,
    required this.status,
    required this.version,
    required this.syncStatus,
  });

  factory LocalInstallmentPlan.fromRow(sql.Row row) {
    return LocalInstallmentPlan(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      title: row['title'] as String,
      vendorName: row['vendor_name'] as String?,
      categoryId: row['category_id'] as String?,
      totalAmount: row['total_amount'] as int,
      installmentCount: row['installment_count'] as int,
      frequency: (row['frequency'] as String?) ?? 'monthly',
      startDate: row['start_date'] as String,
      notes: row['notes'] as String?,
      status: (row['status'] as String?) ?? 'active',
      version: (row['version'] as int?) ?? 1,
      syncStatus: (row['sync_status'] as String?) ?? 'synced',
    );
  }
}

class LocalInstallment {
  final String id;
  final String userId;
  final String planId;
  final int installmentNumber;
  final String dueDate;
  final int plannedAmount;
  final int paidAmount;
  final String status;
  final String? paidAt;
  final int version;
  final String syncStatus;

  const LocalInstallment({
    required this.id,
    required this.userId,
    required this.planId,
    required this.installmentNumber,
    required this.dueDate,
    required this.plannedAmount,
    required this.paidAmount,
    required this.status,
    this.paidAt,
    required this.version,
    required this.syncStatus,
  });

  int get remainingAmount => (plannedAmount - paidAmount) > 0 ? (plannedAmount - paidAmount) : 0;

  factory LocalInstallment.fromRow(sql.Row row) {
    return LocalInstallment(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      planId: row['plan_id'] as String,
      installmentNumber: row['installment_number'] as int,
      dueDate: row['due_date'] as String,
      plannedAmount: row['planned_amount'] as int,
      paidAmount: row['paid_amount'] as int,
      status: (row['status'] as String?) ?? 'pending',
      paidAt: row['paid_at'] as String?,
      version: (row['version'] as int?) ?? 1,
      syncStatus: (row['sync_status'] as String?) ?? 'synced',
    );
  }
}

class LocalInstallmentPayment {
  final String id;
  final String userId;
  final String installmentId;
  final String? linkedTransactionId;
  final int amount;
  final String paymentDate;
  final String? notes;
  final String status;
  final int version;
  final String syncStatus;

  const LocalInstallmentPayment({
    required this.id,
    required this.userId,
    required this.installmentId,
    this.linkedTransactionId,
    required this.amount,
    required this.paymentDate,
    this.notes,
    required this.status,
    required this.version,
    required this.syncStatus,
  });

  factory LocalInstallmentPayment.fromRow(sql.Row row) {
    return LocalInstallmentPayment(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      installmentId: row['installment_id'] as String,
      linkedTransactionId: row['linked_transaction_id'] as String?,
      amount: row['amount'] as int,
      paymentDate: row['payment_date'] as String,
      notes: row['notes'] as String?,
      status: (row['status'] as String?) ?? 'active',
      version: (row['version'] as int?) ?? 1,
      syncStatus: (row['sync_status'] as String?) ?? 'synced',
    );
  }
}

class LocalWishlist {
  final String id;
  final String userId;
  final String itemName;
  final String? categoryId;
  final int targetAmount;
  final int savedAmount;
  final String priority;
  final String? targetDate;
  final String? urlOrReference;
  final String? notes;
  final String status;
  final int version;
  final String syncStatus;

  const LocalWishlist({
    required this.id,
    required this.userId,
    required this.itemName,
    this.categoryId,
    required this.targetAmount,
    required this.savedAmount,
    required this.priority,
    this.targetDate,
    this.urlOrReference,
    this.notes,
    required this.status,
    required this.version,
    required this.syncStatus,
  });

  int get remainingNeeded =>
      (targetAmount - savedAmount) > 0 ? (targetAmount - savedAmount) : 0;

  factory LocalWishlist.fromRow(sql.Row row) {
    return LocalWishlist(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      itemName: row['item_name'] as String,
      categoryId: row['category_id'] as String?,
      targetAmount: row['target_amount'] as int,
      savedAmount: row['saved_amount'] as int,
      priority: (row['priority'] as String?) ?? 'medium',
      targetDate: row['target_date'] as String?,
      urlOrReference: row['url_or_reference'] as String?,
      notes: row['notes'] as String?,
      status: (row['status'] as String?) ?? 'planned',
      version: (row['version'] as int?) ?? 1,
      syncStatus: (row['sync_status'] as String?) ?? 'synced',
    );
  }
}

class SyncOutboxItem {
  final int localSeq;
  final String operationId;
  final String entityType;
  final String entityId;
  final String operationType;
  final int? baseVersion;
  final Map<String, dynamic> payload;
  final int retryCount;
  final String? lastError;
  final String createdAt;

  const SyncOutboxItem({
    required this.localSeq,
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    this.baseVersion,
    required this.payload,
    required this.retryCount,
    this.lastError,
    required this.createdAt,
  });

  factory SyncOutboxItem.fromRow(sql.Row row) {
    final decoded = jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
    return SyncOutboxItem(
      localSeq: row['local_seq'] as int,
      operationId: row['operation_id'] as String,
      entityType: row['entity_type'] as String,
      entityId: row['entity_id'] as String,
      operationType: row['operation_type'] as String,
      baseVersion: row['base_version'] as int?,
      payload: decoded,
      retryCount: (row['retry_count'] as int?) ?? 0,
      lastError: row['last_error'] as String?,
      createdAt: row['created_at'] as String,
    );
  }
}

class SyncConflictEntry {
  final String id;
  final String operationId;
  final String entityType;
  final String entityId;
  final Map<String, dynamic> localPayload;
  final Map<String, dynamic> serverPayload;
  final String createdAt;

  const SyncConflictEntry({
    required this.id,
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.localPayload,
    required this.serverPayload,
    required this.createdAt,
  });

  factory SyncConflictEntry.fromRow(sql.Row row) {
    return SyncConflictEntry(
      id: row['id'] as String,
      operationId: row['operation_id'] as String,
      entityType: row['entity_type'] as String,
      entityId: row['entity_id'] as String,
      localPayload: jsonDecode(row['local_payload_json'] as String) as Map<String, dynamic>,
      serverPayload: jsonDecode(row['server_payload_json'] as String) as Map<String, dynamic>,
      createdAt: row['created_at'] as String,
    );
  }
}

class AppDatabase extends ChangeNotifier {
  final String userId;
  final String? dbFilePath;
  final sql.Database _rawDb;
  int _txDepth = 0;
  bool _isClosed = false;

  AppDatabase._({
    required this.userId,
    required sql.Database rawDb,
    this.dbFilePath,
  }) : _rawDb = rawDb {
    _initializeSchema();
  }

  factory AppDatabase.inMemory({required String userId}) {
    final raw = sql.sqlite3.openInMemory();
    return AppDatabase._(userId: userId, rawDb: raw);
  }

  factory AppDatabase.openFile({
    required String userId,
    required String directoryPath,
  }) {
    final sanitizedUser = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filePath = p.join(directoryPath, 'finance_$sanitizedUser.db');
    final raw = sql.sqlite3.open(filePath);
    return AppDatabase._(
      userId: userId,
      rawDb: raw,
      dbFilePath: filePath,
    );
  }

  void _initializeSchema() {
    _rawDb.execute('PRAGMA foreign_keys = ON;');
    _rawDb.execute('''
      CREATE TABLE IF NOT EXISTS local_categories (
        id TEXT PRIMARY KEY,
        user_id TEXT NULL,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        icon_key TEXT NOT NULL DEFAULT 'receipt',
        color_hex TEXT NOT NULL DEFAULT '#0F766E',
        is_system INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        version INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS local_transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        category_id TEXT NULL,
        type TEXT NOT NULL,
        source_type TEXT NOT NULL DEFAULT 'manual',
        amount INTEGER NOT NULL CHECK (amount > 0),
        transaction_date TEXT NOT NULL,
        title TEXT NULL,
        notes TEXT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        reversal_of_transaction_id TEXT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS local_debts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        direction TEXT NOT NULL,
        counterparty_name TEXT NOT NULL,
        title TEXT NULL,
        notes TEXT NULL,
        principal_amount INTEGER NOT NULL CHECK (principal_amount > 0),
        remaining_amount INTEGER NOT NULL CHECK (remaining_amount >= 0),
        start_date TEXT NOT NULL,
        due_date TEXT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        version INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS local_debt_payments (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        debt_id TEXT NOT NULL,
        linked_transaction_id TEXT NULL,
        amount INTEGER NOT NULL CHECK (amount > 0),
        payment_date TEXT NOT NULL,
        notes TEXT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        version INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS local_installment_plans (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        vendor_name TEXT NULL,
        category_id TEXT NULL,
        total_amount INTEGER NOT NULL CHECK (total_amount > 0),
        installment_count INTEGER NOT NULL CHECK (installment_count > 0),
        frequency TEXT NOT NULL DEFAULT 'monthly',
        start_date TEXT NOT NULL,
        notes TEXT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        version INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS local_installments (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        plan_id TEXT NOT NULL,
        installment_number INTEGER NOT NULL,
        due_date TEXT NOT NULL,
        planned_amount INTEGER NOT NULL CHECK (planned_amount > 0),
        paid_amount INTEGER NOT NULL DEFAULT 0 CHECK (paid_amount >= 0),
        status TEXT NOT NULL DEFAULT 'pending',
        paid_at TEXT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS local_installment_payments (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        installment_id TEXT NOT NULL,
        linked_transaction_id TEXT NULL,
        amount INTEGER NOT NULL CHECK (amount > 0),
        payment_date TEXT NOT NULL,
        notes TEXT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        version INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS local_wishlists (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        item_name TEXT NOT NULL,
        category_id TEXT NULL,
        target_amount INTEGER NOT NULL CHECK (target_amount > 0),
        saved_amount INTEGER NOT NULL DEFAULT 0 CHECK (saved_amount >= 0),
        priority TEXT NOT NULL DEFAULT 'medium',
        target_date TEXT NULL,
        url_or_reference TEXT NULL,
        notes TEXT NULL,
        status TEXT NOT NULL DEFAULT 'planned',
        version INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS sync_outbox (
        local_seq INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_id TEXT NOT NULL UNIQUE,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        base_version INTEGER NULL,
        payload_json TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT NULL,
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS sync_conflicts (
        id TEXT PRIMARY KEY,
        operation_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        local_payload_json TEXT NOT NULL,
        server_payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');
  }

  Future<T> transaction<T>(Future<T> Function() action) async {
    final isOuter = _txDepth == 0;
    if (isOuter) {
      _rawDb.execute('BEGIN IMMEDIATE;');
    }
    _txDepth++;
    try {
      final result = await action();
      _txDepth--;
      if (isOuter) {
        _rawDb.execute('COMMIT;');
        notifyListeners();
      }
      return result;
    } catch (e) {
      _txDepth--;
      if (isOuter) {
        _rawDb.execute('ROLLBACK;');
      }
      rethrow;
    }
  }

  void execute(String sqlQuery, [List<Object?> parameters = const []]) {
    _rawDb.execute(sqlQuery, parameters);
  }

  sql.ResultSet select(String sqlQuery, [List<Object?> parameters = const []]) {
    return _rawDb.select(sqlQuery, parameters);
  }

  void notifyDataChanged() {
    if (!_isClosed) {
      notifyListeners();
    }
  }

  static const List<Map<String, String>> defaultSystemCategories = [
    {
      'id': '11111111-1111-4111-8111-000000000001',
      'name': 'Makan & Minum',
      'kind': 'expense',
      'icon_key': 'fork_knife',
      'color_hex': '#0F766E',
    },
    {
      'id': '11111111-1111-4111-8111-000000000002',
      'name': 'Transportasi',
      'kind': 'expense',
      'icon_key': 'car_simple',
      'color_hex': '#0F766E',
    },
    {
      'id': '11111111-1111-4111-8111-000000000003',
      'name': 'Kebutuhan Rumah',
      'kind': 'expense',
      'icon_key': 'house_line',
      'color_hex': '#0F766E',
    },
    {
      'id': '11111111-1111-4111-8111-000000000004',
      'name': 'Tagihan & Utilitas',
      'kind': 'expense',
      'icon_key': 'lightning',
      'color_hex': '#B45309',
    },
    {
      'id': '11111111-1111-4111-8111-000000000005',
      'name': 'Cicilan & Kewajiban',
      'kind': 'expense',
      'icon_key': 'calendar_check',
      'color_hex': '#B45309',
    },
    {
      'id': '11111111-1111-4111-8111-000000000006',
      'name': 'Kesehatan',
      'kind': 'expense',
      'icon_key': 'first_aid_kit',
      'color_hex': '#0F766E',
    },
    {
      'id': '11111111-1111-4111-8111-000000000007',
      'name': 'Hiburan & Gaya Hidup',
      'kind': 'expense',
      'icon_key': 'film_slate',
      'color_hex': '#0F766E',
    },
    {
      'id': '11111111-1111-4111-8111-000000000008',
      'name': 'Belanja',
      'kind': 'expense',
      'icon_key': 'shopping_bag',
      'color_hex': '#0F766E',
    },
    {
      'id': '11111111-1111-4111-8111-000000000009',
      'name': 'Gaji',
      'kind': 'income',
      'icon_key': 'wallet',
      'color_hex': '#0F766E',
    },
    {
      'id': '11111111-1111-4111-8111-000000000010',
      'name': 'Bonus & THR',
      'kind': 'income',
      'icon_key': 'coins',
      'color_hex': '#0F766E',
    },
    {
      'id': '11111111-1111-4111-8111-000000000011',
      'name': 'Usaha & Freelance',
      'kind': 'income',
      'icon_key': 'briefcase',
      'color_hex': '#0F766E',
    },
    {
      'id': '11111111-1111-4111-8111-000000000012',
      'name': 'Penerimaan Lainnya',
      'kind': 'income',
      'icon_key': 'arrow_down_left',
      'color_hex': '#0F766E',
    },
  ];

  Future<void> ensureDefaultCategoriesSeeded() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    for (final cat in defaultSystemCategories) {
      execute(
        '''
        INSERT OR IGNORE INTO local_categories (
          id, user_id, name, kind, icon_key, color_hex, is_system, is_archived, version, sync_status, created_at, updated_at
        ) VALUES (?, NULL, ?, ?, ?, ?, 1, 0, 1, 'synced', ?, ?)
        ''',
        [
          cat['id'],
          cat['name'],
          cat['kind'],
          cat['icon_key'],
          cat['color_hex'],
          nowIso,
          nowIso,
        ],
      );
    }
  }

  Future<List<LocalCategory>> getActiveCategories({String? kind}) async {
    final sql.ResultSet rows;
    if (kind != null) {
      rows = select(
        'SELECT * FROM local_categories WHERE is_archived = 0 AND kind = ? ORDER BY is_system DESC, name ASC',
        [kind],
      );
    } else {
      rows = select(
        'SELECT * FROM local_categories WHERE is_archived = 0 ORDER BY is_system DESC, name ASC',
      );
    }
    return rows.map(LocalCategory.fromRow).toList();
  }

  Future<List<LocalTransaction>> getActiveTransactions({String? yearMonth}) async {
    final sql.ResultSet rows;
    if (yearMonth != null && yearMonth.isNotEmpty) {
      rows = select(
        '''
        SELECT * FROM local_transactions
        WHERE user_id = ? AND status = 'active' AND substr(transaction_date, 1, 7) = ?
        ORDER BY transaction_date DESC, created_at DESC
        ''',
        [userId, yearMonth],
      );
    } else {
      rows = select(
        '''
        SELECT * FROM local_transactions
        WHERE user_id = ? AND status = 'active'
        ORDER BY transaction_date DESC, created_at DESC
        ''',
        [userId],
      );
    }
    return rows.map(LocalTransaction.fromRow).toList();
  }

  Future<LocalTransaction?> getTransactionById(String id) async {
    final rows = select(
      'SELECT * FROM local_transactions WHERE id = ? AND user_id = ? LIMIT 1',
      [id, userId],
    );
    if (rows.isEmpty) return null;
    return LocalTransaction.fromRow(rows.first);
  }

  Future<List<LocalDebt>> getActiveDebts({String? direction}) async {
    final sql.ResultSet rows;
    if (direction != null) {
      rows = select(
        '''
        SELECT * FROM local_debts
        WHERE user_id = ? AND status != 'archived' AND direction = ?
        ORDER BY CASE WHEN status = 'paid' THEN 1 ELSE 0 END ASC, due_date ASC, updated_at DESC
        ''',
        [userId, direction],
      );
    } else {
      rows = select(
        '''
        SELECT * FROM local_debts
        WHERE user_id = ? AND status != 'archived'
        ORDER BY CASE WHEN status = 'paid' THEN 1 ELSE 0 END ASC, due_date ASC, updated_at DESC
        ''',
        [userId],
      );
    }
    return rows.map(LocalDebt.fromRow).toList();
  }

  Future<LocalDebt?> getDebtById(String id) async {
    final rows = select(
      'SELECT * FROM local_debts WHERE id = ? AND user_id = ? LIMIT 1',
      [id, userId],
    );
    if (rows.isEmpty) return null;
    return LocalDebt.fromRow(rows.first);
  }

  Future<List<LocalDebtPayment>> getDebtPayments(String debtId) async {
    final rows = select(
      '''
      SELECT * FROM local_debt_payments
      WHERE debt_id = ? AND user_id = ? AND status = 'active'
      ORDER BY payment_date DESC, created_at DESC
      ''',
      [debtId, userId],
    );
    return rows.map(LocalDebtPayment.fromRow).toList();
  }

  Future<List<LocalInstallmentPlan>> getActiveInstallmentPlans() async {
    final rows = select(
      '''
      SELECT * FROM local_installment_plans
      WHERE user_id = ? AND status != 'archived'
      ORDER BY CASE WHEN status = 'completed' THEN 1 ELSE 0 END ASC, start_date DESC
      ''',
      [userId],
    );
    return rows.map(LocalInstallmentPlan.fromRow).toList();
  }

  Future<List<LocalInstallment>> getInstallmentsForPlan(String planId) async {
    final rows = select(
      '''
      SELECT * FROM local_installments
      WHERE plan_id = ? AND user_id = ? AND status != 'archived'
      ORDER BY installment_number ASC
      ''',
      [planId, userId],
    );
    return rows.map(LocalInstallment.fromRow).toList();
  }

  Future<LocalInstallment?> getInstallmentById(String installmentId) async {
    final rows = select(
      'SELECT * FROM local_installments WHERE id = ? AND user_id = ? LIMIT 1',
      [installmentId, userId],
    );
    if (rows.isEmpty) return null;
    return LocalInstallment.fromRow(rows.first);
  }

  Future<List<LocalWishlist>> getActiveWishlistItems() async {
    final rows = select(
      '''
      SELECT * FROM local_wishlists
      WHERE user_id = ? AND status NOT IN ('cancelled', 'archived')
      ORDER BY
        CASE priority WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END ASC,
        created_at DESC
      ''',
      [userId],
    );
    return rows.map(LocalWishlist.fromRow).toList();
  }

  Future<LocalWishlist?> getWishlistById(String id) async {
    final rows = select(
      'SELECT * FROM local_wishlists WHERE id = ? AND user_id = ? LIMIT 1',
      [id, userId],
    );
    if (rows.isEmpty) return null;
    return LocalWishlist.fromRow(rows.first);
  }

  void enqueueOutbox({
    required String operationId,
    required String entityType,
    required String entityId,
    required String operationType,
    int? baseVersion,
    required Map<String, dynamic> payload,
  }) {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    execute(
      '''
      INSERT INTO sync_outbox (
        operation_id, entity_type, entity_id, operation_type, base_version, payload_json, retry_count, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, 0, ?)
      ''',
      [
        operationId,
        entityType,
        entityId,
        operationType,
        baseVersion,
        jsonEncode(payload),
        nowIso,
      ],
    );
  }

  Future<List<SyncOutboxItem>> getPendingOutboxItems() async {
    final rows = select('SELECT * FROM sync_outbox ORDER BY local_seq ASC');
    return rows.map(SyncOutboxItem.fromRow).toList();
  }

  Future<int> getPendingOutboxCount() async {
    final rows = select('SELECT COUNT(*) AS cnt FROM sync_outbox');
    return (rows.first['cnt'] as int?) ?? 0;
  }

  Future<void> removeOutboxByOperationId(String operationId) async {
    execute('DELETE FROM sync_outbox WHERE operation_id = ?', [operationId]);
    notifyDataChanged();
  }

  Future<void> recordSyncConflict({
    required String id,
    required String operationId,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localPayload,
    required Map<String, dynamic> serverPayload,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    execute(
      '''
      INSERT OR REPLACE INTO sync_conflicts (
        id, operation_id, entity_type, entity_id, local_payload_json, server_payload_json, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        operationId,
        entityType,
        entityId,
        jsonEncode(localPayload),
        jsonEncode(serverPayload),
        nowIso,
      ],
    );
    execute('DELETE FROM sync_outbox WHERE operation_id = ?', [operationId]);
    notifyDataChanged();
  }

  Future<List<SyncConflictEntry>> getSyncConflicts() async {
    final rows = select('SELECT * FROM sync_conflicts ORDER BY created_at DESC');
    return rows.map(SyncConflictEntry.fromRow).toList();
  }

  Future<String?> getSyncMeta(String key) async {
    final rows = select('SELECT value FROM sync_metadata WHERE key = ? LIMIT 1', [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> setSyncMeta(String key, String value) async {
    execute(
      'INSERT OR REPLACE INTO sync_metadata (key, value) VALUES (?, ?)',
      [key, value],
    );
  }

  Future<Map<String, dynamic>> exportSnapshotMap() async {
    final categories = await getActiveCategories();
    final transactions = await getActiveTransactions();
    final debts = await getActiveDebts();
    final plans = await getActiveInstallmentPlans();
    final wishlists = await getActiveWishlistItems();
    return {
      'user_id': userId,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'categories_count': categories.length,
      'transactions': transactions
          .map(
            (t) => {
              'id': t.id,
              'type': t.type,
              'source_type': t.sourceType,
              'amount': t.amount,
              'transaction_date': t.transactionDate,
              'title': t.title,
              'notes': t.notes,
              'category_id': t.categoryId,
            },
          )
          .toList(),
      'debts': debts
          .map(
            (d) => {
              'id': d.id,
              'direction': d.direction,
              'counterparty_name': d.counterpartyName,
              'principal_amount': d.principalAmount,
              'remaining_amount': d.remainingAmount,
              'due_date': d.dueDate,
              'status': d.status,
            },
          )
          .toList(),
      'installment_plans_count': plans.length,
      'wishlists': wishlists
          .map(
            (w) => {
              'id': w.id,
              'item_name': w.itemName,
              'target_amount': w.targetAmount,
              'saved_amount': w.savedAmount,
              'priority': w.priority,
            },
          )
          .toList(),
    };
  }

  Future<void> close() async {
    if (!_isClosed) {
      _isClosed = true;
      _rawDb.dispose();
    }
  }

  Future<void> closeAndDeleteFile() async {
    await close();
    if (dbFilePath != null) {
      final file = File(dbFilePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
