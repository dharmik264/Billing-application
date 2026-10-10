import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/restaurant_api.dart';
import '../utils/pdf_export.dart';
import '../utils/csv_export.dart';
import '../utils/bill_event_notifier.dart';
import 'customer_ledger_screen.dart';

class AnalyticsReportsScreen extends StatefulWidget {
  const AnalyticsReportsScreen({super.key});

  @override
  State<AnalyticsReportsScreen> createState() => _AnalyticsReportsScreenState();
}

class _AnalyticsReportsScreenState extends State<AnalyticsReportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<_HistoryToken> _tokens = [];
  final List<ApiCustomer> _customers = [];

  String _selectedRange = 'Today';
  String _activeReportType = 'Bills';
  DateTime? _customStart;
  DateTime? _customEnd;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadTokensFromDatabase();
    BillEventNotifier.billRefreshNotifier.addListener(_onBillChanged);
  }

  void _onBillChanged() {
    if (mounted) {
      _loadTokensFromDatabase();
    }
  }

  @override
  void dispose() {
    BillEventNotifier.billRefreshNotifier.removeListener(_onBillChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ANALYTICS REPORTS',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111111),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'DHARA FOOD POS',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF666666),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh data',
            icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF111111)),
            onPressed: _loadTokensFromDatabase,
          ),
          IconButton(
            tooltip: 'Quick range selector',
            icon: const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF111111)),
            onPressed: _pickDateRange,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE5E5E5)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search Input Container
                      _buildSearchBar(),
                      const SizedBox(height: 10),

                      // Period Horizontal Filters (Date Range)
                      _buildPeriodFilters(),
                      const SizedBox(height: 10),

                      // Report Category Segmented Tabs
                      _buildCategoryTabs(),
                      const SizedBox(height: 12),

                      // Minimal Business Export Action Buttons
                      _buildExportActions(),
                      const SizedBox(height: 14),

                      // Data Table Frame Container
                      _buildDataTableContainer(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
                if (_loading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.6),
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



  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF111111)),
      decoration: InputDecoration(
        hintText: 'Search token number or customer...',
        hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFA3A3A3)),
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
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF111111), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPeriodFilters() {
    final ranges = ['All', 'Today', 'Yesterday', 'This Week'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final r in ranges) ...[
            _periodPill(r),
            const SizedBox(width: 6),
          ],
          Builder(builder: (context) {
            final isCustom = !ranges.contains(_selectedRange);
            return GestureDetector(
              onTap: _pickDateRange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isCustom ? const Color(0xFF111111) : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isCustom ? const Color(0xFF111111) : const Color(0xFFD8D8D8),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: 14,
                  color: isCustom ? Colors.white : const Color(0xFF111111),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _periodPill(String rangeLabel) {
    final selected = _selectedRange == rangeLabel;
    return GestureDetector(
      onTap: () => setState(() => _selectedRange = rangeLabel),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111111) : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? const Color(0xFF111111) : const Color(0xFFD8D8D8),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              rangeLabel,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF111111),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    const reportTypes = ['Bills', 'Item Detail', 'Item Summary', 'Customer Detail', 'Customer Summary', 'Customer Ledger'];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5), width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (final rType in reportTypes) ...[
              _categoryTab(rType),
              const SizedBox(width: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _categoryTab(String label) {
    final selected = _activeReportType == label;
    return GestureDetector(
      onTap: () => setState(() => _activeReportType = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? const Color(0xFF111111) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? const Color(0xFF111111) : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }

  Widget _buildExportActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _exportToPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 15, color: Color(0xFF666666)),
            label: Text(
              'EXPORT PDF',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111111),
                letterSpacing: 0.5,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _exportToCsv,
            icon: const Icon(Icons.table_view_outlined, size: 15, color: Color(0xFF666666)),
            label: Text(
              'EXPORT EXCEL',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111111),
                letterSpacing: 0.5,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTableContainer() {
    final recordCount = _getRecordCountForActiveReport();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Header
          _buildTableHeader(),

          // Body (List View or Empty State)
          if (recordCount == 0)
            _buildEmptyStateView()
          else
            _buildActiveReportList(),

          // Table Footer Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(top: BorderSide(color: Color(0xFFE5E5E5), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$recordCount records found',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF666666),
                  ),
                ),
                Text(
                  'Ledger synced',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    List<Widget> cols;

    switch (_activeReportType) {
      case 'Item Detail':
        cols = [
          const Expanded(flex: 4, child: Text('ITEM NAME')),
          const Expanded(flex: 4, child: Text('BILL / DATE')),
          const Expanded(flex: 2, child: Text('QTY x RATE', textAlign: TextAlign.right)),
          const Expanded(flex: 2, child: Text('SUBTOTAL', textAlign: TextAlign.right)),
        ];
        break;
      case 'Item Summary':
        cols = [
          const Expanded(flex: 1, child: Text('#')),
          const Expanded(flex: 6, child: Text('ITEM & CATEGORY')),
          const Expanded(flex: 2, child: Text('QTY SOLD', textAlign: TextAlign.right)),
          const Expanded(flex: 3, child: Text('REVENUE', textAlign: TextAlign.right)),
        ];
        break;
      case 'Customer Detail':
        cols = [
          const Expanded(flex: 5, child: Text('CUSTOMER')),
          const Expanded(flex: 4, child: Text('BILL / DATE')),
          const Expanded(flex: 3, child: Text('AMOUNT', textAlign: TextAlign.right)),
        ];
        break;
      case 'Customer Summary':
        cols = [
          const Expanded(flex: 1, child: Text('#')),
          const Expanded(flex: 5, child: Text('CUSTOMER & PHONE')),
          const Expanded(flex: 2, child: Text('ORDERS', textAlign: TextAlign.center)),
          const Expanded(flex: 4, child: Text('SPENT', textAlign: TextAlign.right)),
        ];
        break;
      case 'Customer Ledger':
        cols = [
          const Expanded(flex: 5, child: Text('CUSTOMER & PHONE')),
          const Expanded(flex: 2, child: Text('ORDERS', textAlign: TextAlign.center)),
          const Expanded(flex: 5, child: Text('BILLED / NET DUE', textAlign: TextAlign.right)),
        ];
        break;
      case 'Bills':
      default:
        cols = [
          const Expanded(flex: 3, child: Text('TOKEN #')),
          const Expanded(flex: 4, child: Text('TIME / ORDER')),
          const Expanded(flex: 2, child: Text('STATUS', textAlign: TextAlign.center)),
          const Expanded(flex: 3, child: Text('AMOUNT', textAlign: TextAlign.right)),
        ];
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5), width: 1)),
      ),
      child: Row(
        children: cols
            .map((c) => DefaultTextStyle(
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF666666),
                    letterSpacing: 0.5,
                  ),
                  child: c,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildEmptyStateView() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      constraints: const BoxConstraints(minHeight: 200),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
            ),
            child: const Icon(
              Icons.article_outlined,
              size: 20,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'NO TOKENS FOUND',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111111),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No bills recorded for today. Try adjusting date filters or search terms.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  int _getRecordCountForActiveReport() {
    switch (_activeReportType) {
      case 'Item Detail':
        int count = 0;
        for (final t in _filteredTokens) {
          count += t.items.length;
        }
        return count;
      case 'Item Summary':
        final set = <String>{};
        for (final t in _filteredTokens) {
          for (final i in t.items) {
            set.add(i.name);
          }
        }
        return set.length;
      case 'Customer Detail':
        return _filteredTokens.where((t) => t.customerName.isNotEmpty || t.customerPhone.isNotEmpty).length;
      case 'Customer Summary':
        final set = <String>{};
        for (final t in _filteredTokens) {
          final key = t.customerName.isNotEmpty ? t.customerName : (t.customerPhone.isNotEmpty ? t.customerPhone : 'Walk-in');
          set.add(key);
        }
        return set.length;
      case 'Customer Ledger':
        final query = _searchController.text.trim().toLowerCase();
        final set = <String>{};
        for (final t in _tokens) {
          final name = t.customerName.trim();
          final phone = t.customerPhone.trim();
          final lowerName = name.toLowerCase();
          final isUnnamed = phone.isEmpty && (name.isEmpty || lowerName == 'walk-in' || lowerName == 'walk-in customer' || lowerName == 'walkin');
          if (isUnnamed) continue;
          if (query.isNotEmpty) {
            if (!name.toLowerCase().contains(query) && !phone.toLowerCase().contains(query)) continue;
          }
          final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
          final normPhone = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
          final key = normPhone.isNotEmpty ? 'phone_$normPhone' : 'name_${name.trim().toLowerCase()}';
          set.add(key);
        }
        return set.length;
      case 'Bills':
      default:
        return _filteredTokens.length;
    }
  }

  Widget _buildActiveReportList() {
    switch (_activeReportType) {
      case 'Item Detail':
        return _buildItemDetailList();
      case 'Item Summary':
        return _buildItemSummaryList();
      case 'Customer Detail':
        return _buildCustomerDetailList();
      case 'Customer Summary':
        return _buildCustomerSummaryList();
      case 'Customer Ledger':
        return _buildCustomerLedgerList();
      case 'Bills':
      default:
        return _buildTokenList();
    }
  }

  Widget _buildTokenList() {
    final tokens = _filteredTokens;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tokens.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E5E5)),
      itemBuilder: (context, index) => _tokenRow(tokens[index]),
    );
  }

  Widget _tokenRow(_HistoryToken token) {
    final isReady = token.status == 'Ready' || token.status == 'Completed';
    final isCancelled = token.status == 'Cancelled';

    final badgeBg = isCancelled
        ? const Color(0xFFFEF2F2)
        : isReady
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFFFF7ED);
    final badgeFg = isCancelled
        ? const Color(0xFFDC2626)
        : isReady
            ? const Color(0xFF16A34A)
            : const Color(0xFFEA580C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token.shortId,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111111),
                  ),
                ),
                if (token.billNumber.isNotEmpty)
                  Text(
                    'Bill #${token.billNumber}',
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF666666)),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getDisplayTitle(token),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111111),
                  ),
                ),
                Text(
                  '${token.payment.isEmpty ? "N/A" : token.payment} • ${token.dateTimeString}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF666666)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  token.status,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: badgeFg,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _money(token.amount),
              textAlign: TextAlign.right,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111111),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDisplayTitle(_HistoryToken token) {
    final isDelivery = token.orderType.toLowerCase() == 'delivery';
    final cName = token.customerName.trim();
    String displayTitle;
    if (isDelivery) {
      displayTitle = cName.isNotEmpty ? 'Delivery - $cName' : 'Delivery';
    } else {
      displayTitle = cName.isNotEmpty ? 'Walk-in - $cName' : 'Walk-in';
    }
    return '$displayTitle (${token.title})';
  }

  Widget _buildItemDetailList() {
    final entries = <_ItemDetailEntry>[];
    for (final token in _filteredTokens) {
      for (final item in token.items) {
        entries.add(_ItemDetailEntry(
          date: token.dateTimeString,
          rawDate: token.rawDate,
          billNumber: token.billNumber.isNotEmpty ? token.billNumber : token.shortId,
          itemName: item.name,
          category: item.category,
          quantity: item.quantity,
          rate: item.rate,
          subtotal: item.subtotal,
        ));
      }
    }

    entries.sort((a, b) => b.rawDate.compareTo(a.rawDate));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E5E5)),
      itemBuilder: (context, index) {
        final item = entries[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF111111)),
                    ),
                    Text(
                      item.category.isNotEmpty ? item.category : 'General',
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF666666)),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bill #${item.billNumber}',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF111111)),
                    ),
                    Text(
                      item.date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF666666)),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${item.quantity} × ${_money(item.rate)}',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF666666)),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _money(item.subtotal),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF111111)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemSummaryList() {
    final map = <String, _ItemSummaryEntry>{};
    for (final token in _filteredTokens) {
      for (final item in token.items) {
        if (!map.containsKey(item.name)) {
          map[item.name] = _ItemSummaryEntry(
            itemName: item.name,
            category: item.category,
            totalQty: 0,
            totalRevenue: 0.0,
          );
        }
        final existing = map[item.name]!;
        map[item.name] = _ItemSummaryEntry(
          itemName: item.name,
          category: item.category.isNotEmpty ? item.category : existing.category,
          totalQty: existing.totalQty + item.quantity,
          totalRevenue: existing.totalRevenue + item.subtotal,
        );
      }
    }

    final summaries = map.values.toList()..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: summaries.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E5E5)),
      itemBuilder: (context, index) {
        final summary = summaries[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Text(
                  '#${index + 1}',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF666666)),
                ),
              ),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.itemName,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF111111)),
                    ),
                    Text(
                      summary.category.isNotEmpty ? summary.category : 'General',
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF666666)),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${summary.totalQty}',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF111111)),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  _money(summary.totalRevenue),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF111111)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomerDetailList() {
    final list = _filteredTokens
        .where((t) => t.customerName.isNotEmpty || t.customerPhone.isNotEmpty)
        .toList()
      ..sort((a, b) => b.rawDate.compareTo(a.rawDate));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E5E5)),
      itemBuilder: (context, index) {
        final token = list[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      token.customerName.trim().isNotEmpty ? token.customerName.trim() : token.title,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF111111)),
                    ),
                    Text(
                      token.customerPhone.isNotEmpty ? token.customerPhone : 'No Mobile',
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF666666)),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bill #${token.billNumber.isNotEmpty ? token.billNumber : token.shortId}',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF111111)),
                    ),
                    Text(
                      token.dateTimeString,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF666666)),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  _money(token.amount),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF111111)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomerSummaryList() {
    final map = <String, _CustomerSummaryEntry>{};
    for (final token in _filteredTokens) {
      final key = token.customerName.isNotEmpty
          ? token.customerName
          : (token.customerPhone.isNotEmpty ? token.customerPhone : 'Walk-in');

      if (!map.containsKey(key)) {
        map[key] = _CustomerSummaryEntry(
          customerName: key,
          customerPhone: token.customerPhone,
          totalOrders: 0,
          totalSpent: 0.0,
          lastPurchaseDate: token.dateTimeString,
        );
      }
      final existing = map[key]!;
      map[key] = _CustomerSummaryEntry(
        customerName: key,
        customerPhone: token.customerPhone.isNotEmpty ? token.customerPhone : existing.customerPhone,
        totalOrders: existing.totalOrders + 1,
        totalSpent: existing.totalSpent + token.amount,
        lastPurchaseDate: token.dateTimeString,
      );
    }

    final summaries = map.values.toList()..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: summaries.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E5E5)),
      itemBuilder: (context, index) {
        final summary = summaries[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Text(
                  '#${index + 1}',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF666666)),
                ),
              ),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.customerName,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF111111)),
                    ),
                    Text(
                      summary.customerPhone.isNotEmpty ? summary.customerPhone : 'No Mobile',
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF666666)),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${summary.totalOrders}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF111111)),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  _money(summary.totalSpent),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF111111)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomerLedgerList() {
    final map = <String, _CustomerLedgerSummary>{};
    final query = _searchController.text.trim().toLowerCase();

    for (final token in _tokens) {
      final name = token.customerName.trim();
      final phone = token.customerPhone.trim();

      final lowerName = name.toLowerCase();
      final isUnnamed = phone.isEmpty && (name.isEmpty || lowerName == 'walk-in' || lowerName == 'walk-in customer' || lowerName == 'walkin');
      if (isUnnamed) continue;

      if (query.isNotEmpty) {
        final matchesName = name.toLowerCase().contains(query);
        final matchesPhone = phone.toLowerCase().contains(query);
        if (!matchesName && !matchesPhone) continue;
      }

      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      final normPhone = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
      final key = normPhone.isNotEmpty ? 'phone_$normPhone' : 'name_${name.trim().toLowerCase()}';

      if (!map.containsKey(key)) {
        map[key] = _CustomerLedgerSummary(
          customerName: name.isNotEmpty ? name : phone,
          customerPhone: phone,
          totalOrders: 0,
          totalBilled: 0.0,
          totalPaid: 0.0,
          dueBalance: 0.0,
          lastTransactionDate: token.dateTimeString,
          tokens: [],
        );
      }

      final existing = map[key]!;
      final isCancelled = token.status.toLowerCase() == 'cancelled';
      final isPaid = token.isPaid || (token.payment.isNotEmpty && token.payment.toLowerCase() != 'credit' && token.payment.toLowerCase() != 'due' && !isCancelled);

      final billed = isCancelled ? 0.0 : token.amount;
      double paid = 0.0;
      if (!isCancelled) {
        if (isPaid) {
          paid = token.amount;
        } else if (token.receivedAmount > 0) {
          paid = token.receivedAmount;
        } else {
          paid = 0.0;
        }
      }

      existing.tokens.add(token);
      final newBilled = existing.totalBilled + billed;
      final newPaid = existing.totalPaid + paid;
      final netDue = (newBilled - newPaid) > 0 ? (newBilled - newPaid) : 0.0;

      map[key] = _CustomerLedgerSummary(
        customerName: name.isNotEmpty ? name : existing.customerName,
        customerPhone: phone.isNotEmpty ? phone : existing.customerPhone,
        totalOrders: existing.totalOrders + 1,
        totalBilled: newBilled,
        totalPaid: newPaid,
        dueBalance: netDue,
        lastTransactionDate: token.dateTimeString,
        tokens: existing.tokens,
      );
    }

    final summaries = map.values.toList()..sort((a, b) => b.totalBilled.compareTo(a.totalBilled));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: summaries.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E5E5)),
      itemBuilder: (context, index) {
        final summary = summaries[index];
        final netDueAmount = _getNetDueForCustomer(summary.customerName, summary.customerPhone, summary.dueBalance);
        final isDue = netDueAmount > 0;

        return InkWell(
          onTap: () => _openFullLedgerForSummary(summary),
          onLongPress: () => _openCustomerLedgerSheet(summary),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.customerName,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF111111)),
                      ),
                      Text(
                        summary.customerPhone.isNotEmpty ? summary.customerPhone : 'No Mobile',
                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF666666)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${summary.totalOrders}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF111111)),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _money(summary.totalBilled),
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF111111)),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDue ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isDue ? 'Due: ${_money(netDueAmount)}' : 'Paid in Full',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isDue ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportToCsv() async {
    final filtered = _filteredTokens;
    if (filtered.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export')));
      }
      return;
    }

    try {
      if (mounted) setState(() => _loading = true);

      if (_activeReportType == 'Customer Summary') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel export for Customer Summary coming soon!')));
        }
        return;
      }

      final pdfTokens = filtered.map((t) {
        String bNum = t.billNumber;
        if (bNum.isEmpty) {
          final digits = t.shortId.replaceAll(RegExp(r'[^0-9]'), '');
          bNum = digits.padLeft(4, '0');
        }

        final subtotal = t.items.fold(0.0, (sum, i) => sum + i.subtotal);
        final finalAmt = t.amount;
        final gstAmt = (finalAmt - subtotal) > 0 ? (finalAmt - subtotal) : 0.0;

        return PdfTokenRow(
          billNumber: bNum,
          tokenNumber: t.title.replaceFirst('Token ', ''),
          orderType: t.orderType,
          customerName: t.customerName,
          customerPhone: t.customerPhone,
          dateTime: t.dateTimeString,
          subtotal: subtotal > 0 ? subtotal : finalAmt,
          gstAmount: gstAmt,
          finalAmount: finalAmt,
          amount: finalAmt,
          payment: t.payment,
          status: t.status,
          items: t.items.map((i) => '${i.name} x${i.quantity}').join(', '),
        );
      }).toList();

      final totalAmount = filtered.fold(0.0, (sum, t) => sum + t.amount);

      await CsvExport.exportReport(
        tokens: pdfTokens,
        rangeLabel: _selectedRange,
        shopName: 'My Shop',
        totalAmount: totalAmount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Report exported to Excel successfully!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_HistoryToken> get _filteredTokens {
    final query = _searchController.text.trim().toLowerCase();

    List<_HistoryToken> rangeFiltered = _tokens.toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_selectedRange == 'All') {
      rangeFiltered = _tokens.toList();
    } else if (_selectedRange == 'Today') {
      rangeFiltered = _tokens
          .where((t) =>
              t.rawDate.year == today.year &&
              t.rawDate.month == today.month &&
              t.rawDate.day == today.day)
          .toList();
    } else if (_selectedRange == 'Yesterday') {
      final yesterday = today.subtract(const Duration(days: 1));
      rangeFiltered = _tokens
          .where((t) =>
              t.rawDate.year == yesterday.year &&
              t.rawDate.month == yesterday.month &&
              t.rawDate.day == yesterday.day)
          .toList();
    } else if (_selectedRange == 'This Week') {
      final weekAgo = today.subtract(const Duration(days: 7));
      rangeFiltered = _tokens
          .where((t) =>
              t.rawDate.isAfter(weekAgo) || t.rawDate.isAtSameMomentAs(weekAgo))
          .toList();
    } else if (_customStart != null && _customEnd != null) {
      final endOfDay = DateTime(
          _customEnd!.year, _customEnd!.month, _customEnd!.day, 23, 59, 59);
      rangeFiltered = _tokens.where((t) {
        return (t.rawDate.isAfter(_customStart!) ||
                t.rawDate.isAtSameMomentAs(_customStart!)) &&
            (t.rawDate.isBefore(endOfDay) ||
                t.rawDate.isAtSameMomentAs(endOfDay));
      }).toList();
    }

    return rangeFiltered.where((token) {
      if (query.isEmpty) return true;
      final matchTitle = token.title.toLowerCase().contains(query);
      final matchId = token.shortId.toLowerCase().contains(query);
      final matchPayment = token.payment.toLowerCase().contains(query);
      final matchCustomer = token.customerName.toLowerCase().contains(query) || token.customerPhone.contains(query);
      final matchOrderType = token.orderType.toLowerCase().contains(query);
      final matchItem = token.items.any((item) => item.name.toLowerCase().contains(query) || item.code.toLowerCase().contains(query));

      return matchTitle || matchId || matchPayment || matchCustomer || matchOrderType || matchItem;
    }).toList();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportToPdf() async {
    if (_filteredTokens.isEmpty) {
      _showSnackBar('No data to export');
      return;
    }

    _showSnackBar('Generating PDF...');

    try {
      if (_activeReportType == 'Item Detail') {
        final entries = <PdfItemDetailRow>[];
        for (final token in _filteredTokens) {
          for (final item in token.items) {
            entries.add(PdfItemDetailRow(
              date: token.dateTimeString,
              billNumber: token.billNumber.isNotEmpty ? token.billNumber : token.shortId,
              itemName: item.name,
              category: item.category,
              quantity: item.quantity,
              rate: item.rate,
              subtotal: item.subtotal,
            ));
          }
        }
        await PdfExport.exportItemDetailReport(
          items: entries,
          rangeLabel: _selectedRange,
          shopName: 'My Shop',
        );
      } else if (_activeReportType == 'Item Summary') {
        final map = <String, PdfItemSummaryRow>{};
        for (final token in _filteredTokens) {
          for (final item in token.items) {
            if (!map.containsKey(item.name)) {
              map[item.name] = PdfItemSummaryRow(
                itemName: item.name,
                category: item.category,
                totalQty: 0,
                totalRevenue: 0.0,
              );
            }
            final existing = map[item.name]!;
            map[item.name] = PdfItemSummaryRow(
              itemName: item.name,
              category: item.category.isNotEmpty ? item.category : existing.category,
              totalQty: existing.totalQty + item.quantity,
              totalRevenue: existing.totalRevenue + item.subtotal,
            );
          }
        }
        await PdfExport.exportItemSummaryReport(
          summary: map.values.toList()..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue)),
          rangeLabel: _selectedRange,
          shopName: 'My Shop',
        );
      } else if (_activeReportType == 'Customer Detail') {
        final entries = _filteredTokens.map((t) => PdfCustomerDetailRow(
          date: t.dateTimeString,
          customerName: t.customerName,
          customerPhone: t.customerPhone,
          billNumber: t.billNumber.isNotEmpty ? t.billNumber : t.shortId,
          amount: t.amount,
          paymentMode: t.payment,
          status: t.status,
        )).toList();
        await PdfExport.exportCustomerDetailReport(
          customers: entries,
          rangeLabel: _selectedRange,
          shopName: 'My Shop',
        );
      } else if (_activeReportType == 'Customer Summary') {
        final map = <String, PdfCustomerSummaryRow>{};
        for (final token in _filteredTokens) {
          final key = token.customerName.isNotEmpty
              ? token.customerName
              : (token.customerPhone.isNotEmpty ? token.customerPhone : 'Walk-in');
          if (!map.containsKey(key)) {
            map[key] = PdfCustomerSummaryRow(
              customerName: key,
              customerPhone: token.customerPhone,
              totalOrders: 0,
              totalSpent: 0.0,
              lastPurchaseDate: token.dateTimeString,
            );
          }
          final existing = map[key]!;
          map[key] = PdfCustomerSummaryRow(
            customerName: key,
            customerPhone: token.customerPhone.isNotEmpty ? token.customerPhone : existing.customerPhone,
            totalOrders: existing.totalOrders + 1,
            totalSpent: existing.totalSpent + token.amount,
            lastPurchaseDate: token.dateTimeString,
          );
        }
        await PdfExport.exportCustomerSummaryReport(
          summary: map.values.toList()..sort((a, b) => b.totalSpent.compareTo(a.totalSpent)),
          rangeLabel: _selectedRange,
          shopName: 'My Shop',
        );
      } else {
        final pdfTokens = _filteredTokens.map((t) {
          String bNum = t.billNumber;
          if (bNum.isEmpty) {
            final digits = t.shortId.replaceAll(RegExp(r'[^0-9]'), '');
            bNum = digits.padLeft(4, '0');
          }

          final subtotal = t.items.fold(0.0, (sum, i) => sum + i.subtotal);
          final finalAmt = t.amount;
          final gstAmt = (finalAmt - subtotal) > 0 ? (finalAmt - subtotal) : 0.0;

          return PdfTokenRow(
            billNumber: bNum,
            tokenNumber: t.title.replaceFirst('Token ', ''),
            orderType: t.orderType,
            customerName: t.customerName,
            customerPhone: t.customerPhone,
            dateTime: t.dateTimeString,
            subtotal: subtotal > 0 ? subtotal : finalAmt,
            gstAmount: gstAmt,
            finalAmount: finalAmt,
            amount: finalAmt,
            payment: t.payment,
            status: t.status,
            items: t.items.map((i) => '${i.name} x${i.quantity}').join(', '),
          );
        }).toList();

        final totalAmount = _filteredTokens.fold(0.0, (sum, t) => sum + t.amount);

        await PdfExport.exportReport(
          tokens: pdfTokens,
          rangeLabel: _selectedRange,
          shopName: 'My Shop',
          totalAmount: totalAmount,
        );
      }

      _showSnackBar('Report saved successfully');
    } catch (e) {
      _showSnackBar('Error exporting report: $e');
    }
  }

  Future<void> _openFullLedgerForSummary(_CustomerLedgerSummary summary) async {
    try {
      final searchParam = summary.customerPhone.isNotEmpty ? summary.customerPhone : summary.customerName;
      final customers = await RestaurantApi.instance.fetchCustomers(search: searchParam);

      ApiCustomer? match;
      if (summary.customerPhone.isNotEmpty) {
        final cleanPhone = summary.customerPhone.replaceAll(RegExp(r'\D'), '');
        match = customers.firstWhere(
          (c) => c.mobileNumber.replaceAll(RegExp(r'\D'), '').endsWith(cleanPhone) ||
                 cleanPhone.endsWith(c.mobileNumber.replaceAll(RegExp(r'\D'), '')),
          orElse: () => customers.firstWhere(
            (c) => c.name.toLowerCase() == summary.customerName.toLowerCase(),
            orElse: () => customers.isNotEmpty ? customers.first : _createDummyCustomer(summary),
          ),
        );
      } else {
        match = customers.firstWhere(
          (c) => c.name.toLowerCase() == summary.customerName.toLowerCase(),
          orElse: () => customers.isNotEmpty ? customers.first : _createDummyCustomer(summary),
        );
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerLedgerScreen(customer: match!),
        ),
      );
      _loadTokensFromDatabase();
    } catch (e) {
      final fallback = _createDummyCustomer(summary);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerLedgerScreen(customer: fallback),
        ),
      );
      _loadTokensFromDatabase();
    }
  }

  ApiCustomer _createDummyCustomer(_CustomerLedgerSummary summary) {
    return ApiCustomer(
      id: '0',
      name: summary.customerName,
      mobileNumber: summary.customerPhone,
      address: '',
      gstNumber: '',
      status: 'active',
      createdAt: '',
      updatedAt: '',
    );
  }

  void _openCustomerLedgerSheet(_CustomerLedgerSummary summary) {
    final sheetNetDue = _getNetDueForCustomer(summary.customerName, summary.customerPhone, summary.dueBalance);
    final isSheetDue = sheetNetDue > 0;

    final sortedTokens = [...summary.tokens]..sort((a, b) => a.rawDate.compareTo(b.rawDate));

    double runningBalance = 0.0;
    final ledgerEntries = <_CustomerLedgerEntry>[];

    for (final t in sortedTokens) {
      final isCancelled = t.status.toLowerCase() == 'cancelled';
      final isPaid = t.payment.isNotEmpty && t.payment.toLowerCase() != 'credit' && t.payment.toLowerCase() != 'due' && !isCancelled;

      final debit = isCancelled ? 0.0 : t.amount;
      final credit = (isCancelled || !isPaid) ? 0.0 : t.amount;

      runningBalance += (debit - credit);

      final itemsSummary = t.items.map((i) => '${i.name} x${i.quantity}').join(', ');
      final particulars = itemsSummary.isNotEmpty ? itemsSummary : 'Sales Invoice';

      ledgerEntries.add(_CustomerLedgerEntry(
        date: t.dateTimeString,
        rawDate: t.rawDate,
        billNumber: t.billNumber.isNotEmpty ? t.billNumber : t.shortId,
        particulars: particulars,
        debit: debit,
        credit: credit,
        runningBalance: runningBalance,
        paymentMode: t.payment.isNotEmpty ? t.payment : 'N/A',
        status: t.status,
      ));
    }

    final displayEntries = ledgerEntries.reversed.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEF2FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: Color(0xFF4F46E5), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.customerName,
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF111111)),
                          ),
                          Text(
                            'Phone: ${summary.customerPhone.isNotEmpty ? summary.customerPhone : "N/A"} · Ledger Statement',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF666666)),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openFullLedgerForSummary(summary);
                      },
                      icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                      label: Text('Ledger', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Billed', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF1E40AF), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            FittedBox(child: Text(_money(summary.totalBilled), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A)))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Paid', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF166534), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            FittedBox(child: Text(_money(summary.totalPaid), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF14532D)))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSheetDue ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSheetDue ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Net Due', style: GoogleFonts.inter(fontSize: 11, color: isSheetDue ? const Color(0xFF991B1B) : const Color(0xFF166534), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            FittedBox(child: Text(_money(sheetNetDue), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: isSheetDue ? const Color(0xFF991B1B) : const Color(0xFF14532D)))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Color(0xFFDC2626)),
                        label: Text('Statement PDF', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final pdfRows = ledgerEntries.map((e) => PdfCustomerLedgerRow(
                            date: e.date,
                            billNumber: e.billNumber,
                            particulars: e.particulars,
                            debit: e.debit,
                            credit: e.credit,
                            runningBalance: e.runningBalance,
                            paymentMode: e.paymentMode,
                            status: e.status,
                          )).toList();

                          final totalBilled = summary.totalBilled;
                          final effectivePaid = (totalBilled >= sheetNetDue)
                              ? (totalBilled - sheetNetDue)
                              : summary.totalPaid;

                          await PdfExport.exportCustomerLedgerReport(
                            customerName: summary.customerName,
                            customerPhone: summary.customerPhone,
                            ledgerRows: pdfRows,
                            rangeLabel: _selectedRange,
                            shopName: 'My Shop',
                            totalDebit: totalBilled,
                            totalCredit: effectivePaid,
                            netBalance: sheetNetDue,
                          );
                          if (mounted) {
                            _showSnackBar('Customer Ledger PDF statement downloaded!');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.table_view_outlined, size: 16, color: Color(0xFF16A34A)),
                        label: Text('Statement Excel', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFBBF7D0)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final pdfRows = ledgerEntries.map((e) => PdfCustomerLedgerRow(
                            date: e.date,
                            billNumber: e.billNumber,
                            particulars: e.particulars,
                            debit: e.debit,
                            credit: e.credit,
                            runningBalance: e.runningBalance,
                            paymentMode: e.paymentMode,
                            status: e.status,
                          )).toList();

                          final totalBilled = summary.totalBilled;
                          final effectivePaid = (totalBilled >= sheetNetDue)
                              ? (totalBilled - sheetNetDue)
                              : summary.totalPaid;

                          await CsvExport.exportCustomerLedgerReport(
                            customerName: summary.customerName,
                            customerPhone: summary.customerPhone,
                            ledgerRows: pdfRows,
                            rangeLabel: _selectedRange,
                            shopName: 'My Shop',
                            totalDebit: totalBilled,
                            totalCredit: effectivePaid,
                            netBalance: sheetNetDue,
                          );
                          if (mounted) {
                            _showSnackBar('Customer Ledger Excel downloaded!');
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: Container(
                  color: const Color(0xFFF8FAFC),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: displayEntries.length,
                    itemBuilder: (context, index) {
                      final entry = displayEntries[index];
                      final isCancelled = entry.status.toLowerCase() == 'cancelled';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Bill #${entry.billNumber}',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF111111)),
                                ),
                                Text(
                                  entry.date,
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF666666)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.particulars,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155)),
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Debit: ${_money(entry.debit)}',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E3A8A)),
                                    ),
                                    Text(
                                      'Credit: ${_money(entry.credit)}',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF166534)),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Balance: ${_money(entry.runningBalance)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: entry.runningBalance > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${entry.paymentMode} · ${isCancelled ? "Cancelled" : entry.status}',
                                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF666666), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _money(double amount) => '\u20B9${amount.toStringAsFixed(2)}';

  double _getNetDueForCustomer(String name, String phone, double fallbackDue) {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

    if (cleanPhone.isNotEmpty) {
      for (final c in _customers) {
        final cPhone = c.mobileNumber.replaceAll(RegExp(r'\D'), '');
        if (cPhone.isNotEmpty && cPhone == cleanPhone) {
          return c.hasNetDue ? c.netDue : fallbackDue;
        }
      }
      return fallbackDue;
    }

    final lowerName = name.trim().toLowerCase();
    if (lowerName.isNotEmpty) {
      for (final c in _customers) {
        if (c.name.trim().toLowerCase() == lowerName) {
          return c.hasNetDue ? c.netDue : fallbackDue;
        }
      }
    }
    return fallbackDue;
  }

  Future<void> _loadTokensFromDatabase() async {
    setState(() => _loading = true);
    try {
      final tokenListFuture = RestaurantApi.instance.fetchTokens().then<List<ApiToken>?>((t) => t).catchError((e) {
        debugPrint('Analytics: failed to load tokens: $e');
        return null;
      });
      final customerListFuture = RestaurantApi.instance.fetchCustomers().then<List<ApiCustomer>?>((c) => c).catchError((e) {
        debugPrint('Analytics: failed to load customers: $e');
        return null;
      });

      final tokens = await tokenListFuture;
      final customers = await customerListFuture;

      if (!mounted) return;
      setState(() {
        if (tokens != null && customers != null) {
          final activeTokens = tokens.where((token) {
            final name = token.customerName.trim().toLowerCase();
            final phone = token.customerPhone.trim();
            final isUnnamed = phone.isEmpty && (name.isEmpty || name == 'walk-in' || name == 'walk-in customer' || name == 'walkin');
            if (isUnnamed) return true;

            final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
            final normPhone = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
            
            if (normPhone.isNotEmpty) {
              return customers.any((c) => c.mobileNumber.replaceAll(RegExp(r'\D'), '').endsWith(normPhone));
            } else {
              return customers.any((c) => c.name.toLowerCase() == name);
            }
          }).toList();

          _tokens
            ..clear()
            ..addAll(activeTokens.map(_HistoryToken.fromApiToken));
        } else if (tokens != null) {
          _tokens
            ..clear()
            ..addAll(tokens.map(_HistoryToken.fromApiToken));
        }

        if (customers != null) {
          _customers
            ..clear()
            ..addAll(customers);
        }
      });
    } catch (e) {
      debugPrint('Analytics: failed to load tokens/customers: $e');
      if (mounted) {
        _showSnackBar('Network error. Using cached/demo data.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF111111),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1F2937),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 360,
                maxHeight: 600,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: const Size(360, 600),
                  ),
                  child: child!,
                ),
              ),
            ),
          ),
        );
      },
    );

    if (picked != null) {
      final start = '${picked.start.day}/${picked.start.month}';
      final end = '${picked.end.day}/${picked.end.month}';
      setState(() {
        _selectedRange = start == end ? start : '$start - $end';
        _customStart = picked.start;
        _customEnd = picked.end;
      });
    }
  }
}

