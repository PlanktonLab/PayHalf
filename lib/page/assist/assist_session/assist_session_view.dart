import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:town_pass/bean/assist.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_route.dart';

/// 協辦進行中：跟著協助者的步驟走，個資逐項授權，最後由長輩自己送出。
class AssistSessionView extends StatelessWidget {
  const AssistSessionView({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    final id = Get.arguments as String;

    return Obx(() {
      final s = service.sessions[id];
      final def = s == null ? null : service.serviceDefs[s.serviceId];
      final auth = s != null && s.isActive ? s.pendingAuthField : null;

      final Widget body;
      if (s == null || def == null) {
        body = const Center(child: CircularProgressIndicator());
      } else if (!s.isOpen) {
        body = _Result(s: s);
      } else if (s.isPending) {
        body = const Center(child: Text('等待您回應協助請求', style: AssistText.headline));
      } else {
        body = Column(
          children: [
            _HelperStrip(s: s),
            Expanded(
              child: s.isReviewing ? _Review(s: s, def: def) : _Steps(s: s, def: def),
            ),
          ],
        );
      }

      return AssistTextScaleCap(
        child: PopScope(
          // 授權畫面出現時不能用返回手勢關掉，必須明確選擇
          canPop: auth == null,
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: TPColors.grayscale50,
                appBar: TPAppBar(title: s?.serviceTitle ?? '陪你辦'),
                body: body,
              ),
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
                  transitionBuilder: (child, a) => SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                  child: auth == null
                      ? const SizedBox.shrink(key: ValueKey('none'))
                      : _AuthSheet(key: ValueKey('auth-${auth.key}-${s!.field(auth.key).requestCount}'), s: s, f: auth),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ═════════════════════════════════════════════ 上方協助者列

class _HelperStrip extends StatelessWidget {
  const _HelperStrip({required this.s});
  final AssistSession s;

  @override
  Widget build(BuildContext context) {
    final h = s.helper!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: const BoxDecoration(
        color: TPColors.white,
        border: Border(bottom: BorderSide(color: TPColors.grayscale100)),
      ),
      child: Row(
        children: [
          AssistHelperAvatar(helper: h, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(assistHelperDisplayName(h), style: AssistText.headline.copyWith(fontSize: 18)),
                const Text('正在陪您辦理', style: AssistText.footnote),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: TPColors.red600,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: () async {
              final ok = await assistConfirm(
                title: '結束這次協助？',
                message: '${h.name} 會馬上斷線，還沒送出的資料都不會送出。',
                confirmLabel: '結束協助',
              );
              if (ok) await assistRun(() => Get.find<AssistService>().end(s.id));
            },
            child: Text('結束協助', style: AssistText.headline.copyWith(fontSize: 18, color: TPColors.red600)),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════ 步驟

class _Steps extends StatelessWidget {
  const _Steps({required this.s, required this.def});
  final AssistSession s;
  final ServiceDef def;

  @override
  Widget build(BuildContext context) {
    final step = def.steps[s.currentStep];
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        Semantics(
          label: '第 ${s.currentStep + 1} 步，共 ${def.steps.length} 步',
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '第 ${s.currentStep + 1} 步',
                        style: AssistText.callout.copyWith(color: TPColors.primary600, fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: '，共 ${def.steps.length} 步', style: AssistText.callout),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < def.steps.length; i++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 8,
                          decoration: BoxDecoration(
                            color: i <= s.currentStep ? TPColors.primary500 : TPColors.grayscale200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Semantics(header: true, child: Text(step.title, style: AssistText.largeTitle)),
        const SizedBox(height: 10),
        Text(step.elderGuide, style: AssistText.body.copyWith(fontSize: 21)),
        const SizedBox(height: 18),
        for (final f in step.fields) ...[_FieldCard(s: s, f: f), const SizedBox(height: 14)],
        if (step.fields.isEmpty)
          AssistNotice(
            icon: Icons.hearing_rounded,
            color: TPColors.primary800,
            background: TPColors.primary50,
            text: '請聽 ${s.helper!.name} 說明，這一步不用按任何東西。',
          ),
        const SizedBox(height: 8),
        AssistButton(
          '我的權利與法規說明',
          style: AssistButtonStyle.plain,
          icon: Icons.gavel_rounded,
          onPressed: () => Get.toNamed(TPRoute.assistLegal),
        ),
      ],
    );
  }
}

class _FieldCard extends StatefulWidget {
  const _FieldCard({required this.s, required this.f});
  final AssistSession s;
  final FieldDef f;
  @override
  State<_FieldCard> createState() => _FieldCardState();
}

class _FieldCardState extends State<_FieldCard> {
  bool reveal = false;

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    final s = widget.s;
    final f = widget.f;
    final st = s.field(f.key);
    final focused = s.focusField == f.key;

    final Widget body;
    if (f.type == 'choice') {
      body = Column(
        children: [
          for (final o in f.options)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _ChoiceRow(
                label: o.label,
                selected: st.value == o.value,
                onTap: () {
                  HapticFeedback.selectionClick();
                  assistRun(() => service.input(s.id, f.key, o.value));
                },
              ),
            ),
        ],
      );
    } else if (st.status == 'authorized') {
      body = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text(reveal ? (st.value ?? '') : assistMask(f.key, st.value), style: AssistText.headline),
          IconButton(
            tooltip: reveal ? '遮住${f.label}' : '顯示完整${f.label}',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => setState(() => reveal = !reveal),
            icon: Icon(reveal ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: context.iconSize(24)),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: TPColors.red600),
            onPressed: () async {
              final ok = await assistConfirm(title: '撤回「${f.label}」？', message: '撤回後，這項資料不會被送出。', confirmLabel: '撤回');
              if (ok) await assistRun(() => service.revoke(s.id, f.key));
            },
            child: Text(
              '撤回',
              style: AssistText.callout.copyWith(color: TPColors.red600, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    } else {
      body = Text(switch (st.status) {
        'denied' => '您選擇不提供這項資料',
        'requested' => '請看跳出來的確認畫面',
        _ => '等 ${s.helper!.name} 請您確認',
      }, style: AssistText.callout.copyWith(color: st.status == 'denied' ? TPColors.red600 : null));
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TPColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: focused ? TPColors.secondary500 : Colors.transparent, width: 3),
        boxShadow: focused ? const [BoxShadow(color: Color(0x40F5BA4B), blurRadius: 20, spreadRadius: 2)] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (focused)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.arrow_circle_right_rounded, color: TPColors.secondary600, size: context.iconSize(24)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${s.helper!.name} 請您看這裡',
                      style: AssistText.headline.copyWith(color: TPColors.secondary700),
                    ),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      f.sensitive ? Icons.lock_rounded : Icons.touch_app_rounded,
                      color: f.sensitive ? TPColors.secondary700 : TPColors.primary500,
                      size: context.iconSize(24),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text(f.label, style: AssistText.title.copyWith(fontSize: 22))),
                ],
              ),
              if (f.sensitive) AssistPill.forField(st),
            ],
          ),
          const SizedBox(height: 8),
          body,
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? TPColors.primary50 : TPColors.grayscale50,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? TPColors.primary500 : TPColors.grayscale200, width: 2),
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: selected ? TPColors.primary500 : TPColors.grayscale400,
                    size: context.iconSize(28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AssistText.body.copyWith(fontSize: 20, fontWeight: selected ? FontWeight.w600 : null),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════ 授權（全螢幕）

class _AuthSheet extends StatefulWidget {
  const _AuthSheet({super.key, required this.s, required this.f});
  final AssistSession s;
  final FieldDef f;
  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
  bool reveal = false;
  bool busy = false;

  Future<void> answer(bool approve) async {
    setState(() => busy = true);
    if (approve) HapticFeedback.mediumImpact();
    await assistRun(() => Get.find<AssistService>().authorize(widget.s.id, widget.f.key, approve));
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.f;
    final s = widget.s;
    final high = f.riskLevel == 'high';
    final accent = high ? TPColors.red600 : TPColors.secondary700;
    final accentBg = high ? TPColors.red50 : TPColors.secondary50;

    Widget info(IconData icon, String label, String value) => MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: context.iconSize(24), color: TPColors.primary600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AssistText.callout),
                  Text(value, style: AssistText.headline.copyWith(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Material(
      color: TPColors.white,
      child: SafeArea(
        bottom: false,
        child: AssistActionLayout(
          padding: EdgeInsets.zero,
          content: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              color: accentBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(Icons.lock_rounded, color: accent, size: context.iconSize(24)),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          high ? '重要資料，請看清楚' : '資料授權',
                          style: AssistText.callout.copyWith(color: accent, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    header: true,
                    label: '${s.helper!.name} 請您確認：要提供您的${f.label}嗎？',
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('要提供您的', style: AssistText.headline),
                          Text('「${f.label}」嗎？', style: AssistText.largeTitle.copyWith(fontSize: 34)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                    decoration: BoxDecoration(color: TPColors.grayscale50, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('將提供', style: AssistText.callout),
                              Text(
                                reveal ? (f.value ?? '') : assistMask(f.key, f.value),
                                style: AssistText.title.copyWith(fontSize: 22),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: reveal ? '遮住內容' : '顯示完整內容',
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          onPressed: () => setState(() => reveal = !reveal),
                          icon: Icon(
                            reveal ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: context.iconSize(26),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  info(Icons.account_balance_rounded, '給誰用', f.recipient ?? s.agency ?? ''),
                  const Divider(height: 1),
                  info(Icons.help_outline_rounded, '做什麼用', f.purpose ?? ''),
                  const Divider(height: 1),
                  info(Icons.schedule_rounded, '保存多久', f.retention ?? ''),
                  const SizedBox(height: 12),
                  AssistNotice(
                    icon: Icons.visibility_off_rounded,
                    color: AssistColors.green700,
                    background: AssistColors.green50,
                    text: '${s.helper!.name} 看不到這項資料的內容',
                  ),
                  const SizedBox(height: 12),
                  AssistNotice(
                    icon: Icons.warning_amber_rounded,
                    color: high ? TPColors.red700 : TPColors.secondary800,
                    background: accentBg,
                    title: '請注意',
                    text: [...f.risks, '不想提供可以按「先不要」，不會有任何處罰。'].map((r) => '・$r').join('\n'),
                  ),
                  const SizedBox(height: 12),
                  Text('法令依據：${f.legalBasis ?? ''}', style: AssistText.footnote),
                  AssistButton(
                    '看我的權利與詳細法規',
                    style: AssistButtonStyle.plain,
                    icon: Icons.gavel_rounded,
                    onPressed: () => Get.toNamed(TPRoute.assistLegal),
                  ),
                ],
              ),
            ),
          ],
          actions: [
            AssistButton('同意提供', icon: Icons.check_rounded, onPressed: busy ? null : () => answer(true)),
            AssistButton('先不要', style: AssistButtonStyle.secondary, onPressed: busy ? null : () => answer(false)),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════ 確認送出

class _Review extends StatefulWidget {
  const _Review({required this.s, required this.def});
  final AssistSession s;
  final ServiceDef def;
  @override
  State<_Review> createState() => _ReviewState();
}

class _ReviewState extends State<_Review> {
  bool reveal = false;
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    final s = widget.s;
    final fields = widget.def.allFields;
    return AssistActionLayout(
      content: [
        Semantics(header: true, child: const Text('請確認您的資料', style: AssistText.largeTitle)),
        const SizedBox(height: 4),
        Text('「${s.serviceTitle}」', style: AssistText.callout),
        const SizedBox(height: 16),
        AssistCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                MergeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fields[i].label, style: AssistText.callout),
                        Text(
                          fields[i].type == 'choice'
                              ? fields[i].optionLabel(s.field(fields[i].key).value)
                              : reveal
                              ? (s.field(fields[i].key).value ?? '')
                              : assistMask(fields[i].key, s.field(fields[i].key).value),
                          style: AssistText.headline,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        AssistButton(
          reveal ? '遮住資料' : '顯示完整資料',
          style: AssistButtonStyle.plain,
          icon: reveal ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          onPressed: () => setState(() => reveal = !reveal),
        ),
        AssistNotice(
          icon: Icons.send_rounded,
          color: TPColors.primary800,
          background: TPColors.primary50,
          text: '按下「確認送出」後，資料會交給 ${s.agency}。送出鍵只有您能按。',
        ),
      ],
      actions: [
        AssistButton(
          '確認送出',
          style: AssistButtonStyle.success,
          icon: Icons.send_rounded,
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  HapticFeedback.mediumImpact();
                  await assistRun(() => service.submit(s.id, true));
                  if (mounted) setState(() => busy = false);
                },
        ),
        AssistButton(
          '我要再看一下',
          style: AssistButtonStyle.secondary,
          onPressed: busy ? null : () => assistRun(() => service.submit(s.id, false)),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════ 結果

class _Result extends StatelessWidget {
  const _Result({required this.s});
  final AssistSession s;

  @override
  Widget build(BuildContext context) {
    final ok = s.status == 'completed';
    final message = switch ((s.endedBy, s.endReason)) {
      (_, 'submitted') => '申請已經送出了！',
      (_, 'timeout') => '太久沒有動作，協助已自動結束',
      (_, 'blocked') => '已封鎖對方，協助已結束',
      ('elder', _) => '您已經結束這次協助',
      _ => '${s.helper?.name ?? '協助者'} 結束了這次協助',
    };
    return AssistActionLayout(
      content: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(shape: BoxShape.circle, color: ok ? AssistColors.green50 : TPColors.grayscale100),
            child: Icon(
              ok ? Icons.check_rounded : Icons.info_outline_rounded,
              size: 64,
              color: ok ? AssistColors.green500 : TPColors.grayscale500,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(message, textAlign: TextAlign.center, style: AssistText.largeTitle),
        ),
        const SizedBox(height: 6),
        Text('「${s.serviceTitle}」', textAlign: TextAlign.center, style: AssistText.callout),
        if (ok) ...[
          const SizedBox(height: 20),
          AssistCard(
            color: TPColors.primary50,
            child: Semantics(
              label: '案件編號 ${s.caseNo}',
              child: ExcludeSemantics(
                child: Column(
                  children: [
                    Text('案件編號', style: AssistText.callout.copyWith(color: TPColors.primary700)),
                    FittedBox(
                      child: Text(
                        s.caseNo ?? '',
                        textScaler: context.cappedScaler,
                        style: AssistText.largeTitle.copyWith(color: TPColors.primary800, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        const Text('這次是誰陪您、您提供了哪些資料，都可以在「我的帳戶 › 歷程與授權管理」查看。', textAlign: TextAlign.center, style: AssistText.callout),
      ],
      actions: [
        AssistButton(
          '回到首頁',
          onPressed: () {
            Get.find<AssistService>().dismissResult();
            Get.until((route) => route.settings.name == TPRoute.main || route.isFirst);
          },
        ),
      ],
    );
  }
}
