import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:town_pass/bean/assist.dart';
import 'package:town_pass/service/account_service.dart';
import 'package:town_pass/service/notification_service.dart';
import 'package:town_pass/util/tp_route.dart';

class AssistApiException implements Exception {
  AssistApiException(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;
  @override
  String toString() => message;
}

class PairingCode {
  PairingCode(Map raw)
    : code = raw['code'] as String,
      qrPayload = raw['qrPayload'] as String,
      expiresAt = DateTime.fromMillisecondsSinceEpoch((raw['expiresAt'] as num).toInt());
  final String code;
  final String qrPayload;
  final DateTime expiresAt;
}

/// 陪你辦（協辦）服務。
///
/// 長輩的台北通 App 已完成實名驗證，啟動時以帳號向協辦後端換取 token，
/// 再透過 Socket 接收「有人想協助您」等即時事件。正式版的即時事件應改走 APNs／FCM 推播。
class AssistService extends GetxService {
  /// 模擬器可直接連本機；實機請用 --dart-define=ASSIST_API=http://<電腦區網 IP>:3000
  static const String apiBase = String.fromEnvironment('ASSIST_API', defaultValue: 'http://localhost:3000');

  final RxMap<String, AssistSession> sessions = <String, AssistSession>{}.obs;
  final Rxn<PairingCode> pairing = Rxn<PairingCode>();
  final RxBool linked = false.obs;
  final RxBool connected = false.obs;
  final RxnString resultId = RxnString();
  final RxList<Map<String, dynamic>> audit = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> applications = <Map<String, dynamic>>[].obs;
  final Rxn<Map<String, dynamic>> auditStatus = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> legal = Rxn<Map<String, dynamic>>();
  final RxMap<String, ServiceDef> serviceDefs = <String, ServiceDef>{}.obs;

  String? _token;
  io.Socket? _socket;
  Timer? _retry;
  String? _watchingId;
  final Set<String> _notifiedRequests = {};
  final Set<String> _notifiedAuth = {};

  AssistService init() {
    _link();
    return this;
  }

  // ───────────────────────── 查詢

