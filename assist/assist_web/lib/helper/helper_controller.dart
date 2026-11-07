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
  List<Map<String, dynamic>> auditEntries = [];

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
    final list = await api.get('/services') as List;
    serviceSummaries = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    await refreshAudit();
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
