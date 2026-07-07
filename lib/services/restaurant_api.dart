import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RestaurantApi {
  RestaurantApi({
    http.Client? client,
    String? baseUrl,
    Duration timeout = const Duration(seconds: 0),
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            (const String.fromEnvironment('API_BASE_URL', defaultValue: '')
                    .isNotEmpty
                ? const String.fromEnvironment('API_BASE_URL')
                : (!kIsWeb && Platform.isAndroid
                      // 10.0.2.2 works for Android Emulator, but physical devices need the PC's local IP.
                      // Updated back to 127.0.0.1 since we are using 'adb reverse tcp:8000 tcp:8000' over USB
                      ? 'https://billing-application-wdss.onrender.com/api'
                    : 'https://billing-application-wdss.onrender.com/api')),
        _timeout = timeout;

  static final RestaurantApi instance = RestaurantApi(timeout: const Duration(seconds: 60));
  static const String defaultShopId = 'a1b2c3d4-0000-0000-0000-000000000001';

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  String? _accessToken;
  ApiShopData? _cachedShopData;
  List<ApiItem>? _cachedItems;
  ApiSummaryReport? _cachedSummary;

  bool get hasValidToken => _accessToken != null && _accessToken!.isNotEmpty;
  ApiShopData? get shopData => _cachedShopData;

  String get baseUrl => _baseUrl;

  String getMediaUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    // Base URL is typically ending with /api, we might need to go to root for media
    final base = Uri.parse(_baseUrl);
    final origin = '${base.scheme}://${base.host}:${base.port}';
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$origin$normalizedPath';
  }

  void setTokens(String access, String refresh) {
    _accessToken = access;
  }

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');
  }

  Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', access);
    await prefs.setString('refreshToken', refresh);
    setTokens(access, refresh);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    _accessToken = null;
  }

  Map<String, String> _headers() {
    final headers = {'Content-Type': 'application/json'};
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(_baseUrl);
    final normalizedPath = '${base.path.replaceAll(RegExp(r'/$'), '')}/$path'
        .replaceAll('//', '/');
    return base.replace(path: normalizedPath, queryParameters: query);
  }

  // ── Auth ────────────────────────────────────────────────────

  Future<String?> requestOtp(String mobile) async {
    final response = await _post('auth/send-otp/', {'phone': mobile});
    if (response.containsKey('otp')) {
      return response['otp'].toString();
    }
    return null;
  }

  Future<Map<String, dynamic>> verifyOtp(String mobile, String otp) async {
    final response = await _post('auth/verify-otp/', {
      'phone': mobile,
      'code': otp,
    });
    if (response.containsKey('access') && response.containsKey('refresh')) {
      await saveTokens(response['access'], response['refresh']);
      // Return the full response to allow checking status in UI
      return response;
    }
    return response;
  }

  Future<Map<String, dynamic>> superAdminLogin(String username, String password) async {
    final response = await _post('auth/super-admin/login/', {
      'username': username,
      'password': password,
    });
    if (response.containsKey('access') && response.containsKey('refresh')) {
      await saveTokens(response['access'], response['refresh']);
    }
    return response;
  }

  Future<Map<String, dynamic>> registerUser({
    required String name,
    required String phone,
    required String shopName,
    String? email,
  }) async {
    return await _post('auth/register/', {
      'name': name,
      'phone': phone,
      'shop_name': shopName,
      'email': email ?? '',
    });
  }

  // ── Super Admin ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchShopRequests() async {
    return await _getPaginatedList('auth/shop-requests/');
  }

  Future<List<Map<String, dynamic>>> fetchSuperAdminUsers() async {
    return await _getPaginatedList('auth/super-admin/users/');
  }

  Future<void> updateUserPermissions(String userId, Map<String, bool> permissions) async {
    await _post('auth/super-admin/users/$userId/permissions/', {
      'permissions': permissions,
    });
  }

  Future<void> deleteSuperAdminUser(String userId) async {
    await _delete('auth/super-admin/users/$userId/delete/');
  }

  // Super Admin Plans
  Future<List<dynamic>> fetchPlans() async {
    return await _getPaginatedList('auth/super-admin/plans/');
  }

  Future<Map<String, dynamic>> createPlan(Map<String, dynamic> data) async {
    return await _post('auth/super-admin/plans/', data);
  }

  Future<Map<String, dynamic>> updatePlan(String planId, Map<String, dynamic> data) async {
    return await _put('auth/super-admin/plans/$planId/', data);
  }

  Future<void> deletePlan(String planId) async {
    await _delete('auth/super-admin/plans/$planId/');
  }

  Future<void> approveShopRequest(String userId, String plan) async {
    await _post('auth/shop-requests/$userId/action/', {
      'action': 'approve',
      'plan': plan,
    });
  }

  Future<void> declineShopRequest(String userId) async {
    await _post('auth/shop-requests/$userId/action/', {
      'action': 'decline',
    });
  }

  Future<Map<String, dynamic>> fetchSuperAdminStats() async {
    final response = await _get('auth/super-admin/stats/');
    return response;
  }

  // ── Shop ────────────────────────────────────────────────────

  Future<ApiShopData> fetchShop({String shopId = defaultShopId, bool forceRefresh = false}) async {
    if (_cachedShopData != null && !forceRefresh) {
      return _cachedShopData!;
    }
    final data = await _get('shop/');
    _cachedShopData = ApiShopData.fromJson(data);
    return _cachedShopData!;
  }

  Future<ApiShopData> saveShop(
    ApiShopDraft shop, {
    String shopId = defaultShopId,
  }) async {
    final data = await _patch('shop/', shop.toJson());
    _cachedShopData = ApiShopData.fromJson(data);
    return _cachedShopData!;
  }

  Future<ApiBillTemplate> fetchBillTemplate() async {
    final data = await _get('shop/bill-template/');
    return ApiBillTemplate.fromJson(data);
  }

  Future<ApiBillTemplate> saveBillTemplate(
      ApiBillTemplateDraft template) async {
    final data = await _patch('shop/bill-template/', template.toJson());
    return ApiBillTemplate.fromJson(data);
  }

  // ── Items ────────────────────────────────────────────────────

  Future<List<ApiItem>> fetchItems({String shopId = defaultShopId, bool forceRefresh = false}) async {
    if (_cachedItems != null && !forceRefresh) {
      return _cachedItems!;
    }
    final data = await _getPaginatedList('menu/items/');
    _cachedItems = data.map((item) => ApiItem.fromJson(item)).toList();
    return _cachedItems!;
  }

  Future<ApiItem> createItem(ApiItemDraft item,
      {String shopId = defaultShopId}) async {
    final data = await _postMultipart('menu/items/', {
      ...item.toJson(),
    });
    _cachedItems = null;
    return ApiItem.fromJson(data);
  }

  Future<ApiItem> updateItem(String id, ApiItemDraft item) async {
    final data = await _putMultipart('menu/items/$id/', item.toJson());
    _cachedItems = null;
    return ApiItem.fromJson(data);
  }

  Future<ApiItem> updateItemStatus(String id, {required bool active}) async {
    final data =
        await _patch('menu/items/$id/toggle/', {'is_available': active});
    _cachedItems = null;
    return ApiItem.fromJson(data);
  }

  Future<void> deleteItem(String id) async {
    await _delete('menu/items/$id/');
    _cachedItems = null;
  }

  // ── Tokens ───────────────────────────────────────────────────

  Future<List<ApiToken>> fetchTokens({
    String shopId = defaultShopId,
    int? limit,
  }) async {
    final query = <String, String>{};
    if (limit != null) query['limit'] = limit.toString();
    
    List<ApiToken> apiTokens = [];
    final data = await _getPaginatedList('tokens/', query);
    apiTokens = data.map((token) => ApiToken.fromJson(token)).toList();

    if (limit != null && apiTokens.length > limit) {
      return apiTokens.sublist(0, limit);
    }
    return apiTokens;
  }

  Future<ApiToken> createToken(ApiTokenDraft token,
      {String shopId = defaultShopId}) async {

    // Online mode: standard API call
    final data = await _post('tokens/create/', {
      ...token.toJson(),
    });
    return ApiToken.fromJson(data);
  }

  Future<void> processPayment(String id, String paymentMode) async {
    await _post('tokens/$id/payment/', {
      'payment_mode': paymentMode.toLowerCase(),
    });
  }

  Future<void> updateTokenPaymentMode(String id, String paymentMode) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/tokens/$id/'),
      headers: _headers(),
      body: jsonEncode({'payment_mode': paymentMode}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update payment mode: ${response.body}');
    }
  }

  Future<void> cancelToken(String id) async {
    await _patch('tokens/$id/cancel/', {});
  }

  Future<void> deleteToken(String id) async {
    await _delete('tokens/$id/');
  }

  // ── Reports ──────────────────────────────────────────────────

  Future<ApiSummaryReport> fetchTodayReport(
      {String shopId = defaultShopId}) async {
    final data = await _get('reports/daily/');
    return ApiSummaryReport.fromJson(data);
  }

  Future<ApiSummaryReport> fetchAllTimeSummary(
      {String shopId = defaultShopId, bool useCache = false}) async {
    if (useCache && _cachedSummary != null) {
      return _cachedSummary!;
    }
    try {
      final data = await _get('tokens/summary/today/');
      _cachedSummary = ApiSummaryReport.fromJson(data);
      return _cachedSummary!;
    } catch (_) {
      final data = await _get('reports/daily/');
      _cachedSummary = ApiSummaryReport.fromJson(data);
      return _cachedSummary!;
    }
  }

  // ── HTTP helpers ──────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? query]) async {
    final response = await _client
        .get(_uri(path, query), headers: _headers())
        .timeout(_timeout);
    return _decodeMap(response);
  }

  Future<List<Map<String, dynamic>>> _getPaginatedList(String path,
      [Map<String, String>? query]) async {
    final response = await _client
        .get(_uri(path, query), headers: _headers())
        .timeout(_timeout);
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(decoded, response.statusCode),
          statusCode: response.statusCode);
    }
    if (decoded is Map<String, dynamic> && decoded.containsKey('results')) {
      return (decoded['results'] as List).cast<Map<String, dynamic>>();
    }
    if (decoded is! List) {
      throw const ApiException('Expected a list or paginated response');
    }
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          _uri(path),
          headers: _headers(),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> _put(
      String path, Map<String, dynamic> body) async {
    final response = await _client
        .put(
          _uri(path),
          headers: _headers(),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> _patch(
      String path, Map<String, dynamic> body) async {
    final response = await _client
        .patch(
          _uri(path),
          headers: _headers(),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> _postMultipart(
      String path, Map<String, dynamic> body) async {
    return _sendMultipart('POST', path, body);
  }

  Future<Map<String, dynamic>> _putMultipart(
      String path, Map<String, dynamic> body) async {
    return _sendMultipart('PUT', path, body);
  }

  Future<Map<String, dynamic>> _sendMultipart(
      String method, String path, Map<String, dynamic> body) async {
    final uri = _uri(path);
    final request = http.MultipartRequest(method, uri);
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }

    for (final entry in body.entries) {
      if (entry.value == null) continue;

      if ((entry.key == 'logo' ||
              entry.key == 'image' ||
              entry.key == 'logo_url' ||
              entry.key == 'payment_qr_code' ||
              entry.key == 'qr_code_url' ||
              entry.key == 'qrUrl') &&
          entry.value.toString().isNotEmpty) {
        try {
          final bytes = base64Decode(entry.value.toString());
          request.files.add(http.MultipartFile.fromBytes(
            entry.key,
            bytes,
            filename: '${entry.key}.png',
          ));
        } catch (_) {
          request.fields[entry.key] = entry.value.toString();
        }
      } else if (entry.value is Map || entry.value is List) {
        request.fields[entry.key] = jsonEncode(entry.value);
      } else {
        request.fields[entry.key] = entry.value.toString();
      }
    }

    final streamedResponse = await _client.send(request).timeout(_timeout);
    final response = await http.Response.fromStream(streamedResponse);
    return _decodeMap(response);
  }

  Future<void> _delete(String path) async {
    final response =
        await _client.delete(_uri(path), headers: _headers()).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
          _errorMessage(jsonDecode(response.body), response.statusCode),
          statusCode: response.statusCode);
    }
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.body.isEmpty) return {};
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      String snippet = response.body;
      final match = RegExp(r'<title>(.*?)</title>').firstMatch(snippet);
      if (match != null) {
        snippet = match.group(1) ?? snippet;
      } else if (snippet.length > 200) {
        snippet = snippet.substring(0, 200);
      }
      throw ApiException('Server Error ${response.statusCode}: $snippet');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(decoded, response.statusCode),
          statusCode: response.statusCode);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Expected an object response');
    }
    return decoded;
  }

  String _errorMessage(Object? decoded, int statusCode) {
    if (decoded is Map) {
      if (decoded['error'] is String) return decoded['error'];
      if (decoded['detail'] is String) return decoded['detail'];

      // Handle Django REST Framework field validation errors
      final errors = <String>[];
      decoded.forEach((key, value) {
        if (value is List) {
          errors.add('$key: ${value.join(", ")}');
        } else if (value is String) {
          errors.add('$key: $value');
        }
      });
      if (errors.isNotEmpty) return errors.join('\n');
    }
    return 'API request failed with status $statusCode';
  }
}

