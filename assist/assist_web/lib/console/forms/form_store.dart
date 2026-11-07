import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../core/api.dart';
import '../../helper/helper_controller.dart';

/// 承辦人表單：資料模型、範本、復原／重做，以及和後端同步。
/// 表單與回覆都存在後端（/api/console/forms），編輯後稍等一下自動儲存。

class QType {
  const QType(this.name, this.icon);
  final String name;
  final IconData icon;
}

const qTypes = <String, QType>{
  'radio': QType('單選', Icons.radio_button_checked_rounded),
  'checkbox': QType('多選', Icons.check_box_outlined),
  'select': QType('下拉選單', Icons.arrow_drop_down_circle_outlined),
  'text': QType('短答', Icons.short_text_rounded),
  'textarea': QType('詳細說明', Icons.notes_rounded),
  'date': QType('日期', Icons.calendar_today_outlined),
  'number': QType('數字', Icons.tag_rounded),
  'phone': QType('電話號碼', Icons.phone_outlined),
  'idno': QType('身分證字號', Icons.badge_outlined),
  'address': QType('地址', Icons.place_outlined),
  'file': QType('上傳照片或檔案', Icons.attach_file_rounded),
  'consent': QType('同意聲明', Icons.verified_user_outlined),
};

const optionTypes = {'radio', 'checkbox', 'select'};

/// 常用個人資料（一鍵加入）
const quickFields = [
  ('text', '你的姓名', '請填身分證上的名字', Icons.person_outline_rounded, '姓名'),
  ('phone', '你的聯絡電話', '方便我們打給你確認', Icons.phone_outlined, '電話'),
  ('idno', '你的身分證字號', '英文字母加 9 個數字', Icons.badge_outlined, '身分證字號'),
  ('address', '你住在哪裡', '請填目前的住址', Icons.place_outlined, '地址'),
  ('date', '你的出生日期', '', Icons.cake_outlined, '出生日期'),
];

/// 公文用語 → 日常說法
const jargon = {
  '茲': '',
  '俾': '讓',
  '惟': '但是',
  '檢附': '附上',
  '敬請': '請',
  '前開': '上面的',
  '核定': '審查通過', //
  '請領': '領取', '逕行': '直接', '戶籍所在地': '你登記的住址', '具結': '保證', '屆時': '到時候', //
  '備齊': '準備好', '申覆': '再申請', '無誤': '沒有錯', '如附': '',
};

final _rand = Random();
String uid() => List.generate(7, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_rand.nextInt(36)]).join();

class FField {
  FField({String? id, required this.type, this.label = '', this.hint = '', this.required = true, List<String>? options})
    : id = id ?? uid(),
      options = options ?? (optionTypes.contains(type) ? ['選項 1'] : []);

  String id;
  String type;
  String label;
  String hint;
  bool required;
  List<String> options;

  bool get hasOptions => optionTypes.contains(type);

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'label': label,
    'hint': hint,
    'required': required,
    'options': options,
  };
  factory FField.fromJson(Map<String, dynamic> j) => FField(
    id: j['id'] as String,
    type: j['type'] as String,
    label: j['label'] as String? ?? '',
    hint: j['hint'] as String? ?? '',
    required: j['required'] as bool? ?? true,
    options: (j['options'] as List? ?? const []).cast<String>().toList(),
  );
  FField clone() => FField.fromJson(toJson())..id = uid();
}

enum FStatus { draft, open, closed }

extension FStatusX on FStatus {
  String get label => switch (this) {
    FStatus.draft => '草稿',
    FStatus.open => '收件中',
    FStatus.closed => '已停止收件',
  };
}

class FForm {
  FForm({
    String? id,
    this.title = '',
    this.dept = '臺北市政府',
    this.desc = '',
    List<FField>? fields,
    this.deadline = '',
    this.allowAssist = true,
    this.once = false,
    this.doneMsg = '已經幫你送出了，謝謝你。',
    this.status = FStatus.draft,
    int? updated,
  }) : id = id ?? uid(),
       fields = fields ?? [],
       updated = updated ?? DateTime.now().millisecondsSinceEpoch;

  String id;
  String title;
  String dept;
  String desc;
  List<FField> fields;
  String deadline;
  bool allowAssist;
  bool once;
  String doneMsg;
  FStatus status;
  int updated;

