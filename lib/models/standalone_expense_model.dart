import 'package:flutter/material.dart';

enum StandaloneExpenseType {
  credit,
  debit,
}

extension StandaloneExpenseTypeExt on StandaloneExpenseType {
  String get value => this == StandaloneExpenseType.credit ? 'CREDIT' : 'DEBIT';
  String get displayLabel => this == StandaloneExpenseType.credit ? 'Credit (જમા)' : 'Debit (ખર્ચ)';
  String get shortLabel => this == StandaloneExpenseType.credit ? 'જમા' : 'ખર્ચ';
  Color get color => this == StandaloneExpenseType.credit ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
}

class StandaloneExpenseCategory {
  final String id;
  final String name;
  final String iconName;
  final String colorHex;
  final bool isDefault;
  final DateTime createdAt;

  StandaloneExpenseCategory({
    required this.id,
    required this.name,
    this.iconName = 'category',
    this.colorHex = '#1976D2',
    this.isDefault = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Color get color {
    try {
      final hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF1976D2);
  }

  IconData get icon {
    switch (iconName) {
      case 'local_cafe':
        return Icons.local_cafe_rounded;
      case 'storefront':
      case 'store':
        return Icons.storefront_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'badge':
      case 'payments':
        return Icons.badge_rounded;
      case 'local_shipping':
        return Icons.local_shipping_rounded;
      case 'build':
        return Icons.build_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_rounded;
      case 'assignment_return':
        return Icons.assignment_return_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'shopping_cart':
        return Icons.shopping_cart_rounded;
      case 'receipt':
        return Icons.receipt_long_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'local_gas_station':
        return Icons.local_gas_station_rounded;
      case 'phone_android':
        return Icons.phone_android_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon_name': iconName,
      'color_hex': colorHex,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory StandaloneExpenseCategory.fromMap(Map<String, dynamic> map) {
    return StandaloneExpenseCategory(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      iconName: map['icon_name']?.toString() ?? 'category',
      colorHex: map['color_hex']?.toString() ?? '#1976D2',
      isDefault: (map['is_default'] is int && map['is_default'] == 1) || map['is_default'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class StandaloneExpense {
  final String id;
  final String categoryId;
  final String categoryName;
  final String type; // 'CREDIT' or 'DEBIT'
  final double amount;
  final String paymentMode; // 'CASH', 'ONLINE', 'BANK_TRANSFER', 'CHEQUE'
  final String? note;
  final String expenseDate; // 'YYYY-MM-DD'
  final DateTime createdAt;

  StandaloneExpense({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.type,
    required this.amount,
    this.paymentMode = 'CASH',
    this.note,
    required this.expenseDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCredit => type.toUpperCase() == 'CREDIT';
  bool get isDebit => type.toUpperCase() == 'DEBIT';

  Color get typeColor => isCredit ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
  String get typeLabel => isCredit ? 'Credit (જમા)' : 'Debit (ખર્ચ)';

  String get formattedPaymentMode {
    switch (paymentMode.toUpperCase()) {
      case 'CASH':
        return 'Cash (રોકડ)';
      case 'ONLINE':
      case 'UPI':
        return 'Online / UPI';
      case 'BANK_TRANSFER':
      case 'BANK':
        return 'Bank Transfer';
      case 'CHEQUE':
        return 'Cheque';
      default:
        return paymentMode;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'category_name': categoryName,
      'type': type.toUpperCase(),
      'amount': amount,
      'payment_mode': paymentMode.toUpperCase(),
      'note': note,
      'expense_date': expenseDate,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory StandaloneExpense.fromMap(Map<String, dynamic> map) {
    return StandaloneExpense(
      id: map['id']?.toString() ?? '',
      categoryId: map['category_id']?.toString() ?? '',
      categoryName: map['category_name']?.toString() ?? '',
      type: (map['type']?.toString() ?? 'DEBIT').toUpperCase(),
      amount: (map['amount'] is num) ? (map['amount'] as num).toDouble() : double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0,
      paymentMode: map['payment_mode']?.toString() ?? 'CASH',
      note: map['note']?.toString(),
      expenseDate: map['expense_date']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
