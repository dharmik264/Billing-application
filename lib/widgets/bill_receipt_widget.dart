import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/restaurant_api.dart';

class BillReceiptWidget extends StatelessWidget {
  const BillReceiptWidget({
    Key? key,
    required this.template,
    this.shopData,
    this.tokenNumber,
    this.billNumber,
    this.date,
    this.time,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.customerGstNumber,
    this.items = const [],
    this.subtotal = 0.0,
    this.discount = 0.0,
    this.tax = 0.0,
    this.roundOff = 0.0,
    this.grandTotal = 0.0,
    this.paymentMode = 'Cash',
    this.logoBytesOverride,
    this.qrBytesOverride,
    this.isForPrint = false,
  }) : super(key: key);

  final ApiBillTemplate template;
  final ApiShopData? shopData;
  final String? tokenNumber;
  final String? billNumber;
  final String? date;
  final String? time;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? customerGstNumber;
  final List<ApiTokenItemDraft> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double roundOff;
  final double grandTotal;
  final String paymentMode;

  /// Used in Shop Setup to show the locally picked image before saving to the server
  final Uint8List? logoBytesOverride;
  final Uint8List? qrBytesOverride;
  final bool isForPrint;

  String _money(double amount) => '\u20B9${amount.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    const textPrimary = Color(0xFF1F2937);
    const textSecondary = Color(0xFF6B7280);
    const muted = Color(0xFFAAAAAA);
    const border = Color(0xFFDDDDDD);

    Uint8List? finalLogo;
    String? networkLogo;
    if (logoBytesOverride != null) {
      finalLogo = logoBytesOverride;
    } else if (template.logoUrl != null && template.logoUrl!.isNotEmpty) {
      try {
        if (template.logoUrl!.startsWith('data:image')) {
          finalLogo = base64Decode(template.logoUrl!.split(',').last);
        } else if (template.logoUrl!.contains('/')) {
          networkLogo = template.logoUrl;
        } else {
          finalLogo = base64Decode(template.logoUrl!);
        }
      } catch (_) {}
    } else if (shopData?.logoUrl != null && shopData!.logoUrl!.isNotEmpty) {
      try {
        if (shopData!.logoUrl!.startsWith('data:image')) {
          finalLogo = base64Decode(shopData!.logoUrl!.split(',').last);
        } else if (shopData!.logoUrl!.contains('/')) {
          networkLogo = shopData!.logoUrl;
        } else {
          finalLogo = base64Decode(shopData!.logoUrl!);
        }
      } catch (_) {}
    }

    Uint8List? finalQr;
    String? networkQr;
    if (qrBytesOverride != null) {
      finalQr = qrBytesOverride;
    } else if (template.qrCodeUrl != null && template.qrCodeUrl!.isNotEmpty) {
      try {
        if (template.qrCodeUrl!.startsWith('data:image')) {
          finalQr = base64Decode(template.qrCodeUrl!.split(',').last);
        } else if (template.qrCodeUrl!.contains('/')) {
          networkQr = template.qrCodeUrl;
        } else {
          finalQr = base64Decode(template.qrCodeUrl!);
        }
      } catch (_) {}
    } else if (shopData?.qrUrl != null && shopData!.qrUrl!.isNotEmpty) {
      try {
        finalQr = base64Decode(shopData!.qrUrl!);
      } catch (_) {}
    }

    final shopName = template.shopName?.isNotEmpty == true
        ? template.shopName!
        : (shopData?.name.isNotEmpty == true ? shopData!.name : 'SHOP NAME');
    final tagline = template.tagline?.isNotEmpty == true
        ? template.tagline!
        : shopData?.tagline;
    final address = template.address?.isNotEmpty == true
        ? template.address!
        : shopData?.address;
    final mobile = template.mobileNumber?.isNotEmpty == true
        ? template.mobileNumber!
        : shopData?.phone;
    final emailStr = shopData?.email ?? template.email;
    final hasEmail = emailStr != null && emailStr.isNotEmpty;
    final gstStr = shopData?.gstin ?? template.gstNumber;
    final hasGst = gstStr != null && gstStr.isNotEmpty;

    final upiIdStr = shopData?.upiId;

    final baseStyle = TextStyle(fontSize: isForPrint ? 16 : 10, color: isForPrint ? Colors.black : textSecondary, fontWeight: isForPrint ? FontWeight.bold : FontWeight.normal);

