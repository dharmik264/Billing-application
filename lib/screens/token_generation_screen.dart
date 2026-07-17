import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/restaurant_api.dart';
import '../utils/bill_counter.dart';
import '../utils/local_storage_helper.dart';

import 'print_preview_screen.dart';
import 'main_screen.dart';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';

import 'edit_item_screen.dart';
import '../services/native_sms_service.dart';
import '../utils/bill_settings_helper.dart';
import '../services/printer_service.dart';
import '../services/pdf_receipt_service.dart';
import 'success_screen.dart';

class _TokenProduct {
  final ApiItem rawItem;
  final String id;
  final String name;
  final String code;
  final double price;
  final String category;
  final Color accent;
  Uint8List? localImageBytes;

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
  final ApiToken? editToken;
  const TokenGenerationScreen({super.key, this.editToken});

  @override
  State<TokenGenerationScreen> createState() => _TokenGenerationScreenState();
}

class _TokenGenerationScreenState extends State<TokenGenerationScreen> {
  static const Color _panelBackground = Color(0xFFF5F6FA);

  static const Color _softBorder = Color(0xFFE2E8F0);

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
    _cartTrigger.addListener(_onCartChanged);
  }

  void _onCartChanged() {
    int totalItems = _billItems.fold(0, (sum, item) => sum + item.quantity);
    MainScreen.hideNavbar.value = totalItems > 0;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _receivedAmountController.dispose();
    _cartTrigger
      ..removeListener(_onCartChanged)
      ..dispose();
    MainScreen.hideNavbar.value = false;
    super.dispose();
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
          
          if (widget.editToken != null) {
            _customerNameController.text = widget.editToken!.customerName;
            _customerPhoneController.text = widget.editToken!.customerPhone;
            _paymentMode = widget.editToken!.paymentMode.toUpperCase();
            if (_paymentMode.isEmpty) _paymentMode = 'CASH';
            
            _billItems.clear();
            for (var item in widget.editToken!.items) {
              final prod = products.firstWhere((p) => p.code == item.code, orElse: () => _TokenProduct(
                rawItem: ApiItem(id: '', name: item.name, code: item.code, category: 'Imported', rate: item.rate, active: true, availableOnline: true),
                id: '', name: item.name, code: item.code, price: item.rate, category: 'Imported', accent: const Color(0xFF3B82F6)
              ));
              _billItems.add(_CartItem(product: prod)..quantity = item.quantity);
            }
            _cartTrigger.value++;
          }
          
          _isLoading = false;
        });

        if (products.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No items found. Please add an item first.'))
            );
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const EditItemScreen(initialCode: 'C-9001'),
              ),
            );
            _loadInitialData();
          });
        }
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
  
  double get _taxAmount {
    final billSettings = RestaurantApi.instance.shopData?.billSettings ?? {};
    final taxPercentValue = billSettings['tax_percent'] ?? 0.0;
    double taxPercent = 0.0;
    if (taxPercentValue is num) {
      taxPercent = taxPercentValue.toDouble();
    } else if (taxPercentValue is String) {
      taxPercent = double.tryParse(taxPercentValue) ?? 0.0;
    }
    return (_subtotal * taxPercent) / 100.0;
  }

  double get _grandTotal => _subtotal + _taxAmount;

  void _addProduct(_TokenProduct product) {
    setState(() {
      final existing = _billItems.indexWhere((i) => i.product.id == product.id);
      if (existing >= 0) {
        _billItems[existing].quantity++;
      } else {
        _billItems.add(_CartItem(product: product));
      }
    });
    _cartTrigger.value++;
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      _billItems[index].quantity += delta;
      if (_billItems[index].quantity <= 0) {
        _billItems.removeAt(index);
      }
    });
    _cartTrigger.value++;
  }

  void _clearCart() {
    setState(() {
      _billItems.clear();
      _customerNameController.clear();
      _customerPhoneController.clear();
      _receivedAmountController.clear();
      _paymentMode = 'CASH';
    });
    _cartTrigger.value++;
    
    // Automatically redirect back to the Token Generation page (item grid)
    if (MediaQuery.of(context).size.width < 800) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _saveBill() async {
    if (_billItems.isEmpty) return;
    if (_grandTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save a bill with amount 0')),
      );
      return;
    }

    final name = _customerNameController.text.trim();
    final phone = _customerPhoneController.text.trim();

    if (phone.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final isEdit = widget.editToken != null;
      final billNum = isEdit ? widget.editToken!.billNumber : await BillCounter.nextBillNumber();
      final tokenNum = isEdit ? widget.editToken!.tokenNumber : await BillCounter.nextTokenNumber();

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
          id: c.product.id,
        )).toList(),
      );

      if (isEdit) {
        await RestaurantApi.instance.updateToken(widget.editToken!.id, apiToken);
      } else {
        await RestaurantApi.instance.createToken(apiToken);
      }
      
      final sendSmsEnabled = await BillSettingsHelper.getSendSms();
      final billPrintEnabled = await BillSettingsHelper.getBillPrint();
      final printPreviewEnabled = await BillSettingsHelper.getPrintPreview();
      final billFormat = await BillSettingsHelper.getBillFormat();
      final pickupSlipEnabled = await BillSettingsHelper.getPickupSlip();

      if (sendSmsEnabled && phone.isNotEmpty && RegExp(r'^\d{10}$').hasMatch(phone)) {
        final status = await Permission.sms.request();
        if (status.isGranted) {
          final shopName = RestaurantApi.instance.shopData?.name ?? "our shop";
          final message = 'Dear Customer,\n\nYour bill amount is \u20B9${_grandTotal.toStringAsFixed(2)}.\n\nThank you for shopping with us.\n\n- $shopName';
          await NativeSmsService.sendSms(phone: '+91$phone', message: message);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMS permission denied. Bill saved without SMS.')));
          }
        }
      }

      // Automatically save customer if name and phone are provided
      if (name.isNotEmpty && phone.isNotEmpty) {
        try {
          await RestaurantApi.instance.createCustomer(ApiCustomerDraft(
            name: name,
            mobileNumber: phone,
            address: '',
            gstNumber: '',
            status: 'active',
          ));
        } catch (_) {
          // Ignore error if customer already exists or validation fails
        }
      }

      if (mounted) {
        final currentSubtotal = _subtotal;
        final currentTax = _taxAmount;
        final currentGrandTotal = _grandTotal;
        _clearCart();

        if (billPrintEnabled) {
          try {
            final shop = await RestaurantApi.instance.fetchShop();
            final template = await RestaurantApi.instance.fetchBillTemplate();
            
            final savedToken = ApiToken(
              id: '',
              tokenNumber: tokenNum,
              billNumber: billNum,
              status: 'PENDING',
              customerName: name,
              customerPhone: phone,
              grandTotal: currentGrandTotal,
              paymentMode: _paymentMode,
              createdAt: DateTime.now().toIso8601String(),
              items: apiToken.items.map((i) => ApiTokenItem(
                  id: i.id ?? '',
                  name: i.name,
                  code: i.code,
                  rate: i.rate,
                  quantity: i.quantity,
                  subtotal: i.rate * i.quantity))
              .toList(),
              orderType: 'dine_in',
            );
            
            if (billFormat == 'Bill A4') {
              await PdfReceiptService.printReceipt(savedToken);
            } else {
              await PrinterService.instance.printReceipt(savedToken, shop, template).timeout(const Duration(seconds: 5));
              if (pickupSlipEnabled) {
                await PrinterService.instance.printKitchenSlip(savedToken).timeout(const Duration(seconds: 5));
              }
            }
          } catch (e) {
            debugPrint('Direct Print Error: $e');
          }
        }

        if (!mounted) return;

        if (printPreviewEnabled) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PrintPreviewScreen(
              tokenNumber: tokenNum,
              billNumber: billNum,
              customerName: name.isNotEmpty ? name : null,
              customerPhone: phone.isNotEmpty ? phone : null,
              paymentMode: _paymentMode,
              items: apiToken.items,
              subtotal: currentSubtotal,
              tax: currentTax,
              grandTotal: currentGrandTotal,
            ),
          ));
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => SuccessScreen(isPrinted: billPrintEnabled)),
          );
        }
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
        title: Text('Token Generation', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: 20)),
        backgroundColor: const Color(0xFFEEF2FF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          LayoutBuilder(
            builder: (context, constraints) {
              // On small screens, show the cart action
              if (MediaQuery.of(context).size.width < 800) {
                return ValueListenableBuilder<int>(
                  valueListenable: _cartTrigger,
                  builder: (context, _, __) {
                    int totalItems = _billItems.fold(0, (sum, item) => sum + item.quantity);
                    if (totalItems == 0) return const SizedBox.shrink();
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.shopping_cart_outlined),
                          onPressed: _openCartPage,
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                            child: Text('$totalItems', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettingsPanel,
          ),
          const SizedBox(width: 8),
        ],
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
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800) return const SizedBox.shrink();
          return ValueListenableBuilder<int>(
            valueListenable: _cartTrigger,
            builder: (context, _, __) {
              int totalItems = _billItems.fold(0, (sum, item) => sum + item.quantity);
              if (totalItems == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 72.0),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF6366F1)]),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      )
                    ]
                  ),
                  child: FloatingActionButton.extended(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    hoverElevation: 0,
                    focusElevation: 0,
                    highlightElevation: 0,
                    onPressed: _openCartPage,
                    icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
                    label: Text(
                      'View Bill ($totalItems)', 
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildProductsSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          decoration: const BoxDecoration(
            color: Color(0xFFEEF2FF),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      hintStyle: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w400),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: _searchController.clear,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                    ),
                  ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.1),
        ),
        Container(
          height: 60,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (var i = 0; i < _categories.length; i++) ...[
                  _categoryChip(_categories[i]),
                  if (i != _categories.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
              : GridView.builder(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 140),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.80,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
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
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4F46E5) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Text(
          category,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 90,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [product.accent.withValues(alpha: 0.15), product.accent.withValues(alpha: 0.05)],
              ),
            ),
            child: product.localImageBytes != null
                ? Image.memory(
                    product.localImageBytes!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  )
                : FutureBuilder<Uint8List?>(
                    future: LocalImageStorage.loadImageBytes('item_image_${product.code}.png'),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              product.localImageBytes = snapshot.data;
                            });
                          }
                        });
                        return Image.memory(
                          snapshot.data!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        );
                      }
                      return Icon(Icons.restaurant_menu_rounded, size: 36, color: product.accent.withValues(alpha: 0.6));
                    },
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.code,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: product.accent, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '\u20B9${product.price.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                      ),
                      GestureDetector(
                        onTap: () => _addProduct(product),
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
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


  void _openCartPage() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text('Current Bill', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: 20)),
          backgroundColor: const Color(0xFFF8FAFC),
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        ),
        backgroundColor: const Color(0xFFF8FAFC),
        body: ValueListenableBuilder<int>(
          valueListenable: _cartTrigger,
          builder: (context, _, __) {
            return _buildCartSection(isTablet: true);
          },
        ),
      ),
    ));
  }


  Widget _buildCartSection({required bool isTablet}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        boxShadow: isTablet ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Customer Details', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                    if (_billItems.isNotEmpty)
                      GestureDetector(
                        onTap: _clearCart,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text('Clear Cart', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444))),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),                RawAutocomplete<ApiCustomer>(
                  textEditingController: _customerNameController,
                  focusNode: FocusNode(),
                  displayStringForOption: (option) => option.name,
                  optionsBuilder: (TextEditingValue textEditingValue) async {
                    if (textEditingValue.text.length < 2) {
                      return const Iterable<ApiCustomer>.empty();
                    }
                    try {
                      return await RestaurantApi.instance.searchCustomers(textEditingValue.text);
                    } catch (_) {
                      return const Iterable<ApiCustomer>.empty();
                    }
                  },
                  onSelected: (option) {
                    _customerPhoneController.text = option.mobileNumber;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Customer Name (Optional)',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                        ),
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: MediaQuery.of(context).size.width - 40,
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                title: Text(option.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                subtitle: Text(option.mobileNumber, style: GoogleFonts.inter(color: Colors.grey)),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customerPhoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Customer Mobile (Optional)',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.phone_android_rounded, size: 18, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                    ),
                  ),
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
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shopping_bag_outlined, size: 64, color: Color(0xFF4F46E5)),
                          ),
                          const SizedBox(height: 20),
                          Text('Your cart is empty', style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text('Add items from the menu to start billing', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 14)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: _billItems.length,
                      itemBuilder: (context, index) {
                        final item = _billItems[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.product.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF0F172A))),
                                    const SizedBox(height: 4),
                                    Text('\u20B9${item.product.price.toStringAsFixed(2)}', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _updateQuantity(index, -1),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.remove_rounded, size: 18, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                  Container(
                                    width: 32,
                                    alignment: Alignment.center,
                                    child: Text('${item.quantity}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF0F172A))),
                                  ),
                                  GestureDetector(
                                    onTap: () => _updateQuantity(index, 1),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF4F46E5)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  '\u20B9${item.total.toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF0F172A)),
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
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -10),
                )
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w500)),
                    Text('\u20B9${_subtotal.toStringAsFixed(2)}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A), fontSize: 15)),
                  ],
                ),
                if (_taxAmount > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tax', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w500)),
                      Text('\u20B9${_taxAmount.toStringAsFixed(2)}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A), fontSize: 15)),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Container(height: 1, color: const Color(0xFFF1F5F9)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Grand Total', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: const Color(0xFF0F172A))),
                    Text('\u20B9${_grandTotal.toStringAsFixed(2)}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 24, color: const Color(0xFF4F46E5))),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _billItems.isEmpty || _isSaving ? null : () {
                          setState(() => _paymentMode = 'CASH');
                          _cartTrigger.value++;
                          _saveBill();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _paymentMode == 'CASH' ? const Color(0xFF10B981) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: _paymentMode == 'CASH' ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                            boxShadow: _paymentMode == 'CASH' ? [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
                          ),
                          alignment: Alignment.center,
                          child: _isSaving && _paymentMode == 'CASH'
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('CASH', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: _paymentMode == 'CASH' ? Colors.white : const Color(0xFF64748B))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _billItems.isEmpty || _isSaving ? null : () {
                          setState(() => _paymentMode = 'ONLINE');
                          _cartTrigger.value++;
                          _saveBill();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _paymentMode == 'ONLINE' ? const Color(0xFF4F46E5) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: _paymentMode == 'ONLINE' ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0)),
                            boxShadow: _paymentMode == 'ONLINE' ? [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
                          ),
                          alignment: Alignment.center,
                          child: _isSaving && _paymentMode == 'ONLINE'
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('ONLINE', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: _paymentMode == 'ONLINE' ? Colors.white : const Color(0xFF64748B))),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsPanel() async {
    bool sendSms = await BillSettingsHelper.getSendSms();
    bool printPreview = await BillSettingsHelper.getPrintPreview();
    bool billPrint = await BillSettingsHelper.getBillPrint();
    String billFormat = await BillSettingsHelper.getBillFormat();
    bool pickupSlip = await BillSettingsHelper.getPickupSlip();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text('Bill Settings', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text('Send SMS', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text('Send bill SMS automatically after bill generation', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        value: sendSms,
                        activeThumbColor: const Color(0xFF4F46E5),
                        onChanged: (val) {
                          setModalState(() => sendSms = val);
                          BillSettingsHelper.setSendSms(val);
                        },
                      ),
                      SwitchListTile(
                        title: Text('Print Preview', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text('Show print preview before printing', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        value: printPreview,
                        activeThumbColor: const Color(0xFF4F46E5),
                        onChanged: (val) {
                          setModalState(() => printPreview = val);
                          BillSettingsHelper.setPrintPreview(val);
                        },
                      ),
                      SwitchListTile(
                        title: Text('Bill Print', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text('Enable bill printing', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        value: billPrint,
                        activeThumbColor: const Color(0xFF4F46E5),
                        onChanged: (val) {
                          setModalState(() => billPrint = val);
                          BillSettingsHelper.setBillPrint(val);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: DropdownButtonFormField<String>(
                          initialValue: billFormat,
                          decoration: InputDecoration(
                            labelText: 'Bill Format',
                            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          items: ['Bill Slip', 'Bill A4'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: GoogleFonts.inter()),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => billFormat = val);
                              BillSettingsHelper.setBillFormat(val);
                            }
                          },
                        ),
                      ),
                      SwitchListTile(
                        title: Text('Pickup Slip', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text('Generate and print pickup slip', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        value: pickupSlip,
                        activeThumbColor: const Color(0xFF4F46E5),
                        onChanged: (val) {
                          setModalState(() => pickupSlip = val);
                          BillSettingsHelper.setPickupSlip(val);
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text('Done', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
