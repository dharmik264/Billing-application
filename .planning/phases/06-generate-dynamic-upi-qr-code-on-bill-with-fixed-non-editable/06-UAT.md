---
status: complete
phase: 06-generate-dynamic-upi-qr-code-on-bill-with-fixed-non-editable
source: 06-01-SUMMARY.md
started: 2026-06-27T22:49:04+05:30
updated: 2026-06-27T23:30:15+05:30
---

## Current Test

[testing complete]

## Tests

### 1. Set UPI ID in Shop Setup
expected: Opening Shop Setup in the Flutter app allows the user to enter a UPI ID in the corresponding field. Saving the setup correctly persists the value (which remains visible when re-opening the screen).
result: pass

### 2. Generate Receipt PDF / Preview
expected: Creating a bill generates a receipt PDF that includes a QR Code at the bottom labeled "Scan to Pay". The bill preview should also show this.
result: pass

### 3. Scan QR Code
expected: Scanning the generated QR Code with a UPI app (like GPay or PhonePe) correctly sets the payee to the shop and pre-fills the EXACT non-editable grand total.
result: pass

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
