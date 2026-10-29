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
    // Match exact or prefix
    for (final key in responses.keys) {
      if (endpoint.contains(key)) {
        final val = responses[key];
        if (val is Exception) throw val;
        return val;
      }
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
        'departmentKey': 'tech',
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
    });

    test('normalizes HR representations to "hr"', () {
      expect(canonicalDepartmentKey('HR'), 'hr');
      expect(canonicalDepartmentKey('Human Resources'), 'hr');
      expect(canonicalDepartmentKey('hr'), 'hr');
    });

    test('fallback returns "tech" on null or empty input', () {
      expect(canonicalDepartmentKey(null), 'tech');
      expect(canonicalDepartmentKey(''), 'tech');
      expect(canonicalDepartmentKey('   '), 'tech');
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
        expect(msg.isHR, isTrue, reason: 'Expected $role to be recognized as HR');
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

    test('isSentBy matches authenticated employee profile accurately', () {
      final currentStaff = Staff(
        id: 'staff_99',
        name: 'Kavita Roy',
        department: Department.telecalling,
      );

      final myMsg = StaffChatMessage(
        id: 'm1',
        senderId: 'staff_99',
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
    test('notifies message listeners when new_message or message_received arrives', () {
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

    test('fetchDepartmentMessages parses and sorts backend list chronologically', () async {
      fakeApi.setResponse(ApiConfig.staffChatMessages, {
        'success': true,
        'data': [
          {
            '_id': 'msg_b',
            'senderId': 'staff_2',
            'senderName': 'Bob',
            'text': 'Second message',
            'timestamp': '2026-10-29T10:02:00.000Z',
          },
          {
            '_id': 'msg_a',
            'senderId': 'staff_1',
            'senderName': 'Alice',
            'text': 'First message',
            'timestamp': '2026-10-29T10:00:00.000Z',
          },
        ]
      });

      final result = await repository.fetchDepartmentMessages();

      expect(result.length, 2);
      expect(result[0].id, 'msg_a');
      expect(result[0].text, 'First message');
      expect(result[1].id, 'msg_b');
      expect(result[1].text, 'Second message');
      expect(repository.departmentChatMessages.value.length, 2);
    });

    test('sendDepartmentMessage validates non-empty text and avoids duplicates', () async {
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
      expect(fakeApi.postRequests.first['body']['text'], 'Real backend message');
      expect(repository.departmentChatMessages.value.contains(sent), isTrue);
    });

    test('deleteDepartmentMessageForMe removes message from local notifier', () async {
      repository.departmentChatMessages.value = [
        StaffChatMessage(
          id: 'del_me_1',
          senderId: 'staff_1',
          text: 'To be deleted',
          timestamp: DateTime.now(),
        ),
      ];

      await repository.deleteDepartmentMessageForMe('del_me_1');

      expect(fakeApi.patchRequests, contains(ApiConfig.staffChatMessageDeleteForMe('del_me_1')));
      expect(repository.departmentChatMessages.value.isEmpty, isTrue);
    });
  });

  group('5. StaffHub Chat Widget Integration', () {
    testWidgets('Displays messages for authenticated department and styles HR separately',
        (WidgetTester tester) async {
      final fakeApi = FakeChatApiService();
      final repository = HRRepositoryImpl(api: fakeApi);
      final socketService = StaffChatSocketService()..isTestMode = true;

      final testStaff = Staff(
        id: 'emp_tele_01',
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
          text: 'Campaign leads uploaded.',
          timestamp: DateTime(2026, 9, 24, 9, 30),
        ),
        StaffChatMessage(
          id: 'msg_hr',
          senderId: 'hr_lead',
          senderName: 'HR Office',
          senderRole: 'HR',
          departmentKey: 'telecalling',
          text: 'Please review updated calling script.',
          timestamp: DateTime(2026, 9, 24, 10, 0),
        ),
        StaffChatMessage(
          id: 'msg_self',
          senderId: 'emp_tele_01',
          senderName: 'Sunita Sharma',
          senderRole: 'STAFF',
          departmentKey: 'telecalling',
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

      // Verify messages are displayed
      expect(find.text('Campaign leads uploaded.'), findsOneWidget);
      expect(find.text('Please review updated calling script.'), findsOneWidget);
      expect(find.text('Understood, starting now.'), findsOneWidget);

      // Verify HR badge is rendered for HR message
      expect(find.text('HR'), findsWidgets);

      // Test real-time message arrival via socket
      final incomingSocketMsg = StaffChatMessage(
        id: 'realtime_sock_msg',
        senderId: 'emp_tele_03',
        senderName: 'Deepak V.',
        senderRole: 'STAFF',
        departmentKey: 'telecalling',
        text: 'Customer confirmed follow-up for 2 PM',
        timestamp: DateTime(2026, 9, 24, 10, 15),
      );

      socketService.emitTestIncomingMessage(incomingSocketMsg);
      await tester.pumpAndSettle();

      expect(find.text('Customer confirmed follow-up for 2 PM'), findsOneWidget);

      // Test real-time message deletion
      socketService.emitTestMessageDeleted('realtime_sock_msg', true);
      await tester.pumpAndSettle();

      expect(find.text('Customer confirmed follow-up for 2 PM'), findsNothing);

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

