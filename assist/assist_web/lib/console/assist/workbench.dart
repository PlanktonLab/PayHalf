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

/// 工作台：依目前聚焦的協辦狀態切換畫面。
class Workbench extends StatelessWidget {
  const Workbench({super.key, required this.c});
  final HelperController c;
  @override
  Widget build(BuildContext context) {
    final s = c.focused;
    if (s == null) return _NewRequestView(c: c);
    if (s.isPending) return _WaitingView(c: c, s: s);
    if (s.isActive) return _SessionConsole(c: c, s: s);
    return _ResultView(c: c, s: s);
  }
}

// ═════════════════════════════════════════════ 發起新協辦

class _NewRequestView extends StatefulWidget {
  const _NewRequestView({required this.c});
  final HelperController c;
  @override
  State<_NewRequestView> createState() => _NewRequestViewState();
}

class _NewRequestViewState extends State<_NewRequestView> {
  String? serviceId;
  String method = 'pairing_code';
  final code = TextEditingController();
  final name = TextEditingController();
  final birthday = TextEditingController();
  final last4 = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.c.serviceSummaries.isNotEmpty) serviceId = widget.c.serviceSummaries.first['id'] as String;
  }

  @override
  void dispose() {
    for (final t in [code, name, birthday, last4]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (serviceId == null || busy) return;
    setState(() => busy = true);
    try {
      if (method == 'pairing_code') {
        await widget.c.requestByCode(serviceId!, code.text.trim());
      } else {
        await widget.c.requestByIdentity(serviceId!, name.text.trim(), birthday.text.trim(), last4.text.trim());
      }
    } catch (e) {
      if (mounted) showApiErr(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final all = c.sessions.values;
    final open = c.sortedSessions.where((s) => s.isOpen).toList();
    final today = DateTime.now();
    final doneToday = all
        .where((s) => s.status == 'completed' && s.createdAt.year == today.year && s.createdAt.day == today.day)
        .length;

    final services = CPanel(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: CPanelHeader(title: '1　選擇要陪辦的業務', subtitle: '長輩手機上會顯示同一個業務的申辦畫面'),
          ),
          const Divider(),
          for (var i = 0; i < c.serviceSummaries.length; i++) ...[
            if (i > 0) const Divider(),
            _ServiceRow(
              s: c.serviceSummaries[i],
              selected: c.serviceSummaries[i]['id'] == serviceId,
              onTap: () => setState(() => serviceId = c.serviceSummaries[i]['id'] as String),
            ),
          ],
        ],
      ),
    );

    final find = CPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CPanelHeader(
            title: '2　找到長輩',
            subtitle: '長輩同意後才會開始，您看不到長輩的個資內容',
            trailing: CSegmented<String>(
              value: method,
              onChanged: (v) => setState(() => method = v),
              options: const [('pairing_code', '配對碼', Icons.pin_outlined), ('identity', '身分資料', Icons.badge_outlined)],
            ),
          ),
          const SizedBox(height: 18),
          if (method == 'pairing_code') ...[
            const Text('請長輩打開台北通首頁的「請人陪我辦」，念出畫面上的 6 位數配對碼。', style: CText.secondary),
            const SizedBox(height: 14),
            CField(
              label: '配對碼',
              controller: code,
              width: 280,
              autofocus: true,
              hint: '000000',
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 28,
                letterSpacing: 10,
                fontWeight: FontWeight.w600,
                fontFeatures: CText.tabular,
              ),
              help: '配對碼 2 分鐘內有效，只能使用一次。',
              onSubmitted: (_) => submit(),
            ),
          ] else ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                CField(label: '長輩姓名', controller: name, width: 180),
                CField(label: '出生日期', controller: birthday, width: 180, hint: '1948-03-15'),
                CField(
                  label: '身分證末四碼',
                  controller: last4,
                  width: 150,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (_) => submit(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const CNotice(
              icon: Icons.shield_outlined,
              text: '為保護長輩，系統不會告訴您是否找到這個人。資料正確時，長輩手機才會收到通知。每 10 分鐘最多查找 5 次，每次查找都會留下紀錄，長輩本人也看得到。',
            ),
          ],
          const SizedBox(height: 20),
          CButton.primary(
            busy ? '送出中…' : '送出陪辦請求',
            icon: Icons.send_rounded,
            large: true,
            onPressed: busy || serviceId == null ? null : submit,
          ),
        ],
      ),
    );

    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (open.isNotEmpty) ...[
          CPanel(
            padding: EdgeInsets.zero,
            clip: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: CPanelHeader(title: '進行中', subtitle: '${open.length} 件，點一下回到協辦畫面'),
                ),
                const Divider(),
                for (final s in open)
                  InkWell(
                    onTap: () => c.focus(s.id),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 14, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.serviceTitle,
                                  overflow: TextOverflow.ellipsis,
                                  style: CText.bodyStrong.copyWith(fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                CStatus('${s.elderDisplayName}・${statusLabel(s)}', tone: sessionTone(s), size: 13),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: C.ink4),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const _SafetyRules(),
      ],
    );

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 1040;
        final pad = box.maxWidth < 640 ? 16.0 : 32.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(pad, 28, pad, 48),
          children: [
            const CPageHeader(title: '工作台', subtitle: '選擇業務、找到長輩。長輩在自己的手機上同意後，您就能一步一步陪他完成申辦。'),
            const SizedBox(height: 24),
            CStatStrip(
              items: [
                CStat(icon: Icons.sync_rounded, label: '進行中', value: '${all.where((s) => s.isActive).length}'),
                CStat(
                  icon: Icons.hourglass_top_rounded,
                  label: '等待長輩回應',
                  value: '${all.where((s) => s.isPending).length}',
                ),
                CStat(icon: Icons.task_alt_rounded, label: '今日完成', value: '$doneToday'),
                CStat(
                  icon: Icons.link_rounded,
                  label: '稽核紀錄',
                  value: '${c.auditStatus?['length'] ?? '—'}',
                  note: c.auditStatus?['ok'] == true ? '雜湊鏈完整' : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: [services, const SizedBox(height: 16), find])),
                  const SizedBox(width: 16),
                  SizedBox(width: 340, child: side),
                ],
              )
            else ...[
              services,
              const SizedBox(height: 16),
              find,
              const SizedBox(height: 16),
              side,
            ],
          ],
        );
      },
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.s, required this.selected, required this.onTap});
  final Map<String, dynamic> s;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        color: selected ? C.accentSoft : C.surface,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 20,
                    color: selected ? C.accentStrong : C.ink4,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(s['title'] as String, style: CText.bodyStrong),
                          CTag(s['category'] as String),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(s['summary'] as String, style: CText.small),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 16,
                        children: [
                          _meta(Icons.schedule_rounded, '約 ${s['estMinutes']} 分鐘'),
                          _meta(Icons.lock_outline_rounded, '${s['sensitiveFieldCount']} 項個資需長輩授權'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData i, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(i, size: 14, color: C.ink4),
      const SizedBox(width: 4),
      Text(t, style: CText.caption),
    ],
  );
}

