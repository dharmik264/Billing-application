import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/restaurant_api.dart';
import '../utils/pdf_export.dart';
import '../utils/csv_export.dart';
import '../widgets/custom_page_header.dart';

class AnalyticsReportsScreen extends StatefulWidget {
  const AnalyticsReportsScreen({super.key});

  @override
  State<AnalyticsReportsScreen> createState() => _AnalyticsReportsScreenState();
}

class _AnalyticsReportsScreenState extends State<AnalyticsReportsScreen> {
  static const Color _panelBackground = Color(0xFFF8FAFC);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  final TextEditingController _searchController = TextEditingController();
  final List<_HistoryToken> _tokens = [];

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
      appBar: const CustomAppBar(
        title: 'Analytics Reports',
        icon: Icons.bar_chart_rounded,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                CustomSearchActionView(
                  searchHint: 'Search token number or customer...',
                  searchController: _searchController,
                  onSearchClear: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  filterChips: <String>['Today', 'Yesterday', 'This Week'].map((range) => FilterChipData(
                    label: range,
                    value: range,
                    icon: Icons.calendar_month_rounded,
                  )).toList(),
                  selectedFilterValue: _selectedRange,
                  onFilterChanged: (val) => setState(() => _selectedRange = val),
                  actionButtons: [
                    ElevatedButton(
                      onPressed: _pickDateRange,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF64748B),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                  ],
                ),
                _reportTypeTabs(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Column(
                    children: [
                      _summaryHeader(),
                      const SizedBox(height: 12),
                      _exportButton(),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
                Expanded(child: _buildActiveReportView()),
              ],
            ),
            if (_loading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.05),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _reportTypeTabs() {
    const reportTypes = ['Bills', 'Item Detail', 'Item Summary', 'Customer Detail', 'Customer Summary'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (final rType in reportTypes) ...[
              _reportTypeChip(rType),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reportTypeChip(String label) {
    final selected = _activeReportType == label;
    return GestureDetector(
      onTap: () => setState(() => _activeReportType = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveReportView() {
    switch (_activeReportType) {
      case 'Item Detail':
        return _buildItemDetailList();
      case 'Item Summary':
        return _buildItemSummaryList();
      case 'Customer Detail':
        return _buildCustomerDetailList();
      case 'Customer Summary':
        return _buildCustomerSummaryList();
      case 'Bills':
      default:
        return _buildTokenList();
    }
  }

  Widget _buildTokenList() {
    final tokens = _filteredTokens;
    if (tokens.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Text('No tokens found.', style: GoogleFonts.inter(color: _textSecondary, fontSize: 16)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: tokens.length,
        itemBuilder: (context, index) => _tokenRow(tokens[index]),
      ),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
            ),
            child: Text(
              token.shortId,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: badgeFg,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getDisplayTitle(token),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${token.payment.isEmpty ? 'N/A' : token.payment} · ${token.dateTimeString}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(token.amount),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  token.status,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
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



  Widget _summaryHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Total Tokens: ${_filteredTokens.length}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 14, color: _textSecondary, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Total: ${_money(_filteredTokens.fold(0, (sum, item) => sum + item.amount))}',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF16A34A),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _exportButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _exportToPdf,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Export PDF',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _exportToCsv,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.table_view_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Export Excel',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

        return PdfTokenRow(
          billNumber: bNum,
          tokenNumber: t.title.replaceFirst('Token ', ''),
          orderType: t.orderType,
          customerName: t.customerName,
          customerPhone: t.customerPhone,
          dateTime: t.dateTimeString,
          amount: t.amount,
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

    // First, filter by selected date range
    List<_HistoryToken> rangeFiltered = _tokens.toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_selectedRange == 'Today') {
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
      // It's a custom date range
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

          return PdfTokenRow(
            billNumber: bNum,
            tokenNumber: t.title.replaceFirst('Token ', ''),
            orderType: t.orderType,
            customerName: t.customerName,
            customerPhone: t.customerPhone,
            dateTime: t.dateTimeString,
            amount: t.amount,
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

  // ── Item Detail List (Date Order wise) ──────────────────────────
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

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Text('No item transactions found.', style: GoogleFonts.inter(color: _textSecondary, fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final item = entries[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fastfood_rounded, color: Color(0xFF4F46E5), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: _textPrimary)),
                    const SizedBox(height: 2),
                    Text('Bill: ${item.billNumber} · ${item.date}', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_money(item.subtotal), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF10B981))),
                  const SizedBox(height: 2),
                  Text('${item.quantity} x ${_money(item.rate)}', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Item Summary List ─────────────────────────────────────────
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

    if (summaries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Text('No item summary data found.', style: GoogleFonts.inter(color: _textSecondary, fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final summary = summaries[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('#${index + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFFD97706), fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary.itemName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: _textPrimary)),
                    const SizedBox(height: 2),
                    Text(summary.category.isNotEmpty ? summary.category : 'General', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_money(summary.totalRevenue), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF4F46E5))),
                  const SizedBox(height: 2),
                  Text('Qty Sold: ${summary.totalQty}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF059669))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Customer Detail List (Date Order wise) ──────────────────────
  Widget _buildCustomerDetailList() {
    final list = _filteredTokens.where((t) => t.customerName.isNotEmpty || t.customerPhone.isNotEmpty).toList()..sort((a, b) => b.rawDate.compareTo(a.rawDate));

    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Text('No customer transactions found.', style: GoogleFonts.inter(color: _textSecondary, fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final token = list[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_outline_rounded, color: Color(0xFF059669), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(token.customerName.isNotEmpty ? token.customerName : 'Walk-in Customer', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: _textPrimary)),
                    const SizedBox(height: 2),
                    Text('${token.customerPhone.isNotEmpty ? token.customerPhone : 'No Mobile'} · ${token.dateTimeString}', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_money(token.amount), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF059669))),
                  const SizedBox(height: 2),
                  Text('${token.billNumber} (${token.payment})', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Customer Summary List ──────────────────────────────────────
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

    if (summaries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Text('No customer summary data found.', style: GoogleFonts.inter(color: _textSecondary, fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final summary = summaries[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('#${index + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5), fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary.customerName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: _textPrimary)),
                    const SizedBox(height: 2),
                    Text('${summary.customerPhone.isNotEmpty ? summary.customerPhone : 'No Mobile'} · Orders: ${summary.totalOrders}', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_money(summary.totalSpent), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF10B981))),
                  const SizedBox(height: 2),
                  Text('Last: ${summary.lastPurchaseDate.split(',').first}', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _money(double amount) => '\u20B9${amount.toStringAsFixed(2)}';

  Future<void> _loadTokensFromDatabase() async {
    setState(() => _loading = true);
    try {
      final tokens = await RestaurantApi.instance.fetchTokens();
      if (!mounted) return;
      setState(() {
        _tokens
          ..clear()
          ..addAll(tokens.map(_HistoryToken.fromApiToken));
      });
    } catch (e) {
      debugPrint('Analytics: failed to load tokens: $e');
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
              primary: Color(0xFF111111), // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Color(0xFF1F2937), // body text color
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
                    size: const Size(
                        360, 600), // Force narrow size to simulate mobile view
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
    this.orderType,
  );

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
      '', // legacy time field
      _formatDateTime(token.createdAt),
      token.grandTotal,
      token.paymentMode,
      _formatStatus(token.status),
      DateTime.tryParse(token.createdAt)?.toLocal() ?? DateTime.now(),
      token.items,
      token.orderType,
    );
  }

  final String shortId;
  final String title;
  final String billNumber;
  final String customerName;
  final String customerPhone;
  final String time; // kept for legacy reference if needed elsewhere
  final String dateTimeString;
  final double amount;
  final String payment;
  final String status;
  final DateTime rawDate;
  final List<ApiTokenItem> items;
  final String orderType;
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
