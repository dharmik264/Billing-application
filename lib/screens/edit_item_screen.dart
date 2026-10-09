import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/local_storage_helper.dart';

class EditItemScreen extends StatefulWidget {
  const EditItemScreen({
    super.key,
    this.initialName,
    this.initialCode = 'C-9003',
    this.initialCategory = '',
    this.initialRate,
    this.initialOnline = true,
    this.initialActive = true,
    this.initialImageBytes,
    this.existingCategories = const [],
  });

  final String? initialName;
  final String initialCode;
  final String initialCategory;
  final double? initialRate;
  final bool initialOnline;
  final bool initialActive;
  final Uint8List? initialImageBytes;
  final List<String> existingCategories;

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  static const Color _bg = Color(0xFFFBF9F8);
  static const Color _surface = Colors.white;
  static const Color _textOnSurface = Color(0xFF1B1C1C);
  static const Color _textSecondary = Color(0xFF5D5F5F);
  static const Color _borderLight = Color(0xFFE5E5E5);
  static const Color _primary = Color(0xFF111111);

  List<String> _categories = [];

  late final TextEditingController _nameController;
  late final TextEditingController _rateController;
  late String _category;
  late bool _availableOnline;
  late bool _activeStatus;
  Uint8List? _imageBytes;
  bool _isSaving = false;

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
        final combined = <String>{
          ...widget.existingCategories,
          ...custom,
        };
        if (_category.isNotEmpty) {
          combined.add(_category);
        }
        _categories = combined.where((c) => c.trim().isNotEmpty).toList()..sort();
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
    final isEditing = widget.initialName != null && widget.initialName!.isNotEmpty;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _borderLight),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textOnSurface, size: 20),
          onPressed: _cancel,
        ),
        title: Text(
          isEditing ? 'Edit Item' : 'Add New Item',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _textOnSurface,
          ),
        ),
        actions: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _borderLight),
              ),
              child: Text(
                'DRAFT',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: _textSecondary, size: 20),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Photo Upload Ledger Box
                        _buildPhotoUploadSection(),
                        const SizedBox(height: 20),
                        // Form Matrix
                        _buildFormMatrix(),
                      ],
                    ),
                  ),
                ),
                // Dual Action Buttons Footer
                _buildFooterActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Photo Upload Ledger Box
  Widget _buildPhotoUploadSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: _showImagePickerSheet,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderLight),
                ),
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.memory(_imageBytes!, width: 80, height: 80, fit: BoxFit.cover),
                      )
                    : FutureBuilder<Uint8List?>(
                        future: LocalImageStorage.loadItemImageBytes(
                          code: widget.initialCode,
                          name: widget.initialName,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.memory(snapshot.data!, width: 80, height: 80, fit: BoxFit.cover),
                            );
                          }
                          return const Center(
                            child: Icon(Icons.add_a_photo_outlined, size: 28, color: _textSecondary),
                          );
                        },
                      ),
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bg, width: 2),
                  ),
                  child: const Icon(Icons.add, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload Item Photo',
          style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
        ),
      ],
    );
  }

  /// Form Elements Matrix
  Widget _buildFormMatrix() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ITEM NAME
        _label('ITEM NAME'),
        const SizedBox(height: 4),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _borderLight),
          ),
          child: TextField(
            controller: _nameController,
            style: GoogleFonts.inter(fontSize: 14, color: _textOnSurface),
            decoration: InputDecoration(
              hintText: 'e.g. Double Cheese Truffle Burger',
              hintStyle: GoogleFonts.inter(fontSize: 14, color: _textSecondary),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 2-Column: ITEM CODE & RATE (₹)
        Row(
          children: [
            // Left: ITEM CODE
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('ITEM CODE'),
                  const SizedBox(height: 4),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3F3),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.initialCode,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _textOnSurface),
                        ),
                        const Icon(Icons.lock_outline_rounded, size: 16, color: _textSecondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right: RATE (₹)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('RATE (\u20B9)'),
                  const SizedBox(height: 4),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _borderLight),
                    ),
                    child: TextField(
                      controller: _rateController,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _textOnSurface),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: GoogleFonts.inter(fontSize: 14, color: _textSecondary),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // CATEGORY
        _label('CATEGORY'),
        const SizedBox(height: 4),
        InkWell(
          onTap: _pickCategory,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _borderLight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _category.isNotEmpty ? _category : 'Select Category',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _category.isNotEmpty ? _textOnSurface : _textSecondary,
                  ),
                ),
                const Icon(Icons.expand_more_rounded, size: 18, color: _textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Option Toggles Ledger Container
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderLight),
          ),
          child: Column(
            children: [
              // Available Online
              InkWell(
                onTap: () => setState(() => _availableOnline = !_availableOnline),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _borderLight),
                        ),
                        child: const Icon(Icons.language_rounded, size: 18, color: _primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available Online',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _textOnSurface),
                            ),
                            Text(
                              'Show this item on digital menu',
                              style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                            ),
                          ],
                        ),
                      ),
                      _customToggle(_availableOnline),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: _borderLight),
              // Active Status
              InkWell(
                onTap: () => setState(() => _activeStatus = !_activeStatus),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _activeStatus ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _activeStatus ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2)),
                        ),
                        child: Icon(
                          _activeStatus ? Icons.check_circle_outline_rounded : Icons.highlight_off_rounded,
                          size: 18,
                          color: _activeStatus ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _activeStatus ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              ),
                              child: Text(_activeStatus ? 'Active Status' : 'Inactive Status'),
                            ),
                            Text(
                              _activeStatus ? 'Item is active on billing menu' : "Set to 'Out of Stock' if disabled",
                              style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                            ),
                          ],
                        ),
                      ),
                      _statusToggle(_activeStatus),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Quick Tax & Inventory Meta (Bento style 1px grid)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderLight),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TAX RATE (GST)', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                        const SizedBox(height: 2),
                        Text('5.00% Standard', style: GoogleFonts.inter(fontSize: 14, color: _textOnSurface)),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: _borderLight),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('STOCK UNIT', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                        const SizedBox(height: 2),
                        Text('Portion (1 pc)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: _textOnSurface)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: _textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _customToggle(bool value) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 40,
      height: 24,
      padding: const EdgeInsets.all(2),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: value ? _primary : const Color(0xFFDBDADA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _borderLight),
        ),
      ),
    );
  }

  Widget _statusToggle(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2)),
      ),
      child: Row(
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
    );
  }

  /// Dual Action Buttons Footer
  Widget _buildFooterActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _borderLight)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 44,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: _borderLight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _cancel,
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _textOnSurface),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.save_outlined, size: 18, color: Colors.white),
                label: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Save Item',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
              ),
            ),
          ),
        ],
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
                    decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.camera_alt_outlined, color: _primary),
                  ),
                  title: Text('Take Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: _textOnSurface)),
                  onTap: () {
                    Navigator.pop(context);
                    _selectImage('Take Photo');
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.photo_library_outlined, color: _primary),
                  ),
                  title: Text('Choose from Gallery', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: _textOnSurface)),
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
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 16,
              left: 16,
              right: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Category',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textOnSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final cat in _categories)
                        ListTile(
                          title: Text(
                            cat,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: cat == _category ? FontWeight.w700 : FontWeight.w500,
                              color: cat == _category ? _primary : _textOnSurface,
                            ),
                          ),
                          trailing: cat == _category
                              ? const Icon(Icons.check_circle_rounded, color: _primary)
                              : null,
                          onTap: () => Navigator.of(context).pop(cat),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop('__ADD_NEW__'),
                  icon: const Icon(Icons.add, size: 20),
                  label: Text('Add New Category', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (result == '__ADD_NEW__') {
      await _showAddNewCategoryDialog();
    } else if (result is String && result.isNotEmpty) {
      setState(() => _category = result);
    }
  }

  Future<void> _showAddNewCategoryDialog() async {
    final controller = TextEditingController();
    final newCategory = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Category', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Category Name (e.g. Pizza)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.inter(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            child: Text('Add', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (newCategory != null && newCategory.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final custom = prefs.getStringList('custom_categories') ?? [];
      if (!custom.contains(newCategory)) {
        custom.add(newCategory);
        await prefs.setStringList('custom_categories', custom);
      }
      setState(() {
        if (!_categories.contains(newCategory)) {
          _categories
            ..add(newCategory)
            ..sort();
        }
        _category = newCategory;
      });
      _showSnackBar('Category "$newCategory" added!');
    }
  }

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