  // ── 後端統計（含示意資料）
  int responses = 0;
  int realResponses = 0;
  int today = 0;
  int assisted = 0;
  int waitingHelp = 0;

  /// QR Code 指向的固定網址（向後端問過才有）
  String? url;

  bool get published => status != FStatus.draft;

  String get displayTitle => title.trim().isEmpty ? '未命名表單' : title;

  /// 復原／重做時比較的內容（不含 id、更新時間與試填回覆）
  Map<String, dynamic> content() => {
    'title': title,
    'dept': dept,
    'desc': desc,
    'fields': fields.map((f) => f.toJson()).toList(),
    'deadline': deadline,
    'allowAssist': allowAssist,
    'once': once,
    'doneMsg': doneMsg,
    'status': status.name,
  };

  void applyContent(Map<String, dynamic> j) {
    title = j['title'] as String? ?? '';
    dept = j['dept'] as String? ?? '';
    desc = j['desc'] as String? ?? '';
    fields = (j['fields'] as List? ?? const [])
        .map((e) => FField.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    deadline = j['deadline'] as String? ?? '';
    allowAssist = j['allowAssist'] as bool? ?? true;
    once = j['once'] as bool? ?? false;
    doneMsg = j['doneMsg'] as String? ?? '';
    status = FStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => FStatus.draft);
  }

  /// 後端的統計數字（不動正在編輯的內容）
  void applyStats(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    responses = n('responses');
    realResponses = n('realResponses');
    today = n('today');
    assisted = n('assisted');
    waitingHelp = n('waitingHelp');
    if (j['url'] is String) url = j['url'] as String;
  }

  Map<String, dynamic> toJson() => {...content(), 'id': id, 'updated': updated};
  factory FForm.fromJson(Map<String, dynamic> j) =>
      FForm(id: j['id'] as String, updated: (j['updated'] as num?)?.toInt())
        ..applyContent(j)
        ..applyStats(j);
}

// ───────────────────────────── 範本

class FTemplate {
  const FTemplate(this.name, this.desc, this.icon, this.make);
  final String name;
  final String desc;
  final IconData icon;
  final FForm Function() make;
}

FField _q(String type, String label, [String hint = '', bool req = true, List<String>? options]) =>
    FField(type: type, label: label, hint: hint, required: req, options: options);

final templates = <String, FTemplate>{
  'blank': FTemplate('空白表單', '從零開始', Icons.add_rounded, () => FForm(fields: [FField(type: 'radio')])),
  'elder': FTemplate(
    '長者敬老禮金申請',
    '社會局範例',
    Icons.elderly_rounded,
    () => FForm(
      title: '重陽敬老禮金申請',
      dept: '臺北市政府社會局',
      desc: '請依序回答下面的問題，約需 5 分鐘。可以請家人、里長或 1999 客服陪你一起辦。',
      fields: [
        _q('text', '你的姓名', '請填身分證上的名字'),
        _q('idno', '你的身分證字號', '英文字母加 9 個數字'),
        _q('date', '你的出生日期'),
        _q('phone', '你的聯絡電話', '方便我們打給你確認'),
        _q('address', '你住在哪裡', '請填目前的住址'),
        _q('radio', '錢要怎麼給你', '', true, ['匯到我的銀行帳戶', '到區公所領現金']),
        _q('text', '銀行名稱', '選匯款才需要填', false),
        _q('consent', '我確認上面填的資料都正確'),
      ],
    ),
  ),
  'repair': FTemplate(
    '路燈與道路損壞通報',
    '工務局範例',
    Icons.construction_rounded,
    () => FForm(
      title: '路燈與道路損壞通報',
      dept: '臺北市政府工務局',
      desc: '發現路燈不亮或馬路破洞，請在這裡告訴我們。',
      fields: [
        _q('radio', '哪裡壞了', '', true, ['路燈不亮', '馬路有洞', '人行道破損', '其他']),
        _q('address', '在哪個位置', '寫路名和附近的店家也可以'),
        _q('file', '拍張照片給我們', '沒有照片也可以', false),
        _q('phone', '你的電話', '處理好之後通知你', false),
      ],
    ),
  ),
  'survey': FTemplate(
    '活動報名',
    '通用範例',
    Icons.event_available_rounded,
    () => FForm(
      title: '市民活動報名',
      desc: '歡迎報名參加，名額有限，請盡早填寫。',
      fields: [
        _q('text', '你的姓名'),
        _q('phone', '你的聯絡電話'),
        _q('number', '參加人數', '包含你自己'),
        _q('checkbox', '想參加哪幾天', '', true, ['星期六上午', '星期六下午', '星期日上午']),
        _q('textarea', '還有什麼想告訴我們的嗎', '', false),
      ],
    ),
  ),
};

