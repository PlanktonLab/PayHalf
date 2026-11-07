import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../shared/tp_colors.dart';
import '../shared/widgets.dart';
import 'helper_controller.dart';

/// 協助者工作台（電腦版）。
class HelperApp extends StatefulWidget {
  const HelperApp({super.key, this.compact = false});

  /// 並排示範時寬度有限，側欄改成圖示列
  final bool compact;

  @override
  State<HelperApp> createState() => _HelperAppState();
}

class _HelperAppState extends State<HelperApp> {
  final c = HelperController();

  @override
  void initState() {
    super.initState();
    c.loadDemoAccounts();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => c.loggedIn ? _HelperShell(c: c, compact: widget.compact) : _HelperLogin(c: c),
    );
  }
}

// ═════════════════════════════════════════════ 登入

class _HelperLogin extends StatelessWidget {
  const _HelperLogin({required this.c});
  final HelperController c;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [TPColors.primary50, TPColors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      TownPassLogo(size: 28),
                      SizedBox(width: 12),
                      Text('台北通　陪你辦｜協辦工作台', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '選擇您的 Demo 身分。正式版將以台北通實名帳號、里長名冊或市府內部帳號登入。',
                    style: TextStyle(fontSize: 15, color: TPColors.grayscale600),
                  ),
                  const SizedBox(height: 28),
                  if (c.accountsLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (c.accountsFailed)
                    TPCard(
                      child: Row(
                        children: [
                          const Expanded(child: Text('連不到後端。請先在 assist_backend 執行 npm start。')),
                          TextButton(onPressed: c.loadDemoAccounts, child: const Text('重試')),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: [
                        for (final a in c.demoAccounts)
                          SizedBox(
                            width: 270,
                            child: TPCard(
                              onTap: () => c.login(a['id'] as String).catchError((e) {
                                if (context.mounted) showApiError(context, e);
                              }),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: TPColors.primary50,
                                    child: Icon(
                                      helperIcon(a['helperType'] as String),
                                      color: TPColors.primary600,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    a['name'] as String,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(a['title'] as String, style: const TextStyle(color: TPColors.grayscale600)),
                                  const SizedBox(height: 12),
                                  HelperBadge(helperType: a['helperType'] as String, verified: a['verified'] == true),
                                  const SizedBox(height: 12),
                                  Text(
                                    a['org'] as String? ?? '一般台北通實名用戶',
                                    style: const TextStyle(fontSize: 13, color: TPColors.grayscale500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════ 外框與側欄

class _HelperShell extends StatefulWidget {
  const _HelperShell({required this.c, required this.compact});
  final HelperController c;
  final bool compact;
  @override
  State<_HelperShell> createState() => _HelperShellState();
}

class _HelperShellState extends State<_HelperShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return LayoutBuilder(
      builder: (context, box) {
        final rail = widget.compact || box.maxWidth < 1100;
        return Scaffold(
          body: Row(
            children: [
              _Sidebar(
                c: c,
                rail: rail,
                tab: tab,
                onTab: (i) {
                  setState(() => tab = i);
                  if (i == 2) c.refreshAudit();
                },
              ),
              Expanded(
                child: switch (tab) {
                  1 => _HistoryView(
                    c: c,
                    onOpen: (id) {
                      c.focus(id);
                      setState(() => tab = 0);
                    },
                  ),
                  2 => _AuditView(c: c),
                  _ => _Workbench(c: c, narrow: box.maxWidth < 1280),
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.c, required this.rail, required this.tab, required this.onTab});
  final HelperController c;
  final bool rail;
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final me = c.me!;
    final open = c.sessions.values.where((s) => s.isOpen).length;
    Widget nav(int i, IconData icon, String label, {int badge = 0}) {
      final selected = tab == i;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Material(
          color: selected ? TPColors.white.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTab(i),
            child: Tooltip(
              message: rail ? label : '',
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: rail ? 0 : 14, vertical: 12),
                child: Row(
                  mainAxisAlignment: rail ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    Badge(
                      isLabelVisible: badge > 0,
                      label: Text('$badge'),
                      backgroundColor: TPColors.secondary500,
                      textColor: TPColors.grayscale900,
                      child: Icon(icon, color: selected ? TPColors.white : TPColors.primary200, size: 22),
                    ),
                    if (!rail) ...[
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: TextStyle(
                          color: selected ? TPColors.white : TPColors.primary100,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final audit = c.auditStatus;
    return Container(
      width: rail ? 76 : 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [TPColors.primary700, TPColors.primary900],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(rail ? 0 : 24, 24, rail ? 0 : 24, 20),
              child: rail
                  ? const Center(child: _LogoChip())
                  : const Row(
                      children: [
                        _LogoChip(),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '陪你辦',
                              style: TextStyle(color: TPColors.white, fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                            Text('台北通協辦工作台', style: TextStyle(color: TPColors.primary200, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
            ),
            if (!rail)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TPColors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: TPColors.primary500,
                          child: Icon(helperIcon(me['helperType'] as String), color: TPColors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                me['name'] as String,
                                style: const TextStyle(
                                  color: TPColors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                me['title'] as String,
                                style: const TextStyle(color: TPColors.primary200, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    HelperBadge(helperType: me['helperType'] as String, verified: me['verified'] == true),
                  ],
                ),
              ),
            nav(0, Icons.handshake_rounded, '協辦工作台', badge: open),
            nav(1, Icons.history_rounded, '協辦紀錄'),
            nav(2, Icons.verified_user_rounded, '稽核紀錄'),
            const Spacer(),
            if (!rail && audit != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TPColors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      audit['ok'] == true ? Icons.link_rounded : Icons.link_off_rounded,
                      color: audit['ok'] == true ? TPColors.primary300 : TPColors.red200,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        audit['ok'] == true ? '稽核鏈完整　共 ${audit['length']} 筆' : '稽核鏈異常',
                        style: const TextStyle(color: TPColors.primary100, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(rail ? 0 : 24, 12, rail ? 0 : 12, 16),
              child: Row(
                mainAxisAlignment: rail ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Tooltip(
                    message: c.connected ? '即時連線中' : '連線中斷，重新連線中',
                    child: Icon(Icons.circle, size: 10, color: c.connected ? TPColors.green500 : TPColors.red500),
                  ),
                  if (!rail) ...[
                    const SizedBox(width: 8),
                    Text(
                      c.connected ? '即時連線中' : '重新連線中…',
                      style: const TextStyle(color: TPColors.primary200, fontSize: 12),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: c.logout,
                      child: const Text('切換身分', style: TextStyle(color: TPColors.primary100, fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoChip extends StatelessWidget {
  const _LogoChip();
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(color: TPColors.white, borderRadius: BorderRadius.circular(12)),
    alignment: Alignment.center,
    child: const TownPassLogo(size: 20),
  );
}

// ═════════════════════════════════════════════ 工作台

class _Workbench extends StatelessWidget {
  const _Workbench({required this.c, required this.narrow});
  final HelperController c;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final s = c.focused;
    if (s == null) return _NewRequestView(c: c, narrow: narrow);
    if (s.isPending) return _WaitingView(c: c, s: s);
    if (s.isActive) return _SessionConsole(c: c, s: s, narrow: narrow);
    return _ResultView(c: c, s: s);
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle, this.trailing});
  final String title;
  final String subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: TPColors.grayscale900),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(fontSize: 15, color: TPColors.grayscale600)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

// ───────────────────────────── 發起新協辦

class _NewRequestView extends StatefulWidget {
  const _NewRequestView({required this.c, required this.narrow});
  final HelperController c;
  final bool narrow;
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

  Future<void> submit() async {
    if (serviceId == null) return;
    setState(() => busy = true);
    try {
      if (method == 'pairing_code') {
        await widget.c.requestByCode(serviceId!, code.text.trim());
      } else {
        await widget.c.requestByIdentity(serviceId!, name.text.trim(), birthday.text.trim(), last4.text.trim());
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepLabel(n: 1, text: '選擇要協辦的業務'),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final s in c.serviceSummaries)
              _ServiceCard(
                s: s,
                selected: s['id'] == serviceId,
                onTap: () => setState(() => serviceId = s['id'] as String),
              ),
          ],
        ),
        const SizedBox(height: 32),
        const _StepLabel(n: 2, text: '找到長輩'),
        const SizedBox(height: 14),
        TPCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: TPColors.primary500,
                  selectedForegroundColor: TPColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                segments: const [
                  ButtonSegment(
                    value: 'pairing_code',
                    icon: Icon(Icons.qr_code_2_rounded),
                    label: Text('配對碼／QR Code（建議）'),
                  ),
                  ButtonSegment(value: 'identity', icon: Icon(Icons.badge_outlined), label: Text('以身分資料查找')),
                ],
                selected: {method},
                onSelectionChanged: (v) => setState(() => method = v.first),
              ),
              const SizedBox(height: 22),
              if (method == 'pairing_code') ...[
                const Text(
                  '請長輩打開台北通首頁的「請人陪我辦」，念出畫面上的 6 位數配對碼，或用掃描器掃 QR Code。',
                  style: TextStyle(color: TPColors.grayscale600, height: 1.6),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: code,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 32, letterSpacing: 12, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(hintText: '000000', counterText: ''),
                    onSubmitted: (_) => submit(),
                  ),
                ),
              ] else ...[
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: name,
                        decoration: const InputDecoration(labelText: '長輩姓名'),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: birthday,
                        decoration: const InputDecoration(labelText: '出生日期', hintText: '1948-03-15'),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: last4,
                        maxLength: 4,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: '身分證末四碼', counterText: ''),
                        onSubmitted: (_) => submit(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _InfoBox(
                  icon: Icons.shield_outlined,
                  text:
                      '為保護長輩，系統不會告訴您是否找到這個人。資料正確時，長輩手機才會收到通知。'
                      '每 10 分鐘最多查找 5 次，每次查找都會留下紀錄，長輩本人也看得到。',
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: busy || serviceId == null ? null : submit,
                style: FilledButton.styleFrom(
                  backgroundColor: TPColors.primary500,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.send_rounded),
                label: const Text('送出協助請求', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHeader(title: '發起新的協辦', subtitle: '選擇業務、找到長輩。長輩在自己的手機上同意後，您就能一步一步帶著他完成申辦。'),
          const SizedBox(height: 32),
          if (widget.narrow) ...[
            form,
            const SizedBox(height: 24),
            const _SafetyRules(),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: form),
                const SizedBox(width: 28),
                const SizedBox(width: 340, child: _SafetyRules()),
              ],
            ),
        ],
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.n, required this.text});
  final int n;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 14,
        backgroundColor: TPColors.primary500,
        child: Text(
          '$n',
          style: const TextStyle(color: TPColors.white, fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(width: 10),
      Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
    ],
  );
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.s, required this.selected, required this.onTap});
  final Map<String, dynamic> s;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? TPColors.primary500 : Colors.transparent, width: 2),
        ),
        child: TPCard(
          onTap: onTap,
          padding: const EdgeInsets.all(20),
          color: selected ? TPColors.primary50 : TPColors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusPill(s['category'] as String, color: TPColors.primary700, background: TPColors.primary100),
                  const Spacer(),
                  Icon(
                    selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: selected ? TPColors.primary500 : TPColors.grayscale200,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(s['title'] as String, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                s['summary'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: TPColors.grayscale600, height: 1.5),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 15, color: TPColors.grayscale500),
                  const SizedBox(width: 4),
                  Text('約 ${s['estMinutes']} 分鐘', style: const TextStyle(fontSize: 12, color: TPColors.grayscale500)),
                  const SizedBox(width: 14),
                  const Icon(Icons.lock_outline_rounded, size: 15, color: TPColors.grayscale500),
                  const SizedBox(width: 4),
                  Text(
                    '${s['sensitiveFieldCount']} 項個資需長輩授權',
                    style: const TextStyle(fontSize: 12, color: TPColors.grayscale500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.text,
    this.color = TPColors.primary700,
    this.bg = TPColors.primary50,
  });
  final IconData icon;
  final String text;
  final Color color;
  final Color bg;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: color, height: 1.6, fontSize: 14)),
        ),
      ],
    ),
  );
}

class _SafetyRules extends StatelessWidget {
  const _SafetyRules();
  @override
  Widget build(BuildContext context) {
    const rules = [
      (Icons.visibility_off_rounded, '您看不到長輩個資的內容', '只會看到「已授權／未授權」等狀態，這是刻意的設計。'),
      (Icons.touch_app_rounded, '授權與送出只有長輩能按', '請引導長輩自己看、自己按，不要拿長輩的手機代按。'),
      (Icons.power_settings_new_rounded, '長輩隨時可以結束', '長輩按「結束協助」後，您這邊會立即失效。'),
      (Icons.link_rounded, '所有操作都有不可竄改的紀錄', '每一步都寫入雜湊鏈稽核紀錄，長輩也能查看。'),
      (Icons.money_off_rounded, '絕不要求轉帳、密碼或驗證碼', '流程中沒有任何步驟需要這些資料。'),
    ];
    return TPCard(
      color: TPColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_rounded, color: TPColors.primary500),
              SizedBox(width: 8),
              Text('協辦安全守則', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 18),
          for (final r in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: TPColors.primary50, borderRadius: BorderRadius.circular(10)),
                    child: Icon(r.$1, size: 18, color: TPColors.primary600),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(r.$3, style: const TextStyle(fontSize: 13, color: TPColors.grayscale600, height: 1.5)),
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

// ───────────────────────────── 等待長輩回應

class _WaitingView extends StatelessWidget {
  const _WaitingView({required this.c, required this.s});
  final HelperController c;
  final AssistSession s;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: TPCard(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Pulse(),
              const SizedBox(height: 28),
              Text('等待 ${s.elderDisplayName} 回應', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text('「${s.serviceTitle}」的協助請求已送出', style: const TextStyle(fontSize: 16, color: TPColors.grayscale600)),
              const SizedBox(height: 24),
              EverySecond(
                builder: (_, now) => Text(
                  mmss(s.expiresAt!.difference(now)),
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w600,
                    color: TPColors.primary600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const Text('後請求自動失效', style: TextStyle(color: TPColors.grayscale500)),
              const SizedBox(height: 24),
              const _InfoBox(icon: Icons.phone_iphone_rounded, text: '請長輩看手機上的台北通。畫面會顯示您的姓名與身分，由長輩自己決定要不要接受協助。'),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => c.end().catchError((e) {
                  if (context.mounted) showApiError(context, e);
                }),
                child: const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text('取消請求')),
              ),
            ],
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
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();
  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: AnimatedBuilder(
        animation: a,
        builder: (_, _) => Stack(
          alignment: Alignment.center,
          children: [
            for (final d in [0.0, 0.5])
              Opacity(
                opacity: (1 - ((a.value + d) % 1)).clamp(0, 1),
                child: Container(
                  width: 60 + 60 * ((a.value + d) % 1),
                  height: 60 + 60 * ((a.value + d) % 1),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: TPColors.primary200),
                ),
              ),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: TPColors.brandGradient),
              child: const Icon(Icons.phone_iphone_rounded, color: TPColors.white, size: 32),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── 同步導覽主控台

class _SessionConsole extends StatelessWidget {
  const _SessionConsole({required this.c, required this.s, required this.narrow});
  final HelperController c;
  final AssistSession s;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final def = c.serviceDefs[s.serviceId];
    if (def == null) return const Center(child: CircularProgressIndicator());
    final step = def.steps[s.currentStep];

    Future<void> run(Future<void> Function() f) async {
      try {
        await f();
      } catch (e) {
        if (context.mounted) showApiError(context, e);
      }
    }

    return LayoutBuilder(
      builder: (context, box) {
        final tight = box.maxWidth < 820;
        final narrow = this.narrow || box.maxWidth < 1100;
        return Column(
          children: [
            // ── 頂部列
            Container(
              padding: EdgeInsets.fromLTRB(tight ? 20 : 32, 20, tight ? 16 : 32, 20),
              decoration: const BoxDecoration(
                color: TPColors.white,
                border: Border(bottom: BorderSide(color: TPColors.grayscale100)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: TPColors.brandGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.handshake_rounded, color: TPColors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                s.serviceTitle,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 10),
                            StatusPill.forSession(s),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '協助對象：${s.elderDisplayName}　·　受理機關：${def.agency}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: TPColors.grayscale600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (!tight)
                    EverySecond(
                      builder: (_, now) => Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '已進行 ${mmss(now.difference(s.startedAt ?? now))}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            '閒置 ${mmss(now.difference(s.lastActivityAt ?? now))}／30:00 自動結束',
                            style: const TextStyle(
                              fontSize: 12,
                              color: TPColors.grayscale500,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 12),
                  if (tight)
                    IconButton.outlined(
                      tooltip: '結束協助',
                      onPressed: () => run(() => c.end()),
                      color: TPColors.red600,
                      icon: const Icon(Icons.power_settings_new_rounded),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => run(() => c.end()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TPColors.red600,
                        side: const BorderSide(color: TPColors.red200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                      label: const Text('結束協助'),
                    ),
                ],
              ),
            ),
            // ── 主體
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!tight)
                    SizedBox(
                      width: 240,
                      child: _StepRail(def: def, s: s, onTap: (i) => run(() => c.gotoStep(i))),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(tight ? 20 : 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (tight) ...[_StepChips(def: def, s: s), const SizedBox(height: 18)],
                          _CurrentStepCard(c: c, s: s, def: def, step: step, run: run, tight: tight),
                          if (narrow) ...[
                            const SizedBox(height: 20),
                            _ScriptCard(step: step),
                            const SizedBox(height: 20),
                            _TimelineCard(s: s),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (!narrow)
                    Container(
                      width: 340,
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: TPColors.grayscale100)),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _ScriptCard(step: step),
                          const SizedBox(height: 20),
                          _TimelineCard(s: s),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 窄版時取代左側步驟欄
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
          Builder(
            builder: (_) {
              final fields = def.steps[i].fields;
              final done = fields.isEmpty ? i < s.currentStep : fields.every((f) => s.field(f.key).done);
              final current = i == s.currentStep;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: current ? TPColors.primary500 : (done ? TPColors.green50 : TPColors.white),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: current ? TPColors.primary500 : TPColors.grayscale100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (done && !current) const Icon(Icons.check_rounded, size: 14, color: TPColors.green700),
                    if (done && !current) const SizedBox(width: 4),
                    Text(
                      '${i + 1} ${def.steps[i].title}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                        color: current ? TPColors.white : (done ? TPColors.green700 : TPColors.grayscale600),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _StepRail extends StatelessWidget {
  const _StepRail({required this.def, required this.s, required this.onTap});
  final ServiceDef def;
  final AssistSession s;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TPColors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              '申辦步驟',
              style: TextStyle(fontSize: 13, color: TPColors.grayscale500, fontWeight: FontWeight.w600),
            ),
          ),
          for (var i = 0; i < def.steps.length; i++) _stepTile(i, def.steps[i]),
        ],
      ),
    );
  }

  Widget _stepTile(int i, StepDef step) {
    final current = i == s.currentStep;
    final fields = step.fields;
    final done = fields.where((f) => s.field(f.key).done).length;
    final complete = fields.isEmpty ? i < s.currentStep : done == fields.length;
    final locked = s.pendingAuth != null || s.isReviewing;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: current ? TPColors.primary50 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: locked || current ? null : () => onTap(i),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: complete ? TPColors.green500 : (current ? TPColors.primary500 : TPColors.white),
                    border: Border.all(
                      color: complete ? TPColors.green500 : (current ? TPColors.primary500 : TPColors.grayscale200),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: complete
                      ? const Icon(Icons.check_rounded, size: 16, color: TPColors.white)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: current ? TPColors.white : TPColors.grayscale500,
                            fontSize: 13,
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
                          fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                          color: current ? TPColors.primary800 : TPColors.grayscale800,
                        ),
                      ),
                      if (fields.isNotEmpty)
                        Text(
                          '$done／${fields.length} 項完成',
                          style: const TextStyle(fontSize: 12, color: TPColors.grayscale500),
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
}

class _CurrentStepCard extends StatelessWidget {
  const _CurrentStepCard({
    required this.c,
    required this.s,
    required this.def,
    required this.step,
    required this.run,
    this.tight = false,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '第 ${s.currentStep + 1} 步，共 ${def.steps.length} 步',
          style: const TextStyle(color: TPColors.primary600, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(step.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
        const SizedBox(height: 18),
        // 長輩畫面預覽
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TPColors.secondary50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TPColors.secondary200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.phone_iphone_rounded, color: TPColors.secondary700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '長輩手機上現在顯示',
                      style: TextStyle(fontSize: 12, color: TPColors.secondary700, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '「${step.elderGuide}」',
                      style: const TextStyle(fontSize: 17, height: 1.6, color: TPColors.secondary800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (s.isReviewing)
          const _InfoBox(
            icon: Icons.hourglass_top_rounded,
            color: TPColors.secondary800,
            bg: TPColors.secondary100,
            text: '長輩正在手機上檢查所有資料。送出鍵只有長輩能按，請耐心等候，必要時口頭協助說明。',
          )
        else if (step.fields.isEmpty)
          const TPCard(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.record_voice_over_rounded, color: TPColors.primary500),
                SizedBox(width: 12),
                Expanded(child: Text('這一步沒有需要填寫的欄位。請依「建議您這樣說」向長輩說明，再按「下一步」。')),
              ],
            ),
          )
        else
          TPCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < step.fields.length; i++) ...[
                  if (i > 0) const Divider(),
                  _FieldRow(c: c, s: s, f: step.fields[i], run: run, tight: tight),
                ],
              ],
            ),
          ),
        const SizedBox(height: 28),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: s.currentStep == 0 || waitingAuth || s.isReviewing
                  ? null
                  : () => run(() => c.gotoStep(s.currentStep - 1)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('上一步'),
            ),
            const Spacer(),
            if (waitingAuth && !tight)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Text('等待長輩回應授權中…', style: TextStyle(color: TPColors.secondary700)),
              ),
            if (!last)
              FilledButton.icon(
                onPressed: waitingAuth ? null : () => run(() => c.gotoStep(s.currentStep + 1)),
                style: FilledButton.styleFrom(
                  backgroundColor: TPColors.primary500,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                ),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(tight ? '下一步' : '下一步（長輩畫面同步翻頁）', style: const TextStyle(fontWeight: FontWeight.w600)),
              )
            else if (!s.isReviewing)
              FilledButton.icon(
                onPressed: waitingAuth ? null : () => run(c.requestSubmit),
                style: FilledButton.styleFrom(
                  backgroundColor: TPColors.green500,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                ),
                icon: const Icon(Icons.fact_check_rounded),
                label: const Text('請長輩確認送出', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.c, required this.s, required this.f, required this.run, this.tight = false});
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

    final iconBox = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: f.sensitive ? (f.riskLevel == 'high' ? TPColors.red50 : TPColors.secondary50) : TPColors.primary50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        f.sensitive ? Icons.lock_rounded : Icons.touch_app_rounded,
        size: 20,
        color: f.sensitive ? (f.riskLevel == 'high' ? TPColors.red500 : TPColors.secondary700) : TPColors.primary600,
      ),
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(f.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            if (f.sensitive && f.riskLevel == 'high')
              const StatusPill('高敏感個資', color: TPColors.red600, background: TPColors.red50, fontSize: 11)
            else if (f.sensitive)
              const StatusPill('個資', color: TPColors.secondary700, background: TPColors.secondary100, fontSize: 11)
            else
              const StatusPill('長輩自選', color: TPColors.primary700, background: TPColors.primary100, fontSize: 11),
          ],
        ),
        const SizedBox(height: 6),
        if (f.sensitive)
          Row(
            children: [
              const Text('●●●●●●', style: TextStyle(color: TPColors.grayscale300, letterSpacing: 2)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  st.status == 'authorized' ? '已由長輩提供，內容僅長輩與受理機關可見' : '用途：${f.purpose ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: TPColors.grayscale500, height: 1.4),
                ),
              ),
            ],
          )
        else
          Text(
            st.value == null ? '請長輩在手機上選擇' : '長輩選了：${f.optionLabel(st.value)}',
            style: TextStyle(fontSize: 14, color: st.value == null ? TPColors.grayscale500 : TPColors.grayscale800),
          ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: focused ? '取消在長輩畫面上的標示' : '在長輩畫面上標示這個欄位',
          child: IconButton.outlined(
            onPressed: s.pendingAuth != null ? null : () => run(() => c.focusField(focused ? null : f.key)),
            isSelected: focused,
            selectedIcon: const Icon(Icons.highlight_alt_rounded),
            icon: const Icon(Icons.highlight_alt_outlined),
          ),
        ),
        if (f.sensitive) ...[
          const SizedBox(width: 8),
          FilledButton(
            onPressed: canRequest && remaining > 0 ? () => run(() => c.requestField(f.key)) : null,
            style: FilledButton.styleFrom(
              backgroundColor: TPColors.primary500,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            child: Text(
              st.status == 'authorized'
                  ? '已授權'
                  : remaining == 0
                  ? '已達詢問上限'
                  : st.status == 'denied'
                  ? '再次詢問（剩 $remaining 次）'
                  : '請長輩授權',
            ),
          ),
        ],
      ],
    );

    final pill = StatusPill.forField(st, sensitive: f.sensitive);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: focused ? TPColors.primary50 : Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: tight ? 16 : 22, vertical: 18),
      child: tight
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    iconBox,
                    const SizedBox(width: 12),
                    Expanded(child: info),
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: [pill, const Spacer(), actions]),
              ],
            )
          : Row(
              children: [
                iconBox,
                const SizedBox(width: 16),
                Expanded(child: info),
                const SizedBox(width: 12),
                pill,
                const SizedBox(width: 12),
                actions,
              ],
            ),
    );
  }
}

class _ScriptCard extends StatelessWidget {
  const _ScriptCard({required this.step});
  final StepDef step;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: TPColors.brandGradient, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.record_voice_over_rounded, color: TPColors.white, size: 20),
              SizedBox(width: 8),
              Text(
                '建議您這樣說',
                style: TextStyle(color: TPColors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(step.helperScript, style: const TextStyle(color: TPColors.white, fontSize: 15, height: 1.7)),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.s});
  final AssistSession s;
  @override
  Widget build(BuildContext context) {
    final items = s.timeline.reversed.toList();
    return TPCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('即時動態', size: 16),
          const SizedBox(height: 14),
          for (final t in items.take(12))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: switch (t.actor) {
                        'elder' => TPColors.secondary500,
                        'helper' => TPColors.primary500,
                        _ => TPColors.grayscale300,
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t.text, style: const TextStyle(fontSize: 13, height: 1.5))),
                  const SizedBox(width: 8),
                  Text(hms(t.ts), style: const TextStyle(fontSize: 12, color: TPColors.grayscale400)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────── 結束畫面

class _ResultView extends StatelessWidget {
  const _ResultView({required this.c, required this.s});
  final HelperController c;
  final AssistSession s;

  @override
  Widget build(BuildContext context) {
    final ok = s.status == 'completed';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: TPCard(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(shape: BoxShape.circle, color: ok ? TPColors.green50 : TPColors.grayscale50),
                child: Icon(
                  ok ? Icons.check_rounded : Icons.info_outline_rounded,
                  size: 44,
                  color: ok ? TPColors.green500 : TPColors.grayscale500,
                ),
              ),
              const SizedBox(height: 20),
              Text(ok ? '長輩已完成送出' : statusLabel(s), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('${s.serviceTitle}　·　${s.elderDisplayName}', style: const TextStyle(color: TPColors.grayscale600)),
              if (ok) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(color: TPColors.primary50, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      const Text('案件編號', style: TextStyle(fontSize: 13, color: TPColors.primary700)),
                      const SizedBox(height: 4),
                      SelectableText(
                        s.caseNo ?? '',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                          color: TPColors.primary800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '長輩的個資已直接送到受理機關，這次協辦的連線紀錄中不保留任何個資。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: TPColors.grayscale500, height: 1.6),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => c.focus(null),
                style: FilledButton.styleFrom(
                  backgroundColor: TPColors.primary500,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                ),
                child: const Text('開始新的協辦'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════ 紀錄頁

class _HistoryView extends StatelessWidget {
  const _HistoryView({required this.c, required this.onOpen});
  final HelperController c;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final list = c.sortedSessions;
    return ListView(
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 40),
      children: [
        const _PageHeader(title: '協辦紀錄', subtitle: '您發起過的所有協辦。長輩姓名一律遮蔽顯示。'),
        const SizedBox(height: 24),
        if (list.isEmpty)
          const TPCard(child: Text('還沒有任何協辦紀錄。'))
        else
          TPCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) const Divider(),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    onTap: () => onOpen(list[i].id),
                    leading: CircleAvatar(
                      backgroundColor: TPColors.primary50,
                      child: Icon(
                        list[i].method == 'identity' ? Icons.badge_outlined : Icons.qr_code_2_rounded,
                        color: TPColors.primary600,
                      ),
                    ),
                    title: Text(
                      '${list[i].serviceTitle}　·　${list[i].elderDisplayName}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${ymdhm(list[i].createdAt)}　${list[i].method == 'identity' ? '身分資料查找' : '配對碼'}'
                      '${list[i].caseNo != null ? '　案件 ${list[i].caseNo}' : ''}',
                    ),
                    trailing: StatusPill.forSession(list[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _AuditView extends StatelessWidget {
  const _AuditView({required this.c});
  final HelperController c;

  @override
  Widget build(BuildContext context) {
    final status = c.auditStatus;
    final ok = status?['ok'] == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 40),
      children: [
        _PageHeader(
          title: '稽核紀錄',
          subtitle: '每個動作都寫入雜湊鏈（hash chain），任何一筆被修改都會被偵測出來。',
          trailing: OutlinedButton.icon(
            onPressed: c.refreshAudit,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新驗證'),
          ),
        ),
        const SizedBox(height: 24),
        if (status != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ok ? TPColors.green50 : TPColors.red50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  ok ? Icons.verified_rounded : Icons.gpp_bad_rounded,
                  color: ok ? TPColors.green500 : TPColors.red500,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ok ? '稽核鏈完整，未被竄改' : '偵測到第 ${status['brokenAt']} 筆紀錄被修改',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: ok ? TPColors.green700 : TPColors.red700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '全系統共 ${status['length']} 筆　·　最新雜湊 ${(status['headHash'] as String? ?? '').padRight(16).substring(0, 16)}…',
                        style: const TextStyle(fontSize: 13, color: TPColors.grayscale600, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        const Text('以下只列出您本人的操作。系統比對結果等內部欄位不會顯示給協助者。', style: TextStyle(color: TPColors.grayscale500, fontSize: 13)),
        const SizedBox(height: 12),
        TPCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (c.auditEntries.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('尚無紀錄')),
              for (var i = 0; i < c.auditEntries.length; i++) ...[
                if (i > 0) const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: Text(
                          '#${c.auditEntries[i]['seq']}',
                          style: const TextStyle(color: TPColors.grayscale400, fontFamily: 'monospace'),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: Text(
                          ymdhm(DateTime.fromMillisecondsSinceEpoch((c.auditEntries[i]['ts'] as num).toInt())),
                          style: const TextStyle(color: TPColors.grayscale600, fontSize: 13),
                        ),
                      ),
                      Expanded(child: Text(c.auditEntries[i]['summary'] as String)),
                      Text(
                        (c.auditEntries[i]['hash'] as String).substring(0, 12),
                        style: const TextStyle(color: TPColors.grayscale400, fontFamily: 'monospace', fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
