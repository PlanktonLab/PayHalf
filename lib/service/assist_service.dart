import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:town_pass/bean/assist.dart';
import 'package:town_pass/page/assist/widget/assist_help_call_sheet.dart';
import 'package:town_pass/page/assist/widget/assist_incoming_sheet.dart';
import 'package:town_pass/page/assist/widget/assist_trust_request_sheet.dart';
import 'package:town_pass/service/account_service.dart';
import 'package:town_pass/service/notification_service.dart';
import 'package:town_pass/service/shared_preferences_service.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:town_pass/util/tp_i18n.dart';

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

  /// 測試用身分（對應後端 demo 帳號）。王大明是台北通模擬帳號本人，走正式的 townpass-login
  static List<({String id, String name, String note})> get elderAccounts => [
    (id: 'elder-wang', name: '王大明', note: '台北通帳號本人'.tr),
    (id: 'elder-lee', name: '李秀英', note: '另一位長輩'.tr),
  ];
  static List<({String id, String name, String note})> get helperAccounts => [
    (id: 'helper-chief', name: '陳美玲', note: '里長・市府認證'.tr),
    (id: 'helper-family', name: '王小華', note: '家人／親友'.tr),
    (id: 'helper-1999', name: '林志明', note: '1999 客服・市府認證'.tr),
  ];
  static const _elderKey = 'assist_elder_id';
  static const _helperKey = 'assist_helper_id';

  /// 這支手機接受協助時是哪位長輩
  final RxString elderId = 'elder-wang'.obs;

  /// 用這支手機掃 QR Code 協助別人時，以哪位協助者登入工作台
  final RxString helperId = 'helper-chief'.obs;

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

  /// 信任的人：不用配對碼就能請求陪辦（長輩仍要同意）
  final RxList<TrustedHelper> trusted = <TrustedHelper>[].obs;

  /// 長輩：家人掃了我的邀請碼、等我確認要不要加他
  final RxList<TrustRequest> trustRequests = <TrustRequest>[].obs;
  final Set<String> _trustShown = {};

  /// 長輩：已經發出、對方還沒回應的「請他來幫我」
  final RxList<HelpRequest> myHelpRequests = <HelpRequest>[].obs;

  /// 協助者身分：有長輩請我去幫忙（推播＋彈窗＋首頁提示）
  final RxList<HelpRequest> helpForMe = <HelpRequest>[].obs;
  final Set<String> _helpNotified = {};

  // 這支手機的「協助者身分」也保持一條即時連線，才收得到長輩的求助推播
  io.Socket? _helperSocket;
  String? _helperToken;

  /// 目前的頁面路由（由 GetMaterialApp.routingCallback 更新）
  final RxString route = ''.obs;

  /// 用「幫別人辦」的身分（helperId）登入時，有哪些長輩把我加為信任的人。
  /// 首頁用它顯示「幫某某辦事」的捷徑；一支手機同時當長輩與協助者是 demo 才有的情境。
  final RxList<TrustingElder> helperTrusting = <TrustingElder>[].obs;
  final Set<String> _sheetShown = {};

  /// 這支手機以「協助者」身分開的案件。測試時同一支手機常常同時是長輩與協助者（同一位長輩），
  /// 這些案件不能再顯示長輩端的提示（膠囊、徽章、彈窗），點了也不能跳到長輩畫面。
  final RxSet<String> helpingSessionIds = <String>{}.obs;
  bool isHelping(String id) => helpingSessionIds.contains(id);
  final Rxn<Map<String, dynamic>> auditStatus = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> legal = Rxn<Map<String, dynamic>>();
  final RxMap<String, ServiceDef> serviceDefs = <String, ServiceDef>{}.obs;

  /// 長輩在靜態 QR 表單按「找線上客服」後的求助單（等待中／已接手／取消）
  final Rxn<Map<String, dynamic>> formTicket = Rxn<Map<String, dynamic>>();

  String? _token;
  io.Socket? _socket;
  // 留著參照，listener 才不會被回收
  // ignore: unused_field
  AppLifecycleListener? _lifecycle;

  void _onResume() {
    if (_token == null) return;
    if (_socket?.connected != true) _socket?.connect();
    if (_helperSocket?.connected != true) _helperSocket?.connect();
    refresh().catchError((_) {});
  }
  Timer? _retry;
  String? _watchingId;
  final Set<String> _notifiedRequests = {};

  /// 系統通知只在 App 不在前景時發：App 開著時畫面上已經有提示，不用每一步都跳通知。
  /// 同一個陪辦在背景時最多每分鐘一則。
  DateTime _lastNotifyAt = DateTime(2000);
  void _notify({required String title, required String content, bool throttle = false}) {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) return;
    final now = DateTime.now();
    if (throttle && now.difference(_lastNotifyAt) < const Duration(minutes: 1)) return;
    _lastNotifyAt = now;
    NotificationService.showNotification(title: title, content: content);
  }
  final Set<String> _notifiedAuth = {};

  // 每次切換伺服器 +1；舊伺服器晚到的回應不得覆寫新狀態
  int _generation = 0;

  AssistService init() {
    final prefs = Get.find<SharedPreferencesService>().instance;
    elderId.value = prefs.getString(_elderKey) ?? elderId.value;
    helperId.value = prefs.getString(_helperKey) ?? helperId.value;
    final saved = prefs.getString(_prefKey);
    server.value = normalizeBase(saved ?? (_apiOverride.isNotEmpty ? _apiOverride : localBase));
    _link();
    // App 從背景回來：iOS 可能已經把連線悄悄斷掉，馬上重連並重新整理，不用等心跳逾時
    _lifecycle = AppLifecycleListener(onResume: _onResume);
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
      throw FormatException('網址格式不正確'.tr);
    }
    await Get.find<SharedPreferencesService>().instance.setString(_prefKey, base);
    server.value = base;
    await _relink();
  }

  /// 換成另一位長輩：清掉狀態後重新登入
  Future<void> useElder(String id) async {
    if (id == elderId.value) return;
    await Get.find<SharedPreferencesService>().instance.setString(_elderKey, id);
    elderId.value = id;
    await _relink();
  }

  /// 目前長輩身分的顯示名稱（左上角切換鈕用）
  String get elderName => elderAccounts.firstWhereOrNull((a) => a.id == elderId.value)?.name ?? elderId.value;

  /// Demo：讓預設信任的人直接向這支手機的長輩發出請求（不用配對碼），回傳新 session 的 id
  Future<String> demoTrustedRequest(String helperId, String serviceId) async {
    final res = await _request('POST', '/demo/trusted-request', {
      'helperId': helperId,
      'elderId': elderId.value,
      'serviceId': serviceId,
    }, false) as Map;
    return res['id'] as String;
  }

  static const _shownKeys = {'title', 'agency', 'category', 'summary', 'dept'};

  /// 可以幫忙辦的項目（申辦業務＋收件中的表單），含機關、預估時間，給「幫別人辦」搜尋用
  Future<List<Map<String, dynamic>>> serviceCatalog() async {
    final list = await _request('GET', '/services', null, false) as List;
    // 名稱、機關等是後端給的中文：依介面語言顯示（搜尋也用看得到的文字）
    return [
      for (final e in list)
        Map<String, dynamic>.from(e as Map).map((k, v) => MapEntry(k, v is String && _shownKeys.contains(k) ? v.tr : v)),
    ];
  }

  /// 可申辦的業務清單（id／名稱）
  Future<List<({String id, String title})>> listServices() async {
    final list = await _request('GET', '/services') as List;
    return [for (final e in list) (id: (e as Map)['id'] as String, title: (e['title'] as String).tr)];
  }

  Future<void> useHelper(String id) async {
    await Get.find<SharedPreferencesService>().instance.setString(_helperKey, id);
    helperId.value = id;
    await _linkHelper();
  }

  /// 以協助者身分登入並連上即時通道：收長輩的求助、知道哪些長輩信任我
  Future<void> _linkHelper() async {
    final gen = _generation;
    _helperSocket?.dispose();
    _helperSocket = null;
    _helperToken = null;
    helpForMe.clear();
    try {
      final login = await _send('POST', '/auth/demo-login', {'userId': helperId.value}, false) as Map;
      if (gen != _generation) return;
      _helperToken = login['token'] as String;
      await refreshHelperTrusting();
      final socket = io.io(
        apiBase,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': _helperToken})
            .enableForceNew()
            .disableAutoConnect()
            .build(),
      );
      socket.on('help:update', (data) {
        try {
          _onHelpForMe(HelpRequest(Map<String, dynamic>.from(data as Map)));
        } catch (_) {}
      });
      socket.on('trusted:update', (_) => refreshHelperTrusting());
      socket.on('trust:request', (data) {
        try {
          final r = TrustRequest(Map<String, dynamic>.from(data as Map));
          if (r.status == 'accepted' || r.status == 'rejected') {
            Get.closeAllSnackbars();
            Get.snackbar(
              r.status == 'accepted' ? trf('{0} 已把您加為信任的人', [r.elderName]) : trf('{0} 這次沒有加您', [r.elderName]),
              r.status == 'accepted' ? '之後他可以直接請您幫忙，您也不用再掃配對碼。'.tr : '需要的話，請長輩再給您一次邀請碼。'.tr,
              snackPosition: SnackPosition.TOP,
              margin: const EdgeInsets.all(12),
              backgroundColor: const Color(0xFF2E3A40),
              colorText: const Color(0xFFFFFFFF),
            );
          }
        } catch (_) {}
      });
      socket.onConnect((_) async {
        try {
          final list = await _helperGet('/helper/help-requests') as List;
          for (final e in list) {
            _onHelpForMe(HelpRequest(Map<String, dynamic>.from(e as Map)));
          }
        } catch (_) {}
      });
      socket.connect();
      _helperSocket = socket;
    } catch (_) {}
  }

  /// 協助者：掃了（或輸入）長輩的加好友邀請碼。回傳長輩遮罩後的姓名與狀態
  Future<TrustRequest?> acceptTrustInvite(String code) async {
    if (_helperToken == null) await _linkHelper();
    final res = await http
        .post(
          Uri.parse('$apiBase/api/helper/trust-invite/accept'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_helperToken'},
          body: jsonEncode({'code': code}),
        )
        .timeout(const Duration(seconds: 8));
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) {
      final err = (data is Map ? data['error'] : null) as Map?;
      throw AssistApiException(res.statusCode, err?['code'] as String? ?? 'ERROR', err?['message'] as String? ?? '系統忙碌中'.tr);
    }
    final m = Map<String, dynamic>.from(data as Map);
    return m['status'] == 'already' ? null : TrustRequest(m);
  }

  Future<dynamic> _helperGet(String path) async {
    final res = await http
        .get(Uri.parse('$apiBase/api$path'), headers: {'Authorization': 'Bearer $_helperToken'})
        .timeout(const Duration(seconds: 8));
    if (res.statusCode >= 400) throw AssistApiException(res.statusCode, 'ERROR', '');
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  void _onHelpForMe(HelpRequest r) {
    helpForMe.removeWhere((e) => e.id == r.id);
    if (!r.isPending || !r.expiresAt.isAfter(DateTime.now())) return;
    // 這支手機自己就是那位長輩（同一支手機兩種身分）：不要通知自己
    if (r.elderId == elderId.value) return;
    helpForMe.add(r);
    if (_helpNotified.add(r.id)) {
      HapticFeedback.heavyImpact();
      _notify(
        title: trf('{0} 請您幫忙', [r.elderName]),
        content: '他把您加為信任的人。打開台北通，就能陪他一起辦。'.tr,
      );
      AssistHelpCallSheet.show(r.id);
    }
  }

  /// 以協助者身分問後端：哪些長輩信任我。失敗就當作沒有，不影響長輩端功能
  Future<void> refreshHelperTrusting() async {
    final gen = _generation;
    try {
      if (_helperToken == null) return;
      final list = await _helperGet('/helper/trusted-elders') as List;
      if (gen != _generation) return;
      helperTrusting.assignAll([for (final e in list) trustingElderFromJson(Map<String, dynamic>.from(e as Map))]);
    } catch (_) {
      if (gen == _generation) helperTrusting.clear();
    }
  }

  /// 掃到長輩的配對 QR Code：用選定的協助者開工作台，並把配對碼填好
  String helperConsoleUrl([String? code]) =>
      '$apiBase/?as=${Uri.encodeQueryComponent(helperId.value)}'
      '${code == null ? '' : '&code=${Uri.encodeQueryComponent(code)}'}#/console';

  /// 從 QR Code 內容取出配對碼（townpass-assist:123456）
  /// 從 QR Code 內容取出加好友邀請碼（townpass-trust:123456）
  /// 靜態 QR Code 表單：https://<任何主機>/f/<表單代號>、townpass://f/<表單代號> 或 townpass-form:<表單代號>
  static String? formIdFrom(String? raw) {
    final v = (raw ?? '').trim();
    final m = RegExp(r'^townpass-form:([\w-]{3,40})$').firstMatch(v) ??
        RegExp(r'^townpass://f/([\w-]{3,40})/?(?:[?#].*)?$').firstMatch(v) ??
        RegExp(r'^https?://[^/\s]+/f/([\w-]{3,40})/?(?:[?#].*)?$').firstMatch(v);
    return m?.group(1);
  }

  static String? trustCodeFrom(String? raw) =>
      RegExp(r'^townpass-trust:(\d{6})$').firstMatch(raw?.trim() ?? '')?.group(1);

  static String? pairingCodeFrom(String? raw) =>
      RegExp(r'^townpass-assist:(\d{6})$').firstMatch(raw?.trim() ?? '')?.group(1);

  Future<void> _relink() async {
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
    trusted.clear();
    helperTrusting.clear();
    myHelpRequests.clear();
    helpForMe.clear();
    trustRequests.clear();
    _helperSocket?.dispose();
    _helperSocket = null;
    _helperToken = null;
    auditStatus.value = null;
    legal.value = null;
    serviceDefs.clear();
    _watchingId = null;
    _notifiedRequests.clear();
    _notifiedAuth.clear();
    await _link();
  }

  /// 不切換，只測試某個位址連不連得上。成功回傳 null，失敗回傳原因。
  static Future<String?> probe(String raw) async {
    try {
      final res = await http.get(Uri.parse('${normalizeBase(raw)}/api/legal')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200 ? null : trf('伺服器回應 {0}', [res.statusCode]);
    } on TimeoutException {
      return '連線逾時，伺服器沒有回應'.tr;
    } catch (e) {
      final text = e.toString();
      if (text.contains('Failed host lookup')) return '找不到這個網域（DNS 可能還沒設定好）'.tr;
      if (text.contains('Connection refused')) return '連不上，該位址沒有在執行後端'.tr;
      if (text.contains('HandshakeException') || text.contains('CERTIFICATE')) return 'HTTPS 憑證有問題'.tr;
      return trf('連不上（{0}）', [text]);
    }
  }

  // ───────────────────────── 查詢

  AssistSession? get incoming {
    final now = DateTime.now();
    final list = sessions.values
        .where((s) => s.isPending && !isHelping(s.id) && (s.expiresAt?.isAfter(now) ?? false))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.firstOrNull;
  }

  AssistSession? get active => sessions.values.where((s) => s.isActive && !isHelping(s.id)).firstOrNull;

  // ───────────────────────── 連線

  /// 以台北通帳號換取陪辦 token。後端重啟後舊 token 會失效，也會從這裡重新登入。
  Future<void> _login() async {
    final Map res;
    if (elderId.value == 'elder-wang') {
      final accountId = Get.find<AccountService>().account?.id;
      res = await _request('POST', '/auth/townpass-login', {'accountId': accountId}, false) as Map;
    } else {
      // 測試其他長輩：用 demo 帳號登入
      res = await _request('POST', '/auth/demo-login', {'userId': elderId.value}, false) as Map;
    }
    _token = res['token'] as String;
    // 帳號上存的介面語言（使用者自己選過才有）
    final lang = (res['user'] as Map?)?['lang'] as String?;
    if (lang != null) TPLanguage.apply(lang);
  }

  /// 換介面語言：整個 App 立刻換，並記在帳號上（長輩與協助者兩個身分都記）
  Future<void> setLanguage(String code) async {
    await TPLanguage.apply(code);
    try {
      await _request('PUT', '/me/lang', {'lang': code});
    } catch (_) {}
    if (_helperToken != null) {
      try {
        await http
            .put(
              Uri.parse('$apiBase/api/me/lang'),
              headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_helperToken'},
              body: jsonEncode({'lang': code}),
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
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
      _linkHelper();
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
    socket.on('trusted:update', (_) => refreshTrusted());
    socket.on('trust:request', (data) {
      try {
        _onTrustRequest(TrustRequest(Map<String, dynamic>.from(data as Map)));
      } catch (_) {}
    });
    socket.on('help:update', (data) {
      try {
        final r = HelpRequest(Map<String, dynamic>.from(data as Map));
        myHelpRequests.removeWhere((e) => e.id == r.id);
        if (r.isPending) myHelpRequests.add(r);
      } catch (_) {}
    });
    socket.on('form:ticket', (data) {
      try {
        final t = Map<String, dynamic>.from(data as Map);
        if (formTicket.value == null || formTicket.value!['id'] == t['id']) formTicket.value = t;
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
        : method == 'PUT'
        ? await http.put(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 8))
        : await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 8));
    final text = utf8.decode(res.bodyBytes);
    final data = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 400) {
      final err = (data is Map ? data['error'] : null) as Map?;
      throw AssistApiException(
        res.statusCode,
        err?['code'] as String? ?? 'ERROR',
        err?['message'] as String? ?? '系統忙碌中，請稍後再試'.tr,
      );
    }
    return data;
  }

  // ───────────────────────── 推播事件

  /// 協辦畫面是否在導覽堆疊裡（長輩可能從協辦畫面點進法規說明等頁面）
  int _sessionScreens = 0;
  void sessionScreenAttached(bool attached) => _sessionScreens += attached ? 1 : -1;

  /// 長輩正在修改資料（底部面板開著）時不要把畫面拉走
  bool editingValue = false;

  /// 長輩自己點開、準備授權的欄位（不用等陪辦人員請求）
  final RxnString selfAuthKey = RxnString();

  /// 協助者帶到下一步、請長輩授權、請長輩確認送出時，
  /// 長輩若停在別的頁面（例如點進法規說明），把畫面帶回協辦畫面，不然會卡住
  static bool needsElderAttention(AssistSession prev, AssistSession s) =>
      s.isActive &&
      (prev.currentStep != s.currentStep ||
          (s.pendingAuth != null && prev.pendingAuth != s.pendingAuth) ||
          (s.isReviewing && !prev.isReviewing));

  void _bringBackToSession() {
    if (_sessionScreens <= 0 || editingValue) return;
    if (Get.currentRoute == TPRoute.assistSession) return;
    Get.until((route) => route.settings.name == TPRoute.assistSession);
  }

  void _onSession(Map<String, dynamic> raw) {
    final s = AssistSession(raw);
    final prev = sessions[s.id];
    sessions[s.id] = s;
    if (prev != null && !isHelping(s.id) && needsElderAttention(prev, s)) _bringBackToSession();
    if (!s.isActive && selfAuthKey.value != null && _watchingId == s.id) selfAuthKey.value = null;
    service(s.serviceId);

    // 稍等一下再提示：如果這個請求其實是這支手機自己以協助者身分發的，協助者那邊會先標記起來
    if (s.isPending && !_notifiedRequests.contains(s.id) && (s.expiresAt?.isAfter(DateTime.now()) ?? false)) {
      _notifiedRequests.add(s.id);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (isHelping(s.id) || !(sessions[s.id]?.isPending ?? false)) return;
        final h = s.helper;
        HapticFeedback.heavyImpact();
        _notify(
          title: trf('{0} {1} 想協助您', [h?.name ?? '', h?.title ?? '']),
          content: trf('辦理「{0}」。請打開台北通首頁查看並回應。', [s.serviceTitle]),
        );
      });
    }
    // 底部彈出提示：長輩關掉也沒關係，首頁徽章會一直留著
    if (s.isPending && !_sheetShown.contains(s.id) && (s.expiresAt?.isAfter(DateTime.now()) ?? false)) {
      _sheetShown.add(s.id);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (isHelping(s.id) || active != null) return;
        AssistIncomingSheet.show(s.id);
      });
    }

    if (isHelping(s.id)) return;

    if (s.isActive) {
      _watchingId = s.id;
      pairing.value = null;
      final authKey = '${s.id}:${s.pendingAuth}:${s.field(s.pendingAuth ?? '').requestCount}';
      if (s.pendingAuth != null && !_notifiedAuth.contains(authKey)) {
        _notifiedAuth.add(authKey);
        HapticFeedback.mediumImpact();
        _notify(
          title: '有一項資料需要您確認'.tr,
          content: trf('{0} 請您確認是否提供「{1}」', [s.helper?.name ?? '協助者', s.pendingAuthField?.label ?? '']),
          throttle: true,
        );
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
    // 伺服器重啟（重新部署）後舊的陪辦已經不存在：清掉，不然首頁會一直顯示一個按了就 404 的陪辦
    final ids = {for (final e in list) (e as Map)['id'] as String};
    sessions.removeWhere((id, _) => !ids.contains(id) && !isHelping(id));
    if (_watchingId != null && !ids.contains(_watchingId)) _watchingId = null;
    for (final e in list.reversed) {
      final s = AssistSession(Map<String, dynamic>.from(e as Map));
      // 啟動前就已存在的請求不再重複發系統通知
      if (s.isPending) _notifiedRequests.add(s.id);
      _onSession(s.raw);
    }
    await refreshRecords();
    await refreshTrusted();
    await refreshMyHelp();
    for (final e in await _request('GET', '/elder/trust-requests') as List) {
      _onTrustRequest(TrustRequest(Map<String, dynamic>.from(e as Map)));
    }
  }

  /// 長輩：可以加為信任的人（陪我辦過的人）
  Future<List<TrustCandidate>> trustCandidates() async {
    final list = await _request('GET', '/elder/trusted/candidates') as List;
    return [for (final e in list) TrustCandidate(Map<String, dynamic>.from(e as Map))];
  }

  Future<void> addTrustedHelper(String helperId) async {
    final list = await _request('POST', '/elder/trusted', {'helperId': helperId}) as List;
    trusted.assignAll(list.map((e) => TrustedHelper(Map<String, dynamic>.from(e as Map))));
  }

  /// 長輩：產生「加信任的人」邀請碼（QR Code＋6 位數）
  Future<({String code, String qrPayload, DateTime expiresAt})> createTrustInvite() async {
    final m = await _request('POST', '/elder/trust-invite') as Map;
    return (
      code: m['code'] as String,
      qrPayload: m['qrPayload'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch((m['expiresAt'] as num).toInt()),
    );
  }

  void _onTrustRequest(TrustRequest r) {
    trustRequests.removeWhere((e) => e.id == r.id);
    if (!r.isPending) return;
    trustRequests.add(r);
    if (_trustShown.add(r.id)) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 350), () => AssistTrustRequestSheet.show(r.id));
    }
  }

  Future<void> respondTrustRequest(String id, bool accept) async {
    final list = await _request('POST', '/elder/trust-requests/$id/respond', {'accept': accept}) as List;
    trusted.assignAll(list.map((e) => TrustedHelper(Map<String, dynamic>.from(e as Map))));
    trustRequests.removeWhere((e) => e.id == id);
  }

  /// 長輩：請信任的人來幫忙（對方手機會跳通知）
  Future<void> requestHelp(String helperId, {String? serviceId}) async {
    final r = HelpRequest(
      Map<String, dynamic>.from(
        await _request('POST', '/elder/help-requests', {'helperId': helperId, 'serviceId': ?serviceId}) as Map,
      ),
    );
    myHelpRequests.removeWhere((e) => e.id == r.id);
    if (r.isPending) myHelpRequests.add(r);
  }

  Future<void> cancelHelp(String id) async {
    await _request('POST', '/elder/help-requests/$id/cancel');
    myHelpRequests.removeWhere((e) => e.id == id);
  }

  Future<void> refreshMyHelp() async {
    final list = await _request('GET', '/elder/help-requests') as List;
    myHelpRequests.assignAll(list.map((e) => HelpRequest(Map<String, dynamic>.from(e as Map))));
  }

  Future<void> refreshTrusted() async {
    if (_token == null) return;
    final list = await _request('GET', '/elder/trusted') as List;
    trusted.assignAll(list.map((e) => TrustedHelper(Map<String, dynamic>.from(e as Map))));
  }

  /// 把這次陪辦的人加為信任的人
  Future<void> addTrusted(String sessionId) async {
    final list = await _request('POST', '/elder/trusted', {'sessionId': sessionId}) as List;
    trusted.assignAll(list.map((e) => TrustedHelper(Map<String, dynamic>.from(e as Map))));
    final s = sessions[sessionId];
    if (s != null) sessions[sessionId] = AssistSession({...s.raw, 'helperTrusted': true});
    refreshRecords();
  }

  Future<void> removeTrusted(String helperId) async {
    final list = await _request('POST', '/elder/trusted/$helperId/remove') as List;
    trusted.assignAll(list.map((e) => TrustedHelper(Map<String, dynamic>.from(e as Map))));
    refreshRecords();
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

  // ───────────────────────── 靜態 QR Code 表單（長輩自己填）

  /// 目前收件中、可以掃的表單（Demo：模擬器沒辦法掃海報，從身分選單直接開）
  Future<List<({String id, String title, String agency})>> listForms() async {
    final list = await _request('GET', '/services', null, false) as List;
    return [
      for (final e in list.cast<Map>())
        if ((e['id'] as String).startsWith('form-'))
          (id: (e['id'] as String).substring(5), title: (e['title'] as String).tr, agency: (e['agency'] as String? ?? '').tr),
    ];
  }

  Future<StaticForm> openForm(String id) async {
    // 從相機掃 QR 冷啟動時，App 可能還在登入：先等一下背景連線
    for (var i = 0; i < 50 && _token == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (_token == null) await _link();
    return StaticForm(Map<String, dynamic>.from(await _request('GET', '/elder/forms/$id') as Map));
  }

  Future<Map<String, dynamic>> submitForm(String id, Map<String, String> answers) async {
    final r = Map<String, dynamic>.from(await _request('POST', '/elder/forms/$id/submit', {'answers': answers}) as Map);
    refreshRecords();
    return r;
  }

  /// 填到一半找人幫忙：mode = online（線上客服）／nearby（旁邊的人掃碼）／trusted（信任的人）
  Future<Map<String, dynamic>> formHelp(
    String id,
    String mode,
    Map<String, String> answers, {
    String? question,
    String? helperId,
  }) async {
    final r = Map<String, dynamic>.from(
      await _request('POST', '/elder/forms/$id/help', {
        'mode': mode,
        'answers': answers,
        'question': ?question,
        'helperId': ?helperId,
      }) as Map,
    );
    if (mode == 'online') formTicket.value = Map<String, dynamic>.from(r['ticket'] as Map);
    if (mode == 'nearby') pairing.value = PairingCode(r);
    if (mode == 'trusted') {
      final h = HelpRequest(Map<String, dynamic>.from(r['help'] as Map));
      myHelpRequests.removeWhere((e) => e.id == h.id);
      myHelpRequests.add(h);
    }
    return r;
  }

  Future<void> cancelFormTicket() async {
    final t = formTicket.value;
    formTicket.value = null;
    if (t != null && t['status'] == 'waiting') await _request('POST', '/elder/form-tickets/${t['id']}/cancel');
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

  /// [value] 有值代表長輩在授權時改了內容
  Future<void> authorize(String id, String key, bool approve, {String? value}) => _apply(
    _request('POST', '/elder/sessions/$id/fields/$key/authorize', {'approve': approve, 'value': ?value}),
  );

  /// 長輩自己同意提供（不用等陪辦人員請求）
  Future<void> selfAuthorize(String id, String key, {String? value}) async {
    await _apply(_request('POST', '/elder/sessions/$id/fields/$key/self-authorize', {'value': ?value}));
    selfAuthKey.value = null;
  }

  Future<void> editField(String id, String key, String value) =>
      _apply(_request('POST', '/elder/sessions/$id/fields/$key/edit', {'value': value}));

  Future<void> gotoStep(String id, int step) => _apply(_request('POST', '/elder/sessions/$id/step', {'step': step}));

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

/// 把這支手機的協助者加為「信任的人」的長輩（好友）
typedef TrustingElder = ({String elderId, String displayName, String name, String? account, DateTime? since});

TrustingElder trustingElderFromJson(Map<String, dynamic> m) => (
  elderId: m['elderId'] as String,
  displayName: m['displayName'] as String,
  name: m['name'] as String? ?? m['displayName'] as String,
  account: m['account'] as String?,
  since: m['since'] is num ? DateTime.fromMillisecondsSinceEpoch((m['since'] as num).toInt()) : null,
);
