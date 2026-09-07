import 'package:shared_preferences/shared_preferences.dart';
import '../services/restaurant_api.dart';

class BillCounter {
  static const String _tokenCountKey = 'token_count';
  static const String _billCountKey = 'bill_count';
  static const String _lastBillDateKey = 'last_bill_date';

  static Future<int> _initTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_tokenCountKey) ?? 0;
  }

  static String _getTodayDate() {
    return DateTime.now().toString().split(' ')[0];
  }

  static Future<void> initialize() async {
    try {
      final summary = await RestaurantApi.instance.fetchAllTimeSummary();
      final prefs = await SharedPreferences.getInstance();

      final today = _getTodayDate();
      final lastBillDate = prefs.getString(_lastBillDateKey) ?? '';

      // If it's a new day, reset bill count
      if (today != lastBillDate) {
        await prefs.setInt(_billCountKey, 0);
        await prefs.setString(_lastBillDateKey, today);
      }

      final currentLocalBills = prefs.getInt(_billCountKey) ?? 0;
      final apiLastBillInt = int.tryParse(summary.lastBillNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? summary.totalBills;
      
      // We only care about syncing from api if it's the same day, since API now sends today's last bill
      if (apiLastBillInt == 0 && summary.totalBills == 0) {
        await prefs.setInt(_billCountKey, 0);
        await prefs.setInt(_tokenCountKey, 0);
      } else if (apiLastBillInt > currentLocalBills) {
        await prefs.setInt(_billCountKey, apiLastBillInt);
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
    final today = _getTodayDate();
    final lastBillDate = prefs.getString(_lastBillDateKey) ?? '';
    
    int count = prefs.getInt(_billCountKey) ?? 0;
    if (today != lastBillDate) {
      count = 0;
    }
    
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
    final today = _getTodayDate();
    final lastBillDate = prefs.getString(_lastBillDateKey) ?? '';
    
    int count = prefs.getInt(_billCountKey) ?? 0;
    if (today != lastBillDate) {
      count = 0;
      await prefs.setString(_lastBillDateKey, today);
    }
    
    final next = count + 1;
    await prefs.setInt(_billCountKey, next);
    return next.toString().padLeft(4, '0');
  }
}
