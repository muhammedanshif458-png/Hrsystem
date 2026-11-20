import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_core/config/api_config.dart';
import 'package:hr_core/hr_repository.dart';
import 'package:hr_core/models.dart';
import 'package:hr_core/services/api_service.dart';
import 'package:hr_core/services/staff_chat_socket_service.dart';
import 'package:hr_core/staff_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test double implementing ApiService to simulate backend REST responses
class FakeChatApiService extends ApiService {
  final Map<String, dynamic> responses = {};
  final List<Map<String, dynamic>> getRequests = [];
  final List<Map<String, dynamic>> postRequests = [];
  final List<String> patchRequests = [];
  final List<String> deleteRequests = [];

  void setResponse(String endpoint, dynamic data) {
    responses[endpoint] = data;
  }

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    getRequests.add({'endpoint': endpoint, 'queryParams': queryParams});
    // Prefer the most specific endpoint (for example, search over history).
    final matchingKeys = responses.keys
        .where((key) => endpoint == key || endpoint.startsWith('$key/'))
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in matchingKeys) {
      final val = responses[key];
      if (val is Exception) throw val;
      return val;
    }
    return {'success': true, 'data': []};
  }

  @override
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    postRequests.add({'endpoint': endpoint, 'body': body});
    for (final key in responses.keys) {
      if (endpoint.contains(key)) {
        final val = responses[key];
        if (val is Exception) throw val;
        return val;
      }
    }
    final text = body?['text'] ?? '';
    final clientMsgId = body?['clientMessageId'];
    return {
      'success': true,
      'data': {
        '_id': 'srv_${DateTime.now().millisecondsSinceEpoch}',
        'senderId': 'staff_current',
        'senderName': 'Authenticated Staff',
        'senderRole': 'STAFF',
        'departmentKey':
            endpoint.contains('/telecalling/') ? 'telecalling' : 'tech',
        'conversationType': 'DEPARTMENT',
        'clientMessageId': clientMsgId,
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
      }
    };
  }

  @override
  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    patchRequests.add(endpoint);
    return {'success': true, 'message': 'Message deleted for you'};
  }

  @override
  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    deleteRequests.add(endpoint);
    return {'success': true, 'message': 'Message deleted for everyone'};
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StaffChatSocketService().reset();
  });

  tearDown(() {
    StaffChatSocketService().reset();
  });

  group('1. Department Key Normalization', () {
    test('normalizes various Tech representations to "tech"', () {
      expect(canonicalDepartmentKey('Tech'), 'tech');
      expect(canonicalDepartmentKey('TECHNOLOGY'), 'tech');
      expect(canonicalDepartmentKey('Engineering'), 'tech');
      expect(canonicalDepartmentKey('tech-team'), 'tech');
    });

    test('normalizes Telecalling and Client relations to "telecalling"', () {
      expect(canonicalDepartmentKey('Telecalling'), 'telecalling');
      expect(canonicalDepartmentKey('TELECALLING'), 'telecalling');
      expect(canonicalDepartmentKey('Calling Dept'), 'telecalling');
      expect(canonicalDepartmentKey('Client Success'), 'telecalling');
      expect(canonicalDepartmentKey('not-tech'), 'not-tech');
    });

    test('normalizes HR representations to "hr"', () {
      expect(canonicalDepartmentKey('HR'), 'hr');
      expect(canonicalDepartmentKey('Human Resources'), 'hr');
      expect(canonicalDepartmentKey('hr'), 'hr');
    });

    test('missing or invalid department keys remain unknown', () {
      expect(canonicalDepartmentKey(null), isEmpty);
      expect(canonicalDepartmentKey(''), isEmpty);
      expect(canonicalDepartmentKey('   '), isEmpty);
      expect(canonicalDepartmentKey('***'), isEmpty);
    });
  });

  group('2. StaffChatMessage Model and Identity', () {
    test('parses backend JSON payload correctly', () {
      final json = {
        '_id': 'msg_101',
        'senderId': 'staff_vikram',
        'senderName': 'Vikram Patel',
        'senderRole': 'STAFF',
        'departmentKey': 'tech',
        'conversationType': 'DEPARTMENT',
        'clientMessageId': 'client_temp_1',
        'receiverId': '',
        'text': 'All automated CI builds are passing.',
        'timestamp': '2026-10-29T10:15:30.000Z',
        'isRead': true,
        'deletedForEveryone': false,
        'deletedByIds': ['staff_other'],
      };

      final msg = StaffChatMessage.fromJson(json);

      expect(msg.id, 'msg_101');
      expect(msg.senderId, 'staff_vikram');
      expect(msg.senderName, 'Vikram Patel');
      expect(msg.senderRole, 'STAFF');
      expect(msg.departmentKey, 'tech');
      expect(msg.clientMessageId, 'client_temp_1');
      expect(msg.text, 'All automated CI builds are passing.');
      expect(msg.isRead, isTrue);
      expect(msg.deletedForEveryone, isFalse);
      expect(msg.deletedByIds.contains('staff_other'), isTrue);
      expect(msg.isHR, isFalse);
      expect(msg.initials, 'VP');
    });

    test('identifies HR roles correctly', () {
      for (final role in ['HR', 'SUPER_ADMIN', 'ADMIN', 'HR MANAGER']) {
        final msg = StaffChatMessage(
          id: 'hr_1',
          senderId: 'admin_1',
          senderName: 'HR Office',
          senderRole: role,
          text: 'Notice',
          timestamp: DateTime.now(),
        );
        expect(msg.isHR, isTrue,
            reason: 'Expected $role to be recognized as HR');
      }

      final staffMsg = StaffChatMessage(
        id: 's_1',
        senderId: 'staff_1',
        senderName: 'Staff Member',
        senderRole: 'STAFF',
        text: 'Hello',
        timestamp: DateTime.now(),
      );
      expect(staffMsg.isHR, isFalse);
    });

    test('never parses original text for globally deleted messages', () {
      final deleted = StaffChatMessage.fromJson({
        '_id': 'gone',
        'departmentKey': 'tech',
        'conversationType': 'DEPARTMENT',
        'text': 'private original content',
        'deletedForEveryone': true,
      });
      expect(deleted.deletedForEveryone, isTrue);
      expect(deleted.text, isEmpty);
    });

    test('missing conversation type remains unknown', () {
      final message = StaffChatMessage.fromJson({
        '_id': 'missing_type',
        'departmentKey': 'tech',
        'text': 'unclassified payload',
      });
      expect(message.conversationType, isEmpty);
      final untyped = StaffChatMessage(
        id: 'constructed_without_type',
        senderId: 'sender',
        departmentKey: 'tech',
        text: 'unclassified model',
        timestamp: DateTime.now(),
      );
      expect(untyped.conversationType, isEmpty);
    });

    test('isSentBy matches authenticated employee profile accurately', () {
      final currentStaff = Staff(
        id: 'EMP-99',
        authUserId: 'user_object_id_99',
        chatSenderId: 'employee_object_id_99',
        name: 'Kavita Roy',
        department: 'Telecalling & Client Relations',
      );

      final myMsg = StaffChatMessage(
        id: 'm1',
        senderId: 'employee_object_id_99',
        senderName: 'Kavita Roy',
        senderRole: 'STAFF',
        text: 'Followed up with 15 leads',
        timestamp: DateTime.now(),
      );
      expect(myMsg.isSentBy(currentStaff), isTrue);

      final otherMsg = StaffChatMessage(
        id: 'm2',
        senderId: 'staff_42',
        senderName: 'Arjun Das',
        senderRole: 'STAFF',
        text: 'Updated records',
        timestamp: DateTime.now(),
      );
      expect(otherMsg.isSentBy(currentStaff), isFalse);

      final sameNameDifferentSender = StaffChatMessage(
        id: 'm2_same_name',
        senderId: 'staff_42',
        senderName: 'Kavita Roy',
        senderRole: 'STAFF',
        text: 'Another employee with the same display name',
        timestamp: DateTime.now(),
      );
      expect(sameNameDifferentSender.isSentBy(currentStaff), isFalse);

      final relatedRefOnly = StaffChatMessage(
        id: 'm2_related_ref',
        senderId: 'different_user_id',
        senderEmployee: 'staff_99',
        senderName: 'Kavita Roy',
        senderRole: 'STAFF',
        text: 'Sender identity must use senderId',
        timestamp: DateTime.now(),
      );
      expect(relatedRefOnly.isSentBy(currentStaff), isFalse);

      final hrMsg = StaffChatMessage(
        id: 'm3',
        senderId: 'hr_admin',
        senderName: 'HR Team',
        senderRole: 'HR',
        text: 'Meeting at 4pm',
        timestamp: DateTime.now(),
      );
      expect(hrMsg.isSentBy(currentStaff), isFalse);
    });

    test('login keeps User and Employee identities separate for chat', () async {
      final api = FakeChatApiService()
        ..setResponse(ApiConfig.login, {
          'success': true,
          'data': {
            'accessToken': 'token',
            'user': {
              '_id': 'user_object_id_99',
              'role': 'STAFF',
              'isActive': true,
              'email': 'staff@example.com',
              'employee': {
                '_id': 'employee_object_id_99',
                'employeeId': 'EMP-99',
                'firstName': 'Kavita',
                'lastName': 'Roy',
                'department': 'Tech',
              },
            },
          },
        });
      final repository = HRRepositoryImpl(api: api);

      final staff = await repository.signIn('staff@example.com', 'password');

      expect(staff.id, 'EMP-99');
      expect(staff.authUserId, 'user_object_id_99');
      expect(staff.chatSenderId, 'employee_object_id_99');
      expect(
        StaffChatMessage(
          id: 'own',
          senderId: 'employee_object_id_99',
          text: 'own message',
          timestamp: DateTime(2026),
        ).isSentBy(staff),
        isTrue,
      );
      repository.dispose();
    });

    test('isHiddenFor respects deletedForEveryone and deletedByIds', () {
      final normal = StaffChatMessage(
        id: '1',
        senderId: 's1',
        text: 'Hi',
        timestamp: DateTime.now(),
      );
      expect(normal.isHiddenFor('s1'), isFalse);
      expect(normal.isHiddenFor('s2'), isFalse);

      final deletedEveryone = normal.copyWith(deletedForEveryone: true);
      expect(deletedEveryone.isHiddenFor('s1'), isTrue);
      expect(deletedEveryone.isHiddenFor('s2'), isTrue);

      final deletedForMe = normal.copyWith(deletedByIds: {'s1'});
      expect(deletedForMe.isHiddenFor('s1'), isTrue);
      expect(deletedForMe.isHiddenFor('s2'), isFalse);
    });
  });

  group('3. StaffChatSocketService Real-time Events and Reconnection', () {
    test('invalid department joins do not subscribe to Tech', () {
      final socketService = StaffChatSocketService()..isTestMode = true;
      socketService.joinDepartment('');
      expect(socketService.currentDepartmentKey, isNull);
      socketService.joinDepartment('***');
      expect(socketService.currentDepartmentKey, isNull);
      socketService.joinDepartment(Department.all);
      expect(socketService.currentDepartmentKey, isNull);
    });

    test('socket parser rejects missing or invalid conversation metadata', () {
      final socketService = StaffChatSocketService()..isTestMode = true;
      final received = <StaffChatMessage>[];
      final unsubscribe = socketService.addMessageListener(received.add);

      socketService.emitTestIncomingPayload({
        '_id': 'missing_type',
        'departmentKey': 'tech',
        'text': 'must not appear',
      });
      socketService.emitTestIncomingPayload({
        '_id': 'missing_dept',
        'conversationType': 'DEPARTMENT',
        'text': 'must not appear either',
      });
      socketService.emitTestIncomingPayload({
        '_id': 'company_conversation',
        'conversationType': 'COMPANY',
        'departmentKey': 'tech',
        'text': 'company chat must not enter department listeners',
      });
      socketService.emitTestIncomingPayload({
        '_id': 'invalid_dept',
        'conversationType': 'DEPARTMENT',
        'departmentKey': '***',
        'text': 'invalid department',
      });
      expect(received, isEmpty);

      socketService.emitTestIncomingPayload({
        '_id': 'valid_tech',
        'conversationType': 'DEPARTMENT',
        'departmentKey': 'Tech & Engineering',
        'text': 'valid tech event',
      });
      socketService.emitTestIncomingPayload({
        '_id': 'valid_telecalling',
        'conversationType': 'DEPARTMENT',
        'departmentKey': 'Telecalling & Client Relations',
        'text': 'valid telecalling event',
      });
      expect(received.map((message) => message.id),
          ['valid_tech', 'valid_telecalling']);
      expect(received.map((message) => message.conversationType),
          everyElement('DEPARTMENT'));
      unsubscribe();
    });

    test(
        'notifies message listeners when new_message or message_received arrives',
        () {
      final socketService = StaffChatSocketService();
      socketService.isTestMode = true;
      socketService.joinDepartment('tech');

      StaffChatMessage? receivedMsg;
      final unsubscribe = socketService.addMessageListener((msg) {
        receivedMsg = msg;
      });

      final incoming = StaffChatMessage(
        id: 'sock_1',
        senderId: 'hr_leader',
        senderName: 'HR Manager',
        senderRole: 'HR',
        departmentKey: 'tech',
        conversationType: 'DEPARTMENT',
        text: 'Welcome to the tech channel',
        timestamp: DateTime.now(),
      );

      socketService.emitTestIncomingMessage(incoming);

      expect(receivedMsg, isNotNull);
      expect(receivedMsg!.id, 'sock_1');
      expect(receivedMsg!.text, 'Welcome to the tech channel');
      expect(receivedMsg!.isHR, isTrue);

      unsubscribe();
    });

    test('notifies delete listeners when message_deleted arrives', () {
      final socketService = StaffChatSocketService();
      socketService.isTestMode = true;

      String? deletedId;
      bool? deletedEveryone;
      final unsubscribe = socketService.addDeleteListener((msgId, forEveryone) {
        deletedId = msgId;
        deletedEveryone = forEveryone;
      });

      socketService.emitTestMessageDeleted('msg_to_remove', true);

      expect(deletedId, 'msg_to_remove');
      expect(deletedEveryone, isTrue);

      unsubscribe();
    });

    test('reconnect listener triggers missed messages refetch', () {
      final socketService = StaffChatSocketService();
      socketService.isTestMode = true;
      socketService.joinDepartment('telecalling');

      String? reconnectedDept;
      final unsubscribe = socketService.addReconnectListener((deptKey) {
        reconnectedDept = deptKey;
      });

      socketService.emitTestReconnect('telecalling');

      expect(reconnectedDept, 'telecalling');
      unsubscribe();
    });

    test('preserves conversation type on scoped deletion events', () {
      final socketService = StaffChatSocketService();
      socketService.isTestMode = true;

      String? receivedType;
      String? receivedDepartment;
      bool? receivedForEveryone;
      final unsubscribe = socketService.addScopedDeleteListener(
          (messageId, deletedForEveryone, conversationType, departmentKey) {
        receivedType = conversationType;
        receivedDepartment = departmentKey;
        receivedForEveryone = deletedForEveryone;
      });

      socketService.emitTestDeletedPayload({
        'messageId': 'missing_metadata',
        'deletedForEveryone': true,
        'departmentKey': 'telecalling',
      });
      expect(receivedType, isNull);

      socketService.emitTestDeletedPayload({
        'messageId': 'department_message',
        'deletedForEveryone': false,
        'conversationType': 'DEPARTMENT',
        'departmentKey': 'telecalling',
      });

      expect(receivedType, 'DEPARTMENT');
      expect(receivedDepartment, 'telecalling');
      expect(receivedForEveryone, isFalse);
      unsubscribe();
    });
  });

  group('4. HRRepositoryImpl Chat Operations', () {
    late FakeChatApiService fakeApi;
    late HRRepositoryImpl repository;

    setUp(() {
      fakeApi = FakeChatApiService();
      repository = HRRepositoryImpl(api: fakeApi);
    });

    tearDown(() {
      repository.dispose();
    });

    test(
        'fetchDepartmentMessages parses and sorts backend list chronologically',
        () async {
      fakeApi.setResponse(ApiConfig.staffDepartmentMessages('tech'), {
        'success': true,
        'data': [
          {
            '_id': 'msg_b',
            'senderId': 'staff_2',
            'senderName': 'Bob',
            'departmentKey': 'tech',
            'conversationType': 'DEPARTMENT',
            'text': 'Second message',
            'timestamp': '2026-10-29T10:02:00.000Z',
          },
          {
            '_id': 'msg_a',
            'senderId': 'staff_1',
            'senderName': 'Alice',
            'departmentKey': 'tech',
            'conversationType': 'DEPARTMENT',
            'text': 'First message',
            'timestamp': '2026-10-29T10:00:00.000Z',
          },
          {
            '_id': 'missing_type',
            'senderId': 'staff_3',
            'departmentKey': 'tech',
            'text': 'must not enter history',
            'timestamp': '2026-10-29T10:03:00.000Z',
          },
          {
            '_id': 'wrong_department',
            'senderId': 'staff_4',
            'departmentKey': 'telecalling',
            'conversationType': 'DEPARTMENT',
            'text': 'must not enter tech history',
            'timestamp': '2026-10-29T10:04:00.000Z',
          },
          {
            '_id': 'company_message',
            'senderId': 'hr_1',
            'departmentKey': 'tech',
            'conversationType': 'COMPANY',
            'text': 'must not enter department history',
            'timestamp': '2026-10-29T10:05:00.000Z',
          },
        ]
      });

      final result =
          await repository.fetchDepartmentMessages(departmentKey: 'tech');

      expect(result.length, 2);
      expect(result[0].id, 'msg_a');
      expect(result[0].text, 'First message');
      expect(result[1].id, 'msg_b');
      expect(result[1].text, 'Second message');
      expect(repository.departmentChatMessages.value.length, 2);
    });

    test(
        'department API methods reject missing department instead of defaulting',
        () async {
      await expectLater(
        repository.fetchDepartmentMessages(),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        repository.sendDepartmentMessage('message'),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        repository.searchDepartmentMessages(departmentKey: '', query: 'x'),
        throwsA(isA<FormatException>()),
      );
      expect(fakeApi.getRequests, isEmpty);
      expect(fakeApi.postRequests, isEmpty);
    });

    test('department API rejects a requested department different from profile',
        () async {
      repository.currentUser.value = Staff(
        id: 'authenticated_tech',
        name: 'Tech Staff',
        department: Department.tech,
      );
      await expectLater(
        repository.fetchDepartmentMessages(departmentKey: 'telecalling'),
        throwsA(isA<FormatException>()),
      );
      expect(fakeApi.getRequests, isEmpty);
    });

    test('department history requests preserve pagination parameters',
        () async {
      await repository.fetchDepartmentMessages(
        departmentKey: 'Telecalling & Client Relations',
        page: 3,
        limit: 20,
      );

      expect(fakeApi.getRequests.single['endpoint'],
          ApiConfig.staffDepartmentMessages('telecalling'));
      expect(
          fakeApi.getRequests.single['queryParams'], {'page': 3, 'limit': 20});
    });

    test('sendDepartmentMessage validates non-empty text and avoids duplicates',
        () async {
      expect(
        () => repository.sendDepartmentMessage('   '),
        throwsA(isA<Exception>()),
      );

      final sent = await repository.sendDepartmentMessage(
        'Real backend message',
        departmentKey: 'telecalling',
      );

      expect(sent.text, 'Real backend message');
      expect(fakeApi.postRequests.length, 1);
      expect(
        fakeApi.postRequests.first['endpoint'],
        ApiConfig.staffDepartmentMessages('telecalling'),
      );
      expect(
          fakeApi.postRequests.first['body']['text'], 'Real backend message');
      expect(repository.departmentChatMessages.value.contains(sent), isTrue);
    });

    test('deleteDepartmentMessageForMe removes message from local notifier',
        () async {
      repository.departmentChatMessages.value = [
        StaffChatMessage(
          id: 'del_me_1',
          senderId: 'staff_1',
          text: 'To be deleted',
          timestamp: DateTime.now(),
        ),
      ];

      await repository.deleteDepartmentMessageForMe('del_me_1',
          departmentKey: 'telecalling');

      expect(
          fakeApi.patchRequests,
          contains(ApiConfig.staffDepartmentMessageDeleteForMe(
              'telecalling', 'del_me_1')));
      expect(repository.departmentChatMessages.value.isEmpty, isTrue);
    });

    test('deleteDepartmentMessageForEveryone preserves a deleted tombstone',
        () async {
      repository.departmentChatMessages.value = [
        StaffChatMessage(
          id: 'deleted_everyone_1',
          senderId: 'staff_1',
          text: 'Message to delete',
          timestamp: DateTime.now(),
        ),
      ];

      await repository.deleteDepartmentMessageForEveryone('deleted_everyone_1',
          departmentKey: 'tech');

      expect(
        repository.departmentChatMessages.value.single.deletedForEveryone,
        isTrue,
      );
      expect(repository.departmentChatMessages.value.single.text, isEmpty);
      expect(
          fakeApi.deleteRequests,
          contains(ApiConfig.staffDepartmentMessageDelete(
              'tech', 'deleted_everyone_1')));
    });

    test('department search uses scoped route and preserves server pagination',
        () async {
      fakeApi
          .setResponse(ApiConfig.staffDepartmentMessageSearch('telecalling'), {
        'success': true,
        'data': [
          {
            '_id': 'match_1',
            'departmentKey': 'telecalling',
            'conversationType': 'DEPARTMENT',
            'text': 'follow up',
            'timestamp': '2026-10-29T10:00:00.000Z'
          },
          {
            '_id': 'missing_type_search',
            'departmentKey': 'telecalling',
            'text': 'must not enter search results',
            'timestamp': '2026-10-29T10:01:00.000Z'
          },
          {
            '_id': 'wrong_department_search',
            'departmentKey': 'tech',
            'conversationType': 'DEPARTMENT',
            'text': 'must not enter Telecalling results',
            'timestamp': '2026-10-29T10:02:00.000Z'
          },
        ],
        'pagination': {'page': 1, 'hasMore': true},
      });

      final result = await repository.searchDepartmentMessages(
        departmentKey: 'Telecalling & Client Relations',
        query: 'follow',
        page: 1,
      );

      expect(fakeApi.getRequests.single['endpoint'],
          ApiConfig.staffDepartmentMessageSearch('telecalling'));
      expect(fakeApi.getRequests.single['queryParams'],
          {'q': 'follow', 'page': 1, 'limit': 30});
      expect(result.messages.single.id, 'match_1');
      expect(result.hasMore, isTrue);
      final nextPage = await repository.searchDepartmentMessages(
        departmentKey: 'telecalling',
        query: 'follow',
        page: 2,
      );
      expect(nextPage.hasMore, isTrue);
      expect(fakeApi.getRequests.last['queryParams'],
          {'q': 'follow', 'page': 2, 'limit': 30});
    });

    test('clear history posts to own department and empties current view',
        () async {
      repository.departmentChatMessages.value = [
        StaffChatMessage(
            id: 'old',
            senderId: 'someone',
            text: 'old',
            timestamp: DateTime.now()),
      ];
      await repository.clearDepartmentMessages(
          departmentKey: 'Tech & Engineering');

      expect(fakeApi.postRequests.single['endpoint'],
          ApiConfig.staffDepartmentChatClear('tech'));
      expect(fakeApi.postRequests.single['body'], isNull);
      expect(repository.departmentChatMessages.value, isEmpty);
    });
  });

  group('5. StaffHub Chat Widget Integration', () {
    testWidgets(
        'global deletion updates open department search and leaves unrelated results intact',
        (WidgetTester tester) async {
      final fakeApi = FakeChatApiService();
      fakeApi.setResponse(ApiConfig.staffDepartmentMessages('telecalling'), {
        'success': true,
        'data': [],
      });
      fakeApi
          .setResponse(ApiConfig.staffDepartmentMessageSearch('telecalling'), {
        'success': true,
        'data': [
          {
            '_id': 'search_target',
            'senderId': 'coworker_1',
            'senderName': 'Coworker',
            'departmentKey': 'telecalling',
            'conversationType': 'DEPARTMENT',
            'text': 'needle target original',
            'timestamp': '2026-11-15T09:00:00.000Z',
          },
          {
            '_id': 'search_unrelated',
            'senderId': 'coworker_2',
            'senderName': 'Coworker Two',
            'departmentKey': 'telecalling',
            'conversationType': 'DEPARTMENT',
            'text': 'needle retained message',
            'timestamp': '2026-11-15T09:01:00.000Z',
          },
          {
            '_id': 'search_other_department',
            'senderId': 'tech_1',
            'senderName': 'Tech Coworker',
            'departmentKey': 'tech',
            'conversationType': 'DEPARTMENT',
            'text': 'needle wrong department',
            'timestamp': '2026-11-15T09:02:00.000Z',
          },
        ],
        'pagination': {'page': 1, 'hasMore': false},
      });
      final repository = HRRepositoryImpl(api: fakeApi);
      const staff = Staff(
        id: 'tele_staff',
        name: 'Tele Staff',
        department: Department.telecalling,
      );
      repository.departmentChatMessages.value = [
        StaffChatMessage(
          id: 'search_target',
          senderId: 'coworker_1',
          senderName: 'Coworker',
          departmentKey: 'telecalling',
          conversationType: 'DEPARTMENT',
          text: 'needle target original',
          timestamp: DateTime(2026, 11, 15, 9),
        ),
        StaffChatMessage(
          id: 'search_unrelated',
          senderId: 'coworker_2',
          senderName: 'Coworker Two',
          departmentKey: 'telecalling',
          conversationType: 'DEPARTMENT',
          text: 'needle retained message',
          timestamp: DateTime(2026, 11, 15, 9, 1),
        ),
      ];
      StaffChatSocketService().isTestMode = true;

      var pageIndex = 0;
      await tester.pumpWidget(StatefulBuilder(
        builder: (context, updateParent) => MaterialApp(
          home: StaffHubShell(
            repository: repository,
            pageIndex: pageIndex,
            department: Department.telecalling,
            staff: staff,
            workMode: 'Office',
            workLocation: null,
            onNavigate: (index) => updateParent(() => pageIndex = index),
            onLogout: () {},
          ),
        ),
      ));
      await tester.tap(find.byTooltip('Open chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Chat options'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-option-search')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('chat-search')), 'needle');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('needle target original'), findsOneWidget);
      expect(find.text('needle retained message'), findsOneWidget);
      expect(find.text('needle wrong department'), findsNothing);

      final socket = StaffChatSocketService();
      socket.emitTestDeletedPayload({
        'messageId': 'search_target',
        'deletedForEveryone': true,
        'conversationType': 'DEPARTMENT',
        'departmentKey': 'tech',
      });
      await tester.pumpAndSettle();
      expect(find.text('needle target original'), findsOneWidget);

      socket.emitTestDeletedPayload({
        'messageId': 'search_target',
        'deletedForEveryone': false,
        'conversationType': 'DEPARTMENT',
        'departmentKey': 'telecalling',
      });
      await tester.pumpAndSettle();
      expect(find.text('needle target original'), findsOneWidget);

      socket.emitTestDeletedPayload({
        'messageId': 'search_target',
        'deletedForEveryone': true,
        'conversationType': 'DEPARTMENT',
        'departmentKey': 'telecalling',
      });
      await tester.pumpAndSettle();
      expect(find.text('needle target original'), findsNothing);
      expect(find.text('This message was deleted'), findsOneWidget);
      expect(find.text('needle retained message'), findsOneWidget);
      expect(find.text('needle wrong department'), findsNothing);

      await tester.tap(find.byTooltip('Chat options'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-option-search')));
      await tester.pumpAndSettle();
      expect(find.text('needle target original'), findsNothing);
      expect(find.text('This message was deleted'), findsOneWidget);
      expect(
        repository.departmentChatMessages.value
            .singleWhere((message) => message.id == 'search_target')
            .text,
        isEmpty,
      );
      repository.dispose();
    });

    testWidgets(
        'global deletion replaces history and open search result without touching other messages',
        (WidgetTester tester) async {
      final fakeApi = FakeChatApiService();
      fakeApi.setResponse(ApiConfig.staffDepartmentMessages('telecalling'), {
        'success': true,
        'data': [],
      });
      fakeApi
          .setResponse(ApiConfig.staffDepartmentMessageSearch('telecalling'), {
        'success': true,
        'data': [
          {
            '_id': 'search_target',
            'senderId': 'coworker_1',
            'senderName': 'Coworker',
            'departmentKey': 'telecalling',
            'conversationType': 'DEPARTMENT',
            'text': 'needle target original',
            'timestamp': '2026-11-15T09:00:00.000Z',
          },
          {
            '_id': 'search_unrelated',
            'senderId': 'coworker_2',
            'senderName': 'Coworker Two',
            'departmentKey': 'telecalling',
            'conversationType': 'DEPARTMENT',
            'text': 'needle retained message',
            'timestamp': '2026-11-15T09:01:00.000Z',
          },
          {
            '_id': 'search_other_department',
            'senderId': 'tech_1',
            'senderName': 'Tech Coworker',
            'departmentKey': 'tech',
            'conversationType': 'DEPARTMENT',
            'text': 'needle wrong department',
            'timestamp': '2026-11-15T09:02:00.000Z',
          },
        ],
        'pagination': {'page': 1, 'hasMore': false},
      });
      final repository = HRRepositoryImpl(api: fakeApi);
      const staff = Staff(
        id: 'tele_staff',
        name: 'Tele Staff',
        department: Department.telecalling,
      );
      repository.departmentChatMessages.value = [
        StaffChatMessage(
          id: 'search_target',
          senderId: 'coworker_1',
          senderName: 'Coworker',
          departmentKey: 'telecalling',
          conversationType: 'DEPARTMENT',
          text: 'needle target original',
          timestamp: DateTime(2026, 11, 15, 9),
        ),
        StaffChatMessage(
          id: 'search_unrelated',
          senderId: 'coworker_2',
          senderName: 'Coworker Two',
          departmentKey: 'telecalling',
          conversationType: 'DEPARTMENT',
          text: 'needle retained message',
          timestamp: DateTime(2026, 11, 15, 9, 1),
        ),
      ];
      StaffChatSocketService().isTestMode = true;

      var pageIndex = 0;
      await tester.pumpWidget(StatefulBuilder(
        builder: (context, updateParent) => MaterialApp(
          home: StaffHubShell(
            repository: repository,
            pageIndex: pageIndex,
            department: Department.telecalling,
            staff: staff,
            workMode: 'Office',
            workLocation: null,
            onNavigate: (index) => updateParent(() => pageIndex = index),
            onLogout: () {},
          ),
        ),
      ));
      await tester.tap(find.byTooltip('Open chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Chat options'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-option-search')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('chat-search')), 'needle');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('needle target original'), findsOneWidget);
      expect(find.text('needle retained message'), findsOneWidget);
      expect(find.text('needle wrong department'), findsNothing);

      final socket = StaffChatSocketService();
      socket.emitTestDeletedPayload({
        'messageId': 'search_target',
        'deletedForEveryone': false,
        'conversationType': 'DEPARTMENT',
        'departmentKey': 'telecalling',
      });
      await tester.pumpAndSettle();
      expect(find.text('needle target original'), findsOneWidget);

      socket.emitTestDeletedPayload({
        'messageId': 'search_target',
        'deletedForEveryone': true,
        'conversationType': 'DEPARTMENT',
        'departmentKey': 'telecalling',
      });
      await tester.pumpAndSettle();
      expect(find.text('needle target original'), findsNothing);
      expect(find.text('This message was deleted'), findsOneWidget);
      expect(find.text('needle retained message'), findsOneWidget);
      expect(find.text('needle wrong department'), findsNothing);

      await tester.tap(find.byTooltip('Chat options'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-option-search')));
      await tester.pumpAndSettle();
      expect(find.text('needle target original'), findsNothing);
      expect(
        find.byKey(const ValueKey('deleted-message-search_target')),
        findsOneWidget,
      );
      expect(find.text('This message was deleted'), findsWidgets);
      expect(
        repository.departmentChatMessages.value
            .singleWhere((message) => message.id == 'search_target')
            .text,
        isEmpty,
      );
      repository.dispose();
    });

    testWidgets(
        'Displays messages for authenticated department and styles HR separately',
        (WidgetTester tester) async {
      final fakeApi = FakeChatApiService();
      final repository = HRRepositoryImpl(api: fakeApi);
      final socketService = StaffChatSocketService()..isTestMode = true;

      final testStaff = Staff(
        id: 'emp_tele_01',
        chatSenderId: 'emp_tele_01',
        name: 'Sunita Sharma',
        email: 'sunita@company.com',
        department: Department.telecalling,
        role: Role.staff,
        status: Status.active,
      );

      // Seed repository messages
      repository.departmentChatMessages.value = [
        StaffChatMessage(
          id: 'msg_other',
          senderId: 'emp_tele_02',
          senderName: 'Rohan Mehra',
          senderRole: 'STAFF',
          departmentKey: 'telecalling',
          conversationType: 'DEPARTMENT',
          text: 'Campaign leads uploaded.',
          timestamp: DateTime(2026, 9, 24, 9, 30),
        ),
        StaffChatMessage(
          id: 'msg_hr',
          senderId: 'hr_lead',
          senderName: 'HR Office',
          senderRole: 'HR',
          departmentKey: 'telecalling',
          conversationType: 'DEPARTMENT',
          text: 'Please review updated calling script.',
          timestamp: DateTime(2026, 9, 24, 10, 0),
        ),
        StaffChatMessage(
          id: 'msg_self',
          senderId: 'emp_tele_01',
          senderName: 'Sunita Sharma',
          senderRole: 'STAFF',
          departmentKey: 'telecalling',
          conversationType: 'DEPARTMENT',
          text: 'Understood, starting now.',
          timestamp: DateTime(2026, 9, 24, 10, 5),
        ),
      ];

      var currentPage = 0;
      await tester.pumpWidget(StatefulBuilder(
        builder: (context, updateParent) => MaterialApp(
          home: StaffHubShell(
            repository: repository,
            pageIndex: currentPage,
            department: Department.telecalling,
            staff: testStaff,
            workMode: 'Office',
            workLocation: null,
            onNavigate: (index) => updateParent(() => currentPage = index),
            onLogout: () {},
          ),
        ),
      ));

      expect(find.byTooltip('Open chat'), findsOneWidget);
      await tester.tap(find.byTooltip('Open chat'));
      await tester.pumpAndSettle();
      expect(find.text('Company Chat'), findsNothing);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('TELECALLING'), findsOneWidget);

      // Verify messages are displayed
      expect(find.text('Campaign leads uploaded.'), findsOneWidget);
      expect(
          find.text('Please review updated calling script.'), findsOneWidget);
      expect(find.text('Understood, starting now.'), findsOneWidget);

      // Verify HR badge is rendered for HR message
      expect(find.text('HR'), findsWidgets);

      final companyEvent = StaffChatMessage(
        id: 'company_socket_message',
        senderId: 'hr_lead',
        senderName: 'HR Office',
        senderRole: 'HR',
        departmentKey: 'company',
        conversationType: 'COMPANY',
        text: 'Company-only socket update',
        timestamp: DateTime(2026, 9, 24, 10, 10),
      );
      socketService.emitTestIncomingMessage(companyEvent);
      await tester.pumpAndSettle();
      expect(find.text('Company-only socket update'), findsNothing);
      expect(
        repository.departmentChatMessages.value
            .any((message) => message.id == companyEvent.id),
        isFalse,
      );

      final otherDepartmentEvent = StaffChatMessage(
        id: 'tech_socket_message',
        senderId: 'emp_tech_03',
        senderName: 'Tech Colleague',
        senderRole: 'STAFF',
        departmentKey: 'tech',
        conversationType: 'DEPARTMENT',
        text: 'Tech-only socket update',
        timestamp: DateTime(2026, 9, 24, 10, 12),
      );
      socketService.emitTestIncomingMessage(otherDepartmentEvent);
      await tester.pumpAndSettle();
      expect(find.text('Tech-only socket update'), findsNothing);
      socketService.emitTestReconnect('telecalling');
      await tester.pumpAndSettle();
      expect(find.text('Tech-only socket update'), findsNothing);

      // Test real-time message arrival via socket
      final incomingSocketMsg = StaffChatMessage(
        id: 'realtime_sock_msg',
        senderId: 'emp_tele_03',
        senderName: 'Deepak V.',
        senderRole: 'STAFF',
        departmentKey: 'telecalling',
        conversationType: 'DEPARTMENT',
        text: 'Customer confirmed follow-up for 2 PM',
        timestamp: DateTime(2026, 9, 24, 10, 15),
      );

      socketService.emitTestIncomingMessage(incomingSocketMsg);
      await tester.pumpAndSettle();

      expect(
          find.text('Customer confirmed follow-up for 2 PM'), findsOneWidget);

      socketService.emitTestScopedMessageDeleted(
        'realtime_sock_msg',
        false,
        conversationType: 'DEPARTMENT',
        departmentKey: 'telecalling',
      );
      await tester.pumpAndSettle();
      expect(
          find.text('Customer confirmed follow-up for 2 PM'), findsOneWidget);

      // Test real-time message deletion
      socketService.emitTestScopedMessageDeleted(
        'realtime_sock_msg',
        true,
        conversationType: 'DEPARTMENT',
        departmentKey: 'telecalling',
      );
      await tester.pumpAndSettle();

      expect(find.text('Customer confirmed follow-up for 2 PM'), findsNothing);

      final ownDeleted = StaffChatMessage(
        id: 'own_deleted_message',
        senderId: testStaff.chatSenderId!,
        senderName: testStaff.name,
        senderRole: 'STAFF',
        departmentKey: 'telecalling',
        conversationType: 'DEPARTMENT',
        text: '',
        deletedForEveryone: true,
        timestamp: DateTime(2026, 9, 24, 10, 16),
      );
      socketService.emitTestIncomingMessage(ownDeleted);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('deleted-message-own_deleted_message')),
        findsOneWidget,
      );

      // Verify composer prevents empty send
      final composer = find.byKey(const ValueKey('chat-message-composer'));
      await tester.enterText(composer, '   ');
      await tester.tap(find.byKey(const ValueKey('chat-message-send')));
      await tester.pumpAndSettle();

      expect(fakeApi.postRequests.isEmpty, isTrue);

      // Send actual message
      await tester.enterText(composer, 'Client meeting concluded');
      await tester.tap(find.byKey(const ValueKey('chat-message-send')));
      await tester.pumpAndSettle();

      expect(find.text('Client meeting concluded'), findsOneWidget);

      repository.dispose();
    });

    testWidgets('Tech staff stay in their profile department chat',
        (WidgetTester tester) async {
      final fakeApi = FakeChatApiService();
      final repository = HRRepositoryImpl(api: fakeApi);
      final staff = Staff(
        id: 'emp_tech_01',
        name: 'Rohan Verma',
        department: 'Tech & Engineering',
      );
      repository.departmentChatMessages.value = [
        StaffChatMessage(
          id: 'tech_only',
          senderId: 'emp_tech_02',
          senderName: 'Tech Teammate',
          departmentKey: 'tech',
          conversationType: 'DEPARTMENT',
          text: 'Tech department update',
          timestamp: DateTime(2026, 11, 15, 9),
        ),
        StaffChatMessage(
          id: 'tele_only',
          senderId: 'emp_tele_02',
          senderName: 'Telecalling Teammate',
          departmentKey: 'telecalling',
          conversationType: 'DEPARTMENT',
          text: 'Telecalling department update',
          timestamp: DateTime(2026, 11, 15, 9, 5),
        ),
        StaffChatMessage(
          id: 'company_only',
          senderId: 'hr_admin',
          senderName: 'HR Office',
          senderRole: 'HR',
          departmentKey: 'company',
          conversationType: 'COMPANY',
          text: 'Company-wide update',
          timestamp: DateTime(2026, 11, 15, 9, 10),
        ),
      ];

      var pageIndex = 0;
      await tester.pumpWidget(StatefulBuilder(
        builder: (context, updateParent) => MaterialApp(
          home: StaffHubShell(
            repository: repository,
            pageIndex: pageIndex,
            department: Department.telecalling,
            staff: staff,
            workMode: 'Office',
            workLocation: null,
            onNavigate: (index) => updateParent(() => pageIndex = index),
            onLogout: () {},
          ),
        ),
      ));
      await tester.tap(find.byTooltip('Open chat'));
      await tester.pumpAndSettle();

      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('TECH'), findsOneWidget);
      expect(find.text('Tech department update'), findsOneWidget);
      expect(find.text('Telecalling department update'), findsNothing);
      expect(find.text('Company-wide update'), findsNothing);
      expect(find.text('Company Chat'), findsNothing);
      await tester.tap(find.byTooltip('Chat options'));
      await tester.pumpAndSettle();
      expect(find.text('Search messages'), findsOneWidget);
      expect(find.text('Clear chat'), findsOneWidget);
      expect(find.text('Company Chat'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('chat-option-search')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat-search')), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('chat-search')), 'needle');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        fakeApi.getRequests.any((request) =>
            request['endpoint'] ==
                ApiConfig.staffDepartmentMessageSearch('tech') &&
            request['queryParams']['q'] == 'needle'),
        isTrue,
      );
      expect(
        fakeApi.getRequests
            .where((request) =>
                request['endpoint'] ==
                ApiConfig.staffDepartmentMessages('tech'))
            .length,
        1,
      );
      expect(
        fakeApi.getRequests.any((request) =>
            request['endpoint'].toString().contains('company-chat')),
        isFalse,
      );

      final composer = find.byKey(const ValueKey('chat-message-composer'));
      await tester.enterText(composer, 'Tech reply');
      await tester.tap(find.byKey(const ValueKey('chat-message-send')));
      await tester.pumpAndSettle();
      expect(fakeApi.postRequests.single['endpoint'],
          ApiConfig.staffDepartmentMessages('tech'));
      expect(find.text('Tech reply'), findsOneWidget);
      repository.dispose();
    });

    testWidgets('unresolved profile department blocks chat loading and sending',
        (WidgetTester tester) async {
      final fakeApi = FakeChatApiService();
      final repository = HRRepositoryImpl(api: fakeApi);
      final staff = Staff(id: 'staff_no_department', name: 'No Department');
      var pageIndex = 0;
      await tester.pumpWidget(StatefulBuilder(
        builder: (context, updateParent) => MaterialApp(
          home: StaffHubShell(
            repository: repository,
            pageIndex: pageIndex,
            department: Department.tech,
            staff: staff,
            workMode: 'Office',
            workLocation: null,
            onNavigate: (index) => updateParent(() => pageIndex = index),
            onLogout: () {},
          ),
        ),
      ));
      await tester.tap(find.byTooltip('Open chat'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('department-unavailable-heading')),
        findsOneWidget,
      );
      expect(find.text('Your profile has no assigned department.'),
          findsOneWidget);
      expect(
        fakeApi.getRequests.any((request) {
          final endpoint = request['endpoint'] as String;
          return endpoint.startsWith('/staff/departments/') ||
              endpoint == ApiConfig.staffChatMessages;
        }),
        isFalse,
      );
      expect(StaffChatSocketService().currentDepartmentKey, isNull);
      expect(
          tester
              .widget<TextField>(
                  find.byKey(const ValueKey('chat-message-composer')))
              .enabled,
          isFalse);
      expect(find.text('Company Chat'), findsNothing);
      repository.dispose();
    });

    testWidgets('emoji search inserts multiple emojis into the composer',
        (WidgetTester tester) async {
      final repository = HRRepositoryImpl(api: FakeChatApiService());
      final staff = Staff(
        id: 'emp_tele_01',
        name: 'Sunita Sharma',
        department: Department.telecalling,
      );
      var pageIndex = 0;
      await tester.pumpWidget(StatefulBuilder(
        builder: (context, updateParent) => MaterialApp(
          home: StaffHubShell(
            repository: repository,
            pageIndex: pageIndex,
            department: Department.tech,
            staff: staff,
            workMode: 'Office',
            workLocation: null,
            onNavigate: (index) => updateParent(() => pageIndex = index),
            onLogout: () {},
          ),
        ),
      ));
      await tester.tap(find.byTooltip('Open chat'));
      await tester.pumpAndSettle();

      final composer = find.byKey(const ValueKey('chat-message-composer'));
      await tester.enterText(composer, 'Hello ');
      await tester.tap(find.byTooltip('Choose emoji'));
      await tester.pumpAndSettle();
      final emojiSearch = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          (widget.decoration?.hintText == 'Search emojis' ||
              widget.decoration?.hintText == 'Search emoji...'));
      await tester.enterText(emojiSearch, 'smile');
      await tester.pumpAndSettle();
      await tester.tap(find.text('😊'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(composer).controller!.text, 'Hello 😊');

      await tester.tap(find.byTooltip('Choose emoji'));
      await tester.pumpAndSettle();
      await tester.enterText(emojiSearch, 'heart');
      await tester.pumpAndSettle();
      await tester.tap(find.text('❤️'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(composer).controller!.text, 'Hello 😊❤️');
      repository.dispose();
    });

    testWidgets('Attachment icon shows informative tooltip/notice',
        (WidgetTester tester) async {
      final repository = HRRepositoryImpl(api: FakeChatApiService());
      final testStaff = Staff(
        id: 'emp_tech_01',
        name: 'Rahul K.',
        department: Department.tech,
      );

      var selectedPage = 0;
      await tester.pumpWidget(StatefulBuilder(
        builder: (context, updateParent) => MaterialApp(
          home: StaffHubShell(
            repository: repository,
            pageIndex: selectedPage,
            department: Department.tech,
            staff: testStaff,
            workMode: 'Office',
            workLocation: null,
            onNavigate: (idx) => updateParent(() => selectedPage = idx),
            onLogout: () {},
          ),
        ),
      ));

      expect(find.byTooltip('Open chat'), findsOneWidget);
      await tester.tap(find.byTooltip('Open chat'));
      await tester.pumpAndSettle();

      final addAttachmentBtn = find.byIcon(Icons.add_circle_outline);
      expect(addAttachmentBtn, findsOneWidget);

      await tester.tap(addAttachmentBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('File attachments are not currently supported by chat.'),
        findsOneWidget,
      );

      repository.dispose();
    });
  });
}
