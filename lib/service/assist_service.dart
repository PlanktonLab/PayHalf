import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:town_pass/bean/assist.dart';
import 'package:town_pass/service/account_service.dart';
import 'package:town_pass/service/notification_service.dart';
import 'package:town_pass/service/shared_preferences_service.dart';
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

/// 陪辦（協辦）服務。
///
/// 長輩的台北通 App 已完成實名驗證，啟動時以帳號向協辦後端換取 token，
/// 再透過 Socket 接收「有人想協助您」等即時事件。正式版的即時事件應改走 APNs／FCM 推播。
class AssistService extends GetxService {
  /// 雲端 demo 後端（OracleCloud，nginx → pm2 payhalf-assist）
  static const String cloudBase = 'https://payhalf.plankton.tw';

  /// 本機後端：iOS 模擬器連 localhost、Android 模擬器連 10.0.2.2（都指向電腦本機）
  static String get localBase => Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

  /// 編譯時預設：--dart-define=ASSIST_API=https://payhalf.plankton.tw（或實機用 http://<電腦區網 IP>:3000）。
  /// 在「設定 › 陪辦伺服器」切換後，以使用者選的為準。
  static const String _apiOverride = String.fromEnvironment('ASSIST_API');
  static const String _prefKey = 'assist_api_base';

  /// 目前連線的後端位址
  final RxString server = ''.obs;
  String get apiBase => server.value;

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

  // 每次切換伺服器 +1；舊伺服器晚到的回應不得覆寫新狀態
  int _generation = 0;

  AssistService init() {
    final saved = Get.find<SharedPreferencesService>().instance.getString(_prefKey);
    server.value = normalizeBase(saved ?? (_apiOverride.isNotEmpty ? _apiOverride : localBase));
    _link();
    return this;
  }

  /// 去掉結尾斜線；沒寫通訊協定時，網域預設 https、IP 或 localhost 預設 http
  static String normalizeBase(String raw) {
    var v = raw.trim().replaceAll(RegExp(r'/+$'), '');
    if (v.isEmpty) return v;
    if (!v.contains('://')) {
      final local = RegExp(r'^(localhost|10\.|127\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)').hasMatch(v);
      v = '${local ? 'http' : 'https'}://$v';
    }
    return v;
  }

  /// 換到另一個後端：清掉這台的所有狀態後重新登入、重新連線
  Future<void> useServer(String raw) async {
    final base = normalizeBase(raw);
    final uri = Uri.tryParse(base);
    if (uri == null || !uri.hasAuthority || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw const FormatException('網址格式不正確');
    }
    await Get.find<SharedPreferencesService>().instance.setString(_prefKey, base);
    _generation++;
    _retry?.cancel();
    _socket?.dispose();
    _socket = null;
    _token = null;
    linked.value = false;
    connected.value = false;
    sessions.clear();
    pairing.value = null;
    resultId.value = null;
    audit.clear();
    applications.clear();
    auditStatus.value = null;
    legal.value = null;
    serviceDefs.clear();
    _watchingId = null;
    _notifiedRequests.clear();
    _notifiedAuth.clear();
    server.value = base;
    await _link();
  }

  /// 不切換，只測試某個位址連不連得上。成功回傳 null，失敗回傳原因。
  static Future<String?> probe(String raw) async {
    try {
      final res = await http.get(Uri.parse('${normalizeBase(raw)}/api/legal')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200 ? null : '伺服器回應 ${res.statusCode}';
    } on TimeoutException {
      return '連線逾時，伺服器沒有回應';
    } catch (e) {
      final text = e.toString();
      if (text.contains('Failed host lookup')) return '找不到這個網域（DNS 可能還沒設定好）';
      if (text.contains('Connection refused')) return '連不上，該位址沒有在執行後端';
      if (text.contains('HandshakeException') || text.contains('CERTIFICATE')) return 'HTTPS 憑證有問題';
      return '連不上（$text）';
    }
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

  /// 以台北通帳號換取陪辦 token。後端重啟後舊 token 會失效，也會從這裡重新登入。
  Future<void> _login() async {
    final accountId = Get.find<AccountService>().account?.id;
    final res = await _request('POST', '/auth/townpass-login', {'accountId': accountId}, false) as Map;
    _token = res['token'] as String;
  }

  Future<void> _link() async {
    _retry?.cancel();
    final gen = _generation;
    try {
      await _login();
      if (gen != _generation) return;
      linked.value = true;
      _connectSocket();
      final legalInfo = Map<String, dynamic>.from(await _request('GET', '/legal') as Map);
      if (gen != _generation) return;
      legal.value = legalInfo;
      await refresh();
    } catch (_) {
      if (gen != _generation) return;
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
    // token 失效（例如後端重啟）時，socket 會一直被拒絕：改為重新登入並重連
    socket.onConnectError((_) {
      connected.value = false;
      if (_retry?.isActive ?? false) return;
      _retry = Timer(const Duration(seconds: 3), _link);
    });
    socket.connect();
    _socket = socket;
  }

  Future<dynamic> _request(String method, String path, [Map<String, dynamic>? body, bool auth = true]) async {
    try {
      return await _send(method, path, body, auth);
    } on AssistApiException catch (e) {
      // 登入已失效：重新登入一次再重試，不讓畫面卡在轉圈
      if (!auth || e.status != 401) rethrow;
      await _login();
      linked.value = true;
      _connectSocket();
      return _send(method, path, body, auth);
    }
  }

  Future<dynamic> _send(String method, String path, Map<String, dynamic>? body, bool auth) async {
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
    final gen = _generation;
    final list = await _request('GET', '/elder/sessions') as List;
    if (gen != _generation) return;
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

  /// 送出後 10 秒內撤回：案件收回，回到確認畫面
  Future<void> undoSubmit(String id) async {
    resultId.value = null;
    await _apply(_request('POST', '/elder/sessions/$id/undo'));
  }

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
