import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hr_core/config/api_config.dart';
import 'package:hr_core/hr_repository.dart';
import 'package:hr_core/storage/token_storage.dart';

void main() {
  late HttpServer server;
  late HRRepositoryImpl repository;
  final persisted = <Map<String, dynamic>>[];
  var lastPostBody = <String, dynamic>{};
  var authHeader = '';
  var failRequests = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.saveToken('test-staff-token');
    persisted.clear();
    lastPostBody = {};
    authHeader = '';
    failRequests = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      authHeader = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
      if (failRequests) {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'success': false, 'message': 'Backend failed'}));
        await request.response.close();
        return;
      }
      if (request.uri.path == '/api/staff/daily-updates' &&
          request.method == 'POST') {
        lastPostBody = jsonDecode(await utf8.decodeStream(request))
            as Map<String, dynamic>;
        final created = {
          '_id': 'created-1',
          'title': lastPostBody['title'],
          'updateText': lastPostBody['updateText'],
          'createdAt': '2026-10-23T10:00:00.000Z',
        };
        persisted.insert(0, created);
        request.response
          ..statusCode = HttpStatus.created
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'success': true, 'data': created}));
      } else if (request.uri.path == '/api/staff/daily-updates' &&
          request.method == 'GET') {
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'success': true, 'data': persisted}));
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
    ApiConfig.setBaseUrl('http://127.0.0.1:${server.port}/api');
    repository = HRRepositoryImpl();
  });

  tearDown(() async {
    repository.dispose();
    await server.close(force: true);
    ApiConfig.resetBaseUrl();
  });

  test('POST sends validated fields with bearer token and GET refetches it',
      () async {
    final saved = await repository.submitDailyUpdate(
        '  Shift summary  ', '  Finished the rollout.  ');

    expect(lastPostBody, {
      'title': 'Shift summary',
      'updateText': 'Finished the rollout.',
    });
    expect(authHeader, 'Bearer test-staff-token');
    expect(saved.id, 'created-1');

    repository.dailyUpdatesList.value = [];
    await repository.fetchDailyUpdates();
    expect(repository.dailyUpdatesList.value, hasLength(1));
    expect(repository.dailyUpdatesList.value.single.title, 'Shift summary');
  });

  test('GET accepts an empty response list', () async {
    await repository.fetchDailyUpdates();
    expect(repository.dailyUpdatesList.value, isEmpty);
  });

  test('API failures surface the server message and do not change updates',
      () async {
    failRequests = true;
    await expectLater(
      repository.submitDailyUpdate('Title', 'Details'),
      throwsA(
          predicate((error) => error.toString().contains('Backend failed'))),
    );
    expect(repository.dailyUpdatesList.value, isEmpty);
  });
}
