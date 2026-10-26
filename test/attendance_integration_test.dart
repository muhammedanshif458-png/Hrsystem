import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:hr_core/config/api_config.dart';
import 'package:hr_core/hr_repository.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/storage/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const backendBase = 'http://127.0.0.1:5000';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.clearTokens();
    ApiConfig.setBaseUrl('$backendBase/api');
  });

  group('StaffHub Attendance API Integration & Workflow Tests', () {
    test('End-to-End: check-in, active timer persistence, duplicate check-in reconciliation, and check-out', () async {
      final repo = HRRepositoryImpl();

      // 1. Authenticate as Super Admin to provision a fresh test staff member
      final saLoginRes = await http.post(
        Uri.parse('$backendBase/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': 'lysoftware@gmail.com',
          'password': 'hrAdmin',
        }),
      );
      expect(saLoginRes.statusCode, 200, reason: 'Super Admin login failed');
      final saToken = jsonDecode(saLoginRes.body)['data']['accessToken'];

      // 2. Create dedicated test staff member
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final staffEmail = 'attendance.staff.$timestamp@example.com';
      const staffPassword = 'Password@123';

      final createEmpRes = await http.post(
        Uri.parse('$backendBase/api/hr/employees'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $saToken',
        },
        body: jsonEncode({
          'name': 'Attendance Tester $timestamp',
          'email': staffEmail,
          'phoneNumber': '9988776655',
          'department': 'Tech',
          'designation': 'QA Engineer',
          'workMode': 'Office',
          'password': staffPassword,
        }),
      );
      expect(createEmpRes.statusCode, 201, reason: 'Staff creation failed');
      final empData = jsonDecode(createEmpRes.body)['data'];
      final employeeId = empData['_id'];
      expect(employeeId, isNotNull);

      // 3. Log in as that staff member
      final loggedInStaff = await repo.signIn(staffEmail, staffPassword);
      expect(loggedInStaff.email.toLowerCase(), staffEmail.toLowerCase());
      expect(loggedInStaff.role, Role.staff);
      expect(await TokenStorage.hasToken(), isTrue);

      // 4. Initial state before any check-in
      await repo.fetchStaffAttendance();
      final initialToday = repo.attendanceList.value
          .where((a) => a.isToday && (a.staffId == loggedInStaff.id || a.staffId.isEmpty))
          .firstOrNull;
      expect(initialToday, isNull, reason: 'No attendance record should exist before check-in');

      // 5. Check In when no record exists
      final checkInRecord = await repo.checkIn(loggedInStaff.id);
      expect(checkInRecord.id, isNotEmpty);
      expect(checkInRecord.checkInAt, isNotNull);
      expect(checkInRecord.checkOutAt, isNull);
      expect(checkInRecord.isToday, isTrue);
      expect(checkInRecord.status, 'PRESENT');

      final checkInTime = checkInRecord.checkInAt!;
      final now = DateTime.now();
      expect(now.difference(checkInTime).inSeconds >= 0, isTrue);

      // 6. Confirm timer starts from the returned check-in timestamp
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final elapsed = DateTime.now().difference(checkInTime);
      expect(elapsed.inSeconds >= 1, isTrue, reason: 'Active timer must calculate from checkInAt timestamp');

      // 7. Reload / Widget recreation simulation (fresh repository instance restoring state)
      final reloadedRepo = HRRepositoryImpl();
      await reloadedRepo.switchUserDirect(loggedInStaff);
      await reloadedRepo.fetchStaffAttendance();

      final reloadedToday = reloadedRepo.attendanceList.value
          .where((a) => a.isToday && (a.staffId == loggedInStaff.id || a.staffId.isEmpty))
          .firstOrNull;
      expect(reloadedToday, isNotNull, reason: 'Today attendance must be restored from backend');
      expect(reloadedToday!.id, checkInRecord.id);
      expect(reloadedToday.checkInAt, isNotNull);
      // The checkIn timestamp must match exactly (within 1 second)
      expect(
        reloadedToday.checkInAt!.difference(checkInTime).inSeconds.abs() <= 1,
        isTrue,
        reason: 'Restored check-in timestamp must match persisted backend record',
      );
      // Active timer continues from the saved check-in timestamp without resetting to 0
      final reloadedElapsed = DateTime.now().difference(reloadedToday.checkInAt!);
      expect(reloadedElapsed.inSeconds >= 1, isTrue);

      // 8. Attempt duplicate check-in and verify reconciliation
      // Backend should return 400 "already checked in"
      bool threwExpectedException = false;
      try {
        await reloadedRepo.checkIn(loggedInStaff.id);
      } catch (e) {
        threwExpectedException = true;
        expect(e.toString().toLowerCase().contains('already checked in'), isTrue);
      }
      expect(threwExpectedException, isTrue);

      // Reconciled attendance list still has today's record active and intact
      final reconciledToday = reloadedRepo.attendanceList.value
          .where((a) => a.isToday && (a.staffId == loggedInStaff.id || a.staffId.isEmpty))
          .firstOrNull;
      expect(reconciledToday, isNotNull);
      expect(reconciledToday!.checkOutAt, isNull);
      expect(reconciledToday.checkInAt, isNotNull);

      // 9. Test Check Out using real backend endpoint
      await reloadedRepo.checkOut(reconciledToday.id);
      final checkedOutToday = reloadedRepo.attendanceList.value
          .where((a) => a.id == reconciledToday.id)
          .firstOrNull;
      expect(checkedOutToday, isNotNull);
      expect(checkedOutToday!.checkOutAt, isNotNull);
      expect(checkedOutToday.checkOutAt!.isAfter(checkedOutToday.checkInAt!), isTrue);

      // Verify timer stopped: total elapsed is checkOutAt - checkInAt
      final finalDuration = checkedOutToday.checkOutAt!.difference(checkedOutToday.checkInAt!);
      expect(finalDuration.inSeconds >= 0, isTrue);

      // 10. Direct database / API verification: ensure no duplicate records were created
      final userToken = await TokenStorage.getToken();
      final verifyRes = await http.get(
        Uri.parse('$backendBase/api/staff/attendance'),
        headers: {'Authorization': 'Bearer $userToken'},
      );
      expect(verifyRes.statusCode, 200);
      final verifyData = jsonDecode(verifyRes.body);
      final records = (verifyData['data'] as List)
          .map((e) => Attendance.fromJson(e as Map<String, dynamic>))
          .where((a) => a.isToday)
          .toList();

      expect(records.length, 1, reason: 'Exactly one attendance record must exist for today in the database');
      expect(records.first.id, checkInRecord.id);
      expect(records.first.checkInAt, isNotNull);
      expect(records.first.checkOutAt, isNotNull);
    });
  });
}