  AssistSession? get incoming {
    final now = DateTime.now();
    final list = sessions.values.where((s) => s.isPending && (s.expiresAt?.isAfter(now) ?? false)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.firstOrNull;
  }

  AssistSession? get active => sessions.values.where((s) => s.isActive).firstOrNull;

  // ───────────────────────── 連線

  Future<void> _link() async {
    _retry?.cancel();
    try {
      final accountId = Get.find<AccountService>().account?.id;
      final res = await _request('POST', '/auth/townpass-login', {'accountId': accountId}, false) as Map;
      _token = res['token'] as String;
      linked.value = true;
      _connectSocket();
      legal.value = Map<String, dynamic>.from(await _request('GET', '/legal') as Map);
      await refresh();
    } catch (_) {
      linked.value = false;
      _retry = Timer(const Duration(seconds: 5), _link);
    }
  }

  Future<void> retryNow() => _link();

  void _connectSocket() {
    _socket?.dispose();
    final socket = io.io(
      apiBase,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': _token})
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    );
    socket.on('session:update', (data) {
      try {
        _onSession(Map<String, dynamic>.from(data as Map));
      } catch (_) {}
    });
    socket.onConnect((_) {
      connected.value = true;
      refresh();
    });
    socket.onDisconnect((_) => connected.value = false);
    socket.connect();
    _socket = socket;
  }

  Future<dynamic> _request(String method, String path, [Map<String, dynamic>? body, bool auth = true]) async {
    final uri = Uri.parse('$apiBase/api$path');
    final headers = {'Content-Type': 'application/json', if (auth && _token != null) 'Authorization': 'Bearer $_token'};
    final res = method == 'GET'
        ? await http.get(uri, headers: headers).timeout(const Duration(seconds: 8))
        : await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 8));
    final text = utf8.decode(res.bodyBytes);
    final data = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 400) {
      final err = (data is Map ? data['error'] : null) as Map?;
      throw AssistApiException(
        res.statusCode,
        err?['code'] as String? ?? 'ERROR',
        err?['message'] as String? ?? '系統忙碌中，請稍後再試',
      );
    }
    return data;
  }

  // ───────────────────────── 推播事件

  void _onSession(Map<String, dynamic> raw) {
    final s = AssistSession(raw);
    sessions[s.id] = s;
    service(s.serviceId);

    if (s.isPending && !_notifiedRequests.contains(s.id) && (s.expiresAt?.isAfter(DateTime.now()) ?? false)) {
      _notifiedRequests.add(s.id);
      final h = s.helper;
      HapticFeedback.heavyImpact();
      NotificationService.showNotification(
        title: '${h?.name ?? ''} ${h?.title ?? ''} 想協助您',
        content: '辦理「${s.serviceTitle}」。請打開台北通首頁查看並回應。',
      );
    }

    if (s.isActive) {
      _watchingId = s.id;
      pairing.value = null;
      final authKey = '${s.id}:${s.pendingAuth}:${s.field(s.pendingAuth ?? '').requestCount}';
      if (s.pendingAuth != null && !_notifiedAuth.contains(authKey)) {
        _notifiedAuth.add(authKey);
        HapticFeedback.mediumImpact();
        if (Get.currentRoute != TPRoute.assistSession) {
          NotificationService.showNotification(
            title: '有一項資料需要您確認',
            content: '${s.helper?.name ?? '協助者'} 請您確認是否提供「${s.pendingAuthField?.label ?? ''}」',
          );
        }
      }
    } else if (_watchingId == s.id && !s.isOpen) {
      _watchingId = null;
      resultId.value = s.id;
      refreshRecords();
    }
  }

  Future<void> refresh() async {
    if (_token == null) return;
    final list = await _request('GET', '/elder/sessions') as List;
    for (final e in list.reversed) {
      final s = AssistSession(Map<String, dynamic>.from(e as Map));
      // 啟動前就已存在的請求不再重複發系統通知
      if (s.isPending) _notifiedRequests.add(s.id);
      _onSession(s.raw);
    }
    await refreshRecords();
  }

  Future<void> refreshRecords() async {
    if (_token == null) return;
    audit.assignAll(((await _request('GET', '/elder/audit')) as List).map((e) => Map<String, dynamic>.from(e as Map)));
    applications.assignAll(
      ((await _request('GET', '/elder/applications')) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    auditStatus.value = Map<String, dynamic>.from(await _request('GET', '/audit/verify') as Map);
  }

  Future<ServiceDef> service(String id) async {
    final cached = serviceDefs[id];
    if (cached != null) return cached;
    final def = ServiceDef(Map<String, dynamic>.from(await _request('GET', '/services/$id') as Map));
    serviceDefs[id] = def;
    return def;
  }

  // ───────────────────────── 長輩的動作

  Future<void> _apply(Future<dynamic> call) async => _onSession(Map<String, dynamic>.from(await call as Map));

  Future<void> createPairingCode() async {
    pairing.value = PairingCode(await _request('POST', '/elder/pairing-code') as Map);
  }

  void clearPairing() => pairing.value = null;

  void dismissResult() => resultId.value = null;

  Future<void> respond(String id, bool accept) async {
    await _apply(_request('POST', '/elder/sessions/$id/respond', {'accept': accept}));
    refreshRecords();
  }

  Future<void> authorize(String id, String key, bool approve) =>
      _apply(_request('POST', '/elder/sessions/$id/fields/$key/authorize', {'approve': approve}));

  Future<void> revoke(String id, String key) => _apply(_request('POST', '/elder/sessions/$id/fields/$key/revoke'));

  Future<void> input(String id, String key, String value) =>
      _apply(_request('POST', '/elder/sessions/$id/fields/$key/input', {'value': value}));

  Future<void> submit(String id, bool confirm) =>
      _apply(_request('POST', '/elder/sessions/$id/submit', {'confirm': confirm}));

  Future<void> end(String id) => _apply(_request('POST', '/sessions/$id/end'));

  Future<void> block(String id) async {
    await _apply(_request('POST', '/elder/sessions/$id/block'));
    refreshRecords();
  }

  @override
  void onClose() {
    _retry?.cancel();
    _socket?.dispose();
    super.onClose();
  }
}
