import 'dart:math' as math;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class EditItemScreen extends StatefulWidget {
  const EditItemScreen({
    super.key,
    this.initialName,
    this.initialCode = 'C-1030',
    this.initialCategory = 'Burgers',
    this.initialRate,
    this.initialOnline = true,
    this.initialActive = true,
  });

  final String? initialName;
  final String initialCode;
  final String initialCategory;
  final double? initialRate;
  final bool initialOnline;
  final bool initialActive;

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  static const Color _panelBackground = Color(0xFFF5F6FA);
  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _muted = Color(0xFFBBBBBB);
  static const Color _border = Color(0xFFDDDDDD);
  static const Color _softBorder = Color(0xFFEEEEEE);
  static const Color _orange = Color(0xFFEA580C);
  static const double _panelWidth = 360;

  static const List<String> _categories = [
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
  String _imageSource = '';
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
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final width = math.min(_panelWidth, constraints.maxWidth);

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: width,
                      child: _buildPanel(),
                    ),
                  ),
                );
              },
            ),
            if (_isSaving)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.05),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(_orange),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _panelBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildImageSection(),
                const SizedBox(height: 14),
                _buildItemName(),
                const SizedBox(height: 12),
                _buildCodeAndRate(),
                const SizedBox(height: 12),
                _buildCategorySelector(),
                const SizedBox(height: 14),
                _buildSwitchPanel(),
                const SizedBox(height: 20),
                _buildButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: _softBorder, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(50),
                  onTap: _cancel,
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0F0F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF555555),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    'Add New Item',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Draft',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Item Image'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _imageChoice(
                label: 'Gallery',
                icon: Icons.photo_outlined,
                selected: _imageSource == 'Gallery',
                selectedStyle: false,
                imageBytes: _imageSource == 'Gallery' ? _imageBytes : null,
                onTap: () => _selectImage('Gallery'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _imageChoice(
                label: 'Take Photo',
                icon: Icons.camera_alt_outlined,
                selected: _imageSource == 'Take Photo',
                selectedStyle: true,
                helper: 'Max 5MB',
                imageBytes: _imageSource == 'Take Photo' ? _imageBytes : null,
                onTap: () => _selectImage('Take Photo'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _imageChoice({
    required String label,
    required IconData icon,
    required bool selected,
    required bool selectedStyle,
    required VoidCallback onTap,
    String? helper,
    Uint8List? imageBytes,
  }) {
    final orangeCard = selectedStyle || selected;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: orangeCard ? const Color(0xFFFFF7ED) : _panelBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: orangeCard ? const Color(0xFFFED7AA) : _border,
            width: orangeCard ? 0.5 : 1.5,
          ),
        ),
        child: imageBytes != null && selected
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  imageBytes,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: selectedStyle ? 20 : 22,
                      color: orangeCard ? _orange : _muted),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: selectedStyle ? 12 : 11,
                      fontWeight:
                          selectedStyle ? FontWeight.w500 : FontWeight.w400,
                      color: orangeCard ? _orange : _muted,
                    ),
                  ),
                  if (helper != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      helper,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFFAAAAAA)),
                    ),
                  ],
                ],
              ),
      ),
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
            style: const TextStyle(fontSize: 14, color: _textPrimary),
            decoration: const InputDecoration(
              hintText: 'e.g. Double Cheese Truffle Burger',
              hintStyle: TextStyle(fontSize: 14, color: _muted),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.initialCode,
                      style: const TextStyle(fontSize: 14, color: _textPrimary),
                    ),
                    const Icon(Icons.lock_outline, size: 14, color: _muted),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
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
                  style: const TextStyle(fontSize: 14, color: _textPrimary),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(fontSize: 14, color: _muted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
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
          borderRadius: BorderRadius.circular(10),
          onTap: _pickCategory,
          child: _inputShell(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _category,
                  style: const TextStyle(fontSize: 14, color: _textPrimary),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: Color(0xFFAAAAAA),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchPanel() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _softBorder, width: 0.5),
      ),
      child: Column(
        children: [
          _settingsRow(
            icon: Icons.public,
            iconBackground: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF2563EB),
            title: 'Available Online',
            subtitle: 'Show this item on your website',
            value: _availableOnline,
            onTap: () => setState(() => _availableOnline = !_availableOnline),
          ),
          const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFF0F0F0)),
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
      ),
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
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: _textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _switch(value),
          ],
        ),
      ),
    );
  }

  Widget _switch(bool value) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 42,
      height: 24,
      padding: const EdgeInsets.all(3),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: value ? _orange : const Color(0xFFDDDDDD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textSecondary,
                  side: const BorderSide(color: _border, width: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _cancel,
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _save,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_outlined, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Save Item',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputShell({
    required Widget child,
    Color background = Colors.white,
  }) {
    return Container(
      height: 43,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border, width: 0.5),
      ),
      child: child,
    );
  }

  Widget _label(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
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
          _imageSource = source;
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
                        ? const Icon(Icons.check, color: _orange)
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
        imageBase64: _imageBytes != null ? base64Encode(_imageBytes!) : null,
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
    this.imageBase64,
  });

  final String name;
  final String code;
  final String category;
  final double rate;
  final bool online;
  final bool active;
  final String? imageBase64;
}
