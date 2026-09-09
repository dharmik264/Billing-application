import 'package:flutter/foundation.dart';
import '../services/restaurant_api.dart';

/// A global event notifier for bill state changes (add, edit, delete).
/// Screens like DashboardScreen, AllTokensScreen, AnalyticsReportsScreen
/// subscribe to this notifier to auto-refresh their data in real-time.
class BillEventNotifier {
  BillEventNotifier._();

  static final ValueNotifier<int> billRefreshNotifier = ValueNotifier<int>(0);

  /// Trigger a refresh notification across all listening screens.
  static void notifyBillChanged() {
    RestaurantApi.instance.invalidateSummaryCache();
    billRefreshNotifier.value++;
  }
}
