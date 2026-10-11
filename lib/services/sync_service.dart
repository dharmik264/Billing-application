import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'local_database.dart';
import 'restaurant_api.dart';
import 'dart:convert';
import '../utils/bill_event_notifier.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;

  // Online status stream
  final StreamController<bool> _onlineStatusController = StreamController<bool>.broadcast();
  Stream<bool> get onlineStatusStream => _onlineStatusController.stream;
  bool get isOnline => _isOnline;

  // Emits the number of items successfully synced after each syncNow() run.
  final StreamController<int> _syncCountController = StreamController<int>.broadcast();
  Stream<int> get syncCountStream => _syncCountController.stream;

  // Emits the current pending queue size whenever it changes.
  final StreamController<int> _pendingCountController = StreamController<int>.broadcast();
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  SyncService._init();

  void initialize() {
    if (kIsWeb) return; // Connectivity plus might behave differently on web
    _checkInitialConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final connected = results.any((r) => r != ConnectivityResult.none);
      _updateStatus(connected);
      if (connected) {
        syncNow();
      }
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateStatus(results.any((r) => r != ConnectivityResult.none));
    if (_isOnline) {
      syncNow();
    }
  }

  void _updateStatus(bool connected) {
    if (_isOnline != connected) {
      _isOnline = connected;
      _onlineStatusController.add(_isOnline);
    }
  }

  Future<void> syncNow() async {
    if (_isSyncing || !_isOnline) return;
    _isSyncing = true;

    try {
      final queue = await LocalDatabase.instance.getQueue();
      if (queue.isEmpty) {
        _isSyncing = false;
        return;
      }

      // Broadcast current pending count before starting.
      _pendingCountController.add(queue.length);

      int syncedCount = 0;

      for (var item in queue) {
        final id = item['id'] as int;
        final endpoint = item['endpoint'] as String;
        final method = item['method'] as String;
        final bodyStr = item['body'] as String;
        final attempts = (item['attempts'] as int?) ?? 0;
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;

        bool success = false;
        Map<String, dynamic>? serverResult;

        try {
          if (method == 'POST') {
            serverResult = await RestaurantApi.instance.post(endpoint, body);
            success = true;
          } else if (method == 'PUT') {
            serverResult = await RestaurantApi.instance.put(endpoint, body);
            success = true;
          } else if (method == 'PATCH') {
            serverResult = await RestaurantApi.instance.patch(endpoint, body);
            success = true;
          } else if (method == 'DELETE') {
            await RestaurantApi.instance.delete(endpoint);
            success = true;
          } else if (method == 'POST_MULTIPART') {
            serverResult = await RestaurantApi.instance.postMultipart(endpoint, body);
            success = true;
          } else if (method == 'PUT_MULTIPART') {
            serverResult = await RestaurantApi.instance.putMultipart(endpoint, body);
            success = true;
          }

          // If the server returned an authoritative record, update local DB to reflect server IDs
          if (serverResult != null && serverResult.isNotEmpty) {
            if (endpoint.contains('tokens/create')) {
              await LocalDatabase.instance.saveToken(serverResult);
            } else if (endpoint.contains('customers')) {
              await LocalDatabase.instance.saveCustomer(serverResult);
            } else if (endpoint.contains('items')) {
              await LocalDatabase.instance.saveItem(serverResult);
            }
          }
        } catch (e) {
          debugPrint('Sync failed for item $id on $endpoint: $e');
          final newAttempts = attempts + 1;
          final isClientError = e is ApiException && e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500;
          if (newAttempts >= 5 || isClientError) {
            debugPrint('Quarantining sync item $id after $newAttempts attempts (client error: $isClientError)');
            await LocalDatabase.instance.removeFromQueue(id);
          } else {
            await LocalDatabase.instance.incrementQueueAttempts(id);
          }
        }

        if (success) {
          await LocalDatabase.instance.removeFromQueue(id);
          syncedCount++;
        }
      }

      // Notify listeners how many items were synced.
      if (syncedCount > 0) {
        _syncCountController.add(syncedCount);
        BillEventNotifier.notifyBillChanged();
      }

      // Broadcast updated pending count after sync.
      final remaining = await LocalDatabase.instance.getQueue();
      _pendingCountController.add(remaining.length);
    } finally {
      _isSyncing = false;
    }
  }

  /// Call this after adding an item to the queue so the pending count
  /// badge updates immediately without waiting for a full sync cycle.
  Future<void> notifyQueueChanged() async {
    final queue = await LocalDatabase.instance.getQueue();
    _pendingCountController.add(queue.length);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _onlineStatusController.close();
    _syncCountController.close();
    _pendingCountController.close();
  }
}
