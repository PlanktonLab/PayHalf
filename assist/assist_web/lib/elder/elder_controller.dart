import 'package:flutter/foundation.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/realtime.dart';

/// 長輩端狀態：模擬「已登入台北通、通過實名認證」的那支手機。
class ElderController extends ChangeNotifier {
  ElderController({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;
  final Realtime _rt = Realtime();

  Map<String, dynamic>? me;
  List<Map<String, dynamic>> demoAccounts = [];
  final Map<String, AssistSession> sessions = {};
  final Map<String, ServiceDef> serviceDefs = {};
  Map<String, dynamic>? pairing;
  Map<String, dynamic>? legal;
  List<Map<String, dynamic>> audit = [];
  List<Map<String, dynamic>> applications = [];
  Map<String, dynamic>? auditStatus;
  bool connected = false;
  bool accountsLoading = true;
  bool accountsFailed = false;

  /// 長輩正在參與的 session；結束後要顯示結果頁，直到長輩按「回到首頁」
  String? _watchingId;
  String? resultId;

  bool get loggedIn => me != null;
  String get name => me?['name'] as String? ?? '';

  AssistSession? get active => sessions.values.where((s) => s.isActive).firstOrNull;

  AssistSession? get incoming {
    final now = DateTime.now();
    final list = sessions.values.where((s) => s.isPending && (s.expiresAt?.isAfter(now) ?? true)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.firstOrNull;
  }

  AssistSession? get result => resultId == null ? null : sessions[resultId];

  Future<void> loadDemoAccounts() async {
    try {
      final data = await api.get('/auth/demo-accounts') as Map;
      demoAccounts = (data['elders'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      accountsFailed = false;
    } catch (_) {
      accountsFailed = true;
    } finally {
      accountsLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String userId) async {
    final res = await api.post('/auth/demo-login', {'userId': userId}) as Map;
    api.token = res['token'] as String;
    me = Map<String, dynamic>.from(res['user'] as Map);
    _rt.connect(
      base: api.base,
      token: api.token!,
      onSession: _onSession,
      onConnect: refresh,
      onStatus: (c) {
        connected = c;
        notifyListeners();
      },
    );
    legal = Map<String, dynamic>.from(await api.get('/legal') as Map);
    await refresh();
  }

  void logout() {
    _rt.dispose();
    api.token = null;
    me = null;
    sessions.clear();
    pairing = null;
    resultId = null;
    _watchingId = null;
    notifyListeners();
  }

  Future<ServiceDef> service(String id) async {
    if (serviceDefs[id] != null) return serviceDefs[id]!;
    final def = ServiceDef(Map<String, dynamic>.from(await api.get('/services/$id') as Map));
    serviceDefs[id] = def;
    notifyListeners();
    return def;
  }

  /// 協助者換步驟、請授權、請確認送出時呼叫：把長輩從法規說明等頁面帶回協辦畫面
  VoidCallback? onNeedsAttention;

  void _onSession(Map<String, dynamic> raw) {
    final s = AssistSession(raw);
    final prev = sessions[s.id];
    sessions[s.id] = s;
    if (prev != null &&
        s.isActive &&
        (prev.currentStep != s.currentStep ||
            (s.pendingAuth != null && prev.pendingAuth != s.pendingAuth) ||
            (s.phase == 'reviewing' && prev.phase != 'reviewing'))) {
      onNeedsAttention?.call();
    }
    service(s.serviceId);
    if (s.isActive) {
      _watchingId = s.id;
      pairing = null;
    } else if (_watchingId == s.id && !s.isOpen) {
      _watchingId = null;
      resultId = s.id;
      refreshRecords();
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!loggedIn) return;
    final list = await api.get('/elder/sessions') as List;
    for (final e in list) {
      _onSession(Map<String, dynamic>.from(e as Map));
    }
    await refreshRecords();
  }

  Future<void> refreshRecords() async {
    audit = (await api.get('/elder/audit') as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    applications = (await api.get('/elder/applications') as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    auditStatus = Map<String, dynamic>.from(await api.get('/audit/verify') as Map);
    notifyListeners();
  }

  Future<void> createPairingCode() async {
    pairing = Map<String, dynamic>.from(await api.post('/elder/pairing-code') as Map);
    notifyListeners();
  }

  void hidePairing() {
    pairing = null;
    notifyListeners();
  }

  void dismissResult() {
    resultId = null;
    notifyListeners();
  }

  Future<void> _apply(Future<dynamic> call) async {
    _onSession(Map<String, dynamic>.from(await call as Map));
  }

  Future<void> respond(String id, bool accept) async {
    await _apply(api.post('/elder/sessions/$id/respond', {'accept': accept}));
    refreshRecords();
  }

  Future<void> authorize(String id, String key, bool approve, {String? value}) =>
      _apply(api.post('/elder/sessions/$id/fields/$key/authorize', {'approve': approve, 'value': ?value}));

  /// 長輩自己點開、準備授權的欄位（不用等陪辦人員請求）
  String? selfAuthKey;
  void openSelfAuth(String? key) {
    selfAuthKey = key;
    notifyListeners();
  }

  Future<void> selfAuthorize(String id, String key, {String? value}) async {
    await _apply(api.post('/elder/sessions/$id/fields/$key/self-authorize', {'value': ?value}));
    openSelfAuth(null);
  }

  Future<void> editField(String id, String key, String value) =>
      _apply(api.post('/elder/sessions/$id/fields/$key/edit', {'value': value}));

  Future<void> gotoStep(String id, int step) => _apply(api.post('/elder/sessions/$id/step', {'step': step}));

  Future<void> revoke(String id, String key) => _apply(api.post('/elder/sessions/$id/fields/$key/revoke'));

  Future<void> input(String id, String key, String value) =>
      _apply(api.post('/elder/sessions/$id/fields/$key/input', {'value': value}));

  Future<void> submit(String id, bool confirm) => _apply(api.post('/elder/sessions/$id/submit', {'confirm': confirm}));

  Future<void> end(String id) => _apply(api.post('/sessions/$id/end'));

  Future<void> block(String id) async {
    await _apply(api.post('/elder/sessions/$id/block'));
    refreshRecords();
  }

  @override
  void dispose() {
    _rt.dispose();
    super.dispose();
  }
}
