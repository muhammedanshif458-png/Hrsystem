import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_core/config/api_config.dart';
import 'package:hr_core/hr_repository.dart';
import 'package:hr_core/services/api_service.dart';
import 'package:hr_core/storage/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const baseUrl = 'https://staffhub.test/api';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.saveToken('staff-test-token');
    ApiConfig.setBaseUrl(baseUrl);
  });

  tearDown(ApiConfig.resetBaseUrl);

  test('parses company-wide birthdays from data.birthdays with auth', () async {
    final adapter = _BirthdayAdapter({
      'success': true,
      'message': "Today's birthdays fetched successfully",
      'data': {
        'date': '2026-11-13',
        'timeZone': 'Asia/Kolkata',
        'birthdays': [
          {
            'id': 'employee-1',
            'employeeId': 'EMP001',
            'name': 'Employee One',
            'department': 'Tech',
            'designation': 'Developer',
            'profileImage': null,
          },
          {
            'id': 'employee-2',
            'employeeId': 'EMP002',
            'name': 'Employee Two',
            'department': 'Telecalling',
            'designation': 'Associate',
            'profileImage': 'https://staffhub.test/uploads/employee-2.png',
          },
        ],
        'total': 2,
      },
    });

    final birthdays =
        await HRRepositoryImpl(api: _api(adapter)).fetchTodaysBirthdays();

    expect(adapter.request?.uri.toString(), '$baseUrl/birthdays/today');
    expect(
        adapter.request?.headers['Authorization'], 'Bearer staff-test-token');
    expect(birthdays.map((birthday) => birthday.name),
        ['Employee One', 'Employee Two']);
    expect(birthdays.first.profileImageUrl, isNull);
    expect(birthdays.last.profileImageUrl,
        'https://staffhub.test/uploads/employee-2.png');
  });

  test('returns an empty list when data.birthdays is empty', () async {
    final adapter = _BirthdayAdapter({
      'success': true,
      'data': {
        'date': '2026-11-13',
        'timeZone': 'Asia/Kolkata',
        'birthdays': <dynamic>[],
        'total': 0,
      },
    });

    expect(await HRRepositoryImpl(api: _api(adapter)).fetchTodaysBirthdays(),
        isEmpty);
  });

  test('decodes a JSON string response before parsing the envelope', () async {
    final adapter = _BirthdayAdapter(
      {
        'success': true,
        'data': {
          'birthdays': [
            {'name': 'String Response Employee', 'profileImage': null},
          ],
        },
      },
      contentType: 'text/plain; charset=utf-8',
    );

    final birthdays =
        await HRRepositoryImpl(api: _api(adapter)).fetchTodaysBirthdays();

    expect(birthdays.single.name, 'String Response Employee');
    expect(birthdays.single.profileImageUrl, isNull);
  });
}

ApiService _api(_BirthdayAdapter adapter) =>
    ApiService(dio: Dio()..httpClientAdapter = adapter);

class _BirthdayAdapter implements HttpClientAdapter {
  _BirthdayAdapter(this.response, {this.contentType = 'application/json'});

  final Map<String, dynamic> response;
  final String contentType;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
