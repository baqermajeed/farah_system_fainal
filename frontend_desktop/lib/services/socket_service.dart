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
  Function(List<String> onlineUserIds)? onPresenceSnapshot;

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
      if (_socket != null && !_isConnected) {
        _socket!.dispose();
        _socket = null;
      }
    }

    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      print('❌ [SocketService] No token available for presence connection');
      return false;
    }

    try {
      if (_socket != null && !_isConnected) {
        _socket!.dispose();
        _socket = null;
      }

      _isConnecting = true;

      // Match mobile chat client: origin + explicit /socket.io path.
      final socketUrl = ApiConstants.socketOrigin;
      print('🔌 [SocketService] Connecting to $socketUrl (path: /socket.io)');

      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setPath('/socket.io')
            .setTransports(['websocket', 'polling'])
            .setAuth({'token': token})
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .enableForceNew()
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

      for (var i = 0; i < 40 && !_isConnected && _isConnecting; i++) {
        await Future.delayed(const Duration(milliseconds: 250));
      }

      _isConnecting = false;
      if (!_isConnected) {
        print(
          '⚠️ [SocketService] Presence connection timeout '
          '(connected=${_socket?.connected})',
        );
        if (_socket != null && !_socket!.connected) {
          _socket!.dispose();
          _socket = null;
        }
      } else {
        print('✅ [SocketService] Presence socket connected');
      }

      return _isConnected;
    } catch (e) {
      print('❌ [SocketService] Presence connection error: $e');
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

    _socket!.onConnect((_) {
      print('✅ [SocketService] onConnect');
      markConnected();
    });
    _socket!.on('connect', (_) => markConnected());
    _socket!.onDisconnect((reason) {
      print('❌ [SocketService] Disconnected: $reason');
      markDisconnected();
    });
    _socket!.onConnectError((error) {
      print('❌ [SocketService] Connect error: $error');
      markDisconnected();
    });
    _socket!.onError((error) {
      print('❌ [SocketService] Error: $error');
    });
    _socket!.onReconnectFailed((_) {
      print('❌ [SocketService] Reconnect failed');
      markDisconnected();
    });

    _socket!.on('presence_changed', (data) {
      if (data is! Map) return;
      final userId = data['user_id']?.toString();
      final isOnline = data['is_online'] == true;
      if (userId != null && userId.isNotEmpty) {
        onPresenceChanged?.call(userId, isOnline);
      }
    });

    _socket!.on('presence_snapshot', (data) {
      if (data is! Map) return;
      final raw = data['online_user_ids'];
      if (raw is! List) return;
      final ids = raw
          .map((e) => e?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      onPresenceSnapshot?.call(ids);
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
