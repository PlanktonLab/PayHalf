import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helper/helper_controller.dart';
import '../shared/console_kit.dart';
import '../shared/widgets.dart' show TownPassLogo, helperIcon;
import 'assist/workbench.dart';
import 'forms/form_editor.dart';
import 'forms/form_store.dart';
import 'forms/forms_home.dart';
import 'sop/quick_test.dart';
import 'web_utils.dart';

enum Section { workbench, history, audit, forms, quickTest }

/// 台北通承辦工作台：陪辦（協助長輩）與表單（建立民眾表單）共用同一個平台。
class ConsoleApp extends StatefulWidget {
  const ConsoleApp({super.key, this.compact = false, this.initial = Section.workbench});

  /// 並排示範時寬度有限，側欄改成圖示列
  final bool compact;
  final Section initial;

  @override
  State<ConsoleApp> createState() => _ConsoleAppState();
}

class _ConsoleAppState extends State<ConsoleApp> {
  final c = HelperController();
  final forms = FormStore();

  @override
  void initState() {
    super.initState();
    c.loadDemoAccounts();
    // 台北通 App 掃到長輩的 QR Code 後會開 /?as=<協助者>&code=<配對碼>#/console：
    // 直接以該協助者登入，並把配對碼填好
    final q = Uri.base.queryParameters;
    final code = q['code'];
    if (code != null && RegExp(r'^\d{6}$').hasMatch(code)) c.pendingCode = code;
    final as = q['as'];
    if (as != null && as.startsWith('helper-')) c.login(as).catchError((Object _) {});
  }

  @override
  void dispose() {
    c.dispose();
    forms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildConsoleTheme(),
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) =>
            c.loggedIn ? _Shell(c: c, forms: forms, compact: widget.compact, initial: widget.initial) : _Login(c: c),
      ),
    );
  }
}

// ═════════════════════════════════════════════ 登入

