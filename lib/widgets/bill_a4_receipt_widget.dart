import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/restaurant_api.dart';

class BillA4ReceiptWidget extends StatelessWidget {
  const BillA4ReceiptWidget({
    super.key,
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
  });

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

  final Uint8List? logoBytesOverride;
  final Uint8List? qrBytesOverride;

  String _amountToWords(double amount) {
    if (amount <= 0) return 'Zero Rupees Only';

    const ones = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen'
    ];
    const tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];

    String convert(int n) {
      if (n < 20) return ones[n];
      if (n < 100) return '${tens[n ~/ 10]}${n % 10 != 0 ? ' ${ones[n % 10]}' : ''}';
      if (n < 1000) return '${ones[n ~/ 100]} Hundred${n % 100 != 0 ? ' ${convert(n % 100)}' : ''}';
      if (n < 100000) return '${convert(n ~/ 1000)} Thousand${n % 1000 != 0 ? ' ${convert(n % 1000)}' : ''}';
      if (n < 10000000) return '${convert(n ~/ 100000)} Lakh${n % 100000 != 0 ? ' ${convert(n % 100000)}' : ''}';
      return '${convert(n ~/ 10000000)} Crore${n % 10000000 != 0 ? ' ${convert(n % 10000000)}' : ''}';
    }

    final int integerPart = amount.truncate();
    final int decimalPart = ((amount - integerPart) * 100).round();

    String result = '${convert(integerPart)} Rupees';
    if (decimalPart > 0) {
      result += ' and ${convert(decimalPart)} Paise';
    }
    return '$result Only';
  }

  @override
  Widget build(BuildContext context) {
    const textPrimary = Color(0xFF0F172A);
    const textSecondary = Color(0xFF475569);
    const textMuted = Color(0xFF94A3B8);
    const borderColor = Color(0xFFCBD5E1);
    const dividerColor = Color(0xFFE2E8F0);
    const headerBg = Color(0xFFF8FAFC);

    // Resolve Logo
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

    // Resolve QR
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
    final email = shopData?.email ?? template.email;
    final gstin = shopData?.gstin ?? template.gstNumber;
    final upiId = shopData?.upiId;

    // Subtotal and Tax Calculations
    final computedSubtotal = subtotal > 0
        ? subtotal
        : items.fold(0.0, (sum, item) => sum + (item.rate * item.quantity));
    final computedTax = tax > 0 ? tax : (grandTotal > computedSubtotal ? grandTotal - computedSubtotal : 0.0);
    final effectiveGrandTotal = grandTotal > 0 ? grandTotal : (computedSubtotal + computedTax);

    final double gstPercent = (computedSubtotal > 0 && computedTax > 0)
        ? (computedTax / computedSubtotal) * 100
        : 0.0;
    final String gstPercentStr = (gstPercent % 1 == 0)
        ? gstPercent.toStringAsFixed(0)
        : gstPercent.toStringAsFixed(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final horizontalPadding = isCompact ? 12.0 : 18.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. HEADER SECTION (Centered Shop Identity) ──────────
              Center(
                child: Column(
                  children: [
                    if (finalLogo != null || networkLogo != null) ...[
                      ClipOval(
                        child: finalLogo != null
                            ? Image.memory(
                                finalLogo,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                RestaurantApi.instance.getMediaUrl(networkLogo!),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox(),
                              ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      shopName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: isCompact ? 16 : 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                      ),
                      child: Text(
                        'TAX INVOICE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    if (tagline != null && tagline.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '"$tagline"',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontStyle: FontStyle.italic,
                          color: textSecondary,
                        ),
                      ),
                    ],
                    if (address != null && address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        address,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: textSecondary,
                        ),
                      ),
                    ],
                    if (mobile != null && mobile.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ph: $mobile${email != null && email.isNotEmpty ? '  |  Email: $email' : ''}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: textSecondary,
                        ),
                      ),
                    ],
                    if (gstin != null && gstin.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'GSTIN: $gstin',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),
              const Divider(thickness: 1, color: dividerColor, height: 1),
              const SizedBox(height: 14),

              // ── 2. TWO-COLUMN INVOICE & CUSTOMER INFO ───────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Box (Billed To)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Billed To:',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          customerName?.isNotEmpty == true ? customerName! : 'Walk-in Customer',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        if (customerPhone != null && customerPhone!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Ph: $customerPhone',
                            style: GoogleFonts.inter(fontSize: 10, color: textSecondary),
                          ),
                        ],
                        if (customerAddress != null && customerAddress!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Address: $customerAddress',
                            style: GoogleFonts.inter(fontSize: 10, color: textSecondary),
                          ),
                        ],
                        if (customerGstNumber != null && customerGstNumber!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'GSTIN: $customerGstNumber',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: textPrimary),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Partition Line
                  Container(
                    width: 1,
                    height: 70,
                    color: dividerColor,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                  ),

                  // Right Box (Invoice Details)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invoice Details:',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildMetaRow('Bill No:', billNumber ?? '-'),
                        _buildMetaRow('Token No:', tokenNumber ?? '-'),
                        _buildMetaRow('Date:', '${date ?? ''} ${time ?? ''}'.trim()),
                        _buildMetaRow('Payment:', paymentMode),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(thickness: 1, color: dividerColor, height: 1),
              const SizedBox(height: 14),

              // ── 3. ITEMIZED TABLE ──────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: const BoxDecoration(
                        color: headerBg,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                        border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              'Sr.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: textPrimary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 4,
                            child: Text(
                              'Item Name',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: textPrimary),
                            ),
                          ),
                          SizedBox(
                            width: 34,
                            child: Text(
                              'Qty',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: textPrimary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 52,
                            child: Text(
                              'Rate',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: textPrimary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 58,
                            child: Text(
                              'Amount',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Body Rows
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No items added',
                          style: GoogleFonts.inter(fontSize: 11, color: textMuted),
                        ),
                      )
                    else
                      ...List.generate(items.length, (index) {
                        final item = items[index];
                        final itemSubtotal = item.rate * item.quantity;
                        final isLast = index == items.length - 1;
                        final isEven = index % 2 == 0;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                          decoration: BoxDecoration(
                            color: isEven ? Colors.white : const Color(0xFFFAFAFA),
                            border: isLast ? null : const Border(bottom: BorderSide(color: dividerColor, width: 0.5)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${index + 1}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(fontSize: 10, color: textSecondary),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  item.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 34,
                                child: Text(
                                  '${item.quantity}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(fontSize: 10.5, color: textPrimary),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 52,
                                child: Text(
                                  item.rate.toStringAsFixed(2),
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.spaceMono(fontSize: 10.5, color: textSecondary),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 58,
                                child: Text(
                                  itemSubtotal.toStringAsFixed(2),
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.spaceMono(fontSize: 10.5, fontWeight: FontWeight.w600, color: textPrimary),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── 4. TOTALS SECTION (Right Aligned) ───────────────────
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 220,
                  child: Column(
                    children: [
                      _buildTotalRow('Subtotal:', '\u20B9${computedSubtotal.toStringAsFixed(2)}'),
                      if (computedTax > 0.001) ...[
                        const SizedBox(height: 4),
                        _buildTotalRow('Tax ($gstPercentStr%):', '\u20B9${computedTax.toStringAsFixed(2)}'),
                      ],
                      if (discount > 0.001) ...[
                        const SizedBox(height: 4),
                        _buildTotalRow('Discount:', '-\u20B9${discount.toStringAsFixed(2)}'),
                      ],
                      if (roundOff.abs() > 0.001) ...[
                        const SizedBox(height: 4),
                        _buildTotalRow('Round Off:', '\u20B9${roundOff.toStringAsFixed(2)}'),
                      ],
                      const SizedBox(height: 6),
                      const Divider(thickness: 1.5, color: textPrimary, height: 1),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Grand Total:',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            '\u20B9${effectiveGrandTotal.toStringAsFixed(2)}',
                            style: GoogleFonts.spaceMono(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Payment Mode:',
                            style: GoogleFonts.inter(fontSize: 10, color: textSecondary),
                          ),
                          Text(
                            paymentMode,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(thickness: 1, color: dividerColor, height: 1),
              const SizedBox(height: 14),

              // ── 5. FOOTER (UPI QR & Signatory) ──────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side: UPI QR or Placeholder
                  Expanded(
                    child: (upiId != null && upiId.isNotEmpty)
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              QrImageView(
                                data: 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(shopName)}&am=${effectiveGrandTotal.toStringAsFixed(2)}&cu=INR',
                                version: QrVersions.auto,
                                size: 68.0,
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Scan to Pay',
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Any UPI App',
                                      style: GoogleFonts.inter(fontSize: 9.5, color: textSecondary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      upiId,
                                      style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : (finalQr != null || networkQr != null)
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: finalQr != null
                                        ? Image.memory(finalQr, width: 68, height: 68, fit: BoxFit.cover)
                                        : Image.network(
                                            RestaurantApi.instance.getMediaUrl(networkQr!),
                                            width: 68,
                                            height: 68,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const SizedBox(),
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Scan to Pay',
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: textPrimary),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Terms & Conditions',
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '1. Goods once sold will not be taken back.\n2. Subject to local jurisdiction.',
                                    style: GoogleFonts.inter(fontSize: 9, color: textMuted),
                                  ),
                                ],
                              ),
                  ),

                  // Partition Line
                  Container(
                    width: 1,
                    height: 80,
                    color: dividerColor,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                  ),

                  // Right Side: Amount in Words & Signatory
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount in Words:',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _amountToWords(effectiveGrandTotal),
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontStyle: FontStyle.italic,
                            color: textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            'Authorized Signatory',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(thickness: 1, color: dividerColor, height: 1),
              const SizedBox(height: 10),

              // ── 6. THANK YOU / FOOTER MESSAGE ───────────────────────
              Center(
                child: Text(
                  template.footerMessage.isNotEmpty
                      ? template.footerMessage
                      : 'Thank you for your visit!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                    color: textMuted,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
        ),
        Text(
          value,
          style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
        ),
      ],
    );
  }
}