// ───────────────────────────── 好懂檢查

class Advice {
  const Advice(this.msg, [this.from, this.to]);
  final String msg;
  final String? from;
  final String? to;
}

List<Advice> readability(FField f) {
  final w = <Advice>[];
  final t = f.label;
  if (t.length > 20) w.add(const Advice('問題有點長（超過 20 個字），長輩可能看不完。可以縮短，或拆成兩題。'));
  jargon.forEach((k, to) {
    if (t.contains(k)) {
      w.add(
        Advice(
          '「$k」是公文用語，建議改成日常說法${to.isNotEmpty ? '，例如「$to」' : ''}。',
          to.isNotEmpty ? k : null,
          to.isNotEmpty ? to : null,
        ),
      );
    }
  });
  if (RegExp(r'[A-Za-z]{3,}').hasMatch(t) && f.type != 'idno') w.add(const Advice('盡量不要用英文縮寫，長輩看不懂。'));
  if ({'idno', 'address', 'file', 'date'}.contains(f.type) && f.hint.isEmpty) {
    w.add(const Advice('建議在「說明文字」寫一句話，告訴民眾要填什麼、去哪裡找。'));
  }
  if (f.hasOptions && f.options.length > 6) w.add(const Advice('選項超過 6 個，不容易選。可以精簡一下。'));
  return w;
}

int warnCount(FForm f) => f.fields.where((x) => readability(x).isNotEmpty).length;

// ───────────────────────────── 回覆

/// 身分證字號、電話只顯示一部分
String maskAnswer(FField x, Object? v) {
  final s = v?.toString() ?? '';
  if (s.isEmpty) return '';
  if (x.type == 'idno' && s.length >= 6) return '${s.substring(0, 3)}●●●●${s.substring(s.length - 3)}';
  if (x.type == 'phone' && s.length >= 7) return '${s.substring(0, 4)}●●●${s.substring(s.length - 3)}';
  return s;
}

bool isMasked(FField x) => x.type == 'idno' || x.type == 'phone';

/// 一份回覆（後端的列：題目 id → 答案字串，加上 _ 開頭的收件資訊）
extension FRow on Map<String, dynamic> {
  String get rowId => this['_id'] as String? ?? '${this['_t']}';
  DateTime get at => DateTime.fromMillisecondsSinceEpoch((this['_t'] as num).toInt());
  String get by => this['_by'] as String? ?? '';
  bool get viaAssist => this['_via'] == 'assist';
  bool get isSample => this['_sample'] == true;
  String get receipt => this['_receipt'] as String? ?? '';
  String? get helperName => this['_helper'] as String?;
}

// ───────────────────────────── 狀態管理

class _History {
  _History(String first) : stack = [first];
  List<String> stack;
  int i = 0;
}

enum LoadState { idle, loading, ready, failed, notStaff }

class FormStore extends ChangeNotifier {
  FormStore() {
    try {
      hideTip = web.window.localStorage.getItem(_tipKey) == '1';
    } catch (_) {}
  }

  static const _tipKey = 'tp-console-forms-hide-tip';
  HelperController? _c;
  StreamSubscription<Map<String, dynamic>>? _sub;
  ApiClient get api => _c!.api;
  String get apiBase => _c?.api.base ?? '';

  List<FForm> forms = [];
  bool hideTip = false;
  LoadState state = LoadState.idle;
  String? loadError;

  /// 復原／重做或從外部改動內容時遞增，讓輸入框重新載入文字
  int revision = 0;

  final Map<String, _History> _hist = {};
  Timer? _snapTimer;

  // ── 儲存
  final Map<String, Timer> _saveTimers = {};
  final Map<String, Future<void>> _inflight = {};
  final Set<String> saving = {};
  final Map<String, String> saveErrors = {};

