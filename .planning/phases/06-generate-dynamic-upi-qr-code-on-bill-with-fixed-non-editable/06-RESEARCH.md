# Phase 6: Generate Dynamic UPI QR Code on Bill with Fixed Non-Editable Amount - Research

## Objective
Determine the implementation path for generating a dynamic UPI QR code that includes a fixed, non-editable amount based on the generated bill's total, and printing it on the thermal receipt/bill.

## Domain Knowledge & UPI Specifications
To generate a UPI QR code with a pre-filled amount, the standard UPI URI scheme is used:
`upi://pay?pa=<merchant_upi_id>&pn=<merchant_name>&am=<bill_total>&cu=INR`

To ensure the amount is pre-filled and generally non-editable by the user scanning the QR code, the standard URI with the `am=` parameter is used. 

Example URI:
`upi://pay?pa=merchant@upi&pn=Shop Name&am=150.00&cu=INR`

## Current Implementation Analysis
- **Frontend (Flutter)**:
  - The `print_preview_screen.dart` and `pdf_receipt_service.dart` currently handle generating the bill layout.
  - The application allows uploading a custom Payment QR Code in the Shop Setup (`shop_setup_screen.dart`), which is likely a static QR code image.
  - We need to augment the printing logic to generate a dynamic QR code using the bill total.

- **Backend (Django)**:
  - The `shop` model has the static QR code configuration. We need to ensure the Shop model stores the UPI ID (`pa` - Payee Address) so that dynamic QR codes can be generated.
  - If it only stores the static QR code image currently, we need to add a new field `upi_id` to generate dynamic QRs.

## Required Changes
1. **Database / Backend**:
   - Update `Shop` model to include `upi_id`.
   - Update `shop/serializers.py` to expose `upi_id`.
2. **Frontend UI**:
   - In Shop Setup, allow the user to enter their `upi_id`.
3. **Printing Service (`pdf_receipt_service.dart` and ESC/POS logic)**:
   - Construct the UPI URI string dynamically: `upi://pay?pa=${shop.upiId}&pn=${shop.name}&am=${token.totalAmount}&cu=INR`
   - Generate a QR code from this string during the print process.
   - Insert this generated QR code into the PDF/ESC-POS layout.

## Conclusion
The implementation requires shifting from a static image-based QR code to dynamic text-based QR code generation using the UPI URI scheme, driven by a new `upi_id` field in the Shop configuration.
