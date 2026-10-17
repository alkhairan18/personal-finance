import 'package:personal_finance/core/database/app_database.dart';
import 'package:uuid/uuid.dart';

class WishlistRepository {
  final AppDatabase db;
  final Uuid _uuid;

  WishlistRepository(this.db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  Future<String> createWishlistItem({
    required String itemName,
    required int targetAmount,
    String priority = 'medium',
    int savedAmount = 0,
    String? categoryId,
    String? targetDate,
    String? urlOrReference,
    String? notes,
  }) async {
    if (targetAmount <= 0) {
      throw ArgumentError('targetAmount must be greater than zero');
    }

    final id = _uuid.v4();
    final opId = _uuid.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final status = savedAmount >= targetAmount
        ? 'ready_to_buy'
        : (savedAmount > 0 ? 'saving' : 'planned');

    await db.transaction(() async {
      db.execute(
        '''
        INSERT INTO local_wishlists (
          id, user_id, item_name, category_id, target_amount, saved_amount,
          priority, target_date, url_or_reference, notes, status, version, sync_status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 'pending_create', ?, ?)
        ''',
        [
          id,
          db.userId,
          itemName,
          categoryId,
          targetAmount,
          savedAmount,
          priority,
          targetDate,
          urlOrReference,
          notes,
          status,
          nowIso,
          nowIso,
        ],
      );

      db.enqueueOutbox(
        operationId: opId,
        entityType: 'wishlist',
        entityId: id,
        operationType: 'create',
        baseVersion: null,
        payload: {
          'item_name': itemName,
          'category_id': categoryId,
          'target_amount': targetAmount,
          'saved_amount': savedAmount,
          'priority': priority,
          'target_date': targetDate,
          'url_or_reference': urlOrReference,
          'notes': notes,
          'status': status,
        },
      );
    });

    return id;
  }

  Future<void> updateSavedAmount({
    required String wishlistId,
    required int newSavedAmount,
  }) async {
    final item = await db.getWishlistById(wishlistId);
    if (item == null) {
      throw StateError('Wishlist item not found');
    }
    if (newSavedAmount < 0) {
      throw ArgumentError('newSavedAmount cannot be negative');
    }

    final opId = _uuid.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final newStatus = newSavedAmount >= item.targetAmount
        ? 'ready_to_buy'
        : (newSavedAmount > 0 ? 'saving' : 'planned');

    await db.transaction(() async {
      db.execute(
        '''
        UPDATE local_wishlists
        SET saved_amount = ?, status = ?, version = version + 1, sync_status = 'pending_update', updated_at = ?
        WHERE id = ? AND user_id = ?
        ''',
        [newSavedAmount, newStatus, nowIso, wishlistId, db.userId],
      );

      db.enqueueOutbox(
        operationId: opId,
        entityType: 'wishlist',
        entityId: wishlistId,
        operationType: 'update',
        baseVersion: item.version,
        payload: {
          'item_name': item.itemName,
          'target_amount': item.targetAmount,
          'saved_amount': newSavedAmount,
          'priority': item.priority,
          'target_date': item.targetDate,
          'status': newStatus,
        },
      );
    });
  }

  Future<void> markPurchased(String wishlistId) async {
    final item = await db.getWishlistById(wishlistId);
    if (item == null) return;
    final opId = _uuid.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await db.transaction(() async {
      db.execute(
        '''
        UPDATE local_wishlists
        SET status = 'purchased', saved_amount = target_amount, version = version + 1, sync_status = 'pending_update', updated_at = ?
        WHERE id = ? AND user_id = ?
        ''',
        [nowIso, wishlistId, db.userId],
      );

      db.enqueueOutbox(
        operationId: opId,
        entityType: 'wishlist',
        entityId: wishlistId,
        operationType: 'update',
        baseVersion: item.version,
        payload: {
          'item_name': item.itemName,
          'target_amount': item.targetAmount,
          'saved_amount': item.targetAmount,
          'priority': item.priority,
          'status': 'purchased',
        },
      );
    });
  }
}
