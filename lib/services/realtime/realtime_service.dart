import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../api/api_service.dart';

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  static const bool _enableWebRealtime = false;

  io.Socket? _socket;
  Timer? _delayedJoinTimer;
  Timer? _cooldownTimer;
  int _connectErrorCount = 0;
  DateTime? _cooldownUntil;
  bool _isConnecting = false;
  bool _forcePolling = false;

  static const int _maxConnectErrors = 3;
  static const Duration _cooldownDuration = Duration(seconds: 30);

  final StreamController<Map<String, dynamic>> _orderUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _notificationsController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get orderUpdates => _orderUpdatesController.stream;
  Stream<Map<String, dynamic>> get notifications => _notificationsController.stream;

  bool get isConnected => _socket?.connected == true;

  void connect({
    required String token,
    required String userId,
    required String role,
  }) {
    if (token.isEmpty) return;
    if (kIsWeb) {
      if (!_enableWebRealtime) return;
    }
    if (_isInCooldown()) return;
    if (_isConnecting) return;

    // If already connected, just ensure rooms are joined.
    if (_socket != null) {
      if (!isConnected) {
        _isConnecting = true;
        _socket!.connect();
      }
      _joinRooms(userId: userId, role: role);
      return;
    }

    final transports = _forcePolling ? ['polling'] : ['websocket', 'polling'];
    final options = io.OptionBuilder()
      // Allow Socket.IO fallback transport on web/dev setups.
      .setTransports(transports)
      .setTimeout(5000)
      .setReconnectionAttempts(_maxConnectErrors)
      .setReconnectionDelay(2000)
      .setReconnectionDelayMax(10000)
        .disableAutoConnect()
        .setQuery({'token': token, 'user_id': userId, 'role': role})
        .setExtraHeaders({'Authorization': 'Bearer $token'})
        .build();

    final url = ApiService.baseUrl;
    final socket = io.io(url, options);
    _socket = socket;

    socket.onConnect((_) {
      _isConnecting = false;
      _connectErrorCount = 0;
      _cooldownUntil = null;
      if (kDebugMode) {
        print('🟢 Socket connected');
      }
      _joinRooms(userId: userId, role: role);
    });

    socket.onDisconnect((_) {
      _isConnecting = false;
      if (kDebugMode) {
        print('🔴 Socket disconnected');
      }
    });

    socket.onConnectError((err) {
      if (kDebugMode) {
        print('❌ Socket connect error: $err');
      }
      _trackConnectError(err);
    });

    socket.onError((err) {
      if (kDebugMode) {
        print('❌ Socket error: $err');
      }
      _trackConnectError(err);
    });

    socket.on('order_update', (data) {
      final payload = _asMap(data);
      if (payload != null) _orderUpdatesController.add(payload);
    });

    socket.on('notification', (data) {
      final payload = _asMap(data);
      if (payload != null) _notificationsController.add(payload);
    });

    _isConnecting = true;
    socket.connect();

    // One-shot safety: re-join rooms shortly after connect (useful on web hot reload).
    _delayedJoinTimer?.cancel();
    _delayedJoinTimer = Timer(const Duration(seconds: 3), () {
      _joinRooms(userId: userId, role: role);
    });
  }

  void disconnect() {
    _delayedJoinTimer?.cancel();
    _delayedJoinTimer = null;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    _isConnecting = false;

    final socket = _socket;
    _socket = null;

    try {
      socket?.dispose();
    } catch (_) {
      // ignore
    }
  }

  void joinRoom(String room) {
    final socket = _socket;
    if (socket == null) return;
    if (!socket.connected) return;
    socket.emit('join_room', {'room': room});
  }

  void leaveRoom(String room) {
    final socket = _socket;
    if (socket == null) return;
    if (!socket.connected) return;
    socket.emit('leave_room', {'room': room});
  }

  void joinOrderRoom({required String orderId, required String userId}) {
    final socket = _socket;
    if (socket == null) return;
    if (!socket.connected) return;
    socket.emit('join_order_room', {'order_id': orderId, 'user_id': userId});
  }

  void joinAdminRoom({required String userId}) {
    final socket = _socket;
    if (socket == null) return;
    if (!socket.connected) return;
    socket.emit('join_admin_room', {'user_id': userId});
    // Fallback: generic room join (backend has an unguarded handler).
    socket.emit('join_room', {'room': 'admin'});
  }

  void _joinRooms({required String userId, required String role}) {
    final socket = _socket;
    if (socket == null) return;
    if (!socket.connected) return;

    // Always join personal room
    joinRoom('user_$userId');

    if (role == 'vendor') {
      joinRoom('vendor_$userId');
      return;
    }

    if (role == 'rider') {
      joinRoom('riders');
      joinRoom('rider_$userId');
      return;
    }

    if (role == 'admin') {
      joinAdminRoom(userId: userId);
    }
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  bool _isInCooldown() {
    final until = _cooldownUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  void _trackConnectError([dynamic err]) {
    _connectErrorCount += 1;
    _isConnecting = false;

    final errText = err?.toString().toLowerCase() ?? '';
    if (errText.contains('transporterror') || errText.contains('websocket')) {
      _forcePolling = true;
    }

    if (_connectErrorCount < _maxConnectErrors) return;

    _cooldownUntil = DateTime.now().add(_cooldownDuration);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(_cooldownDuration, () {
      _cooldownUntil = null;
    });

    final socket = _socket;
    _socket = null;

    try {
      socket?.disconnect();
      socket?.dispose();
    } catch (_) {
      // ignore
    }
  }
}
