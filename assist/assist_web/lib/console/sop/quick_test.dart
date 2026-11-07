import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/models.dart';
import '../../helper/helper_controller.dart';
import '../../shared/console_kit.dart';
import '../forms/form_store.dart';

/// 測試用的示範表單（後端預設表單 `demo`：姓名、身分證字號、時段，三題）
const kQuickTestFormId = 'demo';

/// 一輪測試的進度。放在工作台外層，切到「工作台」接手陪辦再回來，進度不會不見；
/// 不在這一頁時也持續收回覆。
class QuickTestState extends ChangeNotifier {
  QuickTestState(HelperController c) {
    _sub = c.formResponses.listen((e) {
      if (e['formId'] != kQuickTestFormId || e['row'] is! Map) return;
      rows.insert(0, Map<String, dynamic>.from(e['row'] as Map));
      notifyListeners();
    });
  }

  /// 從這個時間點之後發生的事才算這一輪測試
  DateTime start = DateTime.now();
  final manual = <String>{};
  final rows = <Map<String, dynamic>>[];
  StreamSubscription<Map<String, dynamic>>? _sub;

  void restart() {
    start = DateTime.now();
    manual.clear();
    rows.clear();
    notifyListeners();
  }

  void toggle(String id) {
    manual.contains(id) ? manual.remove(id) : manual.add(id);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// 「1 分鐘測試」：給客服人員照著做的簡短 SOP，測長輩填表的主要功能。
///
/// 能從後端即時事件判斷的步驟會自動打勾（收到回覆、出現求助、陪辦開始、陪辦送出）；
/// 只有長輩手機上才看得到的步驟，由測試的人自己勾。
class QuickTestView extends StatefulWidget {
  const QuickTestView({
    super.key,
    required this.c,
    required this.state,
    required this.store,
    required this.onOpenResponses,
    required this.onOpenWorkbench,
  });
  final HelperController c;
  final QuickTestState state;
  final FormStore store;
  final VoidCallback onOpenResponses;
  final VoidCallback onOpenWorkbench;

  @override
  State<QuickTestView> createState() => _QuickTestViewState();
}

class _QuickTestViewState extends State<QuickTestView> {
  HelperController get c => widget.c;
  QuickTestState get st => widget.state;
  DateTime get start => st.start;
  Set<String> get manual => st.manual;
  List<Map<String, dynamic>> get rows => st.rows;
  Timer? tick;
  bool taking = false;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
    st.addListener(_changed);
    // 經過時間每秒更新
    tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    tick?.cancel();
    c.removeListener(_changed);
    st.removeListener(_changed);
    super.dispose();
  }

  void _changed() => mounted ? setState(() {}) : null;

  void restart() => st.restart();

  // ───────────────────────── 自動偵測

  bool _since(DateTime t) => !t.isBefore(start.subtract(const Duration(seconds: 2)));

  Map<String, dynamic>? get selfRow => rows.where((r) => r['_via'] == 'self').firstOrNull;
  Map<String, dynamic>? get assistRow => rows.where((r) => r['_via'] != 'self').firstOrNull;

  bool get ticketSeen =>
      c.tickets.any((t) => t.formId == kQuickTestFormId && _since(t.createdAt)) || session != null || assistRow != null;

  /// 這一輪測試裡，對示範表單發起的陪辦
  AssistSession? get session => c.sessions.values
      .where((s) => s.serviceId == 'form-$kQuickTestFormId' && _since(s.createdAt))
      .fold<AssistSession?>(null, (best, s) => best == null || s.createdAt.isAfter(best.createdAt) ? s : best);

  bool get sessionActive => session != null && (session!.isActive || !session!.isOpen);

  // ───────────────────────── 畫面

  @override
  Widget build(BuildContext context) {
    final f = widget.store.byId(kQuickTestFormId);
    final s = session;
    final waiting = c.tickets.where((t) => t.formId == kQuickTestFormId && t.isWaiting).toList();
    final selfSteps = [
      _Step('a1', '用手機打開表單', '台北通掃右邊的 QR Code，或首頁「活動訊息」→「免費健康檢查」→「立即報名」。'),
      _Step('a2', '第 1 題：姓名', '按「填入我的姓名」，從台北通帶入，不用打字。'),
      _Step('a3', '第 2 題：身分證字號', '按「填入我的身分證字號」。確認畫面上預設是遮住的，按眼睛才看得到。'),
      _Step('a4', '第 3 題：選時段，按送出', '選一個時段 → 確認頁按「送出」，手機出現收據編號。', auto: selfRow != null),
      _Step(
        'a5',
        '後台收到回覆',
        selfRow == null ? '送出後這裡會自動打勾，不用重新整理。' : '收到：${_rowLine(selfRow!)}',
        auto: selfRow != null,
      ),
    ];
    final assistSteps = [
      _Step('b1', '長輩按「需要別人協助填寫」', '活動頁下方按「需要別人協助填寫」→「請線上客服幫我」。也可以在表單裡任何一題按右上角「找人幫我」。', auto: ticketSeen),
      _Step('b2', '客服在這裡按「接手」', '下方「即時狀態」或工作台會出現求助，按「接手」。', auto: session != null),
      _Step('b3', '長輩按「好，請他幫我」', '長輩手機會問要不要讓您協助，同意後雙方畫面同步。', auto: sessionActive),
      _Step('b4', '帶長輩走完三步', '基本資料（身分證由長輩自己授權，您只看到遮罩）→ 回答問題（選時段）→ 確認送出（只有長輩能按）。', auto: assistRow != null),
      _Step(
        'b5',
        '回覆標示是誰陪辦',
        assistRow == null ? '送出後自動打勾，回覆會標示「1999 客服陪辦」。' : '收到：${_rowLine(assistRow!)}',
        auto: assistRow != null,
      ),
    ];
    _later = [...selfSteps, ...assistSteps];
    final doneA = selfSteps.where(_done).length;
    final doneB = assistSteps.where(_done).length;
    final elapsed = DateTime.now().difference(start);

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Flow(
          n: 'A',
          title: '長輩自己填',
          time: '約 1 分鐘',
          done: doneA,
          steps: selfSteps,
          isDone: _done,
          onToggle: _toggle,
        ),
        const SizedBox(height: 16),
        _Flow(
          n: 'B',
          title: '填不來，找人協助',
          time: '約 2 分鐘',
          done: doneB,
          steps: assistSteps,
          isDone: _done,
          onToggle: _toggle,
        ),
      ],
    );

    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QrPanel(store: widget.store, form: f),
        const SizedBox(height: 16),
        CPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CPanelHeader(
                title: '即時狀態',
                icon: Icons.sensors_rounded,
                trailing: CStatus(c.connected ? '已連線' : '重新連線中', tone: c.connected ? CTone.ok : CTone.danger, size: 12),
              ),
              const SizedBox(height: 12),
              if (!c.isStaff)
                const CNotice(
                  icon: Icons.info_outline_rounded,
                  tone: CTone.warn,
                  text: '流程 B 的線上求助只會送給承辦人員。請從左下角切換成「林志明（1999 客服）」或里長再測。',
                ),
              for (final t in waiting) ...[
                CNotice(
                  icon: Icons.front_hand_outlined,
                  tone: CTone.accent,
                  title: '${t.elderName} 需要協助',
                  text: '已填 ${t.answered}／${t.total} 題${t.question.isEmpty ? '' : '・卡在「${t.question}」'}',
                  action: CButton.primary(
                    taking ? '接手中…' : '接手',
                    onPressed: taking ? null : () => _take(t.id),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (s != null && s.isOpen) ...[
                CNotice(
                  icon: Icons.handshake_outlined,
                  tone: CTone.ok,
                  title: s.isPending ? '等長輩按同意' : '陪辦進行中',
                  text: '第 ${s.currentStep + 1}／${s.stepCount} 步',
                  action: CButton('到工作台', icon: Icons.arrow_forward_rounded, onPressed: widget.onOpenWorkbench),
                ),
                const SizedBox(height: 8),
              ],
              if (rows.isEmpty && waiting.isEmpty && s == null)
                const Text('還沒有動靜。長輩送出或求助時，這裡會即時更新。', style: CText.small),
              for (final r in rows.take(4))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: C.ok),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_rowLine(r), style: CText.secondary)),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              CButton('看全部回覆', icon: Icons.table_rows_outlined, onPressed: widget.onOpenResponses),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const CNotice(
          icon: Icons.checklist_rounded,
          title: '測試重點',
          text: '① 個資一鍵帶入、預設遮罩 ② 協助的人看不到身分證，要長輩授權 ③ 送出鍵只有長輩能按 ④ 後台即時收到回覆，並標示是誰陪辦。',
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 1080;
        final pad = box.maxWidth < 640 ? 16.0 : 32.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(pad, 22, pad, 40),
          children: [
            CPageHeader(
              title: '1 分鐘測試流程',
              subtitle: '用「${f?.displayTitle ?? '長者免費健康檢查報名'}」（3 題）測長輩填表的主要功能。已經測了 ${_mmss(elapsed)}。',
              actions: [CButton('重新開始', icon: Icons.restart_alt_rounded, onPressed: restart)],
            ),
            const SizedBox(height: 20),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: left),
                  const SizedBox(width: 20),
                  SizedBox(width: 360, child: right),
                ],
              )
            else ...[
              right,
              const SizedBox(height: 16),
              left,
            ],
          ],
        );
      },
    );
  }

  /// 後面的步驟系統已經確認完成，前面的步驟一定也做過了
  bool _done(_Step s) => s.auto || manual.contains(s.id) || _later.any((l) => l.auto && l.id[0] == s.id[0] && l.id.compareTo(s.id) > 0);
  List<_Step> _later = const [];

  void _toggle(_Step s) {
    if (s.auto) return;
    HapticFeedback.selectionClick();
    st.toggle(s.id);
  }

  Future<void> _take(String id) async {
    setState(() => taking = true);
    try {
      await c.takeTicket(id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('沒有接到，可能已經被別人接走或長輩取消了')));
      }
    } finally {
      if (mounted) setState(() => taking = false);
    }
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
String _mmss(Duration d) => '${_two(d.inMinutes)}:${_two(d.inSeconds % 60)}';