// ── Exceptions ────────────────────────────────────────────────

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

// ── Models ────────────────────────────────────────────────────

class ApiShopData {
  const ApiShopData({
    required this.id,
    required this.name,
    required this.tagline,
    this.phone,
    this.alternatePhone,
    this.address,
    this.email,
    this.gstin,
    this.logoUrl,
    this.qrUrl,
    this.upiId,
    this.paymentModesConfig,
    this.billSettings,
  });

  factory ApiShopData.fromJson(Map<String, dynamic> json) {
    return ApiShopData(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      tagline: json['tagline']?.toString() ?? '',
      phone: json['phone']?.toString(),
      alternatePhone: json['alternatePhone']?.toString() ??
          json['alternate_phone']?.toString(),
      address: json['address']?.toString(),
      email: json['email']?.toString(),
      gstin: json['gstin']?.toString(),
      logoUrl: json['logo']?.toString() ?? json['logoUrl']?.toString(),
      qrUrl: json['qr_code']?.toString() ?? json['qrUrl']?.toString(),
      upiId: json['upi_id']?.toString() ?? json['upiId']?.toString(),
      paymentModesConfig: json['payment_modes_config']?.toString() ??
          json['paymentModesConfig']?.toString(),
      billSettings: json['billSettings'] ?? json['bill_settings'] ?? {},
    );
  }

