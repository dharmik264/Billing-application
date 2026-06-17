import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/restaurant_api.dart';
import '../utils/bill_counter.dart';

import 'print_preview_screen.dart';

class _TokenProduct {
  final ApiItem rawItem;
  final String id;
  final String name;
  final String code;
  final double price;
  final String category;
  final Color accent;

  _TokenProduct({
    required this.rawItem,
    required this.id,
    required this.name,
    required this.code,
    required this.price,
    required this.category,
    required this.accent,
  });
}

class _CartItem {
  final _TokenProduct product;
  int quantity = 1;
  double discount = 0.0;

  _CartItem({
    required this.product,
  });

  double get total => (product.price * quantity) - discount;
}

class TokenGenerationScreen extends StatefulWidget {
  const TokenGenerationScreen({super.key});

  @override
  State<TokenGenerationScreen> createState() => _TokenGenerationScreenState();
}

class _TokenGenerationScreenState extends State<TokenGenerationScreen> {
  static const Color _panelBackground = Color(0xFFF5F6FA);

  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _softBorder = Color(0xFFE2E8F0);
  static const Color _danger = Color(0xFFDC2626);

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _receivedAmountController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  final ValueNotifier<int> _cartTrigger = ValueNotifier<int>(0);
  String _selectedCategory = 'All';
  String _paymentMode = 'CASH';

  List<_TokenProduct> _allProducts = [];
  final List<_CartItem> _billItems = [];
  List<String> _categories = ['All'];



  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(() => setState(() {}));
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final items = await RestaurantApi.instance.fetchItems();

      final categorySet = <String>{};
      final products = <_TokenProduct>[];
      final colors = [
        const Color(0xFFF59E0B),
        const Color(0xFF10B981),
        const Color(0xFF3B82F6),
        const Color(0xFF8B5CF6),
        const Color(0xFFEC4899),
      ];
      int colorIndex = 0;

      for (var item in items) {
        if (item.category.isNotEmpty) categorySet.add(item.category);
        products.add(_TokenProduct(
          rawItem: item,
          id: item.id ?? '',
          name: item.name,
          code: item.code,
          price: item.rate,
          category: item.category,
          accent: colors[colorIndex % colors.length],
        ));
        colorIndex++;
      }

      if (mounted) {
        setState(() {
          _allProducts = products;
          _categories = ['All', ...categorySet.toList()..sort()];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load items: $e')));
      }
    }
  }

