import 'package:flutter/foundation.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/realtime.dart';

/// 協助者端狀態。所有動作都打 REST，畫面靠 socket 推播更新。
class HelperController extends ChangeNotifier {
  HelperController({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;
  final Realtime _rt = Realtime();

  Map<String, dynamic>? me;
  List<Map<String, dynamic>> demoAccounts = [];
  List<Map<String, dynamic>> serviceSummaries = [];
  final Map<String, ServiceDef> serviceDefs = {};
  final Map<String, AssistSession> sessions = {};
  String? focusedSessionId;
  bool connected = false;
  bool accountsLoading = true;
  bool accountsFailed = false;
  Map<String, dynamic>? auditStatus;
  /// 從台北通 App 掃 QR Code 進來時帶的配對碼，新陪辦畫面會自動填入
  String? pendingCode;
  List<Map<String, dynamic>> auditEntries = [];
  /// 把我加為「信任的人」的長輩：不用配對碼就能請求
  List<Map<String, dynamic>> trustedElders = [];
  /// 信任我的長輩按了「請他來幫我」
  List<HelpRequest> helpRequests = [];

  bool get loggedIn => me != null;

  AssistSession? get focused => focusedSessionId == null ? null : sessions[focusedSessionId];

  List<AssistSession> get sortedSessions =>
      sessions.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> loadDemoAccounts() async {
    try {
      final data = await api.get('/auth/demo-accounts') as Map;
      demoAccounts = (data['helpers'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    // 先載好業務清單再切到工作台，新陪辦畫面才會有預設業務
    final list = await api.get('/services') as List;
    serviceSummaries = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    me = Map<String, dynamic>.from(res['user'] as Map);
    _rt.connect(
      base: api.base,
      token: api.token!,
      onSession: _onSession,
      onConnect: refresh,
      onTrusted: refreshTrusted,
      onHelp: _onHelp,
      onStatus: (c) {
        connected = c;
        notifyListeners();
      },
    );
    for (final s in serviceSummaries) {
      await service(s['id'] as String);
    }
    await refresh();
  }

  void logout() {
    _rt.dispose();
    api.token = null;
    me = null;
    sessions.clear();
    trustedElders = [];
    helpRequests = [];
    focusedSessionId = null;
    notifyListeners();
  }

  Future<ServiceDef> service(String id) async {
    if (serviceDefs[id] != null) return serviceDefs[id]!;
    final def = ServiceDef(Map<String, dynamic>.from(await api.get('/services/$id') as Map));
    serviceDefs[id] = def;
    return def;
  }

  void _onSession(Map<String, dynamic> raw) {
    final s = AssistSession(raw);
    sessions[s.id] = s;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!loggedIn) return;
    final list = await api.get('/helper/sessions') as List;
    for (final e in list) {
      _onSession(Map<String, dynamic>.from(e as Map));
    }
    await refreshTrusted();
    helpRequests = (await api.get('/helper/help-requests') as List)
        .map((e) => HelpRequest(Map<String, dynamic>.from(e as Map)))
        .toList();
    await refreshAudit();
  }

  void _onHelp(Map<String, dynamic> raw) {
    final r = HelpRequest(raw);
    helpRequests = [...helpRequests.where((e) => e.id != r.id), if (r.isPending) r];
    notifyListeners();
  }

  Future<void> refreshTrusted() async {
    if (!loggedIn) return;
    trustedElders =
        (await api.get('/helper/trusted-elders') as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    notifyListeners();
  }

  Future<void> refreshAudit() async {
    auditStatus = Map<String, dynamic>.from(await api.get('/audit/verify') as Map);
    auditEntries = (await api.get('/helper/audit') as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    notifyListeners();
  }

  void focus(String? sessionId) {
    focusedSessionId = sessionId;
    notifyListeners();
  }

  Future<AssistSession> _apply(Future<dynamic> call) async {
    final s = AssistSession(Map<String, dynamic>.from(await call as Map));
    sessions[s.id] = s;
    notifyListeners();
    return s;
  }

  Future<AssistSession> requestByCode(String serviceId, String code) async {
    final s = await _apply(
      api.post('/helper/requests', {'serviceId': serviceId, 'method': 'pairing_code', 'code': code}),
    );
    focus(s.id);
    refreshAudit();
    return s;
  }

  /// 掃了（或輸入）長輩的加好友邀請碼；回傳長輩遮罩姓名與狀態（pending／already）
  Future<Map<String, dynamic>> acceptTrustInvite(String code) async =>
      Map<String, dynamic>.from(await api.post('/helper/trust-invite/accept', {'code': code}) as Map);

  Future<AssistSession> requestTrusted(String serviceId, String elderId) async {
    final s = await _apply(
      api.post('/helper/requests', {'serviceId': serviceId, 'method': 'trusted', 'elderId': elderId}),
    );
    focus(s.id);
    refreshAudit();
    return s;
  }

  Future<AssistSession> requestByIdentity(String serviceId, String name, String birthday, String idLast4) async {
    final s = await _apply(
      api.post('/helper/requests', {
        'serviceId': serviceId,
        'method': 'identity',
        'name': name,
        'birthday': birthday,
        'idLast4': idLast4,
      }),
    );
    focus(s.id);
    refreshAudit();
    return s;
  }

  Future<void> setElderNav(bool enabled) =>
      _apply(api.post('/helper/sessions/$focusedSessionId/elder-nav', {'enabled': enabled}));
  Future<void> setElderSelfAuth(bool enabled) =>
      _apply(api.post('/helper/sessions/$focusedSessionId/elder-self-auth', {'enabled': enabled}));
  Future<void> gotoStep(int step) => _apply(api.post('/helper/sessions/$focusedSessionId/step', {'step': step}));
  Future<void> focusField(String? key) =>
      _apply(api.post('/helper/sessions/$focusedSessionId/focus', {'fieldKey': key}));
  Future<void> requestField(String key) async {
    await _apply(api.post('/helper/sessions/$focusedSessionId/fields/$key/request'));
    refreshAudit();
  }

  Future<void> requestSubmit() => _apply(api.post('/helper/sessions/$focusedSessionId/request-submit'));
  Future<void> end([String? id]) async {
    await _apply(api.post('/sessions/${id ?? focusedSessionId}/end'));
    refreshAudit();
  }

  @override
  void dispose() {
    _rt.dispose();
    super.dispose();
  }
}