  final String id;
  final String name;
  final String tagline;
  final String? phone;
  final String? alternatePhone;
  final String? address;
  final String? email;
  final String? gstin;
  final String? logoUrl;
  final String? qrUrl;
  final String? upiId;
  final String? paymentModesConfig;
  final Map<String, dynamic>? billSettings;
}

class ApiItem {
  const ApiItem({
    required this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.rate,
    required this.active,
    required this.availableOnline,
  });

  factory ApiItem.fromJson(Map<String, dynamic> json) {
    String categoryName = 'Uncategorized';
    if (json['category'] is Map) {
      categoryName = json['category']['name']?.toString() ?? categoryName;
    } else if (json['category'] is String) {
      categoryName = json['category'].toString();
    } else if (json['category_name'] != null) {
      categoryName = json['category_name'].toString();
    }

    return ApiItem(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? json['item_code']?.toString() ?? '',
      category: categoryName,
      rate: _toDouble(json['price'] ?? json['rate']),
      active: json['is_available'] == true ||
          json['active'] == true ||
          json['is_active'] == true,
      availableOnline: json['availableOnline'] == true ||
          json['is_available_online'] == true,
    );
  }

  final String? id;
  final String name;
  final String code;
  final String category;
  final double rate;
  final bool active;
  final bool availableOnline;
}

