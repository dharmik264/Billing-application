import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/restaurant_api.dart';
import 'super_admin_dashboard_screen.dart';

class SuperAdminBillFontSettingsScreen extends StatefulWidget {
  const SuperAdminBillFontSettingsScreen({super.key});

  @override
  State<SuperAdminBillFontSettingsScreen> createState() =>
      _SuperAdminBillFontSettingsScreenState();
}

class _SuperAdminBillFontSettingsScreenState
    extends State<SuperAdminBillFontSettingsScreen> {
  final TextEditingController _titleFontController = TextEditingController(text: '20.0');
  final TextEditingController _bodyFontController = TextEditingController(text: '6.0');
  final TextEditingController _subtotalFontController = TextEditingController(text: '7.0');
  final TextEditingController _grandTotalFontController = TextEditingController(text: '10.0');
  final TextEditingController _footerFontController = TextEditingController(text: '5.0');
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await RestaurantApi.instance.fetchSystemSettings();
      if (mounted) {
        setState(() {
          _titleFontController.text = settings.billTitleFontSizeMm.toStringAsFixed(1);
          _bodyFontController.text = settings.billBodyFontSizeMm.toStringAsFixed(1);
          _subtotalFontController.text = settings.billSubtotalFontSizeMm.toStringAsFixed(1);
          _grandTotalFontController.text = settings.billGrandTotalFontSizeMm.toStringAsFixed(1);
          _footerFontController.text = settings.billFooterFontSizeMm.toStringAsFixed(1);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final double titleFont = double.tryParse(_titleFontController.text.trim()) ?? 20.0;
      final double bodyFont = double.tryParse(_bodyFontController.text.trim()) ?? 6.0;
      final double subtotalFont = double.tryParse(_subtotalFontController.text.trim()) ?? 7.0;
      final double grandTotalFont = double.tryParse(_grandTotalFontController.text.trim()) ?? 10.0;
      final double footerFont = double.tryParse(_footerFontController.text.trim()) ?? 5.0;

      await RestaurantApi.instance.updateSystemSettings(
        titleFontSizeMm: titleFont,
        bodyFontSizeMm: bodyFont,
        subtotalFontSizeMm: subtotalFont,
        grandTotalFontSizeMm: grandTotalFont,
        footerFontSizeMm: footerFont,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Global Printable Bill Font Sizes updated successfully!'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SuperAdminDashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save font settings: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Widget _buildFontInput(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.format_size_rounded),
            suffixText: 'mm',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Global Bill Font Settings',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.print_rounded,
                            color: Color(0xFF4F46E5), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Global Admin Setting: Change thermal bill font sizes (mm) here. This setting applies globally to every user\'s printed bills.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF3730A3),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildFontInput('Title Font Size (mm) [Bold]', _titleFontController, '20.0'),
                  _buildFontInput('Body Font Size (mm)', _bodyFontController, '6.0'),
                  _buildFontInput('Subtotal Font Size (mm)', _subtotalFontController, '7.0'),
                  _buildFontInput('Grand Total Font Size (mm) [Bold]', _grandTotalFontController, '10.0'),
                  _buildFontInput('Footer Font Size (mm)', _footerFontController, '5.0'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'Save Font Size Settings',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
