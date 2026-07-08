import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_constants.dart';

class EditItemScreen extends StatefulWidget {
  const EditItemScreen({
    super.key,
    this.initialName,
    this.initialCode = 'C-1030',
    this.initialCategory = 'Burgers',
    this.initialRate,
    this.initialOnline = true,
    this.initialActive = true,
    this.initialImageBytes,
  });

  final String? initialName;
  final String initialCode;
  final String initialCategory;
  final double? initialRate;
  final bool initialOnline;
  final bool initialActive;
  final Uint8List? initialImageBytes;

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  static const Color _panelBackground = AppColors.slate50;
  static const Color _primary = AppColors.indigo600;
  static const Color _textPrimary = AppColors.slate900;
  static const Color _textSecondary = AppColors.slate500;
  static const Color _border = AppColors.slate200;

  List<String> _categories = [
    'Burgers',
    'Beverages',
    'Sides',
    'Desserts',
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _rateController;
  late String _category;
  late bool _availableOnline;
  late bool _activeStatus;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _rateController = TextEditingController(
      text: widget.initialRate == null
          ? ''
          : widget.initialRate!.toStringAsFixed(2),
    );
    _category = widget.initialCategory;
    _availableOnline = widget.initialOnline;
    _activeStatus = widget.initialActive;
    _imageBytes = widget.initialImageBytes;
    _loadCustomCategories();
  }

  Future<void> _loadCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList('custom_categories') ?? [];
    if (mounted) {
      setState(() {
        final combined = {'Burgers', 'Beverages', 'Sides', 'Desserts', ...custom};
        if (!combined.contains(_category) && _category.isNotEmpty) {
          combined.add(_category);
        }
        _categories = combined.toList()..sort();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              _buildHeader(),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                height: 40,
                decoration: BoxDecoration(
                  color: _panelBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: _primary,
                  unselectedLabelColor: _textSecondary,
                  labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Basic Info'),
                    Tab(text: 'Settings'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildBasicInfoTab(),
                    _buildSettingsTab(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildButtons(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          _buildCompactImageSection(),
          const SizedBox(height: 16),
          _buildItemName(),
          const SizedBox(height: 12),
          _buildCodeAndRate(),
          const SizedBox(height: 12),
          _buildCategorySelector(),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          _buildSwitchPanel(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _cancel,
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(Icons.close_rounded, size: 20, color: _textPrimary),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    widget.initialName != null && widget.initialName!.isNotEmpty ? 'Edit Item' : 'Add New Item',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF), // light indigo
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Draft',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactImageSection() {
    return Center(
      child: GestureDetector(
        onTap: () => _showImagePickerSheet(),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _panelBackground,
            shape: BoxShape.circle,
            border: Border.all(color: _border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _textPrimary.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: _imageBytes != null
              ? ClipOval(
                  child: Image.memory(
                    _imageBytes!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                )
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 24, color: _primary),
                  ],
                ),
        ),
      ),
    );
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _panelBackground, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.camera_alt_outlined, color: _primary),
                  ),
                  title: Text('Take Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: _textPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    _selectImage('Take Photo');
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _panelBackground, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.photo_library_outlined, color: _primary),
                  ),
                  title: Text('Choose from Gallery', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: _textPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    _selectImage('Gallery');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemName() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Item Name'),
        const SizedBox(height: 6),
        _inputShell(
          child: TextField(
            controller: _nameController,
            maxLines: 1,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: _textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Double Cheese Truffle Burger',
              hintStyle: GoogleFonts.inter(fontSize: 15, color: _textSecondary.withValues(alpha: 0.5)),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeAndRate() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Item Code'),
              const SizedBox(height: 6),
              _inputShell(
                background: _panelBackground,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.initialCode,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: _textPrimary),
                      ),
                      const Icon(Icons.lock_outline, size: 16, color: _textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Rate (\u20B9)'),
              const SizedBox(height: 6),
              _inputShell(
                child: TextField(
                  controller: _rateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  maxLines: 1,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: _textPrimary),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: GoogleFonts.inter(fontSize: 15, color: _textSecondary.withValues(alpha: 0.5)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Category'),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _pickCategory,
          child: _inputShell(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _category,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: _textPrimary),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: _textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchPanel() {
    return Column(
      children: [
        _settingsRow(
          icon: Icons.public,
          iconBackground: const Color(0xFFEFF6FF),
          iconColor: const Color(0xFF4F46E5),
          title: 'Available Online',
          subtitle: 'Show this item on your website',
          value: _availableOnline,
          onTap: () => setState(() => _availableOnline = !_availableOnline),
        ),
        const SizedBox(height: 16),
        _settingsRow(
          icon: Icons.check_circle_outline,
          iconBackground: const Color(0xFFF0FDF4),
          iconColor: const Color(0xFF16A34A),
          title: 'Active Status',
          subtitle: "Set to 'Out of Stock' if disabled",
          value: _activeStatus,
          onTap: () => setState(() => _activeStatus = !_activeStatus),
        ),
      ],
    );
  }

  Widget _settingsRow({
    required IconData icon,
    required Color iconBackground,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _switch(value),
          ],
        ),
      ),
    );
  }

  Widget _switch(bool value) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 44,
      height: 26,
      padding: const EdgeInsets.all(3),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: value ? _primary : _border,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: SizedBox(
            height: 56,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _border, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _cancel,
              child: Text('Cancel', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _textSecondary)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.indigo600, Color(0xFF4338CA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.indigo600.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text('Save Item', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _inputShell({
    required Widget child,
    Color background = Colors.white,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          if (background == Colors.white)
            BoxShadow(
              color: _textPrimary.withValues(alpha: 0.01),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
        ],
      ),
      child: child,
    );
  }

  Widget _label(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _selectImage(String source) async {
    final picker = ImagePicker();
    final isCamera = source == 'Take Photo';

    try {
      final XFile? image = await picker.pickImage(
        source: isCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
        _showSnackBar('Image selected successfully');
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _pickCategory() async {
    final category = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final category in _categories)
                  ListTile(
                    title: Text(category),
                    trailing: category == _category
                        ? const Icon(Icons.check, color: _primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(category),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (category != null) {
      setState(() => _category = category);
    }
  }

  bool _isSaving = false;

  void _save() {
    final name = _nameController.text.trim();
    final rate = double.tryParse(_rateController.text.trim());

    if (name.isEmpty) {
      _showSnackBar('Please enter item name');
      return;
    }

    if (rate == null || rate <= 0) {
      _showSnackBar('Please enter valid rate');
      return;
    }

    setState(() => _isSaving = true);

    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.of(context).pop(
      EditItemResult(
        name: name,
        code: widget.initialCode,
        category: _category,
        rate: rate,
        online: _availableOnline,
        active: _activeStatus,
        imageBytes: _imageBytes,
      ),
    );
  }

  void _cancel() {
    Navigator.of(context).maybePop();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class EditItemResult {
  const EditItemResult({
    required this.name,
    required this.code,
    required this.category,
    required this.rate,
    required this.online,
    required this.active,
    this.imageBytes,
  });

  final String name;
  final String code;
  final String category;
  final double rate;
  final bool online;
  final bool active;
  final Uint8List? imageBytes;
}