class ApiItemDraft {
  const ApiItemDraft({
    required this.name,
    required this.code,
    required this.category,
    required this.rate,
    required this.active,
    required this.availableOnline,
    this.imageBase64,
  });

  final String name;
  final String code;
  final String category;
  final double rate;
  final bool active;
  final bool availableOnline;
  final String? imageBase64;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name,
      'item_code': code,
      'category_name': category,
      'price': rate,
      'is_available': active,
      'item_type': 'veg',
    };
    if (imageBase64 != null && imageBase64!.isNotEmpty) {
      data['image'] = imageBase64;
    }
    return data;
  }
}

class ApiToken {
  const ApiToken({
    required this.id,
    required this.tokenNumber,
    required this.billNumber,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.grandTotal,
    required this.paymentMode,
    required this.createdAt,
    required this.items,
    this.orderType = 'dine_in',
  });

  factory ApiToken.fromJson(Map<String, dynamic> json) {
    return ApiToken(
      id: json['id']?.toString() ?? '',
      tokenNumber: json['token_number']?.toString() ??
          json['tokenNumber']?.toString() ??
          '',
      billNumber: json['bill_number']?.toString() ??
          json['billNumber']?.toString() ??
          '',
      status: json['status']?.toString() ?? 'PENDING',
      customerName: json['customer_name']?.toString() ??
          json['customerName']?.toString() ??
          '',
      customerPhone: json['customer_phone']?.toString() ??
          json['customerPhone']?.toString() ??
          '',
      grandTotal:
          _toDouble(json['total'] ?? json['grand_total'] ?? json['grandTotal']),
      paymentMode: json['payment_mode']?.toString() ??
          json['paymentMode']?.toString() ??
          'CASH',
      createdAt:
          json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '',
      orderType: json['order_type']?.toString() ?? 'dine_in',
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => ApiTokenItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  final String id;
  final String tokenNumber;
  final String billNumber;
  final String status;
  final String customerName;
  final String customerPhone;
  final double grandTotal;
  final String paymentMode;
  final String createdAt;
  final String orderType;
  final List<ApiTokenItem> items;
}

class ApiTokenItem {
  const ApiTokenItem({
    required this.id,
    required this.name,
    required this.code,
    required this.rate,
    required this.quantity,
    required this.subtotal,
  });

  factory ApiTokenItem.fromJson(Map<String, dynamic> json) {
    double q = _toDouble(json['quantity']);
    double r = _toDouble(json['price'] ?? json['rate']);
    return ApiTokenItem(
      id: json['id']?.toString() ?? '',
      name:
          json['name']?.toString() ?? json['menu_item_name']?.toString() ?? '',
      code: json['item_code']?.toString() ?? json['code']?.toString() ?? '',
      rate: r,
      quantity: q.toInt() == 0 ? 1 : q.toInt(),
      subtotal: _toDouble(json['subtotal'] ?? (r * q)),
    );
  }

  final String id;
  final String name;
  final String code;
  final double rate;
  final int quantity;
  final double subtotal;
}

typedef ApiTodayReport = ApiSummaryReport;

class ApiSummaryReport {
  const ApiSummaryReport({
    required this.totalTokens,
    required this.totalSales,
    required this.cashTotal,
    required this.onlineTotal,
    required this.totalBills,
    required this.monthlySales,
    required this.lastBillNumber,
  });

  factory ApiSummaryReport.fromJson(Map<String, dynamic> json) {
    // Adapting to Django's reports/daily/ response
    Map<String, dynamic> summary =
        json['summary'] is Map ? json['summary'] : {};
    Map<String, dynamic> byPayment =
        json['by_payment'] is Map ? json['by_payment'] : {};

    return ApiSummaryReport(
      totalTokens: int.tryParse(summary['count']?.toString() ??
              json['totalTokens']?.toString() ??
              json['total_tokens']?.toString() ??
              '') ??
          0,
      totalSales: _toDouble(
          summary['revenue'] ?? json['revenue'] ?? json['totalSales']),
      cashTotal:
          _toDouble(byPayment['cash'] ?? json['cash'] ?? json['cashTotal']),
      onlineTotal:
          _toDouble(byPayment['upi'] ?? json['upi'] ?? json['onlineTotal']),
      totalBills: int.tryParse(json['total_bills']?.toString() ?? '') ?? 0,
      monthlySales: _toDouble(json['monthly_sales']),
      lastBillNumber: json['last_bill_number']?.toString() ?? "0",
    );
  }

  final int totalTokens;
  final double totalSales;
  final double cashTotal;
  final double onlineTotal;
  final int totalBills;
  final double monthlySales;
  final String lastBillNumber;
}

class ApiUser {
  const ApiUser({
    required this.id,
    required this.username,
    required this.phone,
    required this.role,
  });

  factory ApiUser.fromJson(Map<String, dynamic> json) {
    return ApiUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
    );
  }

  final String id;
  final String username;
  final String phone;
  final String role;
}

class ApiDashboardStats {
  const ApiDashboardStats({
    required this.openOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.totalRevenue,
  });

