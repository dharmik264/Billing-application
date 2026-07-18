import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/restaurant_api.dart';
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
  static const _slate100 = Color(0xFFF1F5F9);
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
    return Scaffold(
      backgroundColor: _slate50,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: Text('Add Customer', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final activeCount   = _customers.where((c) => c.isActive).length;
    final inactiveCount = _customers.where((c) => !c.isActive).length;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer Management',
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: _slate900)),
          if (!_isLoading && _customers.isNotEmpty)
            Text('$activeCount active · $inactiveCount inactive',
              style: GoogleFonts.inter(fontSize: 11, color: _slate400)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _slate600),
          onPressed: _loadCustomers,
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _slate200),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearch,
            style: GoogleFonts.inter(fontSize: 14, color: _slate900),
            decoration: InputDecoration(
              hintText: 'Search by name, mobile, GST...',
              hintStyle: GoogleFonts.inter(fontSize: 14, color: _slate400),
              prefixIcon: const Icon(Icons.search_rounded, color: _slate400, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: _slate400),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearch('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: _slate50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _slate200, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _slate200, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _indigo, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Status filter chips
          Row(
            children: [
              _filterChip('All', '', Icons.people_outline_rounded),
              const SizedBox(width: 8),
              _filterChip('Active', 'active', Icons.check_circle_outline_rounded),
              const SizedBox(width: 8),
              _filterChip('Inactive', 'inactive', Icons.cancel_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, IconData icon) {
    final selected = _statusFilter == value;
    return GestureDetector(
      onTap: () => _onStatusFilter(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _indigo : _slate100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _indigo : _slate200,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : _slate600),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _slate600,
              ),
            ),
          ],
        ),
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
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
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              customer.name,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _slate900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _statusBadge(customer.isActive),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _infoRow(Icons.phone_outlined, customer.mobileNumber),
                      const SizedBox(height: 2),
                      _infoRow(Icons.location_on_outlined, customer.address, maxLines: 1),
                      if (customer.gstNumber.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _infoRow(Icons.receipt_long_outlined, customer.gstNumber),
                      ],
                    ],
                  ),
                ),
                // Actions
                const SizedBox(width: 8),
                Column(
                  children: [
                    _iconBtn(Icons.edit_rounded, _indigo, () => _openEdit(customer)),
                    const SizedBox(height: 4),
                    _iconBtn(Icons.delete_outline_rounded, _red, () => _deleteCustomer(customer)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  Widget _statusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (active ? _green : _slate400).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: active ? _green : _slate400,
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 17, color: color),
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
