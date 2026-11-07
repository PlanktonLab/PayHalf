/// 陪辦（協辦）功能的資料模型，對應 assist_backend 的 JSON。
/// 刻意不走 json_serializable，避免為了 Demo 新增 build_runner 產生檔。
class FieldDef {
  FieldDef(this.raw);
  final Map<String, dynamic> raw;

  String get key => raw['key'] as String;
  String get label => raw['label'] as String;
  String get type => raw['type'] as String;
  bool get sensitive => raw['sensitive'] == true;
  bool get required => raw['required'] == true;

  /// 表單的多選題：值是用「、」串起來的選項
  bool get multi => raw['multi'] == true;

  /// 表單的文字題（type == 'text'）：text／textarea／number／date／address／phone…
  String get inputType => raw['inputType'] as String? ?? 'text';
  String get hint => raw['hint'] as String? ?? '';

  /// 遮罩用的個資種類：表單題目的 key 是題號，個資種類看 profileKey
  String get maskKey => raw['profileKey'] as String? ?? key;
  String get riskLevel => raw['riskLevel'] as String? ?? 'medium';
  String? get purpose => raw['purpose'] as String?;
  String? get recipient => raw['recipient'] as String?;
  String? get retention => raw['retention'] as String?;
  String? get legalBasis => raw['legalBasis'] as String?;
  List<String> get risks => (raw['risks'] as List? ?? const []).cast<String>();
  List<ChoiceOption> get options =>
      (raw['options'] as List? ?? const []).map((o) => ChoiceOption(Map<String, dynamic>.from(o as Map))).toList();

  /// 授權視窗會由後端帶入長輩自己的資料值
  String? get value => raw['value'] as String?;

  String optionLabel(String? v) => options.where((o) => o.value == v).map((o) => o.label).firstOrNull ?? (v ?? '');
}

class ChoiceOption {
  ChoiceOption(this.raw);
  final Map<String, dynamic> raw;
  String get value => raw['value'] as String;
  String get label => raw['label'] as String;
}

class StepDef {
  StepDef(this.raw);
  final Map<String, dynamic> raw;
  String get id => raw['id'] as String;
  String get title => raw['title'] as String;
  String get elderGuide => raw['elderGuide'] as String? ?? '';
  String get helperScript => raw['helperScript'] as String? ?? '';
  List<FieldDef> get fields =>
      (raw['fields'] as List).map((f) => FieldDef(Map<String, dynamic>.from(f as Map))).toList();
}

class ServiceDef {
  ServiceDef(this.raw);
  final Map<String, dynamic> raw;
  String get id => raw['id'] as String;
  String get title => raw['title'] as String;
  String get category => raw['category'] as String? ?? '';
  String get summary => raw['summary'] as String? ?? '';
  String get agency => raw['agency'] as String? ?? '';
  String get legalBasis => raw['legalBasis'] as String? ?? '';
  int get estMinutes => (raw['estMinutes'] as num?)?.toInt() ?? 5;
  List<StepDef> get steps =>
      (raw['steps'] as List? ?? const []).map((s) => StepDef(Map<String, dynamic>.from(s as Map))).toList();
  List<FieldDef> get allFields => steps.expand((s) => s.fields).toList();
  FieldDef? field(String key) => allFields.where((f) => f.key == key).firstOrNull;
}

class FieldState {
  FieldState(this.raw);
  final Map<String, dynamic> raw;
  String get status => raw['status'] as String? ?? 'empty';
  String? get value => raw['value'] as String?;
  int get requestCount => (raw['requestCount'] as num?)?.toInt() ?? 0;
  int? get remainingRequests => (raw['remainingRequests'] as num?)?.toInt();
  bool get done => status == 'authorized' || status == 'filled';
  /// 長輩改過帳號帶入的內容
  bool get edited => raw['edited'] == true;
  /// 長輩自己授權前看到的「將提供的內容」（只出現在長輩自己的視圖）
  String? get preview => raw['preview'] as String?;
}