  factory ApiDashboardStats.fromJson(Map<String, dynamic> json) {
    return ApiDashboardStats(
      openOrders: int.tryParse(json['open_orders']?.toString() ?? '') ?? 0,
      completedOrders:
          int.tryParse(json['completed_orders']?.toString() ?? '') ?? 0,
      cancelledOrders:
          int.tryParse(json['cancelled_orders']?.toString() ?? '') ?? 0,
      totalRevenue: _toDouble(json['total_revenue']),
    );
  }

  final int openOrders;
  final int completedOrders;
  final int cancelledOrders;
  final double totalRevenue;
}

class ApiTokenDraft {
  const ApiTokenDraft({
    required this.paymentMode,
    required this.items,
    this.customerName,
    this.customerPhone,
    this.tokenNumber,
    this.billNumber,
    this.orderType,
  });

  factory ApiTokenDraft.fromJson(Map<String, dynamic> json) {
    return ApiTokenDraft(
      paymentMode: json['payment_mode']?.toString() ?? 'cash',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ApiTokenItemDraft.fromJson(e))
              .toList() ??
          [],
      customerName: json['customer_name']?.toString(),
      customerPhone: json['customer_phone']?.toString(),
      tokenNumber: json['token_number']?.toString(),
      billNumber: json['bill_number']?.toString(),
      orderType: json['order_type']?.toString(),
    );
  }

