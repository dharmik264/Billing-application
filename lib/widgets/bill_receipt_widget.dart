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
    this.items = const [],
    this.subtotal = 0.0,
    this.discount = 0.0,
    this.tax = 0.0,
    this.roundOff = 0.0,
    this.grandTotal = 0.0,
    this.paymentMode = 'Cash',
    this.logoBytesOverride,
    this.qrBytesOverride,
  }) : super(key: key);

  final ApiBillTemplate template;
  final ApiShopData? shopData;
  final String? tokenNumber;
  final String? billNumber;
  final String? date;
  final String? time;
  final String? customerName;
  final String? customerPhone;
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

    const baseStyle = TextStyle(fontSize: 10, color: textSecondary);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.5),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'monospace', color: textPrimary),
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
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: textPrimary,
              ),
            ),
            if (tagline?.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(
                '"$tagline"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: textSecondary),
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
                                style: const TextStyle(
                                    fontSize: 9,
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
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFFC2410C),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          if (billNumber == null && tokenNumber == null)
                            const Text(
                              'Inv: #1024',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: textSecondary,
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
            if (template.showCustomerDetails &&
                (customerName != null || customerPhone != null)) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (customerName != null)
                    Expanded(
                      child: Text('Customer: $customerName', style: baseStyle),
                    ),
                  if (customerPhone != null)
                    Expanded(
                      child: Text(customerPhone!,
                          textAlign: TextAlign.right, style: baseStyle),
                    ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            if (template.showInvoiceNumber ||
                template.showDateTime ||
                (template.showCustomerDetails &&
                    (customerName != null || customerPhone != null))) ...[
              const SizedBox(height: 4),
              const Divider(color: border, height: 1),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (template.showItemName)
                  const Expanded(
                    flex: 5,
                    child: Text('ITEM',
                        style: TextStyle(fontSize: 10, color: muted)),
                  ),
                if (template.showQuantity)
                  const Expanded(
                    flex: 2,
                    child: Text('QTY',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: muted)),
                  ),
                if (template.showUnitPrice)
                  const Expanded(
                    flex: 3,
                    child: Text('PRICE',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 10, color: muted)),
                  ),
                if (template.showTotalPrice)
                  const Expanded(
                    flex: 3,
                    child: Text('TOTAL',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 10, color: muted)),
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
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: textPrimary),
                        ),
                      ),
                    if (template.showQuantity)
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.quantity.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: textPrimary),
                        ),
                      ),
                    if (template.showUnitPrice)
                      Expanded(
                        flex: 3,
                        child: Text(
                          _money(item.rate),
                          textAlign: TextAlign.right,
                          style:
                              const TextStyle(fontSize: 12, color: textPrimary),
                        ),
                      ),
                    if (template.showTotalPrice)
                      Expanded(
                        flex: 3,
                        child: Text(
                          _money(item.rate * item.quantity),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: textPrimary),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            const Divider(color: border, height: 1),
            const SizedBox(height: 8),
            if (template.showSubtotal) ...[
              _receiptTotalRow('Subtotal', _money(subtotal), size: 11),
              const SizedBox(height: 3),
            ],
            if (template.showDiscount) ...[
              _receiptTotalRow('Discount', '-${_money(discount)}', size: 11),
              const SizedBox(height: 3),
            ],
            if (template.showTax) ...[
              _receiptTotalRow('Tax (GST 5%)', _money(tax), size: 11),
              const SizedBox(height: 3),
            ],
            if (template.showRoundOff) ...[
              _receiptTotalRow('Round Off', _money(roundOff), size: 11),
              const SizedBox(height: 3),
            ],
            if (template.showGrandTotal) ...[
              const SizedBox(height: 4),
              _receiptTotalRow(
                  'Total Amount', _money(items.isEmpty ? subtotal : grandTotal),
                  bold: true, size: 13),
              const SizedBox(height: 8),
            ],
            if (template.showPaymentMethod) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment Mode',
                      style: TextStyle(fontSize: 11, color: textSecondary)),
                  Text(paymentMode,
                      style: const TextStyle(fontSize: 11, color: textPrimary)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            if (upiIdStr != null && upiIdStr.isNotEmpty) ...[
              QrImageView(
                data: 'upi://pay?pa=$upiIdStr&pn=${Uri.encodeComponent(shopName)}&am=${(items.isEmpty ? subtotal : grandTotal).toStringAsFixed(2)}&cu=INR',
                version: QrVersions.auto,
                size: 64.0,
              ),
              if (template.showUpiId) ...[
                const SizedBox(height: 4),
                Text(upiIdStr,
                    style: const TextStyle(fontSize: 9, color: textPrimary)),
              ],
              const SizedBox(height: 4),
              const Text('Scan to Pay',
                  style: TextStyle(fontSize: 10, color: muted)),
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
              const Text('Scan to Pay',
                  style: TextStyle(fontSize: 10, color: muted)),
              const SizedBox(height: 10),
            ],
            if (template.footerMessage.isNotEmpty) ...[
              Text(
                template.footerMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11,
                    color: textPrimary,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
            ],
            if (template.termsAndConditions.isNotEmpty) ...[
              Text(
                template.termsAndConditions,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, color: muted),
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
