import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/restaurant_api.dart';

class AddCustomerScreen extends StatefulWidget {
  final ApiCustomer? customer; // null = Add mode, non-null = Edit mode

  const AddCustomerScreen({super.key, this.customer});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  // Controllers
  final _nameCtrl    = TextEditingController();
  final _mobileCtrl  = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _gstCtrl     = TextEditingController();

  String _status = 'active';
  bool _isSaving = false;

  bool get _isEdit => widget.customer != null;

  // ── Colours ────────────────────────────────────────────────────
  static const _indigo  = Color(0xFF4F46E5);
  static const _slate50 = Color(0xFFF8FAFC);
  static const _slate300 = Color(0xFFCBD5E1);
  static const _slate600 = Color(0xFF475569);
  static const _slate900 = Color(0xFF0F172A);
  static const _red     = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    if (_isEdit) {
      final c = widget.customer!;
      _nameCtrl.text    = c.name;
      _mobileCtrl.text  = c.mobileNumber;
      _addressCtrl.text = c.address;
      _gstCtrl.text     = c.gstNumber;
      _status            = c.status;
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    _gstCtrl.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────────
  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Customer name is required';
    if (v.trim().length < 3) return 'Name must be at least 3 characters';
    return null;
  }

  String? _validateMobile(String? v) {
    if (v == null || v.trim().isEmpty) return 'Mobile number is required';
    if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) return 'Enter a valid 10-digit number';
    return null;
  }

  String? _validateAddress(String? v) {
    return null; // optional
  }

  String? _validateGst(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    final gstRegex = RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
    );
    if (!gstRegex.hasMatch(v.trim().toUpperCase())) {
      return 'Invalid GST format (e.g. 22AAAAA0000A1Z5)';
    }
    return null;
  }

  // ── Save ───────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final draft = ApiCustomerDraft(
      name:         _nameCtrl.text.trim(),
      mobileNumber: _mobileCtrl.text.trim(),
      address:      _addressCtrl.text.trim(),
      gstNumber:    _gstCtrl.text.trim().toUpperCase(),
      status:       _status,
    );

    try {
      if (_isEdit) {
        await RestaurantApi.instance.updateCustomer(widget.customer!.id, draft);
      } else {
        await RestaurantApi.instance.createCustomer(draft);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Customer updated successfully!' : 'Customer added successfully!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pop(true); // signal refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _slate50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: _slate900,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          _isEdit ? 'Edit Customer' : 'Add Customer',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _slate900,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _slate300.withValues(alpha: 0.5)),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [


                // ── Customer Name ──────────────────────────────
                _buildSectionTitle('Customer Name'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _nameCtrl,
                  hint: 'Enter customer name',
                  icon: Icons.person_outline_rounded,
                  validator: _validateName,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),

                // ── Mobile Number ──────────────────────────────
                _buildSectionTitle('Mobile Number'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _mobileCtrl,
                  hint: '10-digit mobile number',
                  icon: Icons.phone_outlined,
                  validator: _validateMobile,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Address (optional) ────────────────────────────────────
                _buildSectionTitle('Address', optional: true),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _addressCtrl,
                  hint: 'Enter full address (optional)',
                  icon: Icons.location_on_outlined,
                  validator: _validateAddress,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 20),

                // ── GST Number (optional) ──────────────────────
                _buildSectionTitle('GST Number', optional: true),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _gstCtrl,
                  hint: 'e.g. 22AAAAA0000A1Z5 (optional)',
                  icon: Icons.receipt_long_outlined,
                  validator: _validateGst,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 20),

                // ── Status ─────────────────────────────────────
                _buildSectionTitle('Status'),
                const SizedBox(height: 8),
                _buildStatusToggle(),
                const SizedBox(height: 32),

                // ── Buttons ─────────────────────────────────────
                _buildActionButtons(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildSectionTitle(String title, {bool optional = false}) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _slate600,
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Optional',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0891B2),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      validator: validator,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: _slate900,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: _slate300,
        ),
        prefixIcon: Icon(icon, size: 20, color: _slate300),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _slate300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _slate300.withValues(alpha: 0.7), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _indigo, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _red, width: 2),
        ),
      ),
    );
  }

  Widget _buildStatusToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: _statusOption('active', 'Active', Icons.check_circle_outline_rounded, const Color(0xFF10B981))),
          Expanded(child: _statusOption('inactive', 'Inactive', Icons.cancel_outlined, const Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _statusOption(String value, String label, IconData icon, Color activeColor) {
    final selected = _status == value;
    return GestureDetector(
      onTap: () => setState(() => _status = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? activeColor : _slate300),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? activeColor : _slate300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Cancel button
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: _slate300, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _slate600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Save button
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _indigo,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _indigo.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _isEdit ? 'Update Customer' : 'Save Customer',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
