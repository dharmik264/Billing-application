import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/printer_service.dart';
import '../services/restaurant_api.dart';

class KitchenSlipScreen extends StatefulWidget {
  const KitchenSlipScreen({super.key, required this.token});

  final ApiToken token;

  @override
  State<KitchenSlipScreen> createState() => _KitchenSlipScreenState();
}

class _KitchenSlipScreenState extends State<KitchenSlipScreen> {
  static const Color _panelBackground = Color(0xFFF8FAFC);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _softBorder = Color(0xFFE2E8F0);
  static const Color _orange = Color(0xFFEA580C);
  static const double _panelWidth = 360;

  bool _autoCut = true;
  bool _twoCopies = true;
  int _printCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(_panelWidth, constraints.maxWidth);
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(width: width, child: _buildPanel()),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPanel() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildKotSlip(),
                const SizedBox(height: 12),
                _infoBanner(),
                const SizedBox(height: 12),
                _printButton(),
                const SizedBox(height: 10),
                _printOptions(),
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
        border: Border(bottom: BorderSide(color: _softBorder, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _goBack,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.arrow_back,
                      size: 19,
                      color: Color(0xFF555555),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kitchen Order (KOT)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _textPrimary,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Order #2904-X \u00B7 Dine In',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF7ED),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant_menu, size: 16, color: _orange),
          ),
        ],
      ),
    );
  }

  Widget _buildKotSlip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _softBorder, width: 0.5),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'monospace'),
        child: Column(
          children: [
            const Text(
              'TOKEN NUMBER',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFFAAAAAA),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.token.tokenNumber.isEmpty ? '#T-XXX' : widget.token.tokenNumber,
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 13),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          widget.token.createdAt.split('T').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: _textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(Icons.access_time, size: 13),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          widget.token.createdAt.contains('T') ? widget.token.createdAt.split('T').last.substring(0, 5) : '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: _textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: Color(0xFFDDDDDD)),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Order Type: ${widget.token.orderType.replaceAll('_', ' ').toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ITEM DESCRIPTION',
                  style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA)),
                ),
                Text(
                  'QTY',
                  style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA)),
                ),
              ],
            ),
            const Divider(height: 13, color: _softBorder),
            for (var i = 0; i < widget.token.items.length; i++)
              _kotItem(
                widget.token.items[i].name,
                'x${widget.token.items[i].quantity}',
                last: i == widget.token.items.length - 1,
              ),
            const Divider(height: 18, color: Color(0xFFDDDDDD)),
            const Text(
              '*** End of Order ***',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFAAAAAA),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            const Icon(Icons.restaurant_menu,
                size: 22, color: Color(0xFFDDDDDD)),
          ],
        ),
      ),
    );
  }

  Widget _kotItem(
    String name,
    String qty, {
    List<String> tags = const [],
    String? note,
    bool last = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: last ? 0 : 10, top: 2),
      margin: EdgeInsets.only(bottom: last ? 0 : 10),
      decoration: BoxDecoration(
        border:
            last ? null : const Border(bottom: BorderSide(color: _softBorder)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                qty,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final tag in tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                note,
                style: const TextStyle(
                  fontSize: 11,
                  color: _textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A), width: 0.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 15, color: Color(0xFF92400E)),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Prices are hidden for kitchen staff',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _printButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final connected = await PrinterService.instance.isConnected;
        if (!connected) {
          _showSnackBar('Printer not connected');
          return;
        }
        try {
          await PrinterService.instance.printKitchenSlip(widget.token);
          if (_twoCopies) {
            await Future.delayed(const Duration(milliseconds: 500));
            await PrinterService.instance.printKitchenSlip(widget.token);
          }
          setState(() => _printCount += _twoCopies ? 2 : 1);
          _showSnackBar('Kitchen slip sent to printer ($_printCount)');
        } catch (e) {
          _showSnackBar('Print failed: $e');
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.print_outlined, size: 18, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Print Kitchen Slip',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Directly to Kitchen Printer',
                style: TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _printOptions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 20,
        runSpacing: 8,
        children: [
          _optionToggle('Auto-Cut Paper', _autoCut, () {
            setState(() => _autoCut = !_autoCut);
          }),
          _optionToggle('Print 2 Copies', _twoCopies, () {
            setState(() => _twoCopies = !_twoCopies);
          }),
        ],
      ),
    );
  }

  Widget _optionToggle(String label, bool value, VoidCallback onTap) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: value ? _orange : Colors.white,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: value ? _orange : _softBorder),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    _showSnackBar('Back pressed');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