class TimelineItem {
  TimelineItem(this.raw);
  final Map<String, dynamic> raw;
  DateTime get ts => DateTime.fromMillisecondsSinceEpoch((raw['ts'] as num).toInt());
  String get actor => raw['actor'] as String;
  String get text => raw['text'] as String;
}

class HelperInfo {
  HelperInfo(this.raw);
  final Map<String, dynamic> raw;
  String get id => raw['id'] as String;
  String get name => raw['name'] as String;
  String get title => raw['title'] as String;
  String get helperType => raw['helperType'] as String;
  String? get org => raw['org'] as String?;
  bool get verified => raw['verified'] == true;
  bool get isFamily => helperType == 'family';
}

class AssistSession {
  AssistSession(this.raw);
  final Map<String, dynamic> raw;

  String get id => raw['id'] as String;
  String get serviceId => raw['serviceId'] as String;
  String get serviceTitle => raw['serviceTitle'] as String;
  String get status => raw['status'] as String;
  String get phase => raw['phase'] as String? ?? 'filling';
  String get method => raw['method'] as String? ?? '';
  int get currentStep => (raw['currentStep'] as num?)?.toInt() ?? 0;
  int get stepCount => (raw['stepCount'] as num?)?.toInt() ?? 1;
  String? get focusField => raw['focusField'] as String?;
  /// 長輩可以自己換頁（陪辦人員可關閉）
  bool get elderNav => raw['elderNav'] != false;
  /// 長輩可以不等請求，自己點開欄位授權（陪辦人員可關閉）
  bool get elderSelfAuth => raw['elderSelfAuth'] != false;
  String? get pendingAuth => raw['pendingAuth'] as String?;
  String? get caseNo => raw['caseNo'] as String?;
  DateTime? get undoUntil => _dt(raw['undoUntil']);
  String? get endReason => raw['endReason'] as String?;
  String? get endedBy => raw['endedBy'] as String?;
  DateTime get createdAt => _dt(raw['createdAt'])!;
  DateTime? get expiresAt => _dt(raw['expiresAt']);
  DateTime? get startedAt => _dt(raw['startedAt']);
  DateTime? get endedAt => _dt(raw['endedAt']);
  DateTime? get lastActivityAt => _dt(raw['lastActivityAt']);

  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';
  bool get isOpen => isPending || isActive;
  bool get isReviewing => isActive && phase == 'reviewing';

  // 協助者視圖
  String get elderDisplayName => (raw['elder'] as Map?)?['displayName'] as String? ?? '長輩';

  // 長輩視圖
  HelperInfo? get helper => raw['helper'] == null ? null : HelperInfo(Map<String, dynamic>.from(raw['helper'] as Map));
  String? get agency => raw['agency'] as String?;
  String? get legalBasis => raw['legalBasis'] as String?;
  /// 這位協助者是長輩「信任的人」
  bool get helperTrusted => raw['helperTrusted'] == true;
  FieldDef? get pendingAuthField =>
      raw['pendingAuthField'] == null ? null : FieldDef(Map<String, dynamic>.from(raw['pendingAuthField'] as Map));

  FieldState field(String key) =>
      FieldState(Map<String, dynamic>.from((raw['fields'] as Map?)?[key] as Map? ?? const {}));

  List<TimelineItem> get timeline =>
      (raw['timeline'] as List? ?? const []).map((t) => TimelineItem(Map<String, dynamic>.from(t as Map))).toList();

  static DateTime? _dt(dynamic v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());
}

String statusLabel(AssistSession s) => switch (s.status) {
  'pending' => '等待長輩回應',
  'active' => s.isReviewing ? '長輩確認送出中' : '協辦進行中',
  'completed' => '已送出',
  'rejected' => '長輩婉拒',
  'cancelled' => '已取消',
  'expired' => '等待逾時',
  'ended' => switch (s.endReason) {
    'timeout' => '閒置逾時結束',
    'blocked' => '已被長輩封鎖',
    _ => s.endedBy == 'elder' ? '長輩結束協助' : '已結束',
  },
  _ => s.status,
};

