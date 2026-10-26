import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:hr_core/config/api_config.dart';
import 'package:hr_core/hr_repository.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/storage/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.clearTokens();
    ApiConfig.setBaseUrl('http://127.0.0.1:5000/api');
  });

  group('Staff Portal Live Authentication & Integration Tests', () {
    final repo = HRRepositoryImpl();
    const backendBase = 'http://127.0.0.1:5000';

    test('ApiConfig correctly normalizes and preserves base URL', () {
      expect(ApiConfig.baseUrl, 'http://127.0.0.1:5000/api');
      expect(ApiConfig.normalizeBaseUrl('http://127.0.0.1:5000/'), 'http://127.0.0.1:5000/api');
      expect(ApiConfig.normalizeBaseUrl('http://127.0.0.1:5000/api/'), 'http://127.0.0.1:5000/api');
    });

    test('End-to-End: HR provisioned staff sign in, profile retrieval, and RBAC', () async {
      // 1. Authenticate as Super Admin via HR backend
      final saLoginRes = await http.post(
        Uri.parse('$backendBase/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': 'lysoftware@gmail.com',
          'password': 'hrAdmin',
        }),
      );
      expect(saLoginRes.statusCode, 200);
      final saToken = jsonDecode(saLoginRes.body)['data']['accessToken'];

      // 2. Create a dedicated test staff member in HR Dashboard
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final staffEmail = 'staff.portal.$timestamp@example.com';
      final initialPassword = 'InitialPass@123';

      final createRes = await http.post(
        Uri.parse('$backendBase/api/hr/employees'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $saToken',
        },
        body: jsonEncode({
          'name': 'Robin Portal Tester',
          'email': staffEmail,
          'phoneNumber': '9876543211',
          'department': 'Tech',
          'designation': 'Frontend Engineer',
          'workMode': 'Office',
          'password': initialPassword,
        }),
      );
      expect(createRes.statusCode, 201);
      final empData = jsonDecode(createRes.body)['data'];
      final employeeId = empData['_id'];

      // 3. Super Admin updates staff password via PUT /api/hr/employees/:id
      final newStaffPassword = 'NewSecretStaffPass@2026';
      final updateRes = await http.put(
        Uri.parse('$backendBase/api/hr/employees/$employeeId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $saToken',
        },
        body: jsonEncode({
          'password': newStaffPassword,
          'designation': 'Senior Frontend Engineer',
        }),
      );
      expect(updateRes.statusCode, 200);

      // 4. Test wrong password rejection on Staff Portal
      expect(
        () => repo.signIn(staffEmail, 'WrongPassword'),
        throwsA(predicate((e) => e.toString().contains('Invalid email or password'))),
      );
      expect(await TokenStorage.hasToken(), isFalse);

      // 5. Test old password rejection on Staff Portal
      expect(
        () => repo.signIn(staffEmail, initialPassword),
        throwsA(predicate((e) => e.toString().contains('Invalid email or password'))),
      );
      expect(await TokenStorage.hasToken(), isFalse);

      // 6. Real sign in on Staff Portal using provisioned credentials
      final staff = await repo.signIn(staffEmail, newStaffPassword);

      expect(staff.email.toLowerCase(), staffEmail.toLowerCase());
      expect(staff.role, Role.staff);
      expect(staff.name, 'Robin Portal Tester');
      expect(staff.department, Department.tech);
      expect(staff.status, Status.active);

      // Verify token was stored in TokenStorage
      final storedToken = await TokenStorage.getToken();
      expect(storedToken, isNotNull);
      expect(storedToken!.isNotEmpty, isTrue);

      // 7. Verify protected staff profile retrieval with issued token
      final fetchedProfile = await repo.fetchProfile();
      expect(fetchedProfile.email.toLowerCase(), staffEmail.toLowerCase());
      expect(fetchedProfile.role, Role.staff);

      // 8. Verify protected staff dashboard access with stored token
      final dashRes = await http.get(
        Uri.parse('$backendBase/api/staff/dashboard'),
        headers: {'Authorization': 'Bearer $storedToken'},
      );
      expect(dashRes.statusCode, 200);

      // 9. Verify staff token cannot access Super Admin / HR routes
      final hrDashRes = await http.get(
        Uri.parse('$backendBase/api/hr/dashboard'),
        headers: {'Authorization': 'Bearer $storedToken'},
      );
      expect(hrDashRes.statusCode, 403);

      // 10. Verify Super Admin login to Staff Portal is rejected
      await TokenStorage.clearTokens();
      expect(
        () => repo.signIn('lysoftware@gmail.com', 'hrAdmin'),
        throwsA(predicate((e) => e.toString().contains('Only staff accounts can access the Staff Portal'))),
      );

      // 11. Test signOut clears token
      await repo.signIn(staffEmail, newStaffPassword);
      expect(await TokenStorage.hasToken(), isTrue);
      repo.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await TokenStorage.hasToken(), isFalse);
      expect(repo.currentUser.value, isNull);

      // Cleanup test employee
      await http.delete(
        Uri.parse('$backendBase/api/hr/employees/$employeeId'),
        headers: {'Authorization': 'Bearer $saToken'},
      );
    });
  });
}
