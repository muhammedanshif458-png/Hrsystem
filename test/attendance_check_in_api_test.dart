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

  test('check-in sends authenticated POST with empty body and parses server record',
      () async {
    await TokenStorage.saveToken('staff-session-token');
    final adapter = _AttendanceAdapter();
    final repository = HRRepositoryImpl(api: _api(adapter));

    final attendance = await repository.checkIn('client-staff-id');

    expect(adapter.requests.map((request) => request.method), ['POST', 'GET']);
    expect(adapter.requests.first.uri.toString(),
        '$baseUrl/staff/attendance/check-in');
    expect(adapter.requests.first.headers['Authorization'],
        'Bearer staff-session-token');
    expect(adapter.requests.first.data, <String, dynamic>{});
    expect(adapter.requests.first.data, isNot(contains('employee')));
    expect(adapter.requests.first.data, isNot(contains('department')));
    expect(attendance.id, 'attendance-1');
    expect(attendance.staffId, 'client-staff-id');
    expect(attendance.checkInAt, DateTime.parse('2026-10-23T03:25:00.000Z').toLocal());
    expect(attendance.date, '2026-10-23');
    expect(attendance.status, 'LATE');
    expect(attendance.isLate, isTrue);
    expect(repository.attendanceList.value.single.checkInAt, attendance.checkInAt);
  });

  test('check-in API errors retain the backend status and message', () async {
    final adapter = _AttendanceAdapter(checkInStatus: 400);
    final repository = HRRepositoryImpl(api: _api(adapter));

    await expectLater(
      repository.checkIn('client-staff-id'),
      throwsA(isA<ApiException>()
          .having((error) => error.statusCode, 'statusCode', 400)
          .having((error) => error.message, 'message', 'Already checked in')),
    );
    expect(adapter.requests.map((request) => request.method), ['POST', 'GET']);
  });

  test('on-time and alternate backend late fields are parsed without local calculation', () async {
    final late = Attendance.fromJson({
      '_id': 'late', 'checkInAt': '2026-10-23T03:25:00Z', 'late': true,
      'minutesLate': 12, 'department': {'name': 'Tech'},
      'scheduleSnapshot': {'checkInTime': '09:00', 'timezone': 'Asia/Kolkata'},
    });
    final onTime = Attendance.fromJson({'_id': 'on-time', 'isLate': false, 'minutesLate': 0});
    expect(late.isLate, isTrue);
    expect(late.minutesLate, 12);
    expect(late.department, 'Tech');
    expect(late.scheduleSnapshot?['timezone'], 'Asia/Kolkata');
    expect(onTime.isLate, isFalse);
    expect(onTime.minutesLate, 0);
  });

  test('check-out posts empty body, refreshes, and preserves server late fields', () async {
    final adapter = _AttendanceAdapter(checkOutStatus: 200);
    final repository = HRRepositoryImpl(api: _api(adapter));
    await repository.checkOut('attendance-1');
    expect(adapter.requests.map((r) => r.method), ['POST', 'GET']);
    expect(adapter.requests.first.uri.toString(), '$baseUrl/staff/attendance/check-out');
    expect(adapter.requests.first.data, <String, dynamic>{});
    final refreshed = repository.attendanceList.value.single;
    expect(refreshed.checkInAt, isNotNull);
    expect(refreshed.checkOutAt, isNotNull);
    expect(refreshed.isLate, isTrue);
    expect(refreshed.minutesLate, 12);
  });

  test('check-out failure is not treated as success', () async {
    final adapter = _AttendanceAdapter(checkOutStatus: 400);
    final repository = HRRepositoryImpl(api: _api(adapter));
    await expectLater(repository.checkOut('attendance-1'), throwsA(isA<ApiException>()));
    expect(adapter.requests, hasLength(1));
  });

  test('expired authentication is surfaced and missing response data is rejected', () async {
    final unauthorized = _AttendanceAdapter(checkInStatus: 401);
    final repository = HRRepositoryImpl(api: _api(unauthorized));
    await expectLater(repository.checkIn('client-staff-id'), throwsA(isA<ApiException>()));

    final malformed = _AttendanceAdapter(malformedCheckIn: true);
    await expectLater(HRRepositoryImpl(api: _api(malformed)).checkIn('client-staff-id'),
        throwsA(isA<FormatException>()));
  });
}

ApiService _api(_AttendanceAdapter adapter) =>
    ApiService(dio: Dio()..httpClientAdapter = adapter);

class _RecordedRequest {
  const _RecordedRequest(this.method, this.uri, this.headers, this.data);

  final String method;
  final Uri uri;
  final Map<String, dynamic> headers;
  final dynamic data;
}

class _AttendanceAdapter implements HttpClientAdapter {
  _AttendanceAdapter({this.checkInStatus = 200, this.checkOutStatus = 200, this.malformedCheckIn = false});

  final int checkInStatus;
  final int checkOutStatus;
  final bool malformedCheckIn;
  final requests = <_RecordedRequest>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(_RecordedRequest(options.method, options.uri,
        Map<String, dynamic>.from(options.headers), options.data));

    if (options.path.endsWith('/check-in')) {
      final status = checkInStatus;
      final body = status == 200
          ? malformedCheckIn ? {'success': true} : {
              'success': true,
              'data': {
                '_id': 'attendance-1',
                'date': '2026-10-23',
                'checkIn': '2026-10-23T03:25:00.000Z',
                'status': 'LATE',
                'isLate': true,
              },
            }
          : {'success': false, 'message': 'Already checked in'};
      return _response(status, body);
    }

    if (options.path.endsWith('/check-out')) {
      return _response(checkOutStatus, checkOutStatus == 200
          ? {'success': true, 'data': {'checkOut': '2026-10-23T12:00:00Z', 'workingHours': 8}}
          : {'success': false, 'message': 'Check-out failed'});
    }
    return _response(200, {
      'success': true,
      'data': [
        {
          '_id': 'attendance-1',
          'employee': {'_id': 'client-staff-id'},
          'date': '2026-10-23',
          'checkIn': '2026-10-23T03:25:00.000Z',
          'status': 'LATE',
          'isLate': true,
          'minutesLate': 12,
          'department': {'name': 'Tech'},
          'scheduleSnapshot': {'checkInTime': '09:00', 'timezone': 'Asia/Kolkata'},
          'checkOut': '2026-10-23T12:00:00Z',
        }
      ],
    });
  }

  ResponseBody _response(int status, Map<String, dynamic> body) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
