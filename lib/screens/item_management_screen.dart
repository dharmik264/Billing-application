import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/restaurant_api.dart';
import 'edit_item_screen.dart';
import '../widgets/skeleton_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../utils/local_storage_helper.dart';

class ItemManagementScreen extends StatefulWidget {
  const ItemManagementScreen({super.key});

  @override
  State<ItemManagementScreen> createState() => _ItemManagementScreenState();
}

class _ItemManagementScreenState extends State<ItemManagementScreen> {
  static const Color _panelBackground = Color(0xFFF5F6FA);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _orange = Color(0xFFEA580C);
  String _selectedCategory = 'All Items';
  final bool _showOnlyActive = false;

  final TextEditingController _searchController = TextEditingController();
  final List<_MenuItem> _items = [];
  bool _loading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadItemsFromDatabase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _panelBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                _buildCategoryTabs(),
                Expanded(child: _buildItemList()),
              ],
            ),
            if (_isProcessing)
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

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFEEF2FF),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Item Management',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _isProcessing ? null : _addCategory,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.category_rounded, size: 14, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 6),
                      Text('Category', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF4F46E5))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isProcessing ? null : _addItem,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_circle_outline, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('Item', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSearch(),
        ],
      ),
    );
  }

  // ── Search ─────────────────────────────────────────────────

  Widget _buildSearch() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search items by name or code...',
                hintStyle: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w400),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: _searchController.clear,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Category tabs ──────────────────────────────────────────

  Widget _buildCategoryTabs() {
    final categories = <String>['All Items'];
    for (final item in _items) {
      if (!categories.contains(item.category)) categories.add(item.category);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (var i = 0; i < categories.length; i++) ...[
              _categoryChip(categories[i]),
              if (i != categories.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String value) {
    final selected = _selectedCategory == value;
    final label = value == 'All Items' ? 'All Items (${_items.length})' : value;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4F46E5) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // ── Item list ──────────────────────────────────────────────

  Widget _buildItemList() {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        itemCount: 6,
        itemBuilder: (context, index) => const SkeletonListItem(),
      );
    }

    final items = _filteredItems;

    return Stack(
      children: [
        items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 16),
                      Text(
                        'No items found',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) => _itemCard(items[index]),
              ),
        if (_isProcessing)
          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(alpha: 0.5),
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
            ),
          ),
      ],
    );
  }

  Widget _itemCard(_MenuItem item) {
    final isActive = item.active;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: item.localImageBytes != null
                    ? Image.memory(
                        item.localImageBytes!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      )
                    : FutureBuilder<Uint8List?>(
                        future: LocalImageStorage.loadImageBytes('item_image_${item.code}.png'),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                            return Image.memory(
                              snapshot.data!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            );
                          }
                          return Icon(
                            Icons.restaurant_menu_rounded,
                            size: 24,
                            color: isActive ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                          );
                        },
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        _statusBadge(isActive),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.code} • ${item.category}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${item.price.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isActive ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                          ),
                        ),
                        _activeSwitch(item),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _editItem(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF475569)),
                      const SizedBox(width: 6),
                      Text('Edit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _deleteItem(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                      const SizedBox(width: 6),
                      Text('Delete', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: active ? const Color(0xFF059669) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  /// Toggle switch for Active / Inactive status
  Widget _activeSwitch(_MenuItem item) {
    return GestureDetector(
      onTap: () => _toggleActiveStatus(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(3),
        alignment: item.active ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: item.active ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ── Filtering ──────────────────────────────────────────────

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

  // ── Actions ────────────────────────────────────────────────

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
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
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
    final result = await Navigator.of(context).push<EditItemResult>(
      MaterialPageRoute(
        builder: (context) => EditItemScreen(initialCode: 'C-$nextNumber'),
      ),
    );

    if (result == null) return;

    setState(() => _isProcessing = true);
    
    if (result.imageBytes != null) {
      await LocalImageStorage.saveImage('item_image_${result.code}.png', result.imageBytes!);
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
        ),
      ),
    );

    if (result == null) return;

    setState(() => _isProcessing = true);
    
    if (result.imageBytes != null) {
      await LocalImageStorage.saveImage('item_image_${result.code}.png', result.imageBytes!);
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
      // Local only item
      if (mounted) {
        setState(() {
          _items.remove(item);
          _isProcessing = false;
        });
        _showSnackBar('${item.name} deleted');
      }
    }
  }

  /// Immediately toggle active/inactive and persist to DB.
  Future<void> _toggleActiveStatus(_MenuItem item) async {
    final newActive = !item.active;

    // Optimistic update
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
        // Revert on failure
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

// ── Data classes ───────────────────────────────────────────────

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

  _MenuItem copyWith({
    String? id,
    String? name,
    String? code,
    String? category,
    double? price,
    bool? active,
    bool? online,
    Uint8List? localImageBytes,
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
    );
  }
}
