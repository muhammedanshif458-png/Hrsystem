import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_core/config/api_config.dart';
import 'package:hr_core/core/api/api_exception.dart';
import 'package:hr_core/hr_repository.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/services/api_service.dart';
import 'package:hr_core/storage/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const baseUrl = 'https://staffhub.test/api';
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.clearTokens();
    ApiConfig.setBaseUrl(baseUrl);
  });

  for (final department in [Department.tech, Department.telecalling]) {
    for (final type in AttendanceBreakSchedule.types) {
      test('$department can start $type early and refresh it', () async {
        final adapter = _BreakAdapter();
        final repo = _repository(adapter, department);
        final scheduleIndex = AttendanceBreakSchedule.types.indexOf(type);
        expect(
          AttendanceBreakSchedule.canStart(
            DateTime(2026, 10, 26),
            scheduleIndex,
          ),
          isTrue,
        );
        await repo.fetchStaffAttendance();
        await repo.toggleBreak('att-1', breakType: type);
        expect(
            adapter.requests.where((r) => r.uri.path.endsWith('/breaks/start')),
            hasLength(1));
        expect(
            adapter.requests
                .firstWhere((r) => r.uri.path.endsWith('/breaks/start'))
                .data['breakType'],
            type);
        final item = repo.attendanceList.value.single.breaks.single;
        expect(item.breakType, type);
        expect(item.isActive, isTrue);
        expect(adapter.requests.last.method, 'GET');
      });
    }
  }

  test(
      'ending persists both timestamps and dashboard refresh reads completed break',
      () async {
    final adapter = _BreakAdapter()..activeType = 'morning';
    final repo = _repository(adapter, Department.tech);
    await repo.fetchStaffAttendance();
    await repo.toggleBreak('att-1');
    final item = repo.attendanceList.value.single.breaks.single;
    expect(item.endTime, isNotNull);
    expect(item.startTime, isNotNull);
    expect(item.isActive, isFalse);
    expect(adapter.requests.any((r) => r.uri.path.endsWith('/breaks/end')),
        isTrue);
  });

  test('a different break cannot start while one is active', () async {
    final adapter = _BreakAdapter()..activeType = 'morning';
    final repo = _repository(adapter, Department.tech);
    await repo.fetchStaffAttendance();
    await expectLater(
        repo.toggleBreak('att-1', breakType: 'lunch'), throwsException);
    expect(adapter.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  test('tea breaks are independently consumed from server attendance data',
      () async {
    final adapter = _BreakAdapter();
    final repo = _repository(adapter, Department.tech);
    await repo.fetchStaffAttendance();
    for (final type in ['tea_break_1', 'tea_break_2']) {
      await repo.toggleBreak('att-1', breakType: type);
      await repo.toggleBreak('att-1');
    }
    expect(adapter.completedTypes, {'tea_break_1', 'tea_break_2'});
    final refreshed = _repository(adapter, Department.tech);
    await refreshed.fetchStaffAttendance();
    expect(refreshed.attendanceList.value.single.breaks.map((b) => b.breakType),
        containsAll(['tea_break_1', 'tea_break_2']));
    await expectLater(refreshed.toggleBreak('att-1', breakType: 'tea_break_1'),
        throwsException);
    await refreshed.toggleBreak('att-1', breakType: 'lunch');
  });

  test('breaks require check-in and are blocked after check-out', () async {
    final beforeCheckIn = _BreakAdapter()..checkedIn = false;
    final repo = _repository(beforeCheckIn, Department.tech);
    await repo.fetchStaffAttendance();
    await expectLater(
        repo.toggleBreak('att-1', breakType: 'tea_break_1'), throwsException);
    expect(beforeCheckIn.requests.where((r) => r.method == 'POST'), isEmpty);

    final afterCheckOut = _BreakAdapter()..checkedOut = true;
    final checkedOutRepo = _repository(afterCheckOut, Department.tech);
    await checkedOutRepo.fetchStaffAttendance();
    await expectLater(
        checkedOutRepo.toggleBreak('att-1', breakType: 'tea_break_1'),
        throwsException);
    expect(afterCheckOut.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  test('API and authentication failures are surfaced', () async {
    final restricted = _BreakAdapter(startStatus: 400);
    final restrictedRepo = _repository(restricted, Department.telecalling);
    await restrictedRepo.fetchStaffAttendance();
    await expectLater(
        restrictedRepo.toggleBreak('att-1', breakType: 'tea_break_2'),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'Break is not available yet')));

    final unauthorized = _BreakAdapter(startStatus: 401);
    final unauthorizedRepo = _repository(unauthorized, Department.tech);
    await unauthorizedRepo.fetchStaffAttendance();
    await expectLater(
        unauthorizedRepo.toggleBreak('att-1', breakType: 'tea_break_1'),
        throwsA(isA<ApiException>()));
  });

  test('failed break requests do not update local state or report success',
      () async {
    final adapter = _BreakAdapter(startStatus: 500);
    final repo = _repository(adapter, Department.tech);
    await repo.fetchStaffAttendance();
    await expectLater(repo.toggleBreak('att-1', breakType: 'tea_break_1'),
        throwsA(isA<ApiException>()));
    expect(repo.attendanceList.value.single.breaks, isEmpty);
    expect(adapter.requests.where((r) => r.method == 'GET'), hasLength(1));
  });

  test('failed end request preserves active server-backed break state',
      () async {
    final adapter = _BreakAdapter()..activeType = 'lunch';
    adapter.endStatus = 500;
    final repo = _repository(adapter, Department.telecalling);
    await repo.fetchStaffAttendance();
    await expectLater(repo.toggleBreak('att-1'), throwsA(isA<ApiException>()));
    expect(repo.attendanceList.value.single.breaks.single.isActive, isTrue);
    expect(adapter.activeType, 'lunch');
  });

  test('lunch completion remains consumed after attendance refresh', () async {
    final adapter = _BreakAdapter()..activeType = 'lunch';
    final repo = _repository(adapter, Department.tech);
    await repo.fetchStaffAttendance();
    await repo.toggleBreak('att-1');
    final reloaded = _repository(adapter, Department.tech);
    await reloaded.fetchStaffAttendance();
    expect(
        reloaded.attendanceList.value.single.breaks.single.isCompleted, isTrue);
    await expectLater(
        reloaded.toggleBreak('att-1', breakType: 'lunch'), throwsException);
  });
}

HRRepositoryImpl _repository(_BreakAdapter adapter, String department) {
  final repo = HRRepositoryImpl(
      api: ApiService(dio: Dio()..httpClientAdapter = adapter));
  repo.currentUser.value = Staff(id: 'staff-1', department: department);
  return repo;
}

class _Request {
  const _Request(this.method, this.uri, this.data);
  final String method;
  final Uri uri;
  final dynamic data;
}

class _BreakAdapter implements HttpClientAdapter {
  _BreakAdapter({this.startStatus = 200});
  final int startStatus;
  final requests = <_Request>[];
  String? activeType;
  final Set<String> completedTypes = {};
  int endStatus = 200;
  bool checkedIn = true;
  bool checkedOut = false;
  final DateTime _now = DateTime.now();

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final data = options.data;
    requests.add(_Request(options.method, options.uri, data));
    if (options.path.endsWith('/breaks/start')) {
      if (startStatus != 200)
        return _response(startStatus, {
          'success': false,
          'message': startStatus == 400
              ? 'Break is not available yet'
              : 'Request failed'
        });
      activeType = (data as Map)['breakType'] as String;
      return _response(200, {'success': true});
    }
    if (options.path.endsWith('/breaks/end')) {
      if (endStatus != 200)
        return _response(
            endStatus, {'success': false, 'message': 'end failed'});
      if (activeType != null) completedTypes.add(activeType!);
      activeType = null;
      return _response(200, {'success': true});
    }
    final breaks = <Map<String, dynamic>>[
      ...completedTypes.map((type) => {
            'id': 'break-1',
            'attendanceId': 'att-1',
            'breakType': type,
            'startTime': _now.toIso8601String(),
            'endTime': _now.add(const Duration(minutes: 1)).toIso8601String(),
            'durationSeconds': 60
          }),
      if (activeType != null)
        {
          'id': 'break-active',
          'attendanceId': 'att-1',
          'breakType': activeType,
          'startTime': _now.toIso8601String(),
          'endTime': null,
          'durationSeconds': 0,
        },
    ];
    return _response(200, {
      'success': true,
      'data': [
        {
          '_id': 'att-1',
          'employee': {'_id': 'staff-1', 'department': 'Tech'},
          'date': _now.toIso8601String().substring(0, 10),
          'checkIn': checkedIn
              ? _now.subtract(const Duration(hours: 1)).toIso8601String()
              : null,
          'checkOut': checkedOut ? _now.toIso8601String() : null,
          'breaks': breaks
        }
      ]
    });
  }

  ResponseBody _response(int status, Map<String, dynamic> body) =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  void close({bool force = false}) {}
}