  final String paymentMode;
  final List<ApiTokenItemDraft> items;
  final String? customerName;
  final String? customerPhone;
  final String? tokenNumber;
  final String? billNumber;
  final String? orderType;

  Map<String, dynamic> toJson() {
    return {
      'payment_mode': paymentMode.toLowerCase(),
      'items': items.map((item) => item.toJson()).toList(),
      if (orderType != null && orderType!.isNotEmpty) 'order_type': orderType,
      if (customerName != null && customerName!.isNotEmpty)
        'customer_name': customerName,
      if (customerPhone != null && customerPhone!.isNotEmpty)
        'customer_phone': customerPhone,
      if (tokenNumber != null && tokenNumber!.isNotEmpty)
        'token_number':
            int.tryParse(tokenNumber!.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
      if (billNumber != null && billNumber!.isNotEmpty)
        'bill_number': billNumber,
    };
  }
}

class ApiTokenItemDraft {
  const ApiTokenItemDraft({
    required this.name,
    required this.code,
    required this.rate,
    required this.quantity,
    this.id,
  });

  factory ApiTokenItemDraft.fromJson(Map<String, dynamic> json) {
    return ApiTokenItemDraft(
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      id: json['menu_item']?.toString(),
    );
  }

  final String? id;
  final String name;
  final String code;
  final double rate;
  final int quantity;

