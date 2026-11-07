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
    void Function()? onTrusted,
    void Function(Map<String, dynamic> help)? onHelp,
    void Function(Map<String, dynamic> request)? onTrustRequest,
    void Function(Map<String, dynamic> event)? onFormResponse,
    void Function(Map<String, dynamic> ticket)? onFormTicket,
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
    // 信任的人清單有變（長輩加入／移除、封鎖）
    socket.on('trusted:update', (_) => onTrusted?.call());
    // 長輩主動請信任的人幫忙（雙方都會收到狀態更新）
    socket.on('help:update', (data) {
      try {
        onHelp?.call(Map<String, dynamic>.from(data as Map));
      } catch (_) {}
    });
    // 加好友：家人掃了長輩的邀請碼（長輩確認／結果）
    socket.on('trust:request', (data) {
      try {
        onTrustRequest?.call(Map<String, dynamic>.from(data as Map));
      } catch (_) {}
    });
    // 表單後台：民眾送出一份回覆（承辦人員才會收到）
    socket.on('form:response', (data) {
      try {
        onFormResponse?.call(Map<String, dynamic>.from(data as Map));
      } catch (_) {}
    });
    // 長輩填表填到一半請線上客服幫忙（等待／被接手／取消／逾時）
    socket.on('form:ticket', (data) {
      try {
        onFormTicket?.call(Map<String, dynamic>.from(data as Map));
      } catch (_) {}
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