String _rowLine(Map<String, dynamic> r) {
  final t = DateTime.fromMillisecondsSinceEpoch((r['_t'] as num).toInt());
  return '${_two(t.hour)}:${_two(t.minute)}・${r['_by'] ?? ''}・${r['_receipt'] ?? ''}';
}

class _Step {
  const _Step(this.id, this.title, this.desc, {this.auto = false});
  final String id;
  final String title;
  final String desc;

  /// 已從後端事件確認完成
  final bool auto;
}

class _Flow extends StatelessWidget {
  const _Flow({
    required this.n,
    required this.title,
    required this.time,
    required this.done,
    required this.steps,
    required this.isDone,
    required this.onToggle,
  });
  final String n;
  final String title;
  final String time;
  final int done;
  final List<_Step> steps;
  final bool Function(_Step) isDone;
  final ValueChanged<_Step> onToggle;

  @override
  Widget build(BuildContext context) {
    final all = done == steps.length;
    return CPanel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: all ? C.ok : C.accent, borderRadius: BorderRadius.circular(8)),
                child: Text(n, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: CText.title)),
              CTag(time, icon: Icons.timer_outlined),
              const SizedBox(width: 8),
              CStatus(all ? '完成' : '$done／${steps.length}', tone: all ? CTone.ok : CTone.neutral, size: 12),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++)
            _StepRow(i: i + 1, s: steps[i], done: isDone(steps[i]), onTap: () => onToggle(steps[i]), last: i == steps.length - 1),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.i, required this.s, required this.done, required this.onTap, required this.last});
  final int i;
  final _Step s;
  final bool done;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(C.rControl),
        onTap: s.auto ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: C.divider))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: done ? C.ok : C.ink4,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$i. ${s.title}',
                      style: CText.bodyStrong.copyWith(color: done ? C.ink3 : C.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(s.desc, style: CText.small),
                  ],
                ),
              ),
              if (s.auto)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 2),
                  child: CTag('系統確認', icon: Icons.bolt_rounded, tone: CTone.ok),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrPanel extends StatelessWidget {
  const _QrPanel({required this.store, required this.form});
  final FormStore store;
  final FForm? form;

  @override
  Widget build(BuildContext context) {
    final f = form;
    return CPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CPanelHeader(title: '用手機掃這個', subtitle: 'iPhone 相機或台北通「掃描」都可以', icon: Icons.qr_code_2_rounded),
          const SizedBox(height: 14),
          if (f == null)
            CNotice(
              icon: Icons.info_outline_rounded,
              tone: CTone.warn,
              text: store.state == LoadState.notStaff
                  ? '要用承辦人員身分登入才看得到表單。'
                  : store.state == LoadState.loading
                  ? '載入中…'
                  : '找不到示範表單，請確認後端已更新。',
            )
          else
            FutureBuilder<String>(
              future: store.urlOf(f),
              builder: (context, snap) {
                final url = snap.data;
                if (url == null) return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: C.border),
                        ),
                        child: QrImageView(data: url, size: 200, padding: EdgeInsets.zero),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(url, textAlign: TextAlign.center, style: CText.mono),
                    const SizedBox(height: 10),
                    CButton(
                      '複製表單網址',
                      icon: Icons.copy_rounded,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製')));
                      },
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
