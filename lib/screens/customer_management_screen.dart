import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/restaurant_api.dart';
import '../utils/bill_event_notifier.dart';
import '../widgets/custom_page_header.dart';
import 'add_customer_screen.dart';
import 'customer_ledger_screen.dart';
import '../utils/app_constants.dart';

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

  static const Color _cardBorder = Color(0xFFE5E5E5);
  static const Color _brandBlack = Color(0xFF111111);
  static const Color _red        = Color(0xFFD32F2F);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    BillEventNotifier.billRefreshNotifier.addListener(_onBillChanged);
    _loadCustomers();
  }

  @override
  void dispose() {
    BillEventNotifier.billRefreshNotifier.removeListener(_onBillChanged);
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onBillChanged() {
    if (mounted) {
      _loadCustomers();
    }
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

  Future<void> _openLedger(ApiCustomer customer) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CustomerLedgerScreen(customer: customer)),
    );
    _loadCustomers();
  }

  // ── Delete ─────────────────────────────────────────────────────
  Future<void> _deleteCustomer(ApiCustomer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Customer',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _brandBlack)),
        content: Text(
          'Are you sure you want to delete "${customer.name}"? This action cannot be undone.',
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF666666), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await RestaurantApi.instance.deleteCustomer(customer.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Customer deleted'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
        ));
        _loadCustomers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
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
      backgroundColor: StitchColors.background,
      appBar: CustomAppBar(
        title: 'Customer Management',
        icon: Icons.people_rounded,
        subtitle: (!_isLoading && _customers.isNotEmpty)
            ? '$activeCount active · $inactiveCount inactive'
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20, color: _brandBlack),
            onPressed: _loadCustomers,
            tooltip: 'Refresh and sync',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                _buildSearchAndFilters(activeCount, inactiveCount),
                _buildAddButton(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildSearchAndFilters(int activeCount, int inactiveCount) {
    final totalCount = _customers.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          // Search Input
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _cardBorder),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search_rounded, size: 18, color: Color(0xFF888888)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearch,
                    style: GoogleFonts.inter(fontSize: 14, color: _brandBlack),
                    decoration: InputDecoration(
                      hintText: 'Search by name, mobile, GST...',
                      hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF888888)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF888888)),
                    onPressed: () {
                      _searchCtrl.clear();
                      _onSearch('');
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', '', totalCount),
                const SizedBox(width: 8),
                _buildFilterChip('Active', 'active', activeCount),
                const SizedBox(width: 8),
                _buildFilterChip('Inactive', 'inactive', inactiveCount),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _statusFilter == value;
    return InkWell(
      onTap: () => _onStatusFilter(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _brandBlack : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _brandBlack : _cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : _brandBlack,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '($count)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: isSelected ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF888888),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton.icon(
          onPressed: _openAdd,
          style: ElevatedButton.styleFrom(
            backgroundColor: _brandBlack,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: const Icon(Icons.person_add_rounded, size: 18),
          label: Text(
            '+ Add Customer',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _brandBlack),
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
        color: _brandBlack,
        onRefresh: _loadCustomers,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: _filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _buildCustomerCard(_filtered[i]),
        ),
      ),
    );
  }

  Widget _buildCustomerCard(ApiCustomer customer) {
    final initials = customer.name.trim().isEmpty
        ? '?'
        : customer.name
            .trim()
            .split(' ')
            .where((e) => e.isNotEmpty)
            .map((e) => e[0])
            .take(2)
            .join()
            .toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // Top row
          Row(
            children: [
              // Initial avatar box
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _cardBorder),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _brandBlack,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Customer Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _brandBlack,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.call_rounded, size: 14, color: Color(0xFF888888)),
                            const SizedBox(width: 4),
                            Text(
                              customer.mobileNumber,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                color: const Color(0xFF666666),
                              ),
                            ),
                          ],
                        ),
                        if (customer.address.isNotEmpty) ...[
                          const Text('•', style: TextStyle(color: Color(0xFFCCCCCC))),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF888888)),
                              const SizedBox(width: 2),
                              Text(
                                customer.address,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Vertical Edit & Delete Action Options
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openEdit(customer),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _brandBlack,
                      side: const BorderSide(color: _cardBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 12),
                    label: Text('Edit', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () => _deleteCustomer(customer),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _red,
                      side: const BorderSide(color: _cardBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 12),
                    label: Text('Delete', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: _cardBorder),
          const SizedBox(height: 8),
          // Bottom Row: Due Amount & Ledger Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Due: ',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF666666)),
                  ),
                  Text(
                    '\u20B9${customer.netDue.toStringAsFixed(2)}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _brandBlack,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _openLedger(customer),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandBlack,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.receipt_long_rounded, size: 14),
                label: Text('Ledger', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required bool noCustomers}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              noCustomers ? Icons.people_outline_rounded : Icons.search_off_rounded,
              size: 48,
              color: const Color(0xFF888888),
            ),
            const SizedBox(height: 16),
            Text(
              noCustomers ? 'No Customers Yet' : 'No Results Found',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _brandBlack),
            ),
            const SizedBox(height: 6),
            Text(
              noCustomers
                  ? 'Tap the + Add Customer button to get started.'
                  : 'Try changing your search or filter terms.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF666666)),
              textAlign: TextAlign.center,
            ),
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
            const Icon(Icons.error_outline_rounded, size: 48, color: _red),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _brandBlack),
            ),
            const SizedBox(height: 6),
            Text(_error ?? '', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF666666)), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCustomers,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandBlack,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

