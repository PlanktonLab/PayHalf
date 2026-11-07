import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// 只接收伺服器推播；所有動作都透過 REST 送出。
class Realtime {
  io.Socket? _socket;

  void connect({
    required String base,
    required String token,
    required void Function(Map<String, dynamic> session) onSession,
    void Function()? onConnect,
    void Function(bool connected)? onStatus,
  }) {
    dispose();
    final socket = io.io(
      base,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    );
    socket.on('session:update', (data) {
      try {
        onSession(Map<String, dynamic>.from(data as Map));
      } catch (e) {
        debugPrint('[realtime] 推播處理失敗：$e');
      }
    });
    socket.onConnect((_) {
      onStatus?.call(true);
      onConnect?.call();
    });
    socket.onDisconnect((_) => onStatus?.call(false));
    socket.connect();
    _socket = socket;
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