class _SafetyRules extends StatelessWidget {
  const _SafetyRules();
  @override
  Widget build(BuildContext context) {
    const rules = [
      (Icons.visibility_off_outlined, '您看不到長輩個資的內容', '只會看到「已授權／未授權」等狀態，這是刻意的設計。'),
      (Icons.touch_app_outlined, '授權與送出只有長輩能按', '請引導長輩自己看、自己按，不要拿長輩的手機代按。'),
      (Icons.power_settings_new_rounded, '長輩隨時可以結束', '長輩按「結束協助」後，您這邊會立即失效。'),
      (Icons.link_rounded, '所有操作都有不可竄改的紀錄', '每一步都寫入雜湊鏈稽核紀錄，長輩也能查看。'),
      (Icons.money_off_rounded, '絕不要求轉帳、密碼或驗證碼', '流程中沒有任何步驟需要這些資料。'),
    ];
    return CPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CPanelHeader(title: '陪辦守則', icon: Icons.shield_outlined),
          const SizedBox(height: 14),
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
                    CButton('先回工作台', kind: CButtonKind.ghost, onPressed: () => c.focus(null)),
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
        final tight = box.maxWidth < 760;
        final three = box.maxWidth >= 1180;
        final pad = tight ? 16.0 : 32.0;
        final endBtn = CButton(
          '結束陪辦',
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
        );
        final header = Padding(
          padding: EdgeInsets.fromLTRB(pad, 22, pad, 18),
          child: CPageHeader(
            title: s.serviceTitle,
            subtitle: '陪辦對象：${s.elderDisplayName}　·　受理機關：${def.agency}',
            leading: CIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: '回到工作台',
              bordered: true,
              onPressed: () => c.focus(null),
            ),
            actions: [
              EverySecond(
                builder: (_, now) => Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CStatus(statusLabel(s), tone: sessionTone(s), pulse: true, size: 13),
                    const SizedBox(height: 4),
                    Text(
                      '已進行 ${mmss(now.difference(s.startedAt ?? now))}　閒置 ${mmss(now.difference(s.lastActivityAt ?? now))}／30:00',
                      style: CText.caption.copyWith(fontFeatures: CText.tabular),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              endBtn,
            ],
          ),
        );

        final main = _CurrentStep(c: c, s: s, def: def, step: step, run: run, tight: tight);
        final script = _ScriptPanel(step: step);
        final timeline = _TimelinePanel(s: s);
        final steps = _StepList(def: def, s: s, onTap: (i) => run(() => c.gotoStep(i)));

        Widget body;
        if (three) {
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 248, child: steps),
              const SizedBox(width: 16),
              Expanded(child: main),
              const SizedBox(width: 16),
              SizedBox(width: 320, child: Column(children: [script, const SizedBox(height: 16), timeline])),
            ],
          );
        } else if (!tight) {
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 232, child: steps),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [main, const SizedBox(height: 16), script, const SizedBox(height: 16), timeline],
                ),
              ),
            ],
          );
        } else {
          body = Column(
            children: [
              _StepChips(def: def, s: s),
              const SizedBox(height: 14),
              main,
              const SizedBox(height: 16),
              script,
              const SizedBox(height: 16),
              timeline,
            ],
          );
        }

        return ListView(
          padding: EdgeInsets.only(bottom: 48),
          children: [
            header,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: body,
            ),
          ],
        );
      },
    );
  }
}

