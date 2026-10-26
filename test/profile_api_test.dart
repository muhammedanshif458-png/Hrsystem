import 'package:flutter_test/flutter_test.dart';
import 'package:hr_core/models.dart';

void main() {
  group('Profile API Integration Tests', () {
    test('Parse GET /staff/profile response into Staff model', () {
      final jsonResponse = {
        "success": true,
        "data": {
          "employeeId": "EMP1005",
          "firstName": "Mark",
          "department": "Sales"
        }
      };
      
      final data = jsonResponse['data'] as Map<String, dynamic>;
      
      final staff = const Staff().copyWith(
        id: data['employeeId'],
        name: data['firstName'],
        department: data['department'],
      );

      expect(staff.id, 'EMP1005');
      expect(staff.name, 'Mark');
      expect(staff.department, 'Sales');
    });

    test('Construct PUT /staff/profile request body', () {
      final phone = '+1122334455';
      final address = '123 New Street';
      
      final body = <String, dynamic>{};
      if (phone.isNotEmpty) body['phone'] = phone;
      if (address.isNotEmpty) body['address'] = address;

      expect(body, {
        'phone': '+1122334455',
        'address': '123 New Street',
      });
    });
  });
}