/// 長輩「信任的人」
class TrustedHelper {
  TrustedHelper(this.raw);
  final Map<String, dynamic> raw;
  HelperInfo get helper => HelperInfo(Map<String, dynamic>.from(raw['helper'] as Map));
  DateTime get since => DateTime.fromMillisecondsSinceEpoch((raw['since'] as num).toInt());
}

/// 長輩主動請信任的人來幫忙
class HelpRequest {
  HelpRequest(this.raw);
  final Map<String, dynamic> raw;
  String get id => raw['id'] as String;
  String get status => raw['status'] as String;
  bool get isPending => status == 'pending';
  String get elderId => (raw['elder'] as Map)['id'] as String;
  /// 協助者看到的長輩姓名（遮罩過）
  String get elderName => (raw['elder'] as Map)['displayName'] as String;
  HelperInfo get helper => HelperInfo(Map<String, dynamic>.from(raw['helper'] as Map));
  DateTime get expiresAt => DateTime.fromMillisecondsSinceEpoch((raw['expiresAt'] as num).toInt());

  /// 長輩在某份表單裡求助時，帶著那份表單（對方按「去幫他」會直接選好）
  String? get serviceId => raw['serviceId'] as String?;
  String? get serviceTitle => raw['serviceTitle'] as String?;
}

/// 靜態 QR Code 表單的一題（格式同承辦人表單後台）
class StaticFormField {
  StaticFormField(this.raw);
  final Map<String, dynamic> raw;
  String get id => raw['id'] as String;
  String get type => raw['type'] as String;
  String get label => raw['label'] as String? ?? '';
  String get hint => raw['hint'] as String? ?? '';
  bool get required => raw['required'] != false;
  List<String> get options => (raw['options'] as List? ?? const []).cast<String>();

  /// 可以從台北通實名帳號帶入的個資種類（realName／birthday／idNo／phone／residentAddress）
  String? get profile => raw['profile'] as String?;
}

/// 長輩掃 QR Code 打開的表單
class StaticForm {
  StaticForm(this.raw);
  final Map<String, dynamic> raw;
  String get id => raw['id'] as String;
  String get title => raw['title'] as String? ?? '';
  String get dept => raw['dept'] as String? ?? '';
  String get desc => raw['desc'] as String? ?? '';
  String get deadline => raw['deadline'] as String? ?? '';
  String get doneMsg => raw['doneMsg'] as String? ?? '';
  String get status => raw['status'] as String? ?? 'open';
  String get serviceId => raw['serviceId'] as String? ?? 'form-$id';
  bool get allowAssist => raw['allowAssist'] != false;
  List<StaticFormField> get fields =>
      (raw['fields'] as List? ?? const []).map((f) => StaticFormField(Map<String, dynamic>.from(f as Map))).toList();
  Map<String, String> get prefill =>
      Map<String, dynamic>.from(raw['prefill'] as Map? ?? const {}).map((k, v) => MapEntry(k, '$v'));
  Map<String, dynamic>? get submitted => raw['submitted'] == null ? null : Map<String, dynamic>.from(raw['submitted'] as Map);
}

/// 可以加為信任的人：陪長輩辦過的人
class TrustCandidate {
  TrustCandidate(this.raw);
  final Map<String, dynamic> raw;
  HelperInfo get helper => HelperInfo(Map<String, dynamic>.from(raw['helper'] as Map));
  String? get serviceTitle => raw['serviceTitle'] as String?;
  DateTime get lastHelpedAt => DateTime.fromMillisecondsSinceEpoch((raw['lastHelpedAt'] as num).toInt());
}

/// 加好友：家人掃了長輩的邀請碼，等長輩確認
class TrustRequest {
  TrustRequest(this.raw);
  final Map<String, dynamic> raw;
  String get id => raw['id'] as String;
  String get status => raw['status'] as String;
  bool get isPending => status == 'pending';
  HelperInfo get helper => HelperInfo(Map<String, dynamic>.from(raw['helper'] as Map));
  String get elderName => (raw['elder'] as Map)['displayName'] as String;
  DateTime get expiresAt => DateTime.fromMillisecondsSinceEpoch((raw['expiresAt'] as num).toInt());
}
