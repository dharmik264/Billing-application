import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/restaurant_api.dart';
import '../widgets/offline_banner.dart';

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
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();

  String _status = 'active';
  bool _isSaving = false;

  bool get _isEdit => widget.customer != null;

  // ── Monochromatic Palette ──────────────────────────────────────
  static const Color _bgCanvas = Color(0xFFFBF9F8);
  static const Color _brandBlack = Color(0xFF111111);
  static const Color _mutedText = Color(0xFF71717A);
  static const Color _cardBorder = Color(0xFFE5E5E5);
  static const Color _red = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    if (_isEdit) {
      final c = widget.customer!;
      _nameCtrl.text = c.name;
      _mobileCtrl.text = c.mobileNumber;
      _addressCtrl.text = c.address;
      _gstCtrl.text = c.gstNumber;
      _status = c.status;
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

  // ── Contact Picker ─────────────────────────────────────────────
  Future<void> _pickContact() async {
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      if (status == PermissionStatus.granted || status == PermissionStatus.limited) {
        final contact = await FlutterContacts.native.showPicker(
          properties: {ContactProperty.phone, ContactProperty.name},
        );
        if (contact != null) {
          final displayName = (contact.displayName ?? '').trim();
          String rawPhone = '';
          if (contact.phones.isNotEmpty) {
            rawPhone = contact.phones.first.number;
          }
          final digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');
          final cleanPhone = digitsOnly.length >= 10
              ? digitsOnly.substring(digitsOnly.length - 10)
              : digitsOnly;

          setState(() {
            if (displayName.isNotEmpty) {
              _nameCtrl.text = displayName;
            }
            if (cleanPhone.isNotEmpty) {
              _mobileCtrl.text = cleanPhone;
            }
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Permission to access contacts was denied.'),
              backgroundColor: _red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select contact: $e'),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
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

  // ── Save ───────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final draft = ApiCustomerDraft(
      name: _nameCtrl.text.trim(),
      mobileNumber: _mobileCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      gstNumber: _gstCtrl.text.trim(),
      status: _status,
    );

    try {
      if (_isEdit) {
        await RestaurantApi.instance.updateCustomer(widget.customer!.id, draft);
      } else {
        await RestaurantApi.instance.createCustomer(draft);
      }

      if (!mounted) return;

      final actionText = _isEdit ? 'updated' : 'created';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Customer $actionText successfully'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      backgroundColor: _bgCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: _brandBlack,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          _isEdit ? 'Edit Customer' : 'Add Customer',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _brandBlack,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _cardBorder),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                OfflineBanner(scaffoldContext: context),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Customer Name
                            _buildSectionTitle('Customer Name'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _nameCtrl,
                              hint: 'Enter customer full name',
                              icon: Icons.person_outline_rounded,
                              validator: _validateName,
                              textCapitalization: TextCapitalization.words,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.contacts_rounded, color: _brandBlack, size: 20),
                                tooltip: 'Pick from contacts',
                                onPressed: _pickContact,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Mobile Number
                            _buildSectionTitle('Mobile Number'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _mobileCtrl,
                              hint: '10-digit mobile number',
                              icon: Icons.phone_android_rounded,
                              validator: _validateMobile,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.contacts_rounded, color: _brandBlack, size: 20),
                                tooltip: 'Pick from contacts',
                                onPressed: _pickContact,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Address (optional)
                            _buildSectionTitle('Address', optional: true),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _addressCtrl,
                              hint: 'Enter full address (optional)',
                              icon: Icons.location_on_outlined,
                              maxLines: 3,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                            const SizedBox(height: 20),

                            // GST Number (optional)
                            _buildSectionTitle('GST Number', optional: true),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _gstCtrl,
                              hint: 'e.g. 24AAAAA0000A1Z5 (optional)',
                              icon: Icons.receipt_long_outlined,
                              textCapitalization: TextCapitalization.characters,
                            ),
                            const SizedBox(height: 20),

                            // Status
                            _buildSectionTitle('Status'),
                            const SizedBox(height: 6),
                            _buildStatusToggle(),
                            const SizedBox(height: 32),

                            // Action Buttons
                            _buildActionButtons(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _brandBlack,
            letterSpacing: -0.1,
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 6),
          Text(
            '(Optional)',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _mutedText,
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
    Widget? suffixIcon,
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
        color: _brandBlack,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFFA1A1AA),
        ),
        prefixIcon: Icon(icon, size: 18, color: _mutedText),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _cardBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _cardBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _brandBlack, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _red, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildStatusToggle() {
    final isActive = _status == 'active';
    return GestureDetector(
      onTap: () => setState(() => _status = isActive ? 'inactive' : 'active'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.check_circle_outline_rounded : Icons.highlight_off_rounded,
                  size: 18,
                  color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                ),
                const SizedBox(width: 8),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                  child: Text(isActive ? 'Customer Active' : 'Customer Inactive'),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 20,
                  padding: const EdgeInsets.all(2),
                  alignment: isActive ? Alignment.centerRight : Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                  child: Text(isActive ? 'Active' : 'Inactive'),
                ),
              ],
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
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _cardBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _brandBlack,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Save button
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandBlack,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _isEdit ? 'Update Customer' : 'Save Customer',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
