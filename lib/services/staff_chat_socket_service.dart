import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';
import '../models.dart';
import '../storage/token_storage.dart';

/// Service managing real-time Socket.IO bidirectional connection for StaffHub Department Chat.
class StaffChatSocketService {
  static final StaffChatSocketService _instance =
      StaffChatSocketService._internal();
  factory StaffChatSocketService() => _instance;
  StaffChatSocketService._internal();

  io.Socket? _socket;
  String? _currentDepartmentKey;
  bool _isConnected = false;
  DateTime? _lastDisconnectTime;
  bool isTestMode = false;

  final List<void Function(StaffChatMessage message)> _messageListeners = [];
  final List<void Function(String messageId, bool deletedForEveryone)>
      _deleteListeners = [];
  final List<void Function(String deptKey)> _reconnectListeners = [];
  final List<void Function(bool isConnected)> _connectionListeners = [];

  bool get isConnected => _isConnected;
  String? get currentDepartmentKey => _currentDepartmentKey;

  /// Initialize and connect the socket using the current stored JWT token.
  Future<void> connect({String? token, String? url}) async {
    if (isTestMode) {
      _isConnected = true;
      _notifyConnectionStatus(true);
      return;
    }

    final effectiveToken = token ?? await TokenStorage.getToken();
    final effectiveUrl = url ?? ApiConfig.socketUrl;

    if (effectiveToken == null || effectiveToken.isEmpty) {
      return;
    }

    // If socket exists and is already connected, don't recreate
    if (_socket != null && _socket!.connected) {
      return;
    }

    // Clean up previous socket if any
    disposeSocket();

    try {
      final opts = io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': effectiveToken})
          .setExtraHeaders({'Authorization': 'Bearer $effectiveToken'})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setTimeout(10000)
          .build();

      _socket = io.io(effectiveUrl, opts);

      _socket!.onConnect((_) {
        _isConnected = true;
        _notifyConnectionStatus(true);

        // Rejoin active department room upon connect / reconnect
        if (_currentDepartmentKey != null &&
            _currentDepartmentKey!.isNotEmpty) {
          _emitJoinDepartment(_currentDepartmentKey!);
        }

        // If previously disconnected, notify listeners to fetch missed messages
        if (_lastDisconnectTime != null && _currentDepartmentKey != null) {
          final dept = _currentDepartmentKey!;
          for (final listener in List.of(_reconnectListeners)) {
            try {
              listener(dept);
            } catch (_) {}
          }
        }
        _lastDisconnectTime = null;
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        _lastDisconnectTime = DateTime.now();
        _notifyConnectionStatus(false);
      });

      _socket!.onConnectError((err) {
        _isConnected = false;
        _notifyConnectionStatus(false);
      });

      // Handle server events
      _socket!.on('new_message', (data) => _handleIncomingMessage(data));
      _socket!.on('message_received', (data) => _handleIncomingMessage(data));
      _socket!.on('message_deleted', (data) => _handleMessageDeleted(data));
    } catch (_) {
      _isConnected = false;
      _notifyConnectionStatus(false);
    }
  }

  void _handleIncomingMessage(dynamic data) {
    if (data == null) return;
    try {
      final Map<String, dynamic> json = data is Map<String, dynamic>
          ? data
          : Map<String, dynamic>.from(data as Map);
      final msg = StaffChatMessage.fromJson(json);

      for (final listener in List.of(_messageListeners)) {
        try {
          listener(msg);
        } catch (_) {}
      }
    } catch (_) {}
  }

  void _handleMessageDeleted(dynamic data) {
    if (data == null) return;
    try {
      final Map<String, dynamic> json = data is Map<String, dynamic>
          ? data
          : Map<String, dynamic>.from(data as Map);
      final messageId =
          json['messageId']?.toString() ?? json['id']?.toString() ?? '';
      final deletedForEveryone = json['deletedForEveryone'] == true;

      if (messageId.isNotEmpty) {
        for (final listener in List.of(_deleteListeners)) {
          try {
            listener(messageId, deletedForEveryone);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  void _notifyConnectionStatus(bool connected) {
    for (final listener in List.of(_connectionListeners)) {
      try {
        listener(connected);
      } catch (_) {}
    }
  }

  /// Subscribes to the canonical department room on the backend.
  void joinDepartment(String deptKey) {
    final canonicalKey = canonicalDepartmentKey(deptKey);
    if (canonicalKey.isEmpty) return;

    if (_currentDepartmentKey != null &&
        _currentDepartmentKey != canonicalKey) {
      leaveDepartment();
    }

    _currentDepartmentKey = canonicalKey;

    if (_socket == null || !_socket!.connected) {
      connect();
    } else {
      _emitJoinDepartment(canonicalKey);
    }
  }

  void _emitJoinDepartment(String canonicalKey) {
    if (isTestMode) return;
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join_department', {'departmentKey': canonicalKey});
    }
  }

  /// Leaves the current department room.
  void leaveDepartment() {
    if (_currentDepartmentKey != null) {
      if (!isTestMode && _socket != null && _socket!.connected) {
        _socket!.emit(
            'leave_department', {'departmentKey': _currentDepartmentKey});
      }
      _currentDepartmentKey = null;
    }
  }

  // --- Test Simulation Methods ---

  void emitTestIncomingMessage(StaffChatMessage msg) {
    for (final listener in List.of(_messageListeners)) {
      try {
        listener(msg);
      } catch (_) {}
    }
  }

  void emitTestMessageDeleted(String messageId, bool deletedForEveryone) {
    for (final listener in List.of(_deleteListeners)) {
      try {
        listener(messageId, deletedForEveryone);
      } catch (_) {}
    }
  }

  void emitTestReconnect(String deptKey) {
    for (final listener in List.of(_reconnectListeners)) {
      try {
        listener(deptKey);
      } catch (_) {}
    }
  }

  void emitTestConnection(bool connected) {
    _isConnected = connected;
    _notifyConnectionStatus(connected);
  }

  // Listener registrations

  void Function() addMessageListener(
      void Function(StaffChatMessage message) listener) {
    _messageListeners.add(listener);
    return () => _messageListeners.remove(listener);
  }

  void Function() addDeleteListener(
      void Function(String messageId, bool deletedForEveryone) listener) {
    _deleteListeners.add(listener);
    return () => _deleteListeners.remove(listener);
  }

  void Function() addReconnectListener(void Function(String deptKey) listener) {
    _reconnectListeners.add(listener);
    return () => _reconnectListeners.remove(listener);
  }

  void Function() addConnectionListener(
      void Function(bool isConnected) listener) {
    _connectionListeners.add(listener);
    return () => _connectionListeners.remove(listener);
  }

  /// Clean up listeners and disconnect socket.
  void disposeSocket() {
    leaveDepartment();
    if (_socket != null) {
      try {
        _socket!.off('new_message');
        _socket!.off('message_received');
        _socket!.off('message_deleted');
        _socket!.disconnect();
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }
    _isConnected = false;
  }

  /// Reset internal state completely (useful in test teardown)
  void reset() {
    disposeSocket();
    _messageListeners.clear();
    _deleteListeners.clear();
    _reconnectListeners.clear();
    _connectionListeners.clear();
    _currentDepartmentKey = null;
    _lastDisconnectTime = null;
    isTestMode = false;
  }
}

