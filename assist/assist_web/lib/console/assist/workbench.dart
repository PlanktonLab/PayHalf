import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../helper/helper_controller.dart';
import '../../shared/console_kit.dart';
import '../../shared/widgets.dart' show EverySecond;

void showApiErr(BuildContext context, Object e) => cToast(context, e is ApiException ? e.message : '連線失敗，請確認後端是否啟動');

CTone sessionTone(AssistSession s) => switch (s.status) {
  'pending' => CTone.warn,
  'active' => CTone.accent,
  'completed' => CTone.ok,
  _ => CTone.neutral,
};

/// 工作台（方案 D「案件列表」）：左邊是今天的案件，右邊是內容。
/// 沒有選取案件時，右邊就是輸入配對碼的地方。
class Workbench extends StatelessWidget {
  const Workbench({super.key, required this.c});
  final HelperController c;

  Widget _right() {
    final s = c.focused;
    if (s == null) return _NewRequestView(key: const ValueKey('new'), c: c);
    if (s.isPending) return _WaitingView(c: c, s: s);
    if (s.isActive) return _SessionConsole(c: c, s: s);
    return _ResultView(c: c, s: s);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 860) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 300,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: C.border)),
                ),
                child: _CaseList(c: c),
              ),
              Expanded(child: _right()),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CaseStrip(c: c),
            const Divider(),
            Expanded(child: _right()),
          ],
        );
      },
    );
  }
}

class _CaseList extends StatelessWidget {
  const _CaseList({required this.c});
  final HelperController c;

  @override
  Widget build(BuildContext context) {
    final all = c.sortedSessions;
    final open = all.where((s) => s.isOpen).toList();
    final now = DateTime.now();
    bool today(AssistSession s) =>
        s.createdAt.year == now.year && s.createdAt.month == now.month && s.createdAt.day == now.day;
    final closedToday = all.where((s) => !s.isOpen && today(s)).toList();
    final earlier = all.where((s) => !s.isOpen && !today(s)).take(10).toList();

    Widget group(String title, List<AssistSession> list) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
          child: Text(title, style: CText.caption),
        ),
        CPanel(
          padding: EdgeInsets.zero,
          clip: true,
          child: Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[if (i > 0) const Divider(), _CaseRow(c: c, s: list[i])],
            ],
          ),
        ),
      ],
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        CButton.primary('新陪辦', icon: Icons.add_rounded, large: true, expand: true, onPressed: () => c.focus(null)),
        if (open.isNotEmpty) group('進行中　${open.length}', open),
        if (closedToday.isNotEmpty) group('今天', closedToday),
        if (earlier.isNotEmpty) group('稍早', earlier),
        if (all.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 24, 6, 0),
            child: Text('今天還沒有陪辦。完成的案件會留在這裡，方便回頭查看。', style: CText.small),
          ),
      ],
    );
  }
}

