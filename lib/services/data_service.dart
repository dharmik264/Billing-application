import 'package:flutter/foundation.dart';
import 'local_database.dart';
import 'restaurant_api.dart';
import 'sync_service.dart';

/// Result returned by [DataService.saveWithSync].
class SaveResult<T> {
  /// The entity that was saved (optimistically or from server).
  final T data;

  /// `true` if the save went to the server directly (online path).
  /// `false` means it is queued and will sync later (offline path).
  final bool syncedNow;

  const SaveResult({required this.data, required this.syncedNow});
}

/// Central data-mutation layer that implements the
/// **Optimistic UI + Offline-Aware Sync** pattern.
///
/// Every write operation:
/// 1. Saves to local SQLite immediately (optimistic).
/// 2. If **online** → calls the API directly; on success returns server data.
///    On API failure → falls back to queue (offline path).
/// 3. If **offline** → adds to sync_queue; returns local data instantly.
///
/// Callers get a [SaveResult] they can use to update UI state without waiting.
class DataService {
  DataService._();

  // ── Customers ─────────────────────────────────────────────────

  /// Create a new customer (online → direct API, offline → queued).
  static Future<SaveResult<ApiCustomer>> createCustomer(
    ApiCustomerDraft draft,
  ) async {
    final payload = draft.toJson();

    if (!SyncService.instance.isOnline) {
      return _createCustomerOffline(payload);
    }

    // Online path
    try {
      final data = await RestaurantApi.instance.post('customers/', payload);
      await LocalDatabase.instance.saveCustomer(data);
      return SaveResult(data: ApiCustomer.fromJson(data), syncedNow: true);
    } catch (e) {
      debugPrint('DataService.createCustomer API error, queuing: $e');
      return _createCustomerOffline(payload);
    }
  }

  /// Update an existing customer.
  static Future<SaveResult<ApiCustomer>> updateCustomer(
    String id,
    ApiCustomerDraft draft,
  ) async {
    final payload = draft.toJson();

    if (!SyncService.instance.isOnline) {
      return _updateCustomerOffline(id, payload);
    }

    try {
      final data =
          await RestaurantApi.instance.put('customers/$id/', payload);
      await LocalDatabase.instance.saveCustomer(data);
      return SaveResult(data: ApiCustomer.fromJson(data), syncedNow: true);
    } catch (e) {
      debugPrint('DataService.updateCustomer API error, queuing: $e');
      return _updateCustomerOffline(id, payload);
    }
  }

  static Future<SaveResult<ApiCustomer>> _createCustomerOffline(
    Map<String, dynamic> payload,
  ) async {
    final localCustomer = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      ...payload,
    };
    await LocalDatabase.instance.saveCustomer(localCustomer);
    await LocalDatabase.instance.addToQueue('customers/', 'POST', payload);
    await SyncService.instance.notifyQueueChanged();
    return SaveResult(
      data: ApiCustomer.fromJson(localCustomer),
      syncedNow: false,
    );
  }

  static Future<SaveResult<ApiCustomer>> _updateCustomerOffline(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final localCustomer = {'id': id, ...payload};
    await LocalDatabase.instance.saveCustomer(localCustomer);
    await LocalDatabase.instance.addToQueue('customers/$id/', 'PUT', payload);
    await SyncService.instance.notifyQueueChanged();
    return SaveResult(
      data: ApiCustomer.fromJson(localCustomer),
      syncedNow: false,
    );
  }

  // ── Items ──────────────────────────────────────────────────────

  /// Create a menu item (handles multipart for image fields).
  static Future<SaveResult<ApiItem>> createItem(ApiItemDraft draft) async {
    final payload = draft.toJson();

    if (!SyncService.instance.isOnline) {
      return _createItemOffline(payload);
    }

    try {
      final data =
          await RestaurantApi.instance.postMultipart('menu/items/', payload);
      await LocalDatabase.instance.saveItem(data);
      return SaveResult(data: ApiItem.fromJson(data), syncedNow: true);
    } catch (e) {
      debugPrint('DataService.createItem API error, queuing: $e');
      return _createItemOffline(payload);
    }
  }

  /// Update a menu item.
  static Future<SaveResult<ApiItem>> updateItem(
    String id,
    ApiItemDraft draft,
  ) async {
    final payload = draft.toJson();

    if (!SyncService.instance.isOnline) {
      return _updateItemOffline(id, payload);
    }

    try {
      final data =
          await RestaurantApi.instance.putMultipart('menu/items/$id/', payload);
      await LocalDatabase.instance.saveItem(data);
      return SaveResult(data: ApiItem.fromJson(data), syncedNow: true);
    } catch (e) {
      debugPrint('DataService.updateItem API error, queuing: $e');
      return _updateItemOffline(id, payload);
    }
  }

  static Future<SaveResult<ApiItem>> _createItemOffline(
    Map<String, dynamic> payload,
  ) async {
    final localItem = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      ...payload,
    };
    await LocalDatabase.instance.saveItem(localItem);
    await LocalDatabase.instance
        .addToQueue('menu/items/', 'POST_MULTIPART', payload);
    await SyncService.instance.notifyQueueChanged();
    return SaveResult(data: ApiItem.fromJson(localItem), syncedNow: false);
  }

  static Future<SaveResult<ApiItem>> _updateItemOffline(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final localItem = {'id': id, ...payload};
    await LocalDatabase.instance.saveItem(localItem);
    await LocalDatabase.instance
        .addToQueue('menu/items/$id/', 'PUT_MULTIPART', payload);
    await SyncService.instance.notifyQueueChanged();
    return SaveResult(data: ApiItem.fromJson(localItem), syncedNow: false);
  }

  // ── Tokens ─────────────────────────────────────────────────────

  /// Create a billing token / order.
  static Future<SaveResult<ApiToken>> createToken(ApiTokenDraft draft) async {
    final payload = draft.toJson();

    if (!SyncService.instance.isOnline) {
      return _createTokenOffline(payload);
    }

    try {
      final data =
          await RestaurantApi.instance.post('tokens/create/', payload);
      await LocalDatabase.instance.saveToken(data);
      return SaveResult(data: ApiToken.fromJson(data), syncedNow: true);
    } catch (e) {
      debugPrint('DataService.createToken API error, queuing: $e');
      return _createTokenOffline(payload);
    }
  }

  static Future<SaveResult<ApiToken>> _createTokenOffline(
    Map<String, dynamic> payload,
  ) async {
    final localToken = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      ...payload,
      'status': 'completed',
      'created_at': DateTime.now().toIso8601String(),
    };
    await LocalDatabase.instance.saveToken(localToken);
    await LocalDatabase.instance
        .addToQueue('tokens/create/', 'POST', payload);
    await SyncService.instance.notifyQueueChanged();
    return SaveResult(data: ApiToken.fromJson(localToken), syncedNow: false);
  }
}
