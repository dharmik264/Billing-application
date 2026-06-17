import 'package:flutter/material.dart';

import '../services/restaurant_api.dart';
import '../utils/pdf_export.dart';

class AnalyticsReportsScreen extends StatefulWidget {
  const AnalyticsReportsScreen({super.key});

  @override
  State<AnalyticsReportsScreen> createState() => _AnalyticsReportsScreenState();
}

class _AnalyticsReportsScreenState extends State<AnalyticsReportsScreen> {
  static const Color _panelBackground = Color(0xFFF5F6FA);
  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _softBorder = Color(0xFFEEEEEE);

  final TextEditingController _searchController = TextEditingController();
  final List<_HistoryToken> _tokens = [];

  String _selectedRange = 'Today';
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
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                _searchBar(),
                _rangeTabs(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Column(
                    children: [
                      _summaryHeader(),
                      const SizedBox(height: 20),
                      _exportButton(),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                Expanded(child: _buildTokenList()),
              ],
            ),
            if (_loading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.05),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenList() {
    final tokens = _filteredTokens;
    if (tokens.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Text('No tokens found.', style: TextStyle(color: _textSecondary)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _softBorder, width: 0.5),
        ),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: tokens.length,
          separatorBuilder: (context, index) => const Divider(
            height: 0.5,
            thickness: 0.5,
            color: Color(0xFFF0F0F0),
          ),
          itemBuilder: (context, index) => _tokenRow(tokens[index]),
        ),
      ),
    );
  }

  Widget _tokenRow(_HistoryToken token) {
    final isReady = token.status == 'Ready' || token.status == 'Completed';
    final isCancelled = token.status == 'Cancelled';

    final badgeBg = isCancelled
        ? const Color(0xFFFEE2E2)
        : isReady
            ? const Color(0xFFD1FAE5)
            : const Color(0xFFFFF3CD);
    final badgeFg = isCancelled
        ? const Color(0xFF991B1B)
        : isReady
            ? const Color(0xFF065F46)
            : const Color(0xFF92400E);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
            ),
            child: Text(
              token.shortId,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badgeFg,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getDisplayTitle(token),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${token.payment.isEmpty ? 'N/A' : token.payment} · ${token.dateTimeString}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _textSecondary),
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  token.status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
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
          const Row(
            children: [
              Text(
                'Analytics Reports',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: _pickDateRange,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.calendar_today_outlined,
                  size: 22, color: Color(0xFF555555)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
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
            const Icon(Icons.search, size: 16, color: Color(0xFFAAAAAA)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14, color: _textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search token number or customer...',
                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeTabs() {
    const ranges = ['Today', 'Yesterday', 'This Week'];

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
            for (var index = 0; index < ranges.length; index++) ...[
              _rangeChip(ranges[index]),
              if (index != ranges.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rangeChip(String range) {
    final selected = _selectedRange == range;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _selectedRange = range),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 16 : 14,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111111) : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          range,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? Colors.white : const Color(0xFF666666),
          ),
        ),
      ),
    );
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
            style: const TextStyle(fontSize: 12, color: _textSecondary),
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF16A34A),
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
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _exportToPdf,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.picture_as_pdf_outlined, size: 17),
              SizedBox(width: 8),
              Text(
                'Export PDF Report',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
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
      return query.isEmpty ||
          token.title.toLowerCase().contains(query) ||
          token.shortId.toLowerCase().contains(query) ||
          token.payment.toLowerCase().contains(query);
    }).toList();
  }


  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportToPdf() async {
    if (_filteredTokens.isEmpty) {
      _showSnackBar('No tokens to export');
      return;
    }

    _showSnackBar('Generating PDF...');

    try {
      final pdfTokens = _filteredTokens.map((t) {
        // Fallback bill number generation if empty
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

      _showSnackBar('Report saved successfully');
    } catch (e) {
      _showSnackBar('Error exporting report: $e');
    }
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
