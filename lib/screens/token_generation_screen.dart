import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/restaurant_api.dart';
import '../utils/bill_counter.dart';
import '../utils/local_storage_helper.dart';

import 'print_preview_screen.dart';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';

import 'edit_item_screen.dart';
import '../services/native_sms_service.dart';
import '../utils/bill_settings_helper.dart';
import '../services/printer_service.dart';
import 'success_screen.dart';
import '../widgets/custom_page_header.dart';
import '../utils/app_constants.dart';

class _TokenProduct {
  final ApiItem rawItem;
  final String id;
  final String name;
  final String code;
  final double price;
  final String category;
  final Color accent;
  Uint8List? localImageBytes;
  final String? imageUrl;

  _TokenProduct({
    required this.rawItem,
    required this.id,
    required this.name,
    required this.code,
    required this.price,
    required this.category,
    required this.accent,
    this.imageUrl,
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
  final TextEditingController _customerAddressController = TextEditingController();
  final TextEditingController _customerGstController = TextEditingController();
  final TextEditingController _receivedAmountController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  final ValueNotifier<int> _cartTrigger = ValueNotifier<int>(0);
  String _selectedCategory = 'All';
  String _paymentMode = 'CASH';
  // Holds the partial amount received for an UDHAR bill; survives _clearCart().
  double _udharReceivedAmount = 0.0;

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
    // Navbar visibility is no longer changed when adding items
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _customerGstController.dispose();
    _receivedAmountController.dispose();
    _cartTrigger
      ..removeListener(_onCartChanged)
      ..dispose();
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
        if (!item.active) continue;
        if (item.category.isNotEmpty) categorySet.add(item.category);
        products.add(_TokenProduct(
          rawItem: item,
          id: item.id ?? '',
          name: item.name,
          code: item.code,
          price: item.rate,
          category: item.category,
          accent: colors[colorIndex % colors.length],
          imageUrl: item.imageUrl,
        ));
        colorIndex++;
      }

      for (var prod in products) {
        final bytes = await LocalImageStorage.loadItemImageBytes(
          id: prod.id,
          code: prod.code,
          name: prod.name,
        );
        if (bytes != null) {
          prod.localImageBytes = bytes;
        }
      }

      if (mounted) {
        setState(() {
          _allProducts = products;
          _categories = ['All', ...categorySet.toList()..sort()];
          
          if (widget.editToken != null) {
            _customerNameController.text = widget.editToken!.customerName;
            _customerPhoneController.text = widget.editToken!.customerPhone;
            _customerAddressController.text = widget.editToken!.customerAddress;
            _customerGstController.text = widget.editToken!.customerGstNumber;
            _paymentMode = widget.editToken!.paymentMode.toUpperCase();
            if (_paymentMode.isEmpty) _paymentMode = 'CASH';
            
            _billItems.clear();
            for (var item in widget.editToken!.items) {
              final prod = products.firstWhere((p) => (item.code.isNotEmpty && p.code == item.code) || p.name == item.name, orElse: () => _TokenProduct(
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
      _udharReceivedAmount = 0.0;
      _paymentMode = 'CASH';
    });
    _cartTrigger.value++;
  }

  Future<void> _onUdharClicked() async {
    if (_billItems.isEmpty || _isSaving) return;
    if (_grandTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save a bill with amount 0')),
      );
      return;
    }

    // Check 1: Ensure customer name and phone are filled
    String name = _customerNameController.text.trim();
    String phone = _customerPhoneController.text.trim();

    if (name.isEmpty && phone.isEmpty) {
      final filled = await _promptCustomerInfoForUdhar();
      if (!filled) return;
      name = _customerNameController.text.trim();
      phone = _customerPhoneController.text.trim();
    }

    if (!mounted) return;

    // Check 2: Prompt for today's received payment amount
    final result = await _promptPartialPaymentForUdhar();
    if (result == null) return; // Cancelled

    final double receivedAmount = result['amount'] ?? 0.0;

    // Capture into a state field so _saveBill() can use it
    // even after _clearCart() discards _receivedAmountController.
    setState(() {
      _udharReceivedAmount = receivedAmount;
      _paymentMode = 'CREDIT';
      if (receivedAmount > 0) {
        _receivedAmountController.text = receivedAmount.toStringAsFixed(2);
      } else {
        _receivedAmountController.clear();
      }
    });

    _cartTrigger.value++;
    await _saveBill();
  }

  Future<bool> _promptCustomerInfoForUdhar() async {
    final nameCtrl = TextEditingController(text: _customerNameController.text);
    final phoneCtrl = TextEditingController(text: _customerPhoneController.text);
    // Local variables to hold address/GST selected from autocomplete.
    // These are only copied to screen controllers when Proceed succeeds,
    // so Cancel leaves the screen values unchanged.
    String dialogAddress = _customerAddressController.text;
    String dialogGst = _customerGstController.text;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_circle_outlined, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer Details Required', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('ઉધાર બિલ માટે કસ્ટમર નામ/ફોન જરૂરી છે', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RawAutocomplete<ApiCustomer>(
                  textEditingController: nameCtrl,
                  focusNode: FocusNode(),
                  displayStringForOption: (option) => option.name,
                  optionsBuilder: (textEditingValue) async {
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
                    nameCtrl.text = option.name;
                    phoneCtrl.text = option.mobileNumber;
                    // Keep address/GST local to the dialog; do NOT write to
                    // screen controllers here — Cancel must leave them unchanged.
                    dialogAddress = option.address;
                    dialogGst = option.gstNumber;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Customer Name *',
                        hintText: 'e.g. Raju Patel',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 280,
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                title: Text(option.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                subtitle: Text(option.mobileNumber),
                                trailing: option.netDue > 0
                                    ? Text('Due: \u20B9${option.netDue.toStringAsFixed(2)}', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12))
                                    : Text('Paid', style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600)),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number *',
                    hintText: '10-digit mobile number',
                    prefixIcon: const Icon(Icons.phone_android_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty && phoneCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter Customer Name or Mobile Number')),
                  );
                  return;
                }
                // Proceed: now safe to commit all values to screen controllers.
                _customerNameController.text = nameCtrl.text.trim();
                _customerPhoneController.text = phoneCtrl.text.trim();
                _customerAddressController.text = dialogAddress;
                _customerGstController.text = dialogGst;
                Navigator.pop(context, true);
              },
              child: Text('Proceed', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<Map<String, dynamic>?> _promptPartialPaymentForUdhar() async {
    final amtCtrl = TextEditingController();

    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Udhar Billing (ઉધાર બિલ)', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Total: \u20B9${_grandTotal.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFD97706))),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Today how much money paid? (હાલે કેટલી રકમ જમા કરી?)', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amtCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Received Amount / જમા રકમ (Optional)',
                  hintText: 'Leave empty for 100% Udhar',
                  prefixText: '\u20B9 ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD97706), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text('If empty or 0, total amount (\u20B9${_grandTotal.toStringAsFixed(2)}) will be recorded as 100% Udhar in customer ledger.', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD97706)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context, {'amount': 0.0, 'mode': 'CASH'});
              },
              child: Text('Full Udhar (\u20B90 Paid)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFFD97706))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final input = amtCtrl.text.trim();
                // Blank input is treated as ₹0 (full udhar).
                if (input.isEmpty) {
                  Navigator.pop(context, {'amount': 0.0, 'mode': 'CASH'});
                  return;
                }
                final double? parsed = double.tryParse(input);
                if (parsed == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid numeric amount')),
                  );
                  return;
                }
                if (parsed < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Amount cannot be negative')),
                  );
                  return;
                }
                if (parsed > _grandTotal) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Amount cannot exceed total ₹${_grandTotal.toStringAsFixed(2)}')),
                  );
                  return;
                }
                Navigator.pop(context, {'amount': parsed, 'mode': 'CASH'});
              },
              child: Text('Save Bill', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
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

      // Snapshot received amount before _clearCart() can discard it.
      final double snapshotReceived = _udharReceivedAmount;

      final apiToken = ApiTokenDraft(
        billNumber: billNum,
        tokenNumber: tokenNum,
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        customerAddress: _customerAddressController.text.trim(),
        customerGstNumber: _customerGstController.text.trim(),
        paymentMode: _paymentMode.toLowerCase(),
        receivedAmount: (_paymentMode == 'CREDIT' && snapshotReceived > 0)
            ? snapshotReceived
            : null,
        items: _billItems.map((c) => ApiTokenItemDraft(
          name: c.product.name,
          code: c.product.code,
          quantity: c.quantity,
          rate: c.product.price,
          id: c.product.id,
        )).toList(),
      );

      ApiToken? savedApiToken;
      CreateTokenResult? tokenResult;
      if (isEdit) {
        savedApiToken = await RestaurantApi.instance.updateToken(widget.editToken!.id, apiToken);
      } else {
        tokenResult = await RestaurantApi.instance.createTokenDetailed(apiToken);
        savedApiToken = tokenResult.token;
      }

      if (mounted && tokenResult != null) {
        if (tokenResult.isOnlineSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Bill #${savedApiToken.billNumber} saved in Database (tokens_token)'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Online DB Save Failed: ${tokenResult.errorMessage ?? "Offline"}. Saved in Local Cache.'),
              backgroundColor: const Color(0xFFF59E0B),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }

      // Use the backend-generated numbers for printing
      final finalTokenNum = savedApiToken.tokenNumber;
      final finalBillNum = savedApiToken.billNumber;
      
      final sendSmsEnabled = await BillSettingsHelper.getSendSms();
      final billPrintEnabled = await BillSettingsHelper.getBillPrint();
      final printPreviewEnabled = await BillSettingsHelper.getPrintPreview();
      final billFormat = await BillSettingsHelper.getBillFormat();
      final pickupSlipEnabled = await BillSettingsHelper.getPickupSlip();

      if (sendSmsEnabled && phone.isNotEmpty && RegExp(r'^\d{10}$').hasMatch(phone)) {
        try {
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
        } catch (e) {
          debugPrint('SMS Sending Exception: $e');
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
              tokenNumber: finalTokenNum,
              billNumber: finalBillNum,
              status: 'PENDING',
              customerName: name,
              customerPhone: phone,
              subtotal: currentSubtotal,
              tax: currentTax,
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
              // The user specifically requested not to automatically show the A4/PDF print dialog upon Save
              // So we do nothing here for A4. The user can manually print from Print Preview if needed.
            } else {
              await PrinterService.instance.printReceipt(savedToken, shop, template);
              if (pickupSlipEnabled) {
                await PrinterService.instance.printKitchenSlip(savedToken);
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
              tokenNumber: finalTokenNum,
              billNumber: finalBillNum,
              customerName: name.isNotEmpty ? name : null,
              customerPhone: phone.isNotEmpty ? phone : null,
              customerAddress: _customerAddressController.text.trim().isNotEmpty ? _customerAddressController.text.trim() : null,
              customerGstNumber: _customerGstController.text.trim().isNotEmpty ? _customerGstController.text.trim() : null,
              paymentMode: _paymentMode,
              items: apiToken.items,
              subtotal: currentSubtotal,
              tax: currentTax,
              grandTotal: currentGrandTotal,
            ),
          )).then((_) {
            if (isEdit && mounted) {
              Navigator.of(context).pop(true);
            }
          });
        } else {
          if (isEdit) {
            Navigator.of(context).pop(true);
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => SuccessScreen(isPrinted: billPrintEnabled)),
            );
          }
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
      backgroundColor: StitchColors.background,
      appBar: CustomAppBar(
        title: widget.editToken != null ? 'Edit Bill #${widget.editToken!.billNumber}' : 'Token Generation',
        icon: Icons.confirmation_number_rounded,
        subtitle: 'Dhara Food POS',
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F5),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE4E4E7)),
            ),
            child: Text(
              'Terminal 01',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF3F3F46),
              ),
            ),
          ),
          const SizedBox(width: 4),
          LayoutBuilder(
            builder: (context, constraints) {
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
                          icon: const Icon(Icons.shopping_cart_outlined, color: StitchColors.textPrimary),
                          onPressed: _openCartPage,
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: StitchColors.primary,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              '$totalItems',
                              style: StitchTypography.caption(color: Colors.white, size: 10).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
            icon: const Icon(Icons.settings_outlined, color: StitchColors.textSecondary),
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
                Container(width: 1, color: StitchColors.border),
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
                child: SizedBox(
                  height: 44,
                  child: FloatingActionButton.extended(
                    backgroundColor: const Color(0xFF111111),
                    elevation: 0,
                    hoverElevation: 0,
                    onPressed: _openCartPage,
                    icon: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                    label: Text(
                      'View Bill ($totalItems)', 
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
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
        ValueListenableBuilder<int>(
          valueListenable: _cartTrigger,
          builder: (context, _, __) {
            final itemCount = _billItems.fold(0, (sum, item) => sum + item.quantity);
            final tokenNo = widget.editToken != null ? '#${widget.editToken!.tokenNumber}' : '#NEW';
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Token No',
                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF666666)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tokenNo,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111111),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E5E5)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected',
                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF666666)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$itemCount items',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111111),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E5E5)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bill Total',
                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF666666)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\u20B9${_grandTotal.toStringAsFixed(2)}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111111),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        CustomSearchActionView(
          searchHint: 'Search products by name or code...',
          searchController: _searchController,
          onSearchClear: _searchController.clear,
          filterChips: _categories.map((cat) => FilterChipData(
            label: cat,
            value: cat,
            icon: cat == 'All' ? Icons.apps_rounded : Icons.label_outline_rounded,
          )).toList(),
          selectedFilterValue: _selectedCategory,
          onFilterChanged: (val) => setState(() => _selectedCategory = val),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: StitchColors.primary))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    childAspectRatio: 1.25,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) => _productCard(_filteredProducts[index]),
                ),
        ),
      ],
    );
  }

  Widget _productCard(_TokenProduct product) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: StitchDecorations.card(),
      child: InkWell(
        onTap: () => _addProduct(product),
        child: Column(
          children: [
            Container(
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: StitchColors.surfaceSubtle,
                border: Border(bottom: BorderSide(color: StitchColors.border, width: 1.0)),
              ),
              child: _buildCardImage(product),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (product.code.isNotEmpty) ...[
                          Text(
                            product.code,
                            style: StitchTypography.caption(color: StitchColors.primary).copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 1),
                        ],
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: StitchTypography.body(weight: FontWeight.w600, size: 12),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '\u20B9${product.price.toStringAsFixed(0)}',
                          style: StitchTypography.monospace(size: 14, weight: FontWeight.w700),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: StitchColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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


  Widget _buildCardImage(_TokenProduct product) {
    if (product.localImageBytes != null) {
      return Image.memory(
        product.localImageBytes!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    }

    final imgUrl = product.imageUrl;
    if (imgUrl != null && imgUrl.startsWith('data:image')) {
      try {
        final base64Str = imgUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        );
      } catch (_) {}
    }

    return FutureBuilder<Uint8List?>(
      future: LocalImageStorage.loadItemImageBytes(
        id: product.id,
        code: product.code,
        name: product.name,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          );
        }

        if (imgUrl != null && imgUrl.isNotEmpty && (imgUrl.startsWith('http://') || imgUrl.startsWith('https://'))) {
          return Image.network(
            imgUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.restaurant_menu_rounded,
              size: 36,
              color: product.accent.withValues(alpha: 0.6),
            ),
          );
        }

        return Icon(
          Icons.restaurant_menu_rounded,
          size: 36,
          color: product.accent.withValues(alpha: 0.6),
        );
      },
    );
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Customer Details', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                    if (_billItems.isNotEmpty)
                      GestureDetector(
                        onTap: _clearCart,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text('Clear Cart', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444))),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                RawAutocomplete<ApiCustomer>(
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
                    _customerAddressController.text = option.address;
                    _customerGstController.text = option.gstNumber;
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
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
                                trailing: option.netDue > 0
                                    ? Text('Due: \u20B9${option.netDue.toStringAsFixed(2)}', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12))
                                    : Text('Paid', style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600)),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _customerPhoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Customer Mobile (Optional)',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.phone_android_rounded, size: 18, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: _billItems.length,
                      itemBuilder: (context, index) {
                        final item = _billItems[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.product.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF0F172A)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _updateQuantity(index, -1),
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.remove_rounded, size: 16, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                  Container(
                                    width: 28,
                                    alignment: Alignment.center,
                                    child: Text('${item.quantity}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF0F172A))),
                                  ),
                                  GestureDetector(
                                    onTap: () => _updateQuantity(index, 1),
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF4F46E5)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '₹${item.product.price.toStringAsFixed(2)} × ${item.quantity}',
                                    style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '₹${item.total.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF4F46E5)),
                                  ),
                                ],
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
                              : Text('CASH', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: _paymentMode == 'CASH' ? Colors.white : const Color(0xFF64748B))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
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
                              : Text('ONLINE', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: _paymentMode == 'ONLINE' ? Colors.white : const Color(0xFF64748B))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: _billItems.isEmpty || _isSaving ? null : _onUdharClicked,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _paymentMode == 'CREDIT' ? const Color(0xFFF59E0B) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: _paymentMode == 'CREDIT' ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0)),
                            boxShadow: _paymentMode == 'CREDIT' ? [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
                          ),
                          alignment: Alignment.center,
                          child: _isSaving && _paymentMode == 'CREDIT'
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('UDHAR', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: _paymentMode == 'CREDIT' ? Colors.white : const Color(0xFF64748B))),
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
