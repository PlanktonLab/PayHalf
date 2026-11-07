import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// 承辦人表單：資料模型、範本、暫存與復原／重做。
/// 資料暫存在瀏覽器 localStorage，回覆為示意假資料（尚未串接後端）。

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
  '茲': '', '俾': '讓', '惟': '但是', '檢附': '附上', '敬請': '請', '前開': '上面的', '核定': '審查通過', //
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
    List<Map<String, dynamic>>? live,
  }) : id = id ?? uid(),
       fields = fields ?? [],
       updated = updated ?? DateTime.now().millisecondsSinceEpoch,
       live = live ?? [];

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

  /// 在預覽中試填送出的回覆
  List<Map<String, dynamic>> live;

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

  Map<String, dynamic> toJson() => {...content(), 'id': id, 'updated': updated, 'live': live};
  factory FForm.fromJson(Map<String, dynamic> j) => FForm(
    id: j['id'] as String,
    updated: (j['updated'] as num?)?.toInt(),
    live: (j['live'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
  )..applyContent(j);
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

// ───────────────────────────── 回覆（示意）

String maskAnswer(FField x, Object? v) {
  final s = v?.toString() ?? '';
  if (s.isEmpty) return '';
  if (x.type == 'idno' && s.length >= 6) return '${s.substring(0, 3)}●●●●${s.substring(s.length - 3)}';
  if (x.type == 'phone' && s.length >= 7) return '${s.substring(0, 4)}●●●${s.substring(s.length - 3)}';
  return s;
}

List<Map<String, dynamic>> mockResponses(FForm f) {
  if (f.status == FStatus.draft) return [];
  var seed = 0;
  for (final c in f.id.codeUnits) {
    seed = (seed * 31 + c) & 0xFFFFFFFF;
  }
  double r() {
    seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
    return seed / 4294967296;
  }

  const names = ['陳美玲', '林建國', '黃秀英', '張志明', '李淑芬', '王大明', '吳金龍', '蔡玉蘭'];
  const by = ['本人', '家屬陪辦', '里長陪辦', '看護陪辦', '1999 客服陪辦'];
  const dist = ['大安', '信義', '中正', '萬華', '北投'];
  final now = DateTime.now().millisecondsSinceEpoch;
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < (f.status == FStatus.closed ? 18 : 24); i++) {
    final row = <String, dynamic>{'_t': now - (r() * 86400000 * 6).floor(), '_by': by[(r() * by.length).floor()]};
    for (final x in f.fields) {
      final o = x.options;
      row[x.id] = switch (x.type) {
        'idno' => 'A${(r() * 2).floor() + 1}${(r() * 1e8).floor().toString().padLeft(8, '0')}',
        'phone' => '09${(r() * 1e8).floor().toString().padLeft(8, '0')}',
        'radio' || 'select' => o.isEmpty ? '' : o[(r() * r() * o.length).floor()],
        'checkbox' => o.where((_) => r() > .55).join('、'),
        'date' => '19${30 + (r() * 30).floor()}-0${1 + (r() * 9).floor()}-1${(r() * 9).floor()}',
        'consent' => '已同意',
        'file' => '照片${i + 1}.jpg',
        'address' => '臺北市${dist[(r() * 5).floor()]}區○○路${(r() * 200).floor()}號',
        'number' => '${1 + (r() * 4).floor()}',
        _ => x.label.contains('姓名') ? names[(r() * names.length).floor()] : '（示意回答）',
      };
    }
    out.add(row);
  }
  return out;
}

List<Map<String, dynamic>> allResponses(FForm f) =>
    [...f.live, ...mockResponses(f)]..sort((a, b) => (b['_t'] as num).compareTo(a['_t'] as num));

// ───────────────────────────── 狀態管理

class _History {
  _History(String first) : stack = [first];
  List<String> stack;
  int i = 0;
}

class FormStore extends ChangeNotifier {
  FormStore() {
    _load();
  }

  static const _key = 'tp-console-forms-v1';
  List<FForm> forms = [];
  bool hideTip = false;

  /// 復原／重做或從外部改動內容時遞增，讓輸入框重新載入文字
  int revision = 0;

  final Map<String, _History> _hist = {};
  Timer? _snapTimer;

  FForm? byId(String? id) => forms.where((f) => f.id == id).firstOrNull;

  void _load() {
    try {
      final raw = web.window.localStorage.getItem(_key);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        forms = (j['forms'] as List).map((e) => FForm.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        hideTip = j['hideTip'] as bool? ?? false;
        return;
      }
    } catch (_) {}
    final now = DateTime.now().millisecondsSinceEpoch;
    forms = [
      templates['elder']!.make()
        ..deadline = '2026-12-31'
        ..status = FStatus.open
        ..updated = now - 86400000 * 2,
      templates['repair']!.make()
        ..allowAssist = false
        ..updated = now - 3600000 * 5,
    ];
  }

  void _save() {
    try {
      web.window.localStorage.setItem(
        _key,
        jsonEncode({'forms': forms.map((f) => f.toJson()).toList(), 'hideTip': hideTip}),
      );
    } catch (_) {}
  }

  void dismissTip() {
    hideTip = true;
    _save();
    notifyListeners();
  }

  FForm create(String template) {
    final f = templates[template]!.make();
    forms.insert(0, f);
    _hist.remove(f.id);
    _save();
    notifyListeners();
    return f;
  }

  FForm duplicate(FForm o) {
    final c = FForm.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>)
      ..id = uid()
      ..title = '${o.displayTitle} 的複本'
      ..status = FStatus.draft
      ..live = []
      ..updated = DateTime.now().millisecondsSinceEpoch;
    for (final x in c.fields) {
      x.id = uid();
    }
    forms.insert(0, c);
    _save();
    notifyListeners();
    return c;
  }

  void delete(FForm f) {
    forms.removeWhere((x) => x.id == f.id);
    _hist.remove(f.id);
    _save();
    notifyListeners();
  }

  /// 修改表單內容。打字時（immediate = false）延遲 0.5 秒才記一筆復原點，
  /// 其他操作立即記錄，並讓輸入框重新載入。
  void edit(FForm f, void Function() change, {bool immediate = true}) {
    _histOf(f);
    change();
    f.updated = DateTime.now().millisecondsSinceEpoch;
    _save();
    _snapTimer?.cancel();
    if (immediate) {
      _snap(f);
      revision++;
    } else {
      _snapTimer = Timer(const Duration(milliseconds: 500), () => _snap(f));
    }
    notifyListeners();
  }

  void addLive(FForm f, Map<String, dynamic> row) {
    f.live.insert(0, row);
    _save();
    notifyListeners();
  }

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
    _save();
    notifyListeners();
  }

  @override
  void dispose() {
    _snapTimer?.cancel();
    super.dispose();
  }
}
