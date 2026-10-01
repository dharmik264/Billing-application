import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/restaurant_api.dart';
import '../widgets/custom_page_header.dart';
import 'add_customer_screen.dart';

class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  State<CustomerManagementScreen> createState() => _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────
  List<ApiCustomer> _customers = [];
  List<ApiCustomer> _filtered  = [];
  bool   _isLoading   = true;
  String _searchQuery = '';
  String _statusFilter = ''; // '' = All, 'active', 'inactive'
  String? _error;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  final _searchCtrl = TextEditingController();

  // ── Colours ────────────────────────────────────────────────────
  static const _indigo   = Color(0xFF4F46E5);
  static const _slate50  = Color(0xFFF8FAFC);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _slate400 = Color(0xFF94A3B8);
  static const _slate600 = Color(0xFF475569);
  static const _slate700 = Color(0xFF334155);
  static const _slate900 = Color(0xFF0F172A);
  static const _green    = Color(0xFF10B981);
  static const _red      = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadCustomers();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data Loading ───────────────────────────────────────────────
  Future<void> _loadCustomers() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await RestaurantApi.instance.fetchCustomers();
      if (!mounted) return;
      setState(() {
        _customers = data;
        _applyFilters();
        _isLoading = false;
      });
      _animCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _applyFilters() {
    var list = [..._customers];
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) =>
        c.name.toLowerCase().contains(q) ||
        c.mobileNumber.contains(q) ||
        c.gstNumber.toLowerCase().contains(q) ||
        c.address.toLowerCase().contains(q),
      ).toList();
    }
    if (_statusFilter.isNotEmpty) {
      list = list.where((c) => c.status == _statusFilter).toList();
    }
    _filtered = list;
  }

  void _onSearch(String val) {
    setState(() {
      _searchQuery = val;
      _applyFilters();
    });
  }

  void _onStatusFilter(String status) {
    setState(() {
      _statusFilter = status;
      _applyFilters();
    });
  }

  // ── Navigation helpers ─────────────────────────────────────────
  Future<void> _openAdd() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
    );
    if (result == true) _loadCustomers();
  }

  Future<void> _openEdit(ApiCustomer customer) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddCustomerScreen(customer: customer)),
    );
    if (result == true) _loadCustomers();
  }

  // ── Delete ─────────────────────────────────────────────────────
  Future<void> _deleteCustomer(ApiCustomer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Customer',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _slate900)),
        content: Text(
          'Are you sure you want to delete "${customer.name}"? This action cannot be undone.',
          style: GoogleFonts.inter(fontSize: 14, color: _slate600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(color: _slate600, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await RestaurantApi.instance.deleteCustomer(customer.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Customer deleted'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        _loadCustomers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final activeCount   = _customers.where((c) => c.isActive).length;
    final inactiveCount = _customers.where((c) => !c.isActive).length;
    
    return Scaffold(
      backgroundColor: _slate50,
      appBar: CustomAppBar(
        title: 'Customer Management',
        icon: Icons.people_rounded,
        subtitle: (!_isLoading && _customers.isNotEmpty) ? '$activeCount active · $inactiveCount inactive' : null,
      ),
      body: Column(
        children: [
          CustomSearchActionView(
            searchHint: 'Search by name, mobile, GST...',
            searchController: _searchCtrl,
            onSearchChanged: _onSearch,
            onSearchClear: () {
              _searchCtrl.clear();
              _onSearch('');
            },
            filterChips: [
              FilterChipData(label: 'All', value: '', icon: Icons.people_outline_rounded),
              FilterChipData(label: 'Active', value: 'active', icon: Icons.check_circle_outline_rounded),
              FilterChipData(label: 'Inactive', value: 'inactive', icon: Icons.cancel_outlined),
            ],
            selectedFilterValue: _statusFilter,
            onFilterChanged: _onStatusFilter,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openAdd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _indigo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: Text('Add Customer', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: _slate600),
                  onPressed: _loadCustomers,
                  tooltip: 'Refresh',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: _slate200, width: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _indigo),
      );
    }
    if (_error != null) {
      return _buildErrorState();
    }
    if (_customers.isEmpty) {
      return _buildEmptyState(noCustomers: true);
    }
    if (_filtered.isEmpty) {
      return _buildEmptyState(noCustomers: false);
    }
    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
        color: _indigo,
        onRefresh: _loadCustomers,
        child: _buildCustomerList(),
      ),
    );
  }

  Widget _buildCustomerList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildCustomerCard(_filtered[i]),
    );
  }

  Widget _buildCustomerCard(ApiCustomer customer) {
    final initials = customer.name.trim().isEmpty
        ? '?'
        : customer.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openEdit(customer),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: customer.isActive
                          ? [const Color(0xFF4F46E5), const Color(0xFF6366F1)]
                          : [const Color(0xFF94A3B8), const Color(0xFFCBD5E1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        customer.name,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _infoRow(Icons.phone_outlined, customer.mobileNumber),
                      if (customer.address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _infoRow(Icons.location_on_outlined, customer.address, maxLines: 1),
                      ],
                      if (customer.gstNumber.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _infoRow(Icons.receipt_long_outlined, customer.gstNumber),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Actions Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _showJamaDialog(customer),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _green.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_balance_wallet_rounded, size: 14, color: _green),
                            const SizedBox(width: 4),
                            Text('Jama (\u20B9 જમા)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _green)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _openEdit(customer),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _indigo.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_rounded, size: 14, color: _indigo),
                            const SizedBox(width: 4),
                            Text('Edit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _indigo)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _deleteCustomer(customer),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.delete_outline_rounded, size: 14, color: _red),
                            const SizedBox(width: 4),
                            Text('Delete', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _red)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _statusToggleBadge(customer),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showJamaDialog(ApiCustomer customer) async {
    final amountCtrl = TextEditingController();
    String selectedMode = 'CASH';
    bool submitting = false;

    final result = await showDialog<dynamic>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: _green, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Jama / Payment (નાણાં જમા)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17, color: _slate900),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _slate50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _slate200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _slate900)),
                          const SizedBox(height: 2),
                          Text('Phone: ${customer.mobileNumber}', style: GoogleFonts.inter(fontSize: 12, color: _slate600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Jama Amount (\u20B9 જમા રકમ)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _slate700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        prefixText: '\u20B9 ',
                        hintText: 'Enter amount to credit...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _green, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Payment Mode (ચૂકવણી મોડ)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _slate700)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Cash'),
                            selected: selectedMode == 'CASH',
                            selectedColor: _green.withValues(alpha: 0.2),
                            onSelected: (val) {
                              if (val) setDialogState(() => selectedMode = 'CASH');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('UPI'),
                            selected: selectedMode == 'ONLINE',
                            selectedColor: _indigo.withValues(alpha: 0.2),
                            onSelected: (val) {
                              if (val) setDialogState(() => selectedMode = 'ONLINE');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Card'),
                            selected: selectedMode == 'CARD',
                            selectedColor: Colors.amber.withValues(alpha: 0.2),
                            onSelected: (val) {
                              if (val) setDialogState(() => selectedMode = 'CARD');
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(ctx, false),
                  child: Text('Cancel', style: GoogleFonts.inter(color: _slate600)),
                ),
                ElevatedButton(
                  onPressed: submitting ? null : () async {
                    final text = amountCtrl.text.trim();
                    final amt = double.tryParse(text);
                    if (amt == null || amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount greater than zero')),
                      );
                      return;
                    }
                    setDialogState(() => submitting = true);
                    try {
                      final response = await RestaurantApi.instance.recordCustomerJama(
                        customerPhone: customer.mobileNumber,
                        amount: amt,
                        paymentMode: selectedMode,
                        customerName: customer.name,
                      );
                      if (context.mounted) Navigator.pop(ctx, response);
                    } catch (e) {
                      setDialogState(() => submitting = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Jama failed: $e'), backgroundColor: _red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Submit Jama (\u20B9 જમા)', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result is Map<String, dynamic>) {
      final double unused = (result['remaining_unused'] as num?)?.toDouble() ?? 0.0;
      final double applied = (result['amount_applied'] as num?)?.toDouble() ?? 0.0;
      if (mounted) {
        if (unused > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('\u20B9${applied.toStringAsFixed(2)} applied for ${customer.name}. Warning: \u20B9${unused.toStringAsFixed(2)} remains unused (no pending due).'),
              backgroundColor: Colors.amber.shade800,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Jama recorded successfully for ${customer.name}!'),
              backgroundColor: _green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        _loadCustomers();
      }
    }
  }

  Widget _infoRow(IconData icon, String text, {int maxLines = 2}) {
    return Row(
      children: [
        Icon(icon, size: 13, color: _slate400),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 12, color: _slate600),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statusToggleBadge(ApiCustomer customer) {
    final active = customer.isActive;
    return GestureDetector(
      onTap: () => _toggleCustomerStatus(customer),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? _green.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? _green.withValues(alpha: 0.3) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              active ? 'Active' : 'Inactive',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? _green : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              active ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
              size: 18,
              color: active ? _green : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleCustomerStatus(ApiCustomer customer) async {
    final newStatus = customer.isActive ? 'inactive' : 'active';
    final updatedDraft = ApiCustomerDraft(
      name: customer.name,
      mobileNumber: customer.mobileNumber,
      address: customer.address,
      gstNumber: customer.gstNumber,
      status: newStatus,
    );

    try {
      await RestaurantApi.instance.updateCustomer(customer.id, updatedDraft);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${customer.name} status updated to $newStatus'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        _loadCustomers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState({required bool noCustomers}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _indigo.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                noCustomers ? Icons.people_outline_rounded : Icons.search_off_rounded,
                size: 40,
                color: _indigo.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              noCustomers ? 'No Customers Yet' : 'No Results Found',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _slate700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              noCustomers
                  ? 'Tap the + button to add your first customer'
                  : 'Try a different search or filter',
              style: GoogleFonts.inter(fontSize: 14, color: _slate400),
              textAlign: TextAlign.center,
            ),
            if (noCustomers) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _openAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Add Customer', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _indigo,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded, size: 40, color: _red.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 20),
            Text('Something went wrong',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _slate700)),
            const SizedBox(height: 8),
            Text(_error ?? '', style: GoogleFonts.inter(fontSize: 13, color: _slate400), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCustomers,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Retry', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
