import 'dart:convert';

void main() {
  String response = '[{"id": 1, "name": "Test"}]';
  var decoded = jsonDecode(response);
  
  try {
    List<Map<String, dynamic>> list = decoded.cast<Map<String, dynamic>>();
    print('Cast successful: $list');
  } catch (e) {
    print('Error: $e');
  }
}