  // ── 回覆
  final Map<String, List<Map<String, dynamic>>> rows = {};
  final Set<String> rowsLoading = {};
  final Map<String, String> rowsError = {};

  /// 正在等線上幫忙的長輩：以工作台即時的求助清單為準
  int waitingFor(FForm f) => _c?.isStaff == true ? _c!.tickets.where((t) => t.formId == f.id).length : f.waitingHelp;

  String _ticketSig = '';
  void _onController() {
    final sig = _c?.tickets.map((t) => t.id).join(',') ?? '';
    if (sig == _ticketSig) return;
    _ticketSig = sig;
    notifyListeners();
  }

  FForm? byId(String? id) => forms.where((f) => f.id == id).firstOrNull;

  /// 登入後（或換身分後）接上後端，載入表單並訂閱即時回覆
  void attach(HelperController c) {
    if (_c == c && state != LoadState.idle) return;
    _c?.removeListener(_onController);
    _c = c;
    _sub?.cancel();
    _sub = c.formResponses.listen(_onResponse);
    c.addListener(_onController);
    forms = [];
    rows.clear();
    _hist.clear();
    load();
  }

  Future<void> load() async {
    final c = _c;
    if (c == null) return;
    if (!c.isStaff) {
      state = LoadState.notStaff;
      notifyListeners();
      return;
    }
    state = LoadState.loading;
    loadError = null;
    notifyListeners();
    try {
      final list = await api.get('/console/forms') as List;
      forms = list.map((e) => FForm.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      state = LoadState.ready;
    } on ApiException catch (e) {
      state = e.code == 'NOT_STAFF' ? LoadState.notStaff : LoadState.failed;
      loadError = e.message;
    } catch (_) {
      state = LoadState.failed;
      loadError = '連不到後端，請確認伺服器有沒有啟動';
    }
    notifyListeners();
  }

  void dismissTip() {
    hideTip = true;
    try {
      web.window.localStorage.setItem(_tipKey, '1');
    } catch (_) {}
    notifyListeners();
  }

  FForm create(String template) {
    final f = templates[template]!.make();
    forms.insert(0, f);
    _hist.remove(f.id);
    _saveNow(f);
    notifyListeners();
    return f;
  }

  FForm duplicate(FForm o) {
    final c = FForm.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>)
      ..id = uid()
      ..title = '${o.displayTitle} 的複本'
      ..status = FStatus.draft
      ..updated = DateTime.now().millisecondsSinceEpoch;
    for (final x in c.fields) {
      x.id = uid();
    }
    forms.insert(0, c);
    _saveNow(c);
    notifyListeners();
    return c;
  }

  /// 刪除（後端成功才從清單拿掉）
  Future<void> delete(FForm f) async {
    _saveTimers.remove(f.id)?.cancel();
    await _inflight[f.id];
    await api.delete('/console/forms/${f.id}');
    forms.removeWhere((x) => x.id == f.id);
    _hist.remove(f.id);
    rows.remove(f.id);
    saveErrors.remove(f.id);
    notifyListeners();
  }

  /// 修改表單內容。打字時（immediate = false）延遲 0.5 秒才記一筆復原點，
  /// 其他操作立即記錄，並讓輸入框重新載入。之後稍等一下自動存到後端。
  void edit(FForm f, void Function() change, {bool immediate = true}) {
    _histOf(f);
    change();
    f.updated = DateTime.now().millisecondsSinceEpoch;
    _scheduleSave(f, immediate ? const Duration(milliseconds: 300) : const Duration(milliseconds: 900));
    _snapTimer?.cancel();
    if (immediate) {
      _snap(f);
      revision++;
    } else {
      _snapTimer = Timer(const Duration(milliseconds: 500), () => _snap(f));
    }
    notifyListeners();
  }

  void _scheduleSave(FForm f, Duration d) {
    _saveTimers[f.id]?.cancel();
    _saveTimers[f.id] = Timer(d, () => _saveNow(f));
  }

  bool hasPending(FForm f) => (_saveTimers[f.id]?.isActive ?? false) || saving.contains(f.id);

