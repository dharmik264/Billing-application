import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/restaurant_api.dart';

class SuperAdminPlanSettingsScreen extends StatefulWidget {
  const SuperAdminPlanSettingsScreen({super.key});

  @override
  State<SuperAdminPlanSettingsScreen> createState() => _SuperAdminPlanSettingsScreenState();
}

class _SuperAdminPlanSettingsScreenState extends State<SuperAdminPlanSettingsScreen> {
  bool _isLoading = true;
  List<dynamic> _plans = [];

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() => _isLoading = true);
    try {
      final plans = await RestaurantApi.instance.fetchPlans();
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Failed to fetch plans: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text('Plan Settings', style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _plans.length,
              itemBuilder: (context, index) {
                return _buildPlanCard(_plans[index]);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4F46E5),
        onPressed: () => _showPlanDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('New Plan', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final bool isActive = plan['is_active'] ?? true;
    final bool isPopular = plan['is_popular'] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9)),
        boxShadow: [
          if (isActive)
            BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(plan['name'] ?? 'Plan', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8))),
                  if (isPopular)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text('POPULAR', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFF59E0B))),
                    ),
                  if (!isActive)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF94A3B8).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text('INACTIVE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8))),
                    ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => _showPlanDialog(plan: plan),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                    onPressed: () => _confirmDelete(plan),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(plan['description'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
          const SizedBox(height: 16),
          Row(
            children: [
              _priceBox('Monthly', plan['price_monthly'].toString()),
              const SizedBox(width: 12),
              _priceBox('Yearly', plan['price_yearly'].toString()),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _limitChip('Users', plan['max_users']),
              _limitChip('Tables', plan['max_tables']),
              _limitChip('Invoices/mo', plan['max_invoices_per_month'] == -1 ? 'Unlimited' : plan['max_invoices_per_month']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceBox(String label, String amount) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
            const SizedBox(height: 2),
            Text('₹$amount', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
          ],
        ),
      ),
    );
  }

  Widget _limitChip(String label, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$value $label', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
    );
  }

  void _confirmDelete(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Plan?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete ${plan['name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await RestaurantApi.instance.deletePlan(plan['id'].toString());
                _fetchPlans();
                _showSnack('Plan deleted');
              } catch (e) {
                _showSnack('Error: $e');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPlanDialog({Map<String, dynamic>? plan}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PlanForm(plan: plan, onSaved: _fetchPlans),
    );
  }
}

class _PlanForm extends StatefulWidget {
  final Map<String, dynamic>? plan;
  final VoidCallback onSaved;

  const _PlanForm({this.plan, required this.onSaved});

  @override
  State<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<_PlanForm> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceMoCtrl = TextEditingController(text: '0.00');
  final _priceYrCtrl = TextEditingController(text: '0.00');
  final _usersCtrl = TextEditingController(text: '1');
  final _tablesCtrl = TextEditingController(text: '0');
  final _invoicesCtrl = TextEditingController(text: '-1');
  
  bool _isActive = true;
  bool _isPopular = false;
  
  Map<String, bool> _features = {
    'billing_access': true,
    'inventory_access': false,
    'reports_access': false,
    'tax_access': false,
    'staff_management': false,
  };

  @override
  void initState() {
    super.initState();
    if (widget.plan != null) {
      _nameCtrl.text = widget.plan!['name'] ?? '';
      _descCtrl.text = widget.plan!['description'] ?? '';
      _priceMoCtrl.text = widget.plan!['price_monthly'].toString();
      _priceYrCtrl.text = widget.plan!['price_yearly'].toString();
      _usersCtrl.text = widget.plan!['max_users'].toString();
      _tablesCtrl.text = widget.plan!['max_tables'].toString();
      _invoicesCtrl.text = widget.plan!['max_invoices_per_month'].toString();
      _isActive = widget.plan!['is_active'] ?? true;
      _isPopular = widget.plan!['is_popular'] ?? false;
      
      final Map<String, dynamic> planFeatures = widget.plan!['features'] ?? {};
      _features.forEach((key, _) {
        if (planFeatures.containsKey(key)) {
          _features[key] = planFeatures[key] == true;
        }
      });
    }
  }

  Future<void> _save() async {
    final data = {
      'name': _nameCtrl.text,
      'description': _descCtrl.text,
      'price_monthly': _priceMoCtrl.text,
      'price_yearly': _priceYrCtrl.text,
      'max_users': int.tryParse(_usersCtrl.text) ?? 1,
      'max_tables': int.tryParse(_tablesCtrl.text) ?? 0,
      'max_invoices_per_month': int.tryParse(_invoicesCtrl.text) ?? -1,
      'is_active': _isActive,
      'is_popular': _isPopular,
      'features': _features,
    };

    try {
      if (widget.plan == null) {
        await RestaurantApi.instance.createPlan(data);
      } else {
        await RestaurantApi.instance.updatePlan(widget.plan!['id'].toString(), data);
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: ListView(
            controller: controller,
            children: [
              Text(widget.plan == null ? 'Create Plan' : 'Edit Plan', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              _field('Plan Name', _nameCtrl),
              _field('Description', _descCtrl, maxLines: 2),
              Row(
                children: [
                  Expanded(child: _field('Monthly Price (₹)', _priceMoCtrl, type: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Yearly Price (₹)', _priceYrCtrl, type: TextInputType.number)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _field('Max Users', _usersCtrl, type: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Max Tables (0=unlim)', _tablesCtrl, type: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Invoices (-1=unlim)', _invoicesCtrl, type: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 12),
              
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Active Plan', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                subtitle: const Text('Visible to customers'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Most Popular', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                subtitle: const Text('Shows highlight badge'),
                value: _isPopular,
                onChanged: (val) => setState(() => _isPopular = val),
              ),
              const Divider(height: 30),
              
              Text('INCLUDED FEATURES', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 1.0)),
              const SizedBox(height: 12),
              ..._features.keys.map((key) {
                String label = key.replaceAll('_', ' ').toUpperCase();
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(label, style: GoogleFonts.inter(fontSize: 14)),
                  value: _features[key],
                  onChanged: (val) {
                    setState(() { _features[key] = val ?? false; });
                  },
                );
              }),
              
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _save,
                  child: Text('Save Plan', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1, TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: type,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }
}