  Map<String, dynamic> toJson() {
    return {
      'menu_item': id,
      'quantity': quantity,
      // Internal fields for offline reconstruction
      'name': name,
      'code': code,
      'rate': rate,
    };
  }
}

class ApiShopDraft {
  const ApiShopDraft({
    required this.name,
    required this.tagline,
    this.phone,
    this.alternatePhone,
    this.address,
    this.email,
    this.gstin,
    this.upiId,
    this.logoUrl,
    this.qrUrl,
    this.paymentModesConfig,
    this.billSettings,
  });

  final String name;
  final String tagline;
  final String? phone;
  final String? alternatePhone;
  final String? address;
  final String? email;
  final String? gstin;
  final String? upiId;
  final String? logoUrl;
  final String? qrUrl;
  final String? paymentModesConfig;
  final Map<String, dynamic>? billSettings;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'tagline': tagline,
      'paymentModesConfig': paymentModesConfig,
    };

    if (phone != null) {
      map['phone'] = phone;
    } else {
      map['phone'] = '';
    }

    if (alternatePhone != null) {
      map['alternatePhone'] = alternatePhone;
    } else {
      map['alternatePhone'] = '';
    }

    if (address != null) {
      map['address'] = address;
    } else {
      map['address'] = '';
    }

    if (email != null) {
      map['email'] = email;
    } else {
      map['email'] = '';
    }

    if (gstin != null) {
      map['gstin'] = gstin;
    } else {
      map['gstin'] = '';
    }

    if (upiId != null) {
      map['upiId'] = upiId;
    } else {
      map['upiId'] = '';
    }

    if (billSettings != null) map['billSettings'] = billSettings;

    if (logoUrl != null) map['logoUrl'] = logoUrl;
    if (qrUrl != null) map['qrUrl'] = qrUrl;
    return map;
  }
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

class ApiBillTemplate {
  const ApiBillTemplate({
    required this.id,
    this.logoUrl,
    this.shopName,
    this.tagline,
    this.mobileNumber,
    this.email,
    this.address,
    this.gstNumber,
    this.qrCodeUrl,
    this.showInvoiceNumber = true,
    this.showDateTime = true,
    this.showCustomerDetails = true,
    this.showDiscount = true,
    this.showTax = true,
    this.showItemName = true,
    this.showQuantity = true,
    this.showUnitPrice = true,
    this.showTotalPrice = true,
    this.showSubtotal = true,
    this.showRoundOff = true,
    this.showGrandTotal = true,
    this.showPaymentMethod = true,
    this.showUpiId = true,
    this.footerMessage = "Thank you for visiting!",
    this.termsAndConditions = "",
    this.themeColor = "#000000",
    this.templateDesign = "standard",
  });

  factory ApiBillTemplate.fromJson(Map<String, dynamic> json) {
    return ApiBillTemplate(
      id: json['id']?.toString() ?? '',
      logoUrl: json['logoUrl']?.toString(),
      shopName: json['shop_name']?.toString(),
      tagline: json['tagline']?.toString(),
      mobileNumber: json['mobile_number']?.toString(),
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      gstNumber: json['gst_number']?.toString(),
      qrCodeUrl: json['qrCodeUrl']?.toString(),
      showInvoiceNumber: json['show_invoice_number'] ?? true,
      showDateTime: json['show_date_time'] ?? true,
      showCustomerDetails: json['show_customer_details'] ?? true,
      showDiscount: json['show_discount'] ?? true,
      showTax: json['show_tax'] ?? true,
      showItemName: json['show_item_name'] ?? true,
      showQuantity: json['show_quantity'] ?? true,
      showUnitPrice: json['show_unit_price'] ?? true,
      showTotalPrice: json['show_total_price'] ?? true,
      showSubtotal: json['show_subtotal'] ?? true,
      showRoundOff: json['show_round_off'] ?? true,
      showGrandTotal: json['show_grand_total'] ?? true,
      showPaymentMethod: json['show_payment_method'] ?? true,
      showUpiId: json['show_upi_id'] ?? true,
      footerMessage:
          json['footer_message']?.toString() ?? "Thank you for visiting!",
      termsAndConditions: json['terms_and_conditions']?.toString() ?? "",
      themeColor: json['theme_color']?.toString() ?? "#000000",
      templateDesign: json['template_design']?.toString() ?? "standard",
    );
  }

