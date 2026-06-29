import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:frontend_desktop/core/network/api_constants.dart';
import 'package:frontend_desktop/services/auth_service.dart';

/// Socket.IO service for real-time presence and future chat features.
class SocketService {
  IO.Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;

  final AuthService _authService = AuthService();

  Function(bool)? onConnectionStatusChanged;
  Function(String userId, bool isOnline)? onPresenceChanged;

  IO.Socket? get socket => _socket;
  bool get isConnected => _isConnected;

  Future<bool> connect() async {
    if (_isConnected) return true;

    if (_isConnecting) {
      for (var i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 250));
        if (_isConnected) return true;
      }
      _isConnecting = false;
    }

    final token = await _authService.getToken();
    if (token == null || token.isEmpty) return false;

    try {
      if (_socket != null && !_isConnected) {
        _socket!.dispose();
        _socket = null;
      }

      _isConnecting = true;

      _socket = IO.io(
        ApiConstants.baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setAuth({'token': token})
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setReconnectionAttempts(10)
            .setTimeout(20000)
            .build(),
      );

      _setupEventHandlers();

      if (!_socket!.connected) {
        _socket!.connect();
      }

      for (var i = 0; i < 40 && !_isConnected; i++) {
        await Future.delayed(const Duration(milliseconds: 250));
      }

      _isConnecting = false;
      if (!_isConnected && _socket != null && !_socket!.connected) {
        _socket!.dispose();
        _socket = null;
      }

      return _isConnected;
    } catch (_) {
      _isConnecting = false;
      return false;
    }
  }

  void _setupEventHandlers() {
    if (_socket == null) return;

    void markConnected() {
      _isConnected = true;
      _isConnecting = false;
      onConnectionStatusChanged?.call(true);
    }

    void markDisconnected() {
      _isConnected = false;
      _isConnecting = false;
      onConnectionStatusChanged?.call(false);
    }

    _socket!.onConnect((_) => markConnected());
    _socket!.on('connect', (_) => markConnected());
    _socket!.onDisconnect((_) => markDisconnected());
    _socket!.onConnectError((_) => markDisconnected());
    _socket!.onReconnectFailed((_) => markDisconnected());

    _socket!.on('presence_changed', (data) {
      if (data is! Map) return;
      final userId = data['user_id']?.toString();
      final isOnline = data['is_online'] == true;
      if (userId != null && userId.isNotEmpty) {
        onPresenceChanged?.call(userId, isOnline);
      }
    });
  }

  void disconnect() {
    if (_socket == null) return;
    _socket!.disconnect();
    _socket!.dispose();
    _socket = null;
    _isConnected = false;
    _isConnecting = false;
    onConnectionStatusChanged?.call(false);
  }

  Future<bool> reconnect() async {
    disconnect();
    await Future.delayed(const Duration(milliseconds: 300));
    return connect();
  }
}