  List<_TokenProduct> get _filteredProducts {
    var list = _allProducts;
    if (_selectedCategory != 'All') {
      list = list.where((p) => p.category == _selectedCategory).toList();
    }
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(q) || p.code.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  double get _subtotal => _billItems.fold(0.0, (sum, item) => sum + item.total);
  
  double get _taxAmount => 0.0; // Tax is not calculated per token here if no tax config exists

  double get _grandTotal => _subtotal + _taxAmount;

  void _addProduct(_TokenProduct product) {
    _cartTrigger.value++;
    setState(() {
      final existing = _billItems.indexWhere((i) => i.product.id == product.id);
      if (existing >= 0) {
        _billItems[existing].quantity++;
      } else {
        _billItems.add(_CartItem(product: product));
      }
    });
  }

  void _updateQuantity(int index, int delta) {
    _cartTrigger.value++;
    setState(() {
      _billItems[index].quantity += delta;
      if (_billItems[index].quantity <= 0) {
        _billItems.removeAt(index);
      }
    });
  }

  void _clearCart() {
    _cartTrigger.value++;
    setState(() {
      _billItems.clear();
      _customerNameController.clear();
      _customerPhoneController.clear();
      _receivedAmountController.clear();
      _paymentMode = 'CASH';
    });
  }

  Future<void> _saveBill() async {
    if (_billItems.isEmpty) return;
    if (_grandTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save a bill with amount 0')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final billNum = await BillCounter.nextBillNumber();
      final tokenNum = await BillCounter.nextTokenNumber();

      final apiToken = ApiTokenDraft(
        billNumber: billNum,
        tokenNumber: tokenNum,
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        paymentMode: _paymentMode.toLowerCase(),
        items: _billItems.map((c) => ApiTokenItemDraft(
          name: c.product.name,
          code: c.product.code,
          quantity: c.quantity,
          rate: c.product.price,
        )).toList(),
      );

      await RestaurantApi.instance.createToken(apiToken);
      
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => PrintPreviewScreen(
            tokenNumber: tokenNum,
            billNumber: billNum,
            paymentMode: _paymentMode,
            items: apiToken.items,
            subtotal: _subtotal,
            tax: _taxAmount,
            grandTotal: _grandTotal,
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save bill: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _panelBackground,
      appBar: AppBar(
        title: Text('Token Generation', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _textPrimary, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textPrimary),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 800;
          if (isTablet) {
            return Row(
              children: [
                Expanded(flex: 3, child: _buildProductsSection()),
                Container(width: 1, color: _softBorder),
                Expanded(flex: 2, child: _buildCartSection(isTablet: true)),
              ],
            );
          }
          return _buildProductsSection();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 800;
          if (!isTablet && _billItems.isNotEmpty) {
            return ValueListenableBuilder<int>(
              valueListenable: _cartTrigger,
              builder: (context, _, __) {
                return _buildFloatingCart();
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildProductsSection() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // Slate 100
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 20, color: _muted),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(fontSize: 14, color: _textPrimary, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _searchController.clear,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 14, color: _textSecondary),
                    ),
                  ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.1),
        ),
        Container(
          height: 50,
          color: Colors.white,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _categories.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _categoryChip(_categories[index]),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  padding: const EdgeInsets.only(left: 14, right: 14, top: 14, bottom: 120),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) => _productCard(_filteredProducts[index]),
                ),
        ),
      ],
    );
  }

  Widget _categoryChip(String category) {
    final selected = _selectedCategory == category;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => setState(() => _selectedCategory = category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 16, vertical: 8),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          gradient: selected ? const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF6366F1)]) : null,
          color: selected ? null : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(24),
          boxShadow: selected ? [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Text(
          category,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _productCard(_TokenProduct product) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: Column(
        children: [
          Container(
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [product.accent.withValues(alpha: 0.1), product.accent.withValues(alpha: 0.02)],
              ),
            ),
            child: Icon(Icons.restaurant_menu_rounded, size: 32, color: product.accent.withValues(alpha: 0.4)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.code,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: product.accent, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\u20B9${product.price.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _textPrimary),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _addProduct(product),
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().scale(delay: 50.ms, duration: 200.ms, curve: Curves.easeOutBack);
  }


  Widget _buildFloatingCart() {
    int totalItems = _billItems.fold(0, (sum, item) => sum + item.quantity);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
      child: ElevatedButton(
        onPressed: _showCartBottomSheet,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                const SizedBox(width: 8),
                Text('$totalItems Items', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
            Row(
              children: [
                Text('₹', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ValueListenableBuilder<int>(
          valueListenable: _cartTrigger,
          builder: (context, _, __) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          height: 4,
                          width: 40,
                          decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: _buildCartSection(isTablet: false),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCartSection({required bool isTablet}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: isTablet ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _softBorder))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Current Bill', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
                InkWell(
                  onTap: _clearCart,
                  child: Text('Clear', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _danger)),
                ),
              ],
            ),
          ),
          Builder(
            builder: (context) {
              final cartContent = _billItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_cart_outlined, size: 48, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 12),
                          Text('Cart is empty', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _billItems.length,
                      itemBuilder: (context, index) {
                        final item = _billItems[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.product.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF0F172A))),
                                    const SizedBox(height: 4),
                                    Text('\u20B9${item.product.price.toStringAsFixed(2)}', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12)),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () => _updateQuantity(index, -1),
                                      child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove, size: 16, color: Color(0xFF0F172A))),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text('${item.quantity}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                                    ),
                                    InkWell(
                                      onTap: () => _updateQuantity(index, 1),
                                      child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add, size: 16, color: Color(0xFF0F172A))),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  '\u20B9${item.total.toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF0F172A)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );

              return isTablet
                  ? Expanded(child: cartContent)
                  : ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: _billItems.isEmpty ? 100 : 300),
                      child: cartContent,
                    );
            },
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 14)),
                    Text('\u20B9${_subtotal.toStringAsFixed(2)}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF0F172A), fontSize: 14)),
                  ],
                ),
                if (_taxAmount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tax', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 14)),
                      Text('\u20B9${_taxAmount.toStringAsFixed(2)}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF0F172A), fontSize: 14)),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Grand Total', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A))),
                    Text('\u20B9${_grandTotal.toStringAsFixed(2)}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, color: const Color(0xFF4F46E5))),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () { setState(() => _paymentMode = 'CASH'); _cartTrigger.value++; },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _paymentMode == 'CASH' ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _paymentMode == 'CASH' ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                          ),
                          alignment: Alignment.center,
                          child: Text('CASH', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _paymentMode == 'CASH' ? const Color(0xFF10B981) : const Color(0xFF64748B))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () { setState(() => _paymentMode = 'ONLINE'); _cartTrigger.value++; },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _paymentMode == 'ONLINE' ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _paymentMode == 'ONLINE' ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0)),
                          ),
                          alignment: Alignment.center,
                          child: Text('ONLINE', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _paymentMode == 'ONLINE' ? const Color(0xFF4F46E5) : const Color(0xFF64748B))),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _billItems.isEmpty || _isSaving ? null : _saveBill,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Save Bill', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
