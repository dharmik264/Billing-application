import 'package:flutter/services.dart';

class NativeSmsService {
  static const MethodChannel _channel = MethodChannel('com.example.billing_application/sms');

  static Future<bool> sendSms({required String phone, required String message}) async {
    try {
      final String result = await _channel.invokeMethod('sendSms', {
        'phone': phone,
        'message': message,
      });
      print('SMS sent result: $result');
      return true;
    } on PlatformException catch (e) {
      print('Failed to send SMS: ${e.message}');
      return false;
    }
  }
}
