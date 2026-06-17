import 'package:shared_preferences/shared_preferences.dart';
import '../services/restaurant_api.dart';

class BillCounter {
  static const String _tokenCountKey = 'token_count';
  static const String _billCountKey = 'bill_count';
  static const String _lastDateKey = 'last_token_date';

  static Future<int> _initTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T').first;
    final lastDate = prefs.getString(_lastDateKey);

    if (lastDate != today) {
      await prefs.setInt(_tokenCountKey, 0);
      await prefs.setString(_lastDateKey, today);
    }
    return prefs.getInt(_tokenCountKey) ?? 0;
  }

  static Future<void> initialize() async {
    try {
      final summary = await RestaurantApi.instance.fetchAllTimeSummary();
      final prefs = await SharedPreferences.getInstance();

      final currentLocalBills = prefs.getInt(_billCountKey) ?? 0;
      if (summary.totalBills == 0) {
        await prefs.setInt(_billCountKey, 0);
        await prefs.setInt(_tokenCountKey, 0);
      } else if (summary.totalBills > currentLocalBills) {
        await prefs.setInt(_billCountKey, summary.totalBills);
      }
    } catch (_) {
      // Offline or backend unavailable, continue with local counts
    }
  }

  /// Peek next token without incrementing
  static Future<String> peekTokenNumber() async {
    final count = await _initTokens();
    final next = count + 1;
    return '#T-${next.toString().padLeft(3, '0')}';
  }

  /// Peek next bill without incrementing
  static Future<String> peekBillNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_billCountKey) ?? 0;
    final next = count + 1;
    return next.toString().padLeft(4, '0');
  }

  /// Increment daily counter and return formatted token string
  static Future<String> nextTokenNumber() async {
    final count = await _initTokens();
    final prefs = await SharedPreferences.getInstance();
    final next = count + 1;
    await prefs.setInt(_tokenCountKey, next);
    return '#T-${next.toString().padLeft(3, '0')}';
  }

  /// Increment permanent bill counter and return formatted INV string
  static Future<String> nextBillNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_billCountKey) ?? 0;
    final next = count + 1;
    await prefs.setInt(_billCountKey, next);
    return next.toString().padLeft(4, '0');
  }
}
