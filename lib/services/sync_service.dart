import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'local_database.dart';
import 'restaurant_api.dart';
import 'dart:convert';

class SyncService {
  static final SyncService instance = SyncService._init();
  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;

  final StreamController<bool> _onlineStatusController = StreamController<bool>.broadcast();
  Stream<bool> get onlineStatusStream => _onlineStatusController.stream;
  bool get isOnline => _isOnline;

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
      
      for (var item in queue) {
        final id = item['id'] as int;
        final endpoint = item['endpoint'] as String;
        final method = item['method'] as String;
        final bodyStr = item['body'] as String;
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        
        bool success = false;
        try {
          if (method == 'POST') {
            await RestaurantApi.instance.post(endpoint, body);
            success = true;
          } else if (method == 'PUT') {
            await RestaurantApi.instance.put(endpoint, body);
            success = true;
          } else if (method == 'PATCH') {
            await RestaurantApi.instance.patch(endpoint, body);
            success = true;
          } else if (method == 'DELETE') {
            await RestaurantApi.instance.delete(endpoint);
            success = true;
          } else if (method == 'POST_MULTIPART') {
            await RestaurantApi.instance.postMultipart(endpoint, body);
            success = true;
          } else if (method == 'PUT_MULTIPART') {
            await RestaurantApi.instance.putMultipart(endpoint, body);
            success = true;
          }
        } catch (e) {
          debugPrint('Sync failed for item $id on $endpoint: $e');
        }
        
        if (success) {
          await LocalDatabase.instance.removeFromQueue(id);
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _onlineStatusController.close();
  }
}
