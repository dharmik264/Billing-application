import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/standalone_expense_model.dart';
import 'local_database.dart';

class StandaloneExpenseService {
  StandaloneExpenseService._();
  static final StandaloneExpenseService instance = StandaloneExpenseService._();

  /// Change notifier to trigger automatic UI refreshes across screens
  final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  void _notify() {
    changeNotifier.value = changeNotifier.value + 1;
  }

  // --- Categories ---

  Future<List<StandaloneExpenseCategory>> getCategories() async {
    try {
      final list = await LocalDatabase.instance.getStandaloneCategories();
      return list.map((m) => StandaloneExpenseCategory.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error getting standalone categories: $e');
      return [];
    }
  }

  Future<bool> addCategory(StandaloneExpenseCategory category) async {
    try {
      await LocalDatabase.instance.insertStandaloneCategory(category.toMap());
      _notify();
      return true;
    } catch (e) {
      debugPrint('Error adding standalone category: $e');
      return false;
    }
  }

  Future<bool> updateCategory(StandaloneExpenseCategory category) async {
    try {
      await LocalDatabase.instance.updateStandaloneCategory(category.toMap());
      _notify();
      return true;
    } catch (e) {
      debugPrint('Error updating standalone category: $e');
      return false;
    }
  }

  Future<bool> deleteCategory(String id) async {
    try {
      await LocalDatabase.instance.deleteStandaloneCategory(id);
      _notify();
      return true;
    } catch (e) {
      debugPrint('Error deleting standalone category: $e');
      return false;
    }
  }

  // --- Expenses ---

  Future<bool> addExpense(StandaloneExpense expense) async {
    try {
      await LocalDatabase.instance.insertStandaloneExpense(expense.toMap());
      _notify();
      return true;
    } catch (e) {
      debugPrint('Error adding standalone expense: $e');
      return false;
    }
  }

  Future<bool> updateExpense(StandaloneExpense expense) async {
    try {
      await LocalDatabase.instance.updateStandaloneExpense(expense.toMap());
      _notify();
      return true;
    } catch (e) {
      debugPrint('Error updating standalone expense: $e');
      return false;
    }
  }

  Future<bool> deleteExpense(String id) async {
    try {
      await LocalDatabase.instance.deleteStandaloneExpense(id);
      _notify();
      return true;
    } catch (e) {
      debugPrint('Error deleting standalone expense: $e');
      return false;
    }
  }

  Future<List<StandaloneExpense>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? type,
    String? search,
  }) async {
    try {
      final formatter = DateFormat('yyyy-MM-dd');
      final sDate = startDate != null ? formatter.format(startDate) : null;
      final eDate = endDate != null ? formatter.format(endDate) : null;

      final list = await LocalDatabase.instance.getStandaloneExpenses(
        startDate: sDate,
        endDate: eDate,
        categoryId: categoryId,
        type: type,
        search: search,
      );

      return list.map((m) => StandaloneExpense.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error querying standalone expenses: $e');
      return [];
    }
  }

  Future<Map<String, double>> getSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final formatter = DateFormat('yyyy-MM-dd');
      final sDate = startDate != null ? formatter.format(startDate) : null;
      final eDate = endDate != null ? formatter.format(endDate) : null;

      return await LocalDatabase.instance.getStandaloneExpenseSummary(
        startDate: sDate,
        endDate: eDate,
      );
    } catch (e) {
      debugPrint('Error getting standalone expense summary: $e');
      return {'credit': 0.0, 'debit': 0.0, 'net': 0.0};
    }
  }

  /// Calculates category-wise debit aggregations for report breakdowns
  Map<String, double> computeCategoryDebitBreakdown(List<StandaloneExpense> expenses) {
    final Map<String, double> breakdown = {};
    for (final exp in expenses) {
      if (exp.isDebit) {
        breakdown[exp.categoryName] = (breakdown[exp.categoryName] ?? 0.0) + exp.amount;
      }
    }
    return breakdown;
  }
}