class _HistoryToken {
  const _HistoryToken(
    this.shortId,
    this.title,
    this.billNumber,
    this.customerName,
    this.customerPhone,
    this.time,
    this.dateTimeString,
    this.amount,
    this.payment,
    this.status,
    this.rawDate,
    this.items,
    this.orderType, {
    this.receivedAmount = 0.0,
    this.balanceDue = 0.0,
    this.isPaid = false,
  });

  factory _HistoryToken.fromApiToken(ApiToken token) {
    final number = token.tokenNumber.startsWith('#')
        ? token.tokenNumber
        : '#${token.tokenNumber}';
    return _HistoryToken(
      '#${number.replaceAll(RegExp(r'[^0-9]'), '')}',
      'Token $number',
      token.billNumber,
      token.customerName,
      token.customerPhone,
      '',
      _formatDateTime(token.createdAt),
      token.grandTotal,
      token.paymentMode,
      _formatStatus(token.status),
      DateTime.tryParse(token.createdAt)?.toLocal() ?? DateTime.now(),
      token.items,
      token.orderType,
      receivedAmount: token.receivedAmount,
      balanceDue: token.balanceDue,
      isPaid: token.isPaid,
    );
  }

  final String shortId;
  final String title;
  final String billNumber;
  final String customerName;
  final String customerPhone;
  final String time;
  final String dateTimeString;
  final double amount;
  final String payment;
  final String status;
  final DateTime rawDate;
  final List<ApiTokenItem> items;
  final String orderType;
  final double receivedAmount;
  final double balanceDue;
  final bool isPaid;
}