  /// 立刻存（例如要開海報前，先確定後端是最新內容）
  Future<void> flush(FForm f) async {
    if (_saveTimers[f.id]?.isActive ?? false) {
      _saveTimers[f.id]!.cancel();
      await _saveNow(f);
    } else {
      await _inflight[f.id];
    }
  }

  Future<void> _saveNow(FForm f) {
    _saveTimers.remove(f.id)?.cancel();
    // 同一份表單一次只送一個請求；排在前一個後面
    final prev = _inflight[f.id] ?? Future<void>.value();
    final next = prev.then((_) => _put(f));
    _inflight[f.id] = next;
    return next;
  }

  Future<void> _put(FForm f) async {
    if (!forms.contains(f)) return;
    saving.add(f.id);
    notifyListeners();
    try {
      final res = await api.put('/console/forms/${f.id}', f.content());
      f.applyStats(Map<String, dynamic>.from(res as Map));
      saveErrors.remove(f.id);
    } catch (e) {
      saveErrors[f.id] = e is ApiException ? e.message : '連線中斷，還沒存到伺服器';
    } finally {
      saving.remove(f.id);
      notifyListeners();
    }
  }

  void retrySave(FForm f) => _saveNow(f);

  /// 表單的固定網址（QR Code 內容）
  Future<String> urlOf(FForm f) async {
    if (f.url != null) return f.url!;
    await flush(f);
    final res = Map<String, dynamic>.from(await api.get('/console/forms/${f.id}') as Map);
    f.applyStats(res);
    return f.url ?? '$apiBase/f/${f.id}';
  }

  // ── 回覆

  Future<void> loadRows(FForm f, {bool force = false}) async {
    if (rowsLoading.contains(f.id) || (!force && rows.containsKey(f.id))) return;
    rowsLoading.add(f.id);
    rowsError.remove(f.id);
    notifyListeners();
    try {
      final list = await api.get('/console/forms/${f.id}/responses') as List;
      rows[f.id] = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      rowsError[f.id] = e is ApiException ? e.message : '連不到後端，請稍後再試';
    } finally {
      rowsLoading.remove(f.id);
      notifyListeners();
    }
  }

  void _onResponse(Map<String, dynamic> e) {
    final id = e['formId'] as String?;
    final f = byId(id);
    if (f == null) return;
    if (e['form'] is Map) f.applyStats(Map<String, dynamic>.from(e['form'] as Map));
    final list = rows[f.id];
    if (list != null && e['row'] is Map) {
      final row = Map<String, dynamic>.from(e['row'] as Map);
      if (list.every((r) => r.rowId != row.rowId)) list.insert(0, row);
    }
    notifyListeners();
  }

  // ── 復原／重做

  _History _histOf(FForm f) => _hist.putIfAbsent(f.id, () => _History(jsonEncode(f.content())));

  void _snap(FForm f) {
    final h = _histOf(f);
    final j = jsonEncode(f.content());
    if (h.stack[h.i] == j) return;
    h.stack = h.stack.sublist(0, h.i + 1)..add(j);
    h.i++;
    if (h.stack.length > 80) {
      h.stack.removeAt(0);
      h.i--;
    }
    notifyListeners();
  }

  bool canUndo(FForm f) => (_hist[f.id]?.i ?? 0) > 0 || (_snapTimer?.isActive ?? false);
  bool canRedo(FForm f) {
    final h = _hist[f.id];
    return h != null && h.i < h.stack.length - 1;
  }

  void undo(FForm f) => _move(f, -1);
  void redo(FForm f) => _move(f, 1);

  void _move(FForm f, int d) {
    if (_snapTimer?.isActive ?? false) {
      _snapTimer!.cancel();
      _snap(f);
    }
    final h = _histOf(f);
    final n = h.i + d;
    if (n < 0 || n >= h.stack.length) return;
    h.i = n;
    f.applyContent(jsonDecode(h.stack[n]) as Map<String, dynamic>);
    f.updated = DateTime.now().millisecondsSinceEpoch;
    revision++;
    _scheduleSave(f, const Duration(milliseconds: 300));
    notifyListeners();
  }

  @override
  void dispose() {
    _snapTimer?.cancel();
    _sub?.cancel();
    _c?.removeListener(_onController);
    for (final t in _saveTimers.values) {
      t.cancel();
    }
    super.dispose();
  }
}