class _Login extends StatelessWidget {
  const _Login({required this.c});
  final HelperController c;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.canvas,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    _Brand(),
                    SizedBox(width: 10),
                    Text('承辦工作台', style: CText.title),
                  ],
                ),
                const SizedBox(height: 28),
                const Text('選擇示範身分', style: CText.pageTitle),
                const SizedBox(height: 6),
                const Text('正式版將以台北通實名帳號、里長名冊或市府內部帳號登入。', style: CText.secondary),
                const SizedBox(height: 20),
                if (c.accountsLoading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (c.accountsFailed)
                  CNotice(
                    tone: CTone.danger,
                    icon: Icons.cloud_off_rounded,
                    title: '連不到後端',
                    text: '請先在 assist/assist_backend 執行 npm start，再按重試。',
                    action: CButton('重試', icon: Icons.refresh_rounded, onPressed: c.loadDemoAccounts),
                  )
                else
                  CPanel(
                    padding: EdgeInsets.zero,
                    clip: true,
                    child: Column(
                      children: [
                        for (var i = 0; i < c.demoAccounts.length; i++) ...[
                          if (i > 0) const Divider(),
                          _AccountRow(c: c, a: c.demoAccounts[i]),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                const Text('里長與 1999 客服為市府認證身分，另可使用「表單」建立民眾表單。', style: CText.small),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.c, required this.a});
  final HelperController c;
  final Map<String, dynamic> a;
  @override
  Widget build(BuildContext context) {
    final verified = a['verified'] == true;
    return Semantics(
      button: true,
      label: '以 ${a['name']}（${a['title']}）登入',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => c.login(a['id'] as String).catchError((Object e) {
          if (context.mounted) showApiErr(context, e);
        }),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          child: Row(
            children: [
              CIconTile(helperIcon(a['helperType'] as String), size: 42),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(a['name'] as String, style: CText.bodyStrong),
                        verified
                            ? const CTag('市府認證', icon: Icons.verified_rounded, tone: CTone.ok)
                            : const CTag('非公務人員', tone: CTone.warn),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${a['title']}　·　${a['org'] ?? '一般台北通實名用戶'}', style: CText.small),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: C.ink4),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.size = 32});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: C.surface,
      borderRadius: BorderRadius.circular(size * 0.28),
      border: Border.all(color: C.border),
    ),
    alignment: Alignment.center,
    child: TownPassLogo(size: size * 0.5),
  );
}

// ═════════════════════════════════════════════ 外框

class _Shell extends StatefulWidget {
  const _Shell({required this.c, required this.forms, required this.compact, required this.initial});
  final HelperController c;
  final FormStore forms;
  final bool compact;
  final Section initial;
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  late Section section = widget.initial;
  String? formId;
  int formTab = 0;
  bool bigText = false;

  HelperController get c => widget.c;
  late final QuickTestState quickTest;

  @override
  void initState() {
    super.initState();
    // 一登入就開始收示範表單的回覆：測試的人可能先去手機操作，才打開「1 分鐘測試」
    quickTest = QuickTestState(c);
    // 表單存在後端：登入（或換身分）後重新載入；不是承辦人員時表單頁會說明原因
    widget.forms.attach(c);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    quickTest.dispose();
    super.dispose();
  }

  /// 單鍵切換頁面（輸入文字時不觸發）
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    final k = HardwareKeyboard.instance;
    if (k.isMetaPressed || k.isControlPressed || k.isAltPressed) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final focusCtx = FocusManager.instance.primaryFocus?.context;
    if (focusCtx != null &&
        (focusCtx.widget is EditableText || focusCtx.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return false;
    }
    final target = switch (e.logicalKey) {
      LogicalKeyboardKey.keyW => Section.workbench,
      LogicalKeyboardKey.keyR => Section.history,
      LogicalKeyboardKey.keyA => Section.audit,
      LogicalKeyboardKey.keyF => Section.forms,
      LogicalKeyboardKey.keyT => Section.quickTest,
      _ => null,
    };
    if (target == null) return false;
    go(target);
    return true;
  }

  void go(Section s) {
    setState(() {
      if (s == Section.forms && section == Section.forms) formId = null;
      section = s;
    });
    if (s == Section.audit) c.refreshAudit();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final rail = widget.compact || box.maxWidth < 1000;
        final mq = MediaQuery.of(context);
        return Scaffold(
          backgroundColor: C.canvas,
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Sidebar(
                  c: c,
                  rail: rail,
                  section: section,
                  bigText: bigText,
                  onGo: go,
                  onHelp: () => _help(context),
                  onToggleText: () => setState(() => bigText = !bigText),
                ),
                Expanded(
                  child: MediaQuery(
                    data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * (bigText ? 1.15 : 1))),
                    child: ListenableBuilder(
                      listenable: widget.forms,
                      builder: (context, _) => AnimatedSwitcher(
                        duration: mq.disableAnimations ? Duration.zero : const Duration(milliseconds: 160),
                        child: KeyedSubtree(key: ValueKey('$section-$formId'), child: _content()),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _content() {
    return switch (section) {
      Section.workbench => Workbench(c: c),
      Section.history => HistoryView(
        c: c,
        onOpen: (id) {
          c.focus(id);
          setState(() => section = Section.workbench);
        },
      ),
      Section.audit => AuditView(c: c),
      Section.quickTest => QuickTestView(
        c: c,
        state: quickTest,
        store: widget.forms,
        onOpenWorkbench: () => go(Section.workbench),
        onOpenResponses: () => setState(() {
          section = Section.forms;
          formId = kQuickTestFormId;
          formTab = 1;
        }),
      ),
      Section.forms =>
        formId == null
            ? FormsHome(
                store: widget.forms,
                onHelp: () => _help(context),
                onOpen: (id, tab) => setState(() {
                  formId = id;
                  formTab = tab;
                }),
              )
            : FormEditor(
                store: widget.forms,
                formId: formId!,
                initialTab: formTab,
                onBack: () => setState(() => formId = null),
              ),
    };
  }

  void _help(BuildContext context) {
    Widget item(IconData i, String t, String d) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CIconTile(i, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: CText.bodyStrong.copyWith(fontSize: 14)),
                Text(d, style: CText.small),
              ],
            ),
          ),
        ],
      ),
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => Theme(
        data: buildConsoleTheme(),
        child: CDialog(
          title: '怎麼使用？',
          subtitle: '同一個工作台，處理「陪長輩辦」與「建立表單」兩件事。',
          width: 520,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              item(Icons.handshake_outlined, '工作台（W）', '選業務、輸入長輩念給您的配對碼。長輩同意後，您帶著他一步一步辦，個資由長輩自己授權。'),
              item(Icons.playlist_add_check_rounded, '1 分鐘測試（T）', '照著做一遍就能測完長輩自己填、找人協助、後台收到回覆。能自動確認的步驟會自己打勾。'),
              item(Icons.history_rounded, '陪辦紀錄（R）與稽核紀錄（A）', '查看過去的陪辦，以及不可竄改的操作紀錄。'),
              if (c.isStaff) item(Icons.description_outlined, '表單（F）', '從範本建立民眾要填的表單，點題目就能修改；右側即時預覽長輩看到的畫面，沒問題就按「發布」。'),
              const SizedBox(height: 4),
              const CNotice(icon: Icons.lightbulb_outline_rounded, text: '題目用日常說話的方式寫，例如「你住在哪裡」，而不是「戶籍所在地」。系統會幫你檢查。'),
            ],
          ),
          actions: [CButton.primary('我知道了', onPressed: () => Navigator.pop(ctx))],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.c,
    required this.rail,
    required this.section,
    required this.bigText,
    required this.onGo,
    required this.onHelp,
    required this.onToggleText,
  });
  final HelperController c;
  final bool rail;
  final Section section;
  final bool bigText;
  final ValueChanged<Section> onGo;
  final VoidCallback onHelp;
  final VoidCallback onToggleText;

  @override
  Widget build(BuildContext context) {
    final me = c.me!;
    final open = c.sessions.values.where((s) => s.isOpen).length;
    final audit = c.auditStatus;

    Widget group(String t) => rail
        ? const SizedBox(height: 14)
        : Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 6),
            child: Text(t, style: CText.caption),
          );

    final identity = CMenu(
      items: [CMenuItem('切換身分', icon: Icons.swap_horiz_rounded, onTap: c.logout)],
      builder: (context, toggle) => Tooltip(
        message: rail ? '${me['name']}・切換身分' : '',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(C.rControl),
            onTap: toggle,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: rail ? 0 : 8, vertical: 8),
              child: Row(
                mainAxisAlignment: rail ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  CIconTile(helperIcon(me['helperType'] as String), size: 30),
                  if (!rail) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(me['name'] as String, style: CText.bodyStrong.copyWith(fontSize: 14)),
                          Text(me['title'] as String, overflow: TextOverflow.ellipsis, style: CText.caption),
                        ],
                      ),
                    ),
                    const Icon(Icons.unfold_more_rounded, size: 18, color: C.ink4),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Widget info(String k, Widget v) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
      child: Row(
        children: [
          Expanded(child: Text(k, style: CText.caption)),
          v,
        ],
      ),
    );

    return Container(
      width: rail ? 68 : 248,
      padding: EdgeInsets.fromLTRB(rail ? 10 : 16, 20, rail ? 10 : 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: rail ? 0 : 6),
            child: Row(
              mainAxisAlignment: rail ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                const _Brand(size: 30),
                if (!rail) ...[
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('承辦工作台', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          identity,
          if (!rail) ...[
            const SizedBox(height: 6),
            info('連線', CStatus(c.connected ? '即時' : '重新連線中', tone: c.connected ? CTone.ok : CTone.danger, size: 12)),
            if (audit != null)
              info(
                '稽核鏈',
                Text(
                  audit['ok'] == true ? '完整 · ${audit['length']} 筆' : '異常',
                  style: CText.caption.copyWith(color: C.ink2),
                ),
              ),
          ],
          group('陪辦'),
          _NavItem(
            icon: Icons.handshake_outlined,
            label: '工作台',
            kbd: 'W',
            rail: rail,
            selected: section == Section.workbench,
            badge: open,
            onTap: () => onGo(Section.workbench),
          ),
          _NavItem(
            icon: Icons.history_rounded,
            label: '陪辦紀錄',
            kbd: 'R',
            rail: rail,
            selected: section == Section.history,
            onTap: () => onGo(Section.history),
          ),
          _NavItem(
            icon: Icons.verified_user_outlined,
            label: '稽核紀錄',
            kbd: 'A',
            rail: rail,
            selected: section == Section.audit,
            onTap: () => onGo(Section.audit),
          ),
          group('表單'),
          _NavItem(
            icon: Icons.description_outlined,
            label: '我的表單',
            kbd: 'F',
            rail: rail,
            selected: section == Section.forms,
            onTap: () => onGo(Section.forms),
          ),
          group('測試'),
          _NavItem(
            icon: Icons.playlist_add_check_rounded,
            label: '1 分鐘測試',
            kbd: 'T',
            rail: rail,
            selected: section == Section.quickTest,
            onTap: () => onGo(Section.quickTest),
          ),
          const Spacer(),
          _NavItem(
            icon: Icons.phone_iphone_rounded,
            label: '長輩手機模擬',
            rail: rail,
            muted: true,
            external: true,
            onTap: () => openInNewTab('/#/elder'),
          ),
          _NavItem(icon: Icons.help_outline_rounded, label: '使用說明', rail: rail, muted: true, onTap: onHelp),
          _NavItem(
            icon: Icons.format_size_rounded,
            label: bigText ? '文字大小：大' : '文字大小：標準',
            rail: rail,
            muted: true,
            selected: bigText,
            onTap: onToggleText,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.rail,
    required this.onTap,
    this.kbd,
    this.selected = false,
    this.muted = false,
    this.external = false,
    this.badge = 0,
  });
  final IconData icon;
  final String label;
  final String? kbd;
  final bool rail;
  final bool selected;
  final bool muted;
  final bool external;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconW = Icon(icon, size: 20, color: selected ? C.accentStrong : (muted ? C.ink4 : C.ink3));
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Tooltip(
        message: rail ? (kbd == null ? label : '$label（$kbd）') : '',
        child: Semantics(
          button: true,
          selected: selected,
          label: badge > 0 ? '$label，$badge 件進行中' : label,
          excludeSemantics: true,
          child: Material(
            color: selected && !muted ? C.surface : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(C.rControl),
              side: BorderSide(color: selected && !muted ? C.border : Colors.transparent),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(C.rControl),
              onTap: onTap,
              child: SizedBox(
                height: 40,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: rail ? 0 : 10),
                  child: Row(
                    mainAxisAlignment: rail ? MainAxisAlignment.center : MainAxisAlignment.start,
                    children: [
                      Badge(isLabelVisible: rail && badge > 0, smallSize: 8, backgroundColor: C.accent, child: iconW),
                      if (!rail) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: muted ? 14 : 15,
                              fontWeight: selected && !muted ? FontWeight.w600 : FontWeight.w400,
                              color: selected ? C.ink : (muted ? C.ink3 : C.ink2),
                            ),
                          ),
                        ),
                        if (badge > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(color: C.accentSoft, borderRadius: BorderRadius.circular(99)),
                            child: Text(
                              '$badge',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.accentInk),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (external) const Icon(Icons.north_east_rounded, size: 14, color: C.ink4),
                        if (kbd != null) CKbd(kbd!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
