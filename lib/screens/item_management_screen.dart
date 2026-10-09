import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/restaurant_api.dart';
import '../utils/local_storage_helper.dart';
import '../widgets/skeleton_loader.dart';
import 'edit_item_screen.dart';

class ItemManagementScreen extends StatefulWidget {
  const ItemManagementScreen({super.key});

  @override
  State<ItemManagementScreen> createState() => _ItemManagementScreenState();
}

class _ItemManagementScreenState extends State<ItemManagementScreen> {
  String _selectedCategory = 'All Items';
  final bool _showOnlyActive = false;

  final TextEditingController _searchController = TextEditingController();
  final List<_MenuItem> _items = [];
  List<String> _customCategories = [];
  bool _loading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadCustomCategories();
    _loadItemsFromDatabase();
  }

  Future<void> _loadCustomCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = prefs.getStringList('custom_categories') ?? [];
      if (mounted) {
        setState(() {
          _customCategories = custom;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>['All Items'];
    for (final item in _items) {
      if (item.category.isNotEmpty && !categories.contains(item.category)) {
        categories.add(item.category);
      }
    }
    for (final custom in _customCategories) {
      if (custom.isNotEmpty && !categories.contains(custom)) {
        categories.add(custom);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Item Management',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111111),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'DHARA FOOD POS',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF666666),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Manage Categories',
            icon: const Icon(Icons.category_outlined, size: 20, color: Color(0xFF111111)),
            onPressed: _isProcessing ? null : _manageCategories,
          ),
          IconButton(
            tooltip: 'Add Item',
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: Color(0xFF111111)),
            onPressed: _isProcessing ? null : _addItem,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFD8D8D8)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Stack(
              children: [
                Column(
                  children: [
                    // Search & Category Filters
                    _buildSearchAndFilters(categories),

                    // Main Item Ledger List
                    Expanded(child: _buildItemList()),
                  ],
                ),
                if (_isProcessing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.5),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF111111)),
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



  Widget _buildSearchAndFilters(List<String> categories) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFD8D8D8), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Input Box
          TextField(
            controller: _searchController,
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF111111)),
            decoration: InputDecoration(
              hintText: 'Search items by name or code...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF666666)),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF666666)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF666666)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFFD8D8D8), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFFD8D8D8), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFF111111), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Horizontal Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final cat in categories) ...[
                  _categoryChip(cat),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons Row (2-Column Grid)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _manageCategories,
                  icon: const Icon(Icons.add_rounded, size: 15, color: Color(0xFF111111)),
                  label: Text(
                    'Category',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111111),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFD8D8D8), width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _addItem,
                  icon: const Icon(Icons.add_rounded, size: 15, color: Colors.white),
                  label: Text(
                    'Add Item',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String category) {
    final selected = _selectedCategory == category;
    final label = category == 'All Items' ? 'All (${_items.length})' : category;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111111) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF111111) : const Color(0xFFD8D8D8),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF111111),
          ),
        ),
      ),
    );
  }

  Widget _buildItemList() {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: 6,
        itemBuilder: (context, index) => const SkeletonListItem(),
      );
    }

    final items = _filteredItems;

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 56, color: Color(0xFFD8D8D8)),
              const SizedBox(height: 12),
              Text(
                'No items found',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF666666)),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 105,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _itemCard(items[index]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) => _itemCard(items[index]),
        );
      },
    );
  }

  Widget _itemCard(_MenuItem item) {
    final isActive = item.active;

    String initials = 'IT';
    if (item.name.trim().isNotEmpty) {
      final parts = item.name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts[0].length >= 2) {
        initials = parts[0].substring(0, 2).toUpperCase();
      } else {
        initials = parts[0].toUpperCase();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8D8D8), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Half: Avatar Monogram/Image, Info & Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFD8D8D8), width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildItemTileImage(item, isActive, initials),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isActive ? const Color(0xFF111111) : const Color(0xFF8E8E8E),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF666666) : const Color(0xFF8E8E8E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.category.isNotEmpty ? item.category : 'General',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '|',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFD8D8D8)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Code: ${item.code}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: const Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${item.price.toStringAsFixed(2)}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isActive ? const Color(0xFF111111) : const Color(0xFF8E8E8E),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: Color(0xFFD8D8D8)),
          const SizedBox(height: 10),

          // Bottom Controls Row: Active Status Switch & Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _toggleActiveStatus(item),
                child: AnimatedContainer(
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
                ),
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _editItem(item),
                    icon: const Icon(Icons.edit_rounded, size: 12, color: Color(0xFF111111)),
                    label: Text(
                      'Edit',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFD8D8D8), width: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: () => _deleteItem(item),
                    icon: const Icon(Icons.delete_outline_rounded, size: 12, color: Color(0xFF111111)),
                    label: Text(
                      'Delete',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFD8D8D8), width: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemTileImage(_MenuItem item, bool isActive, String initials) {
    if (item.localImageBytes != null) {
      return Image.memory(
        item.localImageBytes!,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
      );
    }

    final imgUrl = item.imageUrl;
    if (imgUrl != null && imgUrl.startsWith('data:image')) {
      try {
        final base64Str = imgUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
        );
      } catch (_) {}
    }

    return FutureBuilder<Uint8List?>(
      future: LocalImageStorage.loadItemImageBytes(
        id: item.id,
        code: item.code,
        name: item.name,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          );
        }

        if (imgUrl != null && imgUrl.isNotEmpty && (imgUrl.startsWith('http://') || imgUrl.startsWith('https://'))) {
          return Image.network(
            imgUrl,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _monogramFallback(initials),
          );
        }

        return _monogramFallback(initials);
      },
    );
  }

  Widget _monogramFallback(String initials) {
    return Center(
      child: Text(
        initials,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF111111),
        ),
      ),
    );
  }

  List<_MenuItem> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();

    return _items.where((item) {
      final matchesCategory = _selectedCategory == 'All Items' ||
          item.category == _selectedCategory;
      final matchesActive = !_showOnlyActive || item.active;
      final matchesSearch = query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.code.toLowerCase().contains(query);

      return matchesCategory && matchesActive && matchesSearch;
    }).toList();
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final newCategory = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Category Name (e.g. Pizza)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111111),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (newCategory != null && newCategory.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final customCategories = prefs.getStringList('custom_categories') ?? [];
      if (!customCategories.contains(newCategory)) {
        customCategories.add(newCategory);
        await prefs.setStringList('custom_categories', customCategories);
        _showSnackBar('Category "$newCategory" added! It will now appear when adding new items.');
        setState(() {});
      } else {
        _showSnackBar('Category already exists');
      }
    }
  }

  Future<void> _addItem() async {
    final nextNumber = 9000 + _items.length + 1;
    final allCategories = <String>{
      ..._items.map((e) => e.category),
      ..._customCategories,
    }.where((c) => c.isNotEmpty).toList();

    final result = await Navigator.of(context).push<EditItemResult>(
      MaterialPageRoute(
        builder: (context) => EditItemScreen(
          initialCode: 'C-$nextNumber',
          existingCategories: allCategories,
        ),
      ),
    );

    if (result == null) return;

    await _loadCustomCategories();

    setState(() => _isProcessing = true);

    if (result.imageBytes != null) {
      await LocalImageStorage.saveItemImage(
        code: result.code,
        name: result.name,
        bytes: result.imageBytes!,
      );
    }

    final draft = ApiItemDraft(
      name: result.name,
      code: result.code,
      category: result.category,
      rate: result.rate,
      active: result.active,
      availableOnline: result.online,
      imageBase64: result.imageBytes != null ? base64Encode(result.imageBytes!) : null,
    );
    ApiItem? savedItem;
    String? errorMessage;
    try {
      savedItem = await RestaurantApi.instance.createItem(draft);
    } catch (e) {
      errorMessage = e.toString();
    }

    if (mounted) {
      if (result.imageBytes != null) {
        await LocalImageStorage.saveItemImage(
          id: savedItem?.id,
          code: result.code,
          name: result.name,
          bytes: result.imageBytes!,
        );
      }

      setState(() {
        _items.insert(
          0,
          savedItem == null
              ? _MenuItem.fromEditResult(result)
              : _MenuItem.fromApiItem(savedItem).copyWith(localImageBytes: result.imageBytes),
        );
        _selectedCategory = 'All Items';
        _searchController.clear();
        _isProcessing = false;
      });

      if (errorMessage != null) {
        _showSnackBar('Saved locally: $errorMessage');
      } else {
        _showSnackBar('${result.name} added');
      }
    }
  }

  Future<void> _editItem(_MenuItem item) async {
    final allCategories = <String>{
      ..._items.map((e) => e.category),
      ..._customCategories,
    }.where((c) => c.isNotEmpty).toList();

    final result = await Navigator.of(context).push<EditItemResult>(
      MaterialPageRoute(
        builder: (context) => EditItemScreen(
          initialName: item.name,
          initialCode: item.code,
          initialCategory: item.category,
          initialRate: item.price,
          initialOnline: item.online,
          initialActive: item.active,
          initialImageBytes: item.localImageBytes,
          existingCategories: allCategories,
        ),
      ),
    );

    if (result == null) return;

    setState(() => _isProcessing = true);

    if (result.imageBytes != null) {
      await LocalImageStorage.saveItemImage(
        id: item.id,
        code: result.code,
        name: result.name,
        bytes: result.imageBytes!,
      );
    }

    final index = _items.indexOf(item);
    if (index == -1) {
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    final draft = ApiItemDraft(
      name: result.name,
      code: result.code,
      category: result.category,
      rate: result.rate,
      active: result.active,
      availableOnline: result.online,
      imageBase64: result.imageBytes != null ? base64Encode(result.imageBytes!) : null,
    );
    ApiItem? savedItem;
    String? errorMessage;
    if (item.id != null) {
      try {
        savedItem = await RestaurantApi.instance.updateItem(item.id!, draft);
      } catch (e) {
        errorMessage = e.toString();
      }
    }

    if (mounted) {
      setState(() {
        _items[index] = savedItem == null
            ? _MenuItem.fromEditResult(result).copyWith(id: item.id)
            : _MenuItem.fromApiItem(savedItem).copyWith(localImageBytes: result.imageBytes);
        _isProcessing = false;
      });

      if (errorMessage != null) {
        _showSnackBar('Updated locally: $errorMessage');
      } else {
        _showSnackBar('Changes saved');
      }
    }
  }

  Future<void> _deleteItem(_MenuItem item) async {
    setState(() => _isProcessing = true);

    await LocalImageStorage.deleteItemImage(
      id: item.id,
      code: item.code,
      name: item.name,
    );

    if (item.id != null) {
      try {
        await RestaurantApi.instance.deleteItem(item.id!);
        if (mounted) {
          setState(() {
            _items.remove(item);
            _isProcessing = false;
          });
          _showSnackBar('${item.name} deleted');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showSnackBar('Failed to delete ${item.name}: $e');
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _items.remove(item);
          _isProcessing = false;
        });
        _showSnackBar('${item.name} deleted');
      }
    }
  }

  Future<void> _toggleActiveStatus(_MenuItem item) async {
    final newActive = !item.active;

    setState(() {
      item.active = newActive;
      _isProcessing = true;
    });

    if (item.id != null) {
      try {
        await RestaurantApi.instance.updateItemStatus(
          item.id!,
          active: newActive,
        );
      } catch (_) {
        if (mounted) {
          setState(() {
            item.active = !newActive;
            _isProcessing = false;
          });
        }
        _showSnackBar('Failed to update status');
        return;
      }
    }

    if (mounted) setState(() => _isProcessing = false);

    _showSnackBar(
      '${item.name} is now ${newActive ? 'Active' : 'Inactive'}',
    );
  }

  Future<void> _editCategory(String oldName) async {
    final controller = TextEditingController(text: oldName);
    final updated = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Category', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Category Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111111),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != null && updated.isNotEmpty && updated != oldName) {
      final prefs = await SharedPreferences.getInstance();
      final customCategories = prefs.getStringList('custom_categories') ?? [];
      final index = customCategories.indexOf(oldName);
      if (index != -1) {
        customCategories[index] = updated;
      } else {
        customCategories.add(updated);
      }
      await prefs.setStringList('custom_categories', customCategories);

      for (var i = 0; i < _items.length; i++) {
        if (_items[i].category == oldName) {
          _items[i] = _items[i].copyWith(category: updated);
        }
      }

      if (_selectedCategory == oldName) {
        _selectedCategory = updated;
      }

      await _loadCustomCategories();
      _showSnackBar('Category updated to "$updated"');
      setState(() {});
    }
  }

  Future<void> _deleteCategory(String categoryName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Category', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete category "$categoryName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      final customCategories = prefs.getStringList('custom_categories') ?? [];
      await prefs.setStringList('custom_categories', customCategories..remove(categoryName));

      setState(() {
        if (_selectedCategory == categoryName) {
          _selectedCategory = 'All Items';
        }
      });

      await _loadCustomCategories();
      _showSnackBar('Category "$categoryName" deleted');
    }
  }

  Future<void> _manageCategories() async {
    final allCategories = <String>{
      ..._items.map((e) => e.category),
      ..._customCategories,
    }.where((c) => c.isNotEmpty).toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // iOS Sheet Drag Handle Bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4D4D4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Modal Header Title & Add Category Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Manage Categories',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111111),
                        letterSpacing: -0.3,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add Category',
                      icon: const Icon(Icons.add_circle_outline, size: 24, color: Color(0xFF111111)),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _addCategory();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                if (allCategories.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text('No categories found', style: GoogleFonts.inter(color: Colors.grey)),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(top: 4),
                      itemCount: allCategories.length,
                      separatorBuilder: (ctx, idx) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      itemBuilder: (ctx, idx) {
                        final cat = allCategories[idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                cat,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF111111),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Edit category',
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF262626)),
                                    onPressed: () async {
                                      Navigator.of(ctx).pop();
                                      await _editCategory(cat);
                                    },
                                  ),
                                  const SizedBox(width: 14),
                                  IconButton(
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Delete category',
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFF25442)),
                                    onPressed: () async {
                                      Navigator.of(ctx).pop();
                                      await _deleteCategory(cat);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadItemsFromDatabase({bool forceRefresh = false}) async {
    try {
      final items = await RestaurantApi.instance.fetchItems(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(items.map(_MenuItem.fromApiItem));
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _MenuItem {
  _MenuItem({
    this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.price,
    required this.active,
    required this.online,
    this.localImageBytes,
    this.imageUrl,
  });

  factory _MenuItem.fromEditResult(EditItemResult result, {String? id}) {
    return _MenuItem(
      id: id,
      name: result.name,
      code: result.code,
      category: result.category,
      price: result.rate,
      active: result.active,
      online: result.online,
      localImageBytes: result.imageBytes,
    );
  }

  factory _MenuItem.fromApiItem(ApiItem item) {
    return _MenuItem(
      id: item.id,
      name: item.name,
      code: item.code,
      category: item.category,
      price: item.rate,
      active: item.active,
      online: item.availableOnline,
      imageUrl: item.imageUrl,
    );
  }

  final String? id;
  final String name;
  final String code;
  final String category;
  final double price;
  bool active;
  bool online;
  Uint8List? localImageBytes;
  String? imageUrl;

  _MenuItem copyWith({
    String? id,
    String? name,
    String? code,
    String? category,
    double? price,
    bool? active,
    bool? online,
    Uint8List? localImageBytes,
    String? imageUrl,
  }) {
    return _MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      category: category ?? this.category,
      price: price ?? this.price,
      active: active ?? this.active,
      online: online ?? this.online,
      localImageBytes: localImageBytes ?? this.localImageBytes,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
