import 'package:flutter/material.dart';
import '../services/restaurant_api.dart';
import 'edit_item_screen.dart';
import '../widgets/skeleton_loader.dart';

class ItemManagementScreen extends StatefulWidget {
  const ItemManagementScreen({super.key});

  @override
  State<ItemManagementScreen> createState() => _ItemManagementScreenState();
}

class _ItemManagementScreenState extends State<ItemManagementScreen> {
  static const Color _panelBackground = Color(0xFFF5F6FA);
  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _muted = Color(0xFFAAAAAA);
  static const Color _softBorder = Color(0xFFEEEEEE);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _orange = Color(0xFFEA580C);
  static const Color _green = Color(0xFF16A34A);
  String _selectedCategory = 'All Items';
  bool _showOnlyActive = false;

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
                _buildSearch(),
                _buildCategoryTabs(),
                Expanded(child: _buildItemList()),
                _buildAddItemButton(),
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
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _softBorder, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Flexible(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'Item Management',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh Menu',
            onPressed: () => _loadItemsFromDatabase(forceRefresh: true),
            icon: const Icon(Icons.sync, size: 20, color: Color(0xFF555555)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            splashRadius: 18,
          ),
          IconButton(
            tooltip: 'Filter active items',
            onPressed: () {
              setState(() => _showOnlyActive = !_showOnlyActive);
              _showSnackBar(
                _showOnlyActive ? 'Showing active items' : 'Showing all items',
              );
            },
            icon: Icon(
              Icons.tune,
              size: 20,
              color: _showOnlyActive ? _orange : const Color(0xFF555555),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  // ── Search ─────────────────────────────────────────────────

  Widget _buildSearch() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _panelBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 16, color: _muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14, color: _textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search by name or code...',
                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _searchController.clear,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 16, color: _muted),
                ),
              ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: _softBorder, width: 0.5),
          bottom: BorderSide(color: _softBorder, width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
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

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _selectedCategory = value),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 14 : 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111111) : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? Colors.white : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }

  // ── Item list ──────────────────────────────────────────────

  Widget _buildItemList() {
    if (_loading) {
      return ListView.builder(
        itemCount: 6,
        itemBuilder: (context, index) => const SkeletonListItem(),
      );
    }

    final items = _filteredItems;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: items.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _softBorder, width: 0.5),
                  ),
                  child: const Text(
                    'No matching items',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: _textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) => _itemCard(items[index], isLast: index == items.length - 1),
                ),
        ),
        if (_isProcessing)
          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(alpha: 0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _itemCard(_MenuItem item, {required bool isLast}) {
    final activeTextColor = item.active ? _textPrimary : _muted;
    final secondaryColor = item.active ? _muted : const Color(0xFFCCCCCC);

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 14 : 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _softBorder, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Opacity(
                opacity: item.active ? 1 : 0.5,
                child: Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu,
                    size: 24,
                    color: Color(0xFFCCCCCC),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: activeTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _statusBadge(item.active),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${item.code} · ${item.category}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: secondaryColor),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${item.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: activeTextColor,
                          ),
                        ),
                        // Active / Inactive toggle
                        Row(
                          children: [
                            Text(
                              item.active ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 11,
                                color: item.active ? _green : secondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _activeSwitch(item),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _cardButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  background: _panelBackground,
                  border: _softBorder,
                  color: _textSecondary,
                  onTap: () => _editItem(item),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _cardButton(
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  background: const Color(0xFFFEF2F2),
                  border: const Color(0xFFFECACA),
                  color: _danger,
                  onTap: () => _deleteItem(item),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFD1FAE5) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: active ? const Color(0xFF065F46) : _textSecondary,
        ),
      ),
    );
  }

  /// Toggle switch for Active / Inactive status
  Widget _activeSwitch(_MenuItem item) {
    return GestureDetector(
      onTap: () => _toggleActiveStatus(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 38,
        height: 22,
        padding: const EdgeInsets.all(3),
        alignment: item.active ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: item.active ? _green : const Color(0xFFDDDDDD),
          borderRadius: BorderRadius.circular(11),
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
    );
  }

  Widget _cardButton({
    required String label,
    required IconData icon,
    required Color background,
    required Color border,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }

  // ── Add Item button (always visible) ──────────────────────

  Widget _buildAddItemButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _orange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isProcessing ? null : _addItem,
          icon: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.add, size: 20),
          label: Text(
            _isProcessing ? 'Processing...' : 'Add Item',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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

  Future<void> _addItem() async {
    final nextNumber = 9000 + _items.length + 1;
    final result = await Navigator.of(context).push<EditItemResult>(
      MaterialPageRoute(
        builder: (context) => EditItemScreen(initialCode: 'C-$nextNumber'),
      ),
    );

    if (result == null) return;

    setState(() => _isProcessing = true);

    final draft = ApiItemDraft(
      name: result.name,
      code: result.code,
      category: result.category,
      rate: result.rate,
      active: result.active,
      availableOnline: result.online,
      imageBase64: result.imageBase64,
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
              : _MenuItem.fromApiItem(savedItem),
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
        ),
      ),
    );

    if (result == null) return;

    setState(() => _isProcessing = true);

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
      imageBase64: result.imageBase64,
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
            : _MenuItem.fromApiItem(savedItem);
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
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _items.remove(item);
        _isProcessing = false;
      });
    }
    _showSnackBar('${item.name} deleted');
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

  _MenuItem copyWith({
    String? id,
    String? name,
    String? code,
    String? category,
    double? price,
    bool? active,
    bool? online,
  }) {
    return _MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      category: category ?? this.category,
      price: price ?? this.price,
      active: active ?? this.active,
      online: online ?? this.online,
    );
  }
}