String _formatStatus(String status) {
  final normalized = status.toUpperCase();
  if (normalized == 'COMPLETED') return 'Completed';
  if (normalized == 'CANCELLED') return 'Cancelled';
  if (normalized == 'READY') return 'Ready';
  return 'Pending';
}

String _formatDateTime(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return 'Just now';
  final local = parsed.toLocal();

  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year;

  final hour = local.hour == 0
      ? 12
      : local.hour > 12
          ? local.hour - 12
          : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';

  return '$day/$month/$year, $hour:$minute $suffix';
}

class _ItemDetailEntry {
  final String date;
  final DateTime rawDate;
  final String billNumber;
  final String itemName;
  final String category;
  final int quantity;
  final double rate;
  final double subtotal;

  _ItemDetailEntry({
    required this.date,
    required this.rawDate,
    required this.billNumber,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.rate,
    required this.subtotal,
  });
}

class _ItemSummaryEntry {
  final String itemName;
  final String category;
  final int totalQty;
  final double totalRevenue;

  _ItemSummaryEntry({
    required this.itemName,
    required this.category,
    required this.totalQty,
    required this.totalRevenue,
  });
}

class _CustomerSummaryEntry {
  final String customerName;
  final String customerPhone;
  final int totalOrders;
  final double totalSpent;
  final String lastPurchaseDate;

  _CustomerSummaryEntry({
    required this.customerName,
    required this.customerPhone,
    required this.totalOrders,
    required this.totalSpent,
    required this.lastPurchaseDate,
  });
}

class _CustomerLedgerSummary {
  final String customerName;
  final String customerPhone;
  final int totalOrders;
  final double totalBilled;
  final double totalPaid;
  final double dueBalance;
  final String lastTransactionDate;
  final List<_HistoryToken> tokens;

  _CustomerLedgerSummary({
    required this.customerName,
    required this.customerPhone,
    required this.totalOrders,
    required this.totalBilled,
    required this.totalPaid,
    required this.dueBalance,
    required this.lastTransactionDate,
    required this.tokens,
  });
}

class _CustomerLedgerEntry {
  final String date;
  final DateTime rawDate;
  final String billNumber;
  final String particulars;
  final double debit;
  final double credit;
  final double runningBalance;
  final String paymentMode;
  final String status;

  _CustomerLedgerEntry({
    required this.date,
    required this.rawDate,
    required this.billNumber,
    required this.particulars,
    required this.debit,
    required this.credit,
    required this.runningBalance,
    required this.paymentMode,
    required this.status,
  });
}