class _CaseRow extends StatelessWidget {
  const _CaseRow({required this.c, required this.s});
  final HelperController c;
  final AssistSession s;
  @override
  Widget build(BuildContext context) {
    final selected = c.focusedSessionId == s.id;
    return Semantics(
      button: true,
      selected: selected,
      label: '${s.serviceTitle}，${s.elderDisplayName}，${statusLabel(s)}',
      excludeSemantics: true,
      child: Material(
        color: selected ? C.accentSoft : C.surface,
        child: InkWell(
          onTap: () => c.focus(s.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.serviceTitle,
                        overflow: TextOverflow.ellipsis,
                        style: CText.bodyStrong.copyWith(fontSize: 14),
                      ),
                    ),
                    Text(hm(s.createdAt), style: CText.caption.copyWith(fontFeatures: CText.tabular)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(s.elderDisplayName, style: CText.small),
                    const SizedBox(width: 10),
                    Flexible(
                      child: CStatus(statusLabel(s), tone: sessionTone(s), size: 12, pulse: s.isPending),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 窄螢幕：案件列表改成上方一排
class _CaseStrip extends StatelessWidget {
  const _CaseStrip({required this.c});
  final HelperController c;
  @override
  Widget build(BuildContext context) {
    final open = c.sortedSessions.where((s) => s.isOpen).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          CButton.primary('新陪辦', icon: Icons.add_rounded, onPressed: () => c.focus(null)),
          for (final s in open) ...[
            const SizedBox(width: 8),
            CButton(
              '${s.elderDisplayName}・${s.serviceTitle}',
              kind: c.focusedSessionId == s.id ? CButtonKind.secondary : CButtonKind.ghost,
              onPressed: () => c.focus(s.id),
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════ 新陪辦

class _NewRequestView extends StatefulWidget {
  const _NewRequestView({super.key, required this.c});
  final HelperController c;
  @override
  State<_NewRequestView> createState() => _NewRequestViewState();
}

class _NewRequestViewState extends State<_NewRequestView> {
  String? serviceId;
  bool byIdentity = false;
  /// 選了「信任您的長輩」就不用配對碼
  String? elderId;
  final code = TextEditingController();
  final name = TextEditingController();
  final birthday = TextEditingController();
  final last4 = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.c.serviceSummaries.isNotEmpty) serviceId = widget.c.serviceSummaries.first['id'] as String;
    if (widget.c.pendingCode != null) {
      code.text = widget.c.pendingCode!;
      widget.c.pendingCode = null;
    }
  }

  @override
  void dispose() {
    for (final t in [code, name, birthday, last4]) {
      t.dispose();
    }
    super.dispose();
  }

  bool get ready =>
      serviceId != null &&
      !busy &&
      (elderId != null ||
          byIdentity
          ? name.text.trim().isNotEmpty && birthday.text.trim().isNotEmpty && last4.text.length == 4
          : code.text.length == 6);

  Future<void> submit() async {
    if (!ready) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (elderId != null) {
        await widget.c.requestTrusted(serviceId!, elderId!);
      } else if (byIdentity) {
        await widget.c.requestByIdentity(serviceId!, name.text.trim(), birthday.text.trim(), last4.text.trim());
      } else {
        await widget.c.requestByCode(serviceId!, code.text.trim());
      }
    } catch (e) {
      if (mounted) setState(() => error = e is ApiException ? e.message : '連線失敗，請確認後端是否啟動');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _rules() {
    const rules = [
      (Icons.visibility_off_outlined, '您看不到長輩個資的內容', '只會看到「已授權／未授權」等狀態，這是刻意的設計。'),
      (Icons.touch_app_outlined, '授權與送出只有長輩能按', '請引導長輩自己看、自己按，不要拿長輩的手機代按。'),
      (Icons.power_settings_new_rounded, '長輩隨時可以結束', '長輩按「結束協助」後，您這邊會立即失效。'),
      (Icons.link_rounded, '所有操作都有不可竄改的紀錄', '每一步都寫入雜湊鏈稽核紀錄，長輩也能查看。'),
      (Icons.money_off_rounded, '絕不要求轉帳、密碼或驗證碼', '流程中沒有任何步驟需要這些資料。'),
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => Theme(
        data: buildConsoleTheme(),
        child: CDialog(
          title: '陪辦守則',
          body: Column(
            children: [
              for (final r in rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CIconTile(r.$1, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.$2, style: CText.bodyStrong.copyWith(fontSize: 14)),
                            Text(r.$3, style: CText.small),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [CButton.primary('我知道了', onPressed: () => Navigator.pop(ctx))],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final svc = c.serviceSummaries.where((s) => s['id'] == serviceId).firstOrNull;

    final service = CMenu(
      items: [
        for (final s in c.serviceSummaries)
          CMenuItem(
            '${s['title']}（約 ${s['estMinutes']} 分鐘）',
            selected: s['id'] == serviceId,
            onTap: () => setState(() => serviceId = s['id'] as String),
          ),
      ],
      builder: (context, toggle) => Semantics(
        button: true,
        label: '業務：${svc?['title'] ?? '請選擇'}',
        excludeSemantics: true,
        child: Material(
          color: C.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(C.rControl),
            side: const BorderSide(color: C.borderStrong),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(C.rControl),
            onTap: toggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(svc?['title'] as String? ?? '請選擇業務', style: CText.bodyStrong),
                        if (svc != null)
                          Text(
                            '約 ${svc['estMinutes']} 分鐘・${svc['sensitiveFieldCount']} 項個資需長輩授權',
                            style: CText.caption,
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, color: C.ink3),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, box) {
        final pad = box.maxWidth < 640 ? 16.0 : 32.0;
        // 6 格 + 間距（4×10 + 中間 20）要塞得進可用寬度，手機上自動縮小
        final boxSize = ((box.maxWidth - pad * 2 - 60) / 6).clamp(32.0, 52.0);
        return ListView(
          padding: EdgeInsets.fromLTRB(pad, 28, pad, 48),
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('新陪辦', style: CText.pageTitle),
                    const SizedBox(height: 4),
                    Text(
                      byIdentity ? '輸入長輩的姓名、生日與身分證末四碼。' : '請長輩打開台北通首頁的「請人陪我辦」，念出畫面上的 6 位數號碼。',
                      style: CText.secondary.copyWith(color: C.ink3),
                    ),
                    const SizedBox(height: 24),
                    if (c.trustedElders.isNotEmpty && !byIdentity) ...[
                      const Text('信任您的長輩・不用配對碼', style: CText.label),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final e in c.trustedElders)
                            _TrustedChip(
                              name: e['displayName'] as String,
                              selected: elderId == e['elderId'],
                              onTap: () => setState(() {
                                error = null;
                                elderId = elderId == e['elderId'] ? null : e['elderId'] as String;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text('或輸入配對碼', style: CText.label),
                      const SizedBox(height: 8),
                    ],
                    if (!byIdentity) ...[
                      CCodeInput(
                        controller: code,
                        box: boxSize,
                        error: error != null && elderId == null,
                        onChanged: (_) => setState(() {
                          error = null;
                          elderId = null;
                        }),
                        onSubmitted: (_) => submit(),
                      ),
                    ] else ...[
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          CField(
                            label: '長輩姓名',
                            controller: name,
                            width: 170,
                            autofocus: true,
                            onChanged: (_) => setState(() {}),
                          ),
                          CField(
                            label: '出生日期',
                            controller: birthday,
                            width: 170,
                            hint: '1948-03-15',
                            onChanged: (_) => setState(() {}),
                          ),
                          CField(
                            label: '身分證末四碼',
                            controller: last4,
                            width: 150,
                            maxLength: 4,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => submit(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const CNotice(
                        icon: Icons.shield_outlined,
                        text: '為保護長輩，系統不會告訴您是否找到這個人。資料正確時，長輩手機才會收到通知；每次查找都會留下紀錄。',
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 18, color: C.dangerInk),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(error!, style: CText.secondary.copyWith(color: C.dangerInk)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => setState(() {
                        byIdentity = !byIdentity;
                        elderId = null;
                        error = null;
                      }),
                      style: TextButton.styleFrom(foregroundColor: C.accentInk, padding: EdgeInsets.zero),
                      child: Text(
                        byIdentity ? '改用配對碼' : '長輩找不到號碼？改用身分資料查找',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('業務', style: CText.label),
                    const SizedBox(height: 6),
                    SizedBox(width: 360, child: service),
                    const SizedBox(height: 24),
                    CButton.primary(
                      busy ? '送出中…' : (elderId != null ? '請長輩確認' : '送出請求'),
                      icon: Icons.send_rounded,
                      large: true,
                      onPressed: ready ? submit : null,
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        const Icon(Icons.shield_outlined, size: 16, color: C.ink4),
                        const Text('您看不到長輩個資，授權與送出只有長輩能按。', style: CText.small),
                        TextButton(
                          onPressed: _rules,
                          style: TextButton.styleFrom(
                            foregroundColor: C.accentInk,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: const Text('陪辦守則', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════ 等待長輩回應

class _WaitingView extends StatelessWidget {
  const _WaitingView({required this.c, required this.s});
  final HelperController c;
  final AssistSession s;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: CPanel(
            padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Pulse(),
                const SizedBox(height: 22),
                Text(
                  '等待 ${s.elderDisplayName} 回應',
                  style: CText.title.copyWith(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '「${s.serviceTitle}」的陪辦請求已送出',
                  style: CText.secondary.copyWith(color: C.ink3),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                EverySecond(
                  builder: (_, now) => Semantics(
                    liveRegion: false,
                    label: '剩下 ${mmss(s.expiresAt!.difference(now))}',
                    child: Text(mmss(s.expiresAt!.difference(now)), style: CText.kpi.copyWith(fontSize: 44)),
                  ),
                ),
                const Text('後請求自動失效', style: CText.small),
                const SizedBox(height: 22),
                const CNotice(icon: Icons.phone_iphone_rounded, text: '請長輩看手機上的台北通。首頁最上方會出現您的姓名與身分，由長輩自己決定要不要接受陪辦。'),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    CButton('先處理別的案件', kind: CButtonKind.ghost, onPressed: () => c.focus(null)),
                    CButton(
                      '取消請求',
                      onPressed: () => c.end().catchError((Object e) {
                        if (context.mounted) showApiErr(context, e);
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse();
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 尊重「減少動態效果」設定
    if (MediaQuery.of(context).disableAnimations) {
      a.stop();
    } else if (!a.isAnimating) {
      a.repeat();
    }
  }

  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 104,
      child: AnimatedBuilder(
        animation: a,
        builder: (_, _) => Stack(
          alignment: Alignment.center,
          children: [
            for (final d in [0.0, 0.5])
              Opacity(
                opacity: (1 - ((a.value + d) % 1)).clamp(0, 1) * 0.6,
                child: Container(
                  width: 56 + 48 * ((a.value + d) % 1),
                  height: 56 + 48 * ((a.value + d) % 1),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: C.accentSoft2),
                ),
              ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: C.surface,
                border: Border.all(color: C.border),
              ),
              child: const Icon(Icons.phone_iphone_rounded, color: C.accentInk, size: 26),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════ 同步導覽主控台

/// 陪辦進行中：單欄、只留步驟、目前這一步與建議台詞；動態收在最下面。
class _SessionConsole extends StatelessWidget {
  const _SessionConsole({required this.c, required this.s});
  final HelperController c;
  final AssistSession s;

  @override
  Widget build(BuildContext context) {
    final def = c.serviceDefs[s.serviceId];
    if (def == null) return const Center(child: CircularProgressIndicator());
    final step = def.steps[s.currentStep];

    Future<void> run(Future<void> Function() f) async {
      try {
        await f();
      } catch (e) {
        if (context.mounted) showApiErr(context, e);
      }
    }

    return LayoutBuilder(
      builder: (context, box) {
        final tight = box.maxWidth < 700;
        final pad = tight ? 16.0 : 32.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(pad, 24, pad, 48),
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.serviceTitle, style: CText.pageTitle.copyWith(fontSize: 22)),
                              const SizedBox(height: 2),
                              EverySecond(
                                builder: (_, now) => Text(
                                  '陪辦對象 ${s.elderDisplayName}　·　已進行 ${mmss(now.difference(s.startedAt ?? now))}',
                                  style: CText.small.copyWith(fontFeatures: CText.tabular),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8, right: 12),
                          child: CStatus(statusLabel(s), tone: sessionTone(s), pulse: true, size: 13),
                        ),
                        CButton(
                          '結束',
                          icon: Icons.power_settings_new_rounded,
                          kind: CButtonKind.danger,
                          onPressed: () async {
                            final ok = await cConfirm(
                              context,
                              title: '結束這次陪辦？',
                              body: '結束後您就無法再引導長輩，長輩手機上的協助畫面也會關閉。已授權的資料不會送出。',
                              confirm: '結束陪辦',
                              danger: true,
                            );
                            if (ok) run(() => c.end());
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CSwitchRow(
                      title: '長輩自己換頁',
                      desc: s.elderNav
                          ? '完成一步會自動到下一步，長輩也能按上一頁／下一頁。長輩亂按時可以關掉。'
                          : '已關閉：只有您能換頁，長輩手機會顯示「會帶您到下一步」。',
                      value: s.elderNav,
                      onChanged: (v) => run(() => c.setElderNav(v)),
                    ),
                    const SizedBox(height: 8),
                    CSwitchRow(
                      title: '長輩自己授權',
                      desc: s.elderSelfAuth
                          ? '長輩可以直接點開這一步的資料自己同意，不用等您按「請長輩授權」。'
                          : '已關閉：要由您逐項按「請長輩授權」，長輩才能提供資料。',
                      value: s.elderSelfAuth,
                      onChanged: (v) => run(() => c.setElderSelfAuth(v)),
                    ),
                    const SizedBox(height: 8),
                    _StepChips(def: def, s: s),
                    const SizedBox(height: 14),
                    _CurrentStep(c: c, s: s, def: def, step: step, run: run, tight: tight),
                    const SizedBox(height: 20),
                    _TimelinePanel(s: s),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StepChips extends StatelessWidget {
  const _StepChips({required this.def, required this.s});
  final ServiceDef def;
  final AssistSession s;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < def.steps.length; i++)
          Semantics(
            label:
                '第 ${i + 1} 步 ${def.steps[i].title}${i < s.currentStep ? '，已完成' : (i == s.currentStep ? '，目前這一步' : '')}',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: i == s.currentStep ? C.surface : C.inset,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: i == s.currentStep ? C.accent : Colors.transparent),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (i < s.currentStep) ...[
                    const Icon(Icons.check_rounded, size: 14, color: C.ink2),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    i < s.currentStep ? def.steps[i].title : '${i + 1} ${def.steps[i].title}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: i == s.currentStep ? FontWeight.w600 : FontWeight.w400,
                      color: i == s.currentStep ? C.accentInk : (i < s.currentStep ? C.ink2 : C.ink3),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CurrentStep extends StatelessWidget {
  const _CurrentStep({
    required this.c,
    required this.s,
    required this.def,
    required this.step,
    required this.run,
    required this.tight,
  });
  final HelperController c;
  final AssistSession s;
  final ServiceDef def;
  final StepDef step;
  final Future<void> Function(Future<void> Function()) run;
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final last = s.currentStep == def.steps.length - 1;
    final waitingAuth = s.pendingAuth != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '第 ${s.currentStep + 1} 步，共 ${def.steps.length} 步',
                style: CText.small.copyWith(color: C.accentInk, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(step.title, style: CText.title.copyWith(fontSize: 22)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.inset, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.phone_iphone_rounded, size: 18, color: C.ink3),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('長輩手機上現在顯示', style: CText.caption),
                          const SizedBox(height: 2),
                          Text('「${step.elderGuide}」', style: CText.body),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (step.helperScript.isNotEmpty) ...[const SizedBox(height: 10), _ScriptPanel(step: step)],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (s.isReviewing)
          const CNotice(
            icon: Icons.hourglass_top_rounded,
            tone: CTone.warn,
            title: '長輩正在確認送出',
            text: '長輩正在手機上檢查所有資料。送出鍵只有長輩能按，請耐心等候，必要時口頭協助說明。',
          )
        else if (step.fields.isEmpty)
          const SizedBox.shrink()
        else
          CPanel(
            padding: EdgeInsets.zero,
            clip: true,
            child: Column(
              children: [
                for (var i = 0; i < step.fields.length; i++) ...[
                  if (i > 0) const Divider(),
                  _FieldRow(c: c, s: s, f: step.fields[i], run: run, tight: tight),
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            CButton(
              '上一步',
              icon: Icons.arrow_back_rounded,
              large: true,
              onPressed: s.currentStep == 0 || waitingAuth || s.isReviewing
                  ? null
                  : () => run(() => c.gotoStep(s.currentStep - 1)),
            ),
            const Spacer(),
            if (waitingAuth && !tight) ...[
              const CStatus('等待長輩回應授權中', tone: CTone.warn, size: 13),
              const SizedBox(width: 14),
            ],
            if (!last)
              CButton.primary(
                tight ? '下一步' : '下一步（長輩畫面同步翻頁）',
                trailingIcon: Icons.arrow_forward_rounded,
                large: true,
                onPressed: waitingAuth ? null : () => run(() => c.gotoStep(s.currentStep + 1)),
              )
            else if (!s.isReviewing)
              CButton.primary(
                '請長輩確認送出',
                icon: Icons.fact_check_outlined,
                large: true,
                onPressed: waitingAuth ? null : () => run(c.requestSubmit),
              ),
          ],
        ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.c, required this.s, required this.f, required this.run, required this.tight});
  final HelperController c;
  final AssistSession s;
  final FieldDef f;
  final Future<void> Function(Future<void> Function()) run;
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final st = s.field(f.key);
    final focused = s.focusField == f.key;
    final canRequest = f.sensitive && st.status != 'authorized' && st.status != 'requested' && s.pendingAuth == null;
    final remaining = st.remainingRequests ?? 0;

    final (String stLabel, CTone stTone) = switch (st.status) {
      'authorized' => ('長輩已授權', CTone.ok),
      'filled' => ('長輩已選擇', CTone.ok),
      'requested' => ('等待長輩授權', CTone.warn),
      'denied' => ('長輩不同意', CTone.danger),
      _ => (f.sensitive ? '尚未授權' : '尚未選擇', CTone.neutral),
    };

    final tag = f.sensitive && f.riskLevel == 'high'
        ? const CTag('高敏感個資', tone: CTone.danger)
        : f.sensitive
        ? const CTag('個資', tone: CTone.warn)
        : const CTag('長輩自選');

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(f.label, style: CText.bodyStrong),
            tag,
            if (st.edited && st.status == 'authorized') const CTag('長輩修改過', tone: CTone.accent),
          ],
        ),
        const SizedBox(height: 4),
        if (f.sensitive)
          Text(
            st.status == 'authorized'
                ? '●●●●●●　${st.edited ? '長輩修改後提供' : '已由長輩提供'}，內容僅長輩與受理機關可見'
                : '●●●●●●　用途：${f.purpose ?? ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: CText.small,
          )
        else
          Text(
            st.value == null ? '請長輩在手機上選擇' : '長輩選了：${f.optionLabel(st.value)}',
            style: st.value == null ? CText.small : CText.secondary,
          ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CIconButton(
          icon: Icons.highlight_alt_rounded,
          tooltip: focused ? '取消在長輩畫面上的標示' : '在長輩畫面上標示這個欄位',
          bordered: true,
          selected: focused,
          onPressed: s.pendingAuth != null ? null : () => run(() => c.focusField(focused ? null : f.key)),
        ),
        if (f.sensitive) ...[
          const SizedBox(width: 8),
          CButton(
            st.status == 'authorized'
                ? '已授權'
                : remaining == 0
                ? '已達詢問上限'
                : st.status == 'denied'
                ? '再次詢問（剩 $remaining 次）'
                : '請長輩授權',
            kind: st.status == 'authorized' ? CButtonKind.secondary : CButtonKind.primary,
            onPressed: canRequest && remaining > 0 ? () => run(() => c.requestField(f.key)) : null,
          ),
        ],
      ],
    );

    final status = CStatus(stLabel, tone: stTone, size: 13, pulse: st.status == 'requested');

    return LayoutBuilder(
      builder: (context, box) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: focused ? C.accentSoft : C.surface,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: tight || box.maxWidth < 640
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  info,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: status),
                      actions,
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 12),
                  SizedBox(width: 120, child: status),
                  actions,
                ],
              ),
      ),
    );
  }
}

class _ScriptPanel extends StatelessWidget {
  const _ScriptPanel({required this.step});
  final StepDef step;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.accentSoft, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '建議您這樣說',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.accentInk),
          ),
          const SizedBox(height: 2),
          Text(step.helperScript, style: CText.body),
        ],
      ),
    );
  }
}

class _TimelinePanel extends StatefulWidget {
  const _TimelinePanel({required this.s});
  final AssistSession s;
  @override
  State<_TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends State<_TimelinePanel> {
  bool open = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final items = s.timeline.reversed.take(12).toList();
    final toggle = Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => setState(() => open = !open),
        style: TextButton.styleFrom(foregroundColor: C.ink3, padding: const EdgeInsets.symmetric(horizontal: 4)),
        icon: Icon(open ? Icons.expand_less_rounded : Icons.history_rounded, size: 18),
        label: Text('即時動態（${s.timeline.length}）', style: const TextStyle(fontSize: 13)),
      ),
    );
    if (!open) return toggle;
    return CPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: CPanelHeader(title: '即時動態')),
              CIconButton(icon: Icons.close_rounded, tooltip: '收起動態', onPressed: () => setState(() => open = false)),
            ],
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 14,
            children: [
              CStatus('您', tone: CTone.accent, size: 12),
              CStatus('長輩', tone: CTone.warn, size: 12),
              CStatus('系統', size: 12),
            ],
          ),
          const SizedBox(height: 12),
          for (final t in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: toneDot(switch (t.actor) {
                        'elder' => CTone.warn,
                        'helper' => CTone.accent,
                        _ => CTone.neutral,
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t.text, style: CText.secondary.copyWith(fontSize: 13.5))),
                  const SizedBox(width: 8),
                  Text(hms(t.ts), style: CText.caption.copyWith(fontFeatures: CText.tabular)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════ 結束畫面

class _ResultView extends StatelessWidget {
  const _ResultView({required this.c, required this.s});
  final HelperController c;
  final AssistSession s;
  @override
  Widget build(BuildContext context) {
    final ok = s.status == 'completed';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: CPanel(
            padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: ok ? C.okSoft : C.inset),
                  child: Icon(
                    ok ? Icons.check_rounded : Icons.info_outline_rounded,
                    size: 34,
                    color: ok ? C.ok : C.ink3,
                  ),
                ),
                const SizedBox(height: 18),
                Text(ok ? '長輩已完成送出' : statusLabel(s), style: CText.title.copyWith(fontSize: 22)),
                const SizedBox(height: 4),
                Text('${s.serviceTitle}　·　${s.elderDisplayName}', style: CText.secondary.copyWith(color: C.ink3)),
                if (ok) ...[
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(color: C.inset, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        const Text('案件編號', style: CText.caption),
                        const SizedBox(height: 4),
                        SelectableText(s.caseNo ?? '', style: CText.kpi.copyWith(letterSpacing: 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('長輩的個資已直接送到受理機關，這次陪辦的連線紀錄中不保留任何個資。', textAlign: TextAlign.center, style: CText.small),
                ],
                const SizedBox(height: 24),
                CButton.primary('開始新的陪辦', icon: Icons.add_rounded, large: true, onPressed: () => c.focus(null)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════ 紀錄

class HistoryView extends StatelessWidget {
  const HistoryView({super.key, required this.c, required this.onOpen});
  final HelperController c;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) {
    final list = c.sortedSessions;
    final done = list.where((s) => s.status == 'completed').length;
    return LayoutBuilder(
      builder: (context, box) {
        final pad = box.maxWidth < 640 ? 16.0 : 32.0;
        final wide = box.maxWidth > 820;
        return ListView(
          padding: EdgeInsets.fromLTRB(pad, 28, pad, 48),
          children: [
            const CPageHeader(title: '陪辦紀錄', subtitle: '您發起過的所有陪辦。長輩姓名一律遮蔽顯示。'),
            const SizedBox(height: 24),
            CStatStrip(
              items: [
                CStat(icon: Icons.history_rounded, label: '全部', value: '${list.length}'),
                CStat(icon: Icons.task_alt_rounded, label: '已送出', value: '$done'),
                CStat(icon: Icons.sync_rounded, label: '進行中', value: '${list.where((s) => s.isOpen).length}'),
                CStat(
                  icon: Icons.do_not_disturb_on_outlined,
                  label: '未完成',
                  value: '${list.where((s) => !s.isOpen && s.status != 'completed').length}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (list.isEmpty)
              const CPanel(
                child: CEmpty(icon: Icons.history_rounded, title: '還沒有任何陪辦紀錄', body: '從工作台發起第一次陪辦吧。'),
              )
            else
              CTable(
                columns: wide ? const ['業務', '長輩', '找到長輩的方式', '時間', '狀態'] : const ['業務', '狀態'],
                flex: wide ? const [4, 2, 2, 3, 3] : const [3, 2],
                onTap: (i) => onOpen(list[i].id),
                rows: [
                  for (final s in list)
                    wide
                        ? [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.serviceTitle, style: CText.bodyStrong.copyWith(fontSize: 14)),
                                if (s.caseNo != null) Text('案件 ${s.caseNo}', style: CText.caption),
                              ],
                            ),
                            Text(s.elderDisplayName, style: CText.secondary),
                            Text(s.method == 'identity' ? '身分資料查找' : '配對碼', style: CText.secondary),
                            Text(ymdhm(s.createdAt), style: CText.small.copyWith(fontFeatures: CText.tabular)),
                            CStatus(statusLabel(s), tone: sessionTone(s), size: 13),
                          ]
                        : [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.serviceTitle, style: CText.bodyStrong.copyWith(fontSize: 14)),
                                Text('${s.elderDisplayName}・${ymdhm(s.createdAt)}', style: CText.caption),
                              ],
                            ),
                            CStatus(statusLabel(s), tone: sessionTone(s), size: 13),
                          ],
                ],
              ),
          ],
        );
      },
    );
  }
}

class AuditView extends StatelessWidget {
  const AuditView({super.key, required this.c});
  final HelperController c;
  @override
  Widget build(BuildContext context) {
    final st = c.auditStatus;
    final ok = st?['ok'] == true;
    final head = (st?['headHash'] as String? ?? '').padRight(16).substring(0, 16);
    return LayoutBuilder(
      builder: (context, box) {
        final pad = box.maxWidth < 640 ? 16.0 : 32.0;
        final wide = box.maxWidth > 760;
        return ListView(
          padding: EdgeInsets.fromLTRB(pad, 28, pad, 48),
          children: [
            CPageHeader(
              title: '稽核紀錄',
              subtitle: '每個動作都寫入雜湊鏈（hash chain），任何一筆被修改都會被偵測出來。',
              actions: [CButton('重新驗證', icon: Icons.refresh_rounded, onPressed: c.refreshAudit)],
            ),
            const SizedBox(height: 24),
            if (st != null)
              CStatStrip(
                items: [
                  CStat(
                    icon: ok ? Icons.verified_outlined : Icons.gpp_bad_outlined,
                    label: '雜湊鏈',
                    value: ok ? '完整' : '異常',
                    note: ok ? '未被竄改' : '第 ${st['brokenAt']} 筆被修改',
                  ),
                  CStat(icon: Icons.storage_rounded, label: '全系統紀錄', value: '${st['length']}'),
                  CStat(icon: Icons.person_outline_rounded, label: '您的操作', value: '${c.auditEntries.length}'),
                  CStat(
                    icon: Icons.tag_rounded,
                    label: '最新雜湊',
                    value: head.substring(0, 8),
                    note: '${head.substring(8)}…',
                  ),
                ],
              ),
            const SizedBox(height: 12),
            const Text('以下只列出您本人的操作。系統比對結果等內部欄位不會顯示給協助者。', style: CText.small),
            const SizedBox(height: 12),
            if (c.auditEntries.isEmpty)
              const CPanel(
                child: CEmpty(icon: Icons.receipt_long_outlined, title: '尚無紀錄'),
              )
            else
              CTable(
                columns: wide ? const ['序號', '時間', '操作', '雜湊'] : const ['操作', '時間'],
                flex: wide ? const [1, 2, 6, 2] : const [3, 2],
                rows: [
                  for (final e in c.auditEntries)
                    wide
                        ? [
                            Text('#${e['seq']}', style: CText.mono),
                            Text(
                              ymdhm(DateTime.fromMillisecondsSinceEpoch((e['ts'] as num).toInt())),
                              style: CText.small.copyWith(fontFeatures: CText.tabular),
                            ),
                            Text(e['summary'] as String, style: CText.secondary.copyWith(color: C.ink)),
                            Text((e['hash'] as String).substring(0, 12), style: CText.mono.copyWith(fontSize: 12)),
                          ]
                        : [
                            Text(e['summary'] as String, style: CText.secondary.copyWith(color: C.ink)),
                            Text(
                              hms(DateTime.fromMillisecondsSinceEpoch((e['ts'] as num).toInt())),
                              style: CText.caption,
                            ),
                          ],
                ],
              ),
          ],
        );
      },
    );
  }
}


class _TrustedChip extends StatelessWidget {
  const _TrustedChip({required this.name, required this.selected, required this.onTap});
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? C.accentSoft : C.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(99),
        side: BorderSide(color: selected ? C.accent : C.borderStrong, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: C.warnSoft),
                child: Text(name.characters.first, style: CText.bodyStrong.copyWith(color: C.warnInk, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Text(name, style: CText.bodyStrong),
              if (selected) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check_rounded, size: 16, color: C.accentInk),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