  final String id;
  final String? logoUrl;
  final String? shopName;
  final String? tagline;
  final String? mobileNumber;
  final String? email;
  final String? address;
  final String? gstNumber;
  final String? qrCodeUrl;
  final bool showInvoiceNumber;
  final bool showDateTime;
  final bool showCustomerDetails;
  final bool showDiscount;
  final bool showTax;
  final bool showItemName;
  final bool showQuantity;
  final bool showUnitPrice;
  final bool showTotalPrice;
  final bool showSubtotal;
  final bool showRoundOff;
  final bool showGrandTotal;
  final bool showPaymentMethod;
  final bool showUpiId;
  final String footerMessage;
  final String termsAndConditions;
  final String themeColor;
  final String templateDesign;
}

class ApiBillTemplateDraft {
  const ApiBillTemplateDraft({
    this.logoUrl,
    this.shopName,
    this.tagline,
    this.mobileNumber,
    this.email,
    this.address,
    this.gstNumber,
    this.qrCodeUrl,
    this.showInvoiceNumber = true,
    this.showDateTime = true,
    this.showCustomerDetails = true,
    this.showDiscount = true,
    this.showTax = true,
    this.showItemName = true,
    this.showQuantity = true,
    this.showUnitPrice = true,
    this.showTotalPrice = true,
    this.showSubtotal = true,
    this.showRoundOff = true,
    this.showGrandTotal = true,
    this.showPaymentMethod = true,
    this.showUpiId = true,
    this.footerMessage = "Thank you for visiting!",
    this.termsAndConditions = "",
    this.themeColor = "#000000",
    this.templateDesign = "standard",
  });

  final String? logoUrl;
  final String? shopName;
  final String? tagline;
  final String? mobileNumber;
  final String? email;
  final String? address;
  final String? gstNumber;
  final String? qrCodeUrl;
  final bool showInvoiceNumber;
  final bool showDateTime;
  final bool showCustomerDetails;
  final bool showDiscount;
  final bool showTax;
  final bool showItemName;
  final bool showQuantity;
  final bool showUnitPrice;
  final bool showTotalPrice;
  final bool showSubtotal;
  final bool showRoundOff;
  final bool showGrandTotal;
  final bool showPaymentMethod;
  final bool showUpiId;
  final String footerMessage;
  final String termsAndConditions;
  final String themeColor;
  final String templateDesign;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'shop_name': shopName ?? '',
      'tagline': tagline ?? '',
      'mobile_number': mobileNumber ?? '',
      'email': email ?? '',
      'address': address ?? '',
      'gst_number': gstNumber ?? '',
      'show_invoice_number': showInvoiceNumber,
      'show_date_time': showDateTime,
      'show_customer_details': showCustomerDetails,
      'show_discount': showDiscount,
      'show_tax': showTax,
      'show_item_name': showItemName,
      'show_quantity': showQuantity,
      'show_unit_price': showUnitPrice,
      'show_total_price': showTotalPrice,
      'show_subtotal': showSubtotal,
      'show_round_off': showRoundOff,
      'show_grand_total': showGrandTotal,
      'show_payment_method': showPaymentMethod,
      'show_upi_id': showUpiId,
      'footer_message': footerMessage,
      'terms_and_conditions': termsAndConditions,
      'theme_color': themeColor,
      'template_design': templateDesign,
    };
    return map;
  }
}