    return Container(
      width: isForPrint ? 340 : double.infinity,
      padding: isForPrint ? const EdgeInsets.symmetric(horizontal: 4, vertical: 8) : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isForPrint ? 0 : 14),
        border: isForPrint ? null : Border.all(color: border, width: 0.5),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontFamily: 'monospace', color: isForPrint ? Colors.black : textPrimary),
        child: Column(
          children: [
            if (finalLogo != null || networkLogo != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: finalLogo != null
                    ? Image.memory(finalLogo,
                        width: 44, height: 44, fit: BoxFit.cover)
                    : Image.network(
                        RestaurantApi.instance.getMediaUrl(networkLogo!),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const SizedBox()),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              shopName.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isForPrint ? 26 : 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: isForPrint ? Colors.black : textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'TAX INVOICE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isForPrint ? 20 : 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: isForPrint ? Colors.black : textPrimary,
              ),
            ),
            if (tagline?.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(
                '"$tagline"',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: isForPrint ? 22 : 10,
                    fontStyle: FontStyle.italic,
                    color: isForPrint ? Colors.black : textSecondary),
              ),
            ],
            if (address?.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(
                address!,
                textAlign: TextAlign.center,
                style: baseStyle,
              ),
            ],
            if (mobile?.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(
                'Ph: $mobile',
                textAlign: TextAlign.center,
                style: baseStyle,
              ),
            ],
            if (hasEmail) ...[
              const SizedBox(height: 2),
              Text('Email: $emailStr',
                  style: baseStyle, textAlign: TextAlign.center),
            ],
            if (hasGst) ...[
              const SizedBox(height: 2),
              Text('GSTIN: $gstStr',
                  style: baseStyle, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 10),
            const Divider(color: border, height: 1),
            const SizedBox(height: 10),
            if (template.showInvoiceNumber || template.showDateTime) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (template.showInvoiceNumber)
                    Expanded(
                      child: Row(
                        children: [
                          if (billNumber != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF), // Blue
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Text(
                                billNumber!,
                                style: TextStyle(
                                    fontSize: isForPrint ? 19 : 9,
                                    color: Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          if (billNumber != null && tokenNumber != null)
                            const SizedBox(width: 4),
                          if (tokenNumber != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED), // Orange
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: const Color(0xFFFED7AA)),
                              ),
                              child: Text(
                                tokenNumber!,
                                style: TextStyle(
                                    fontSize: isForPrint ? 19 : 9,
                                    color: Color(0xFFC2410C),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          if (billNumber == null && tokenNumber == null)
                            Text(
                              'Inv: #1024',
                              style: TextStyle(
                                  fontSize: isForPrint ? 22 : 10,
                                  color: isForPrint ? Colors.black : textSecondary,
                                  fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                  if (template.showDateTime)
                    Expanded(
                      child: Text(
                        '${date ?? '05/06/2026'} ${time ?? '12:45 PM'}',
                        textAlign: TextAlign.right,
                        style: baseStyle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            if ((customerName != null && customerName!.isNotEmpty) || (customerPhone != null && customerPhone!.isNotEmpty)) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (customerName != null && customerName!.isNotEmpty)
                    Expanded(
                      child: Text('Customer: $customerName', style: baseStyle),
                    ),
                  if (customerPhone != null && customerPhone!.isNotEmpty)
                    Expanded(
                      child: Text('Ph: $customerPhone',
                          textAlign: (customerName != null && customerName!.isNotEmpty) ? TextAlign.right : TextAlign.left, style: baseStyle),
                    ),
                ],
              ),
              const SizedBox(height: 2),
            ],
            if (template.showInvoiceNumber ||
                template.showDateTime ||
                ((customerName != null && customerName!.isNotEmpty) || (customerPhone != null && customerPhone!.isNotEmpty))) ...[
              const SizedBox(height: 4),
              const Divider(color: border, height: 1),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (template.showItemName)
                  Expanded(
                    flex: 5,
                    child: Text('ITEM',
                        style: TextStyle(fontSize: isForPrint ? 22 : 10, color: isForPrint ? Colors.black : muted)),
                  ),
                if (template.showQuantity)
                  Expanded(
                    flex: 2,
                    child: Text('QTY',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: isForPrint ? 22 : 10, color: isForPrint ? Colors.black : muted)),
                  ),
                if (template.showUnitPrice)
                  Expanded(
                    flex: 3,
                    child: Text('PRICE',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: isForPrint ? 22 : 10, color: isForPrint ? Colors.black : muted)),
                  ),
                if (template.showTotalPrice)
                  Expanded(
                    flex: 3,
                    child: Text('TOTAL',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: isForPrint ? 22 : 10, color: isForPrint ? Colors.black : muted)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(color: border, height: 1),
            for (final item in (items.isEmpty ? [_mockItem()] : items)) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    if (template.showItemName)
                      Expanded(
                        flex: 5,
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: isForPrint ? 26 : 12,
                              fontWeight: FontWeight.w500,
                              color: isForPrint ? Colors.black : textPrimary),
                        ),
                      ),
                    if (template.showQuantity)
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.quantity.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: isForPrint ? 26 : 12,
                              fontWeight: FontWeight.w500,
                              color: isForPrint ? Colors.black : textPrimary),
                        ),
                      ),
                    if (template.showUnitPrice)
                      Expanded(
                        flex: 3,
                        child: Text(
                          _money(item.rate),
                          textAlign: TextAlign.right,
                          style:
                              TextStyle(fontSize: isForPrint ? 26 : 12, color: isForPrint ? Colors.black : textPrimary),
                        ),
                      ),
                    if (template.showTotalPrice)
                      Expanded(
                        flex: 3,
                        child: Text(
                          _money(item.rate * item.quantity),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: isForPrint ? 26 : 12,
                              fontWeight: FontWeight.w500,
                              color: isForPrint ? Colors.black : textPrimary),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            const Divider(color: border, height: 1),
            const SizedBox(height: 8),
            _receiptTotalRow('Subtotal', _money(subtotal), size: isForPrint ? 24 : 11),
            const SizedBox(height: 3),
            _receiptTotalRow('Discount', _money(discount), size: isForPrint ? 24 : 11),
            const SizedBox(height: 3),
            Builder(
              builder: (context) {
                final billSettings = shopData?.billSettings ?? {};
                final taxPercentValue = billSettings['tax_percent'] ?? 0.0;
                double taxPercent = 0.0;
                if (taxPercentValue is num) {
                  taxPercent = taxPercentValue.toDouble();
                } else if (taxPercentValue is String) {
                  taxPercent = double.tryParse(taxPercentValue) ?? 0.0;
                }
                final label = taxPercent > 0 ? 'Tax (GST ${taxPercent.toStringAsFixed(0)}%)' : 'Tax';
                return _receiptTotalRow(label, _money(tax), size: isForPrint ? 24 : 11);
              },
            ),
            const SizedBox(height: 3),
            _receiptTotalRow('Round Off', _money(roundOff), size: isForPrint ? 24 : 11),
            const SizedBox(height: 7),
            _receiptTotalRow(
                'Grand Total', _money(grandTotal > 0 ? grandTotal : subtotal),
                bold: true, size: isForPrint ? 28 : 13),
            const SizedBox(height: 8),
            if (template.showPaymentMethod) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Payment Mode',
                      style: TextStyle(fontSize: isForPrint ? 24 : 11, color: isForPrint ? Colors.black : textSecondary)),
                  Text(paymentMode,
                      style: TextStyle(fontSize: isForPrint ? 24 : 11, color: isForPrint ? Colors.black : textPrimary)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            if (upiIdStr != null && upiIdStr.isNotEmpty) ...[
              QrImageView(
                data: 'upi://pay?pa=$upiIdStr&pn=${Uri.encodeComponent(shopName)}&am=${(grandTotal > 0 ? grandTotal : subtotal).toStringAsFixed(2)}&cu=INR',
                version: QrVersions.auto,
                size: 64.0,
              ),
              if (template.showUpiId) ...[
                const SizedBox(height: 4),
                Text(upiIdStr,
                    style: TextStyle(fontSize: isForPrint ? 19 : 9, color: isForPrint ? Colors.black : textPrimary)),
              ],
              const SizedBox(height: 4),
              Text('Scan to Pay ${_money(grandTotal > 0 ? grandTotal : subtotal)}',
                  style: TextStyle(fontSize: isForPrint ? 22 : 10, color: isForPrint ? Colors.black : textPrimary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
            ]
            else if (finalQr != null || networkQr != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: finalQr != null
                    ? Image.memory(finalQr,
                        width: 64, height: 64, fit: BoxFit.cover)
                    : Image.network(
                        RestaurantApi.instance.getMediaUrl(networkQr!),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const SizedBox()),
              ),
              const SizedBox(height: 4),
              Text('Scan to Pay ${_money(grandTotal > 0 ? grandTotal : subtotal)}',
                  style: TextStyle(fontSize: isForPrint ? 22 : 10, color: isForPrint ? Colors.black : textPrimary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
            ],
            if (template.footerMessage.isNotEmpty) ...[
              Text(
                template.footerMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: isForPrint ? 24 : 11,
                    color: isForPrint ? Colors.black : textPrimary,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
            ],
            if (template.termsAndConditions.isNotEmpty) ...[
              Text(
                template.termsAndConditions,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: isForPrint ? 19 : 9, color: isForPrint ? Colors.black : muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _receiptTotalRow(String label, String value,
      {bool bold = false, double size = 12}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: size,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: bold ? const Color(0xFF1F2937) : const Color(0xFF6B7280),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: size,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: bold ? const Color(0xFF1F2937) : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  ApiTokenItemDraft _mockItem() {
    return const ApiTokenItemDraft(
      id: '1',
      name: 'Margherita Pizza',
      code: 'MZ1',
      rate: 12.00,
      quantity: 1,
    );
  }
}
