import 'package:shared_preferences/shared_preferences.dart';

class BillSettingsHelper {
  static const String _keySendSms = 'setting_send_sms';
  static const String _keyPrintPreview = 'setting_print_preview';
  static const String _keyBillPrint = 'setting_bill_print';
  static const String _keyBillFormat = 'setting_bill_format';
  static const String _keyPickupSlip = 'setting_pickup_slip';

  static Future<bool> getSendSms() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySendSms) ?? true;
  }

  static Future<void> setSendSms(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySendSms, value);
  }

  static Future<bool> getPrintPreview() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPrintPreview) ?? true;
  }

  static Future<void> setPrintPreview(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPrintPreview, value);
  }

  static Future<bool> getBillPrint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBillPrint) ?? true;
  }

  static Future<void> setBillPrint(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBillPrint, value);
  }

  static Future<String> getBillFormat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBillFormat) ?? 'Bill Slip';
  }

  static Future<void> setBillFormat(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBillFormat, value);
  }

  static Future<bool> getPickupSlip() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPickupSlip) ?? true;
  }

  static Future<void> setPickupSlip(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPickupSlip, value);
  }
}