class _StepList extends StatelessWidget {
  const _StepList({required this.def, required this.s, required this.onTap});
  final ServiceDef def;
  final AssistSession s;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    final locked = s.pendingAuth != null || s.isReviewing;
    return CPanel(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Text('申辦步驟', style: CText.caption),
          ),
          for (var i = 0; i < def.steps.length; i++)
            Builder(
              builder: (context) {
                final step = def.steps[i];
                final current = i == s.currentStep;
                final done = step.fields.where((f) => s.field(f.key).done).length;
                final complete = step.fields.isEmpty ? i < s.currentStep : done == step.fields.length;
                return Semantics(
                  button: true,
                  selected: current,
                  label: '第 ${i + 1} 步 ${step.title}${complete ? '，已完成' : ''}',
                  excludeSemantics: true,
                  child: Material(
                    color: current ? C.inset : Colors.transparent,
                    borderRadius: BorderRadius.circular(C.rControl),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(C.rControl),
                      onTap: locked || current ? null : () => onTap(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: complete ? C.accentStrong : C.surface,
                                border: Border.all(
                                  color: complete || current ? C.accentStrong : C.borderStrong,
                                  width: 1.5,
                                ),
                              ),
                              child: complete
                                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                  : Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: current ? C.accentInk : C.ink3,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                                      color: current ? C.ink : C.ink2,
                                    ),
                                  ),
                                  if (step.fields.isNotEmpty)
                                    Text('$done／${step.fields.length} 項完成', style: CText.caption),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StepChips extends StatelessWidget {
  const _StepChips({required this.def, required this.s});
  final ServiceDef def;
  final AssistSession s;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < def.steps.length; i++)
            CTag(
              '${i + 1} ${def.steps[i].title}',
              icon: i < s.currentStep ? Icons.check_rounded : (i == s.currentStep ? Icons.arrow_right_rounded : null),
              tone: i == s.currentStep ? CTone.accent : null,
              size: 13,
            ),
        ],
      ),
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
          const CNotice(icon: Icons.record_voice_over_outlined, text: '這一步沒有需要填寫的欄位。請依「建議您這樣說」向長輩說明，再按「下一步」。')
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
          ],
        ),
        const SizedBox(height: 4),
        if (f.sensitive)
          Text(
            st.status == 'authorized' ? '●●●●●●　已由長輩提供，內容僅長輩與受理機關可見' : '●●●●●●　用途：${f.purpose ?? ''}',
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
    return CPanel(
      color: C.accentSoft,
      borderColor: C.accentSoft2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.record_voice_over_outlined, size: 18, color: C.accentInk),
              SizedBox(width: 8),
              Text(
                '建議您這樣說',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: C.accentInk),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(step.helperScript, style: CText.body.copyWith(height: 1.7)),
        ],
      ),
    );
  }
}

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.s});
  final AssistSession s;
  @override
  Widget build(BuildContext context) {
    final items = s.timeline.reversed.take(12).toList();
    return CPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CPanelHeader(title: '即時動態'),
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
