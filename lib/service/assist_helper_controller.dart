import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:town_pass/bean/assist.dart';
import 'package:town_pass/service/assist_service.dart';

/// 用這支手機「協助別人」時的狀態（協助者端）。
/// 與長輩端的 [AssistService] 分開：同一支手機可以同時是長輩、也是協助者。
/// 所有動作走 REST，畫面靠 socket 推播更新（與網頁版工作台相同的 API）。
class AssistHelperController extends GetxController {
  AssistHelperController({required this.helperId});

  final String helperId;

  final Rxn<Map<String, dynamic>> me = Rxn<Map<String, dynamic>>();
  final RxBool loading = true.obs;
  final RxnString loginError = RxnString();
  final RxBool connected = false.obs;
  final RxMap<String, AssistSession> sessions = <String, AssistSession>{}.obs;
  final RxList<Map<String, dynamic>> services = <Map<String, dynamic>>[].obs;
  final RxMap<String, ServiceDef> serviceDefs = <String, ServiceDef>{}.obs;

  /// 把我加為「信任的人」的長輩（只有遮罩後的姓名）
  final RxList<Map<String, dynamic>> trustedElders = <Map<String, dynamic>>[].obs;

  /// 目前打開的案件；null 代表在「新陪辦」畫面
  final RxnString focusedId = RxnString();

  String? _token;
  io.Socket? _socket;

  String get base => Get.find<AssistService>().apiBase;
  AssistSession? get focused => focusedId.value == null ? null : sessions[focusedId.value];

  List<AssistSession> get sorted => sessions.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  void onInit() {
    super.onInit();
    login();
  }

  @override
  void onClose() {
    _socket?.dispose();
    super.onClose();
  }

  Future<void> login() async {
    loading.value = true;
    loginError.value = null;
    try {
      final res = await _send('POST', '/auth/demo-login', {'userId': helperId}, false) as Map;
      _token = res['token'] as String;
      final list = await _send('GET', '/services') as List;
      services.assignAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      for (final s in services) {
        await service(s['id'] as String);
      }
      me.value = Map<String, dynamic>.from(res['user'] as Map);
      _connect();
      await reload();
    } catch (e) {
      loginError.value = e is AssistApiException ? e.message : '連不上陪辦伺服器（$base）';
    } finally {
      loading.value = false;
    }
  }

  void _connect() {
    _socket?.dispose();
    final socket = io.io(
      base,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': _token})
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    );
    socket.on('session:update', (data) {
      try {
        _put(Map<String, dynamic>.from(data as Map));
      } catch (_) {}
    });
    socket.on('trusted:update', (_) => reload());
    socket.onConnect((_) {
      connected.value = true;
      reload();
    });
    socket.onDisconnect((_) => connected.value = false);
    socket.connect();
    _socket = socket;
  }

  Future<ServiceDef> service(String id) async {
    final cached = serviceDefs[id];
    if (cached != null) return cached;
    final def = ServiceDef(Map<String, dynamic>.from(await _send('GET', '/services/$id') as Map));
    serviceDefs[id] = def;
    return def;
  }

  Future<void> reload() async {
    if (_token == null) return;
    final list = await _send('GET', '/helper/sessions') as List;
    for (final e in list) {
      _put(Map<String, dynamic>.from(e as Map));
    }
    final trusted = await _send('GET', '/helper/trusted-elders') as List;
    trustedElders.assignAll(trusted.map((e) => Map<String, dynamic>.from(e as Map)));
  }

  AssistSession _put(Map<String, dynamic> raw) {
    final s = AssistSession(raw);
    sessions[s.id] = s;
    // 讓長輩端知道：這個案件是這支手機在協助別人，不要顯示「某某正在陪您操作」
    Get.find<AssistService>().helpingSessionIds.add(s.id);
    return s;
  }

  Future<AssistSession> _apply(Future<dynamic> call) async => _put(Map<String, dynamic>.from(await call as Map));

  // ───────────────────────── 動作

  Future<void> requestByCode(String serviceId, String code) async {
    final s = await _apply(
      _send('POST', '/helper/requests', {'serviceId': serviceId, 'method': 'pairing_code', 'code': code}),
    );
    focusedId.value = s.id;
  }

  /// 長輩已把我加為信任的人：不用配對碼，直接請長輩確認
  Future<void> requestTrusted(String serviceId, String elderId) async {
    final s = await _apply(
      _send('POST', '/helper/requests', {'serviceId': serviceId, 'method': 'trusted', 'elderId': elderId}),
    );
    focusedId.value = s.id;
  }

  Future<void> gotoStep(int step) => _apply(_send('POST', '/helper/sessions/${focusedId.value}/step', {'step': step}));
  Future<void> focusField(String? key) =>
      _apply(_send('POST', '/helper/sessions/${focusedId.value}/focus', {'fieldKey': key}));
  Future<void> requestField(String key) =>
      _apply(_send('POST', '/helper/sessions/${focusedId.value}/fields/$key/request'));
  Future<void> requestSubmit() => _apply(_send('POST', '/helper/sessions/${focusedId.value}/request-submit'));
  Future<void> setElderNav(bool on) =>
      _apply(_send('POST', '/helper/sessions/${focusedId.value}/elder-nav', {'enabled': on}));
  Future<void> setElderSelfAuth(bool on) =>
      _apply(_send('POST', '/helper/sessions/${focusedId.value}/elder-self-auth', {'enabled': on}));
  Future<void> end() => _apply(_send('POST', '/sessions/${focusedId.value}/end'));

  // ───────────────────────── HTTP

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body, bool auth = true]) async {
    try {
      return await _raw(method, path, body, auth);
    } on AssistApiException catch (e) {
      // 後端重啟後 token 失效：重新登入一次再試
      if (!auth || e.status != 401) rethrow;
      final res = await _raw('POST', '/auth/demo-login', {'userId': helperId}, false) as Map;
      _token = res['token'] as String;
      _connect();
      return _raw(method, path, body, auth);
    }
  }

  Future<dynamic> _raw(String method, String path, Map<String, dynamic>? body, bool auth) async {
    final uri = Uri.parse('$base/api$path');
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
}
