import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:town_pass/page/assist/assist_helper/assist_helper_view.dart';
import 'package:town_pass/page/assist/widget/assist_help_call_sheet.dart';
import 'package:town_pass/page/assist/widget/assist_scan.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_i18n.dart';

/// 「幫別人辦」：協助者的入口。
///
/// - 上方三個動作：掃 QR Code、輸入對方給的協助代碼、輸入邀請碼加好友
/// - 我的好友：把我加為「信任的人」的長輩，直接顯示台北通帳號名稱，按一下選要幫他辦什麼
/// - 可以幫忙辦的項目：申辦業務＋收件中的表單，可搜尋；按一下選要幫誰
class AssistHelpOthersView extends StatefulWidget {
  const AssistHelpOthersView({super.key});

  static Future<void> open() => Get.to(() => const AssistHelpOthersView(), routeName: '/assist_help_others') ?? Future.value();

  @override
  State<AssistHelpOthersView> createState() => _AssistHelpOthersViewState();
}

class _AssistHelpOthersViewState extends State<AssistHelpOthersView> {
  final service = Get.find<AssistService>();
  final query = TextEditingController();
  List<Map<String, dynamic>>? catalog;
  String? loadError;
  _Kind kind = _Kind.all;

  @override
  void initState() {
    super.initState();
    load();
    service.refreshHelperTrusting();
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loadError = null);
    try {
      final list = await service.serviceCatalog();
      if (mounted) setState(() => catalog = list);
    } catch (_) {
      if (mounted) setState(() => loadError = '連不上伺服器，請稍後再試'.tr);
    }
  }

  List<Map<String, dynamic>> get filtered {
    final q = query.text.trim().toLowerCase();
    return [
      for (final s in catalog ?? const <Map<String, dynamic>>[])
        if (kind == _Kind.all || (kind == _Kind.form) == _isForm(s))
          if (q.isEmpty ||
              [s['title'], s['agency'], s['category'], s['summary']].any((v) => '${v ?? ''}'.toLowerCase().contains(q)))
            s,
    ];
  }

  // ───────────────────────── 動作

  Future<void> enterAssistCode() async {
    final code = await _askCode(
      title: '輸入協助代碼'.tr,
      message: '請對方打開台北通「請人陪我辦」或表單裡的「找人幫我」，把畫面上的 6 位數號碼告訴您。'.tr,
      confirm: '開始協助'.tr,
    );
    if (code != null) await AssistHelperView.open(code: code);
  }

  Future<void> addFriend() async {
    final code = await _askCode(
      title: '加好友'.tr,
      message: '請對方打開台北通「信任的人」→「加信任的人」，把邀請碼告訴您，或直接用「掃描」掃他的 QR Code。'.tr,
      confirm: '送出好友邀請'.tr,
    );
    if (code != null) await assistAcceptTrustInvite(code);
  }

  /// 選了好友 → 選要幫他辦什麼 → 直接通知對方確認
  Future<void> helpFriend(TrustingElder e) async {
    final picked = await _pickSheet<Map<String, dynamic>>(
      title: trf('要幫 {0} 辦什麼？', [e.name]),
      builder: (ctx) => _CatalogPicker(catalog: catalog ?? const [], onPick: (s) => Navigator.of(ctx).pop(s)),
    );
    if (picked != null) await AssistHelperView.open(elderId: e.elderId, serviceId: picked['id'] as String, autoSend: true);
  }

  /// 選了項目 → 選要幫誰（好友直接送出；不是好友就用協助代碼或掃描）
  Future<void> helpWith(Map<String, dynamic> s) async {
    final id = s['id'] as String;
    final choice = await _pickSheet<String>(
      title: trf('要幫誰辦「{0}」？', [s['title']]),
      builder: (ctx) => _PersonPicker(onPick: (v) => Navigator.of(ctx).pop(v)),
    );
    if (choice == null) return;
    if (choice == _PersonPicker.scan) {
      await assistScan();
    } else if (choice == _PersonPicker.code) {
      final code = await _askCode(
        title: '輸入協助代碼'.tr,
        message: '請對方打開台北通「請人陪我辦」，把畫面上的 6 位數號碼告訴您。'.tr,
        confirm: '開始協助'.tr,
      );
      if (code != null) await AssistHelperView.open(code: code, serviceId: id);
    } else {
      await AssistHelperView.open(elderId: choice, serviceId: id, autoSend: true);
    }
  }

  Future<T?> _pickSheet<T>({required String title, required WidgetBuilder builder}) => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TPColors.grayscale50,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => AssistTextScaleCap(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => _SheetFrame(title: title, scroll: scroll, child: builder(ctx)),
      ),
    ),
  );

  // ───────────────────────── 畫面

  @override
  Widget build(BuildContext context) {
    final me = AssistService.helperAccounts.firstWhereOrNull((a) => a.id == service.helperId.value);
    final list = filtered;
    return AssistTextScaleCap(
      child: Scaffold(
        backgroundColor: TPColors.grayscale50,
        appBar: TPAppBar(title: '幫別人辦'.tr),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([load(), service.refreshHelperTrusting()]);
            },
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverList.list(
                    children: [
                      if (me != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Icon(Icons.badge_outlined, size: context.iconSize(18), color: TPColors.grayscale500),
                              const SizedBox(width: 6),
                              Expanded(child: Text(trf('以「{0}」（{1}）的身分幫忙', [me.name, me.note]), style: AssistText.footnote)),
                            ],
                          ),
                        ),
                      _QuickActions(onScan: assistScan, onCode: enterAssistCode, onAddFriend: addFriend),
                      Obx(() {
                        final calls = service.helpForMe.toList();
                        if (calls.isEmpty) return const SizedBox(height: 4);
                        return Column(
                          children: [
                            const SizedBox(height: 16),
                            for (final r in calls) ...[
                              _CallBanner(
                                name: r.elderName,
                                what: r.serviceTitle,
                                onTap: () => AssistHelpCallSheet.go(r.elderId, r.serviceId),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        );
                      }),
                      const SizedBox(height: 20),
                      Obx(() => _Header('我的好友'.tr, count: service.helperTrusting.length)),
                      Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text('這些人把您加為「信任的人」，可以直接幫他們辦，不用再要代碼。'.tr, style: AssistText.footnote),
                      ),
                      Obx(() {
                        final friends = service.helperTrusting.toList();
                        if (friends.isEmpty) {
                          return _Empty(
                            icon: Icons.group_add_rounded,
                            text: '還沒有好友。請對方在台北通「信任的人」產生邀請碼，再按上面「加好友」。'.tr,
                            action: '加好友'.tr,
                            onAction: addFriend,
                          );
                        }
                        return _Group(
                          children: [for (final e in friends) _FriendRow(e: e, onTap: () => helpFriend(e))],
                        );
                      }),
                      const SizedBox(height: 24),
                      _Header('可以幫忙辦的項目'.tr, count: catalog?.length),
                      const SizedBox(height: 4),
                      _SearchField(controller: query, onChanged: (_) => setState(() {})),
                      const SizedBox(height: 10),
                      _KindTabs(
                        value: kind,
                        counts: {
                          for (final k in _Kind.values)
                            k: (catalog ?? const []).where((s) => k == _Kind.all || (k == _Kind.form) == _isForm(s)).length,
                        },
                        onChanged: (k) => setState(() => kind = k),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                if (catalog == null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: loadError == null
                            ? const CircularProgressIndicator()
                            : Column(
                                children: [
                                  Text(loadError!, style: AssistText.callout),
                                  TextButton(onPressed: load, child: Text('再試一次'.tr)),
                                ],
                              ),
                      ),
                    ),
                  )
                else if (list.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: _Empty(icon: Icons.search_off_rounded, text: trf('找不到「{0}」，換個關鍵字試試看。', [query.text.trim()])),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _CatalogRow(s: list[i], onTap: () => helpWith(list[i])),
                    ),
                  ),
                SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Kind { all, form, service }

bool _isForm(Map<String, dynamic> s) => (s['id'] as String).startsWith('form-');

/// 6 位數代碼輸入框
Future<String?> _askCode({required String title, required String message, required String confirm}) async {
  final code = await Get.dialog<String>(_CodeDialog(title: title, message: message, confirm: confirm));
  return code != null && RegExp(r'^\d{6}$').hasMatch(code) ? code : null;
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog({required this.title, required this.message, required this.confirm});
  final String title;
  final String message;
  final String confirm;
  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  bool get ok => controller.text.length == 6;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message, style: const TextStyle(fontSize: 15, height: 1.5, color: TPColors.grayscale600)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, letterSpacing: 8, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(hintText: '000000', counterText: ''),
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) => ok ? Get.back(result: v.trim()) : null,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text('取消'.tr)),
        FilledButton(onPressed: ok ? () => Get.back(result: controller.text.trim()) : null, child: Text(widget.confirm)),
      ],
    );
  }
}

// ───────────────────────── 元件

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onScan, required this.onCode, required this.onAddFriend});
  final VoidCallback onScan;
  final VoidCallback onCode;
  final VoidCallback onAddFriend;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _ActionTile(icon: Icons.qr_code_scanner_rounded, label: '掃描\nQR Code'.tr, onTap: onScan, primary: true),
      _ActionTile(icon: Icons.pin_outlined, label: '輸入\n協助代碼'.tr, onTap: onCode),
      _ActionTile(icon: Icons.person_add_alt_1_rounded, label: '加好友'.tr, onTap: onAddFriend),
    ];
    if (context.largeText) {
      return Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const SizedBox(height: 8), tiles[i]],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: tiles[i])],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? TPColors.white : TPColors.primary600;
    final row = context.largeText;
    final iconBox = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(shape: BoxShape.circle, color: primary ? Colors.white24 : TPColors.primary50),
      child: Icon(icon, color: fg, size: context.iconSize(26)),
    );
    final text = Text(
      row ? label.replaceAll('\n', '') : label,
      textAlign: row ? TextAlign.start : TextAlign.center,
      style: AssistText.callout.copyWith(
        color: primary ? TPColors.white : TPColors.grayscale800,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
    );
    return Semantics(
      button: true,
      label: label.replaceAll('\n', ''),
      excludeSemantics: true,
      child: Material(
        color: primary ? TPColors.primary500 : TPColors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: row
                ? Row(children: [iconBox, const SizedBox(width: 14), Expanded(child: text)])
                : Column(mainAxisSize: MainAxisSize.min, children: [iconBox, const SizedBox(height: 10), text]),
          ),
        ),
      ),
    );
  }
}

class _CallBanner extends StatelessWidget {
  const _CallBanner({required this.name, required this.what, required this.onTap});
  final String name;
  final String? what;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: TPColors.secondary50,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TPColors.secondary300, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: TPColors.secondary700, size: context.iconSize(26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trf('{0} 正在找您幫忙', [name]), style: AssistText.headline.copyWith(fontSize: 18)),
                  if (what != null) Text(what!, style: AssistText.footnote),
                ],
              ),
            ),
            Text('去幫忙'.tr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: TPColors.secondary700)),
            const Icon(Icons.chevron_right_rounded, color: TPColors.secondary700),
          ],
        ),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header(this.text, {this.count});
  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(text, style: AssistText.title.copyWith(fontSize: 22)),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 8),
            Text('$count', style: AssistText.callout.copyWith(color: TPColors.grayscale400)),
          ],
        ],
      ),
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: TPColors.white, borderRadius: BorderRadius.circular(16)),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 72, color: TPColors.grayscale100),
          children[i],
        ],
      ],
    ),
  );
}

class _Initial extends StatelessWidget {
  const _Initial(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: TPColors.primary100),
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: TPColors.primary700),
      ),
    ),
  );
}

String _ymd(DateTime t) => '${t.year}/${t.month}/${t.day}';

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.e, required this.onTap});
  final TrustingElder e;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _Initial(e.name),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, style: AssistText.headline.copyWith(fontSize: 19)),
                Text(
                  [
                    if (e.account != null) trf('台北通帳號 {0}', [e.account]),
                    if (e.since != null) trf('{0} 加入', [_ymd(e.since!)]),
                  ].join('・'),
                  style: AssistText.footnote.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: TPColors.primary50, borderRadius: BorderRadius.circular(99)),
            child: Text('幫他辦'.tr, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: TPColors.primary700)),
          ),
        ],
      ),
    ),
  );
}

class _SearchField extends StatelessWidget {
  _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    style: AssistText.body.copyWith(fontSize: 18),
    decoration: InputDecoration(
      hintText: '搜尋表單、業務或機關'.tr,
      hintStyle: AssistText.body.copyWith(fontSize: 18, color: TPColors.grayscale400),
      prefixIcon: Icon(Icons.search_rounded, color: TPColors.grayscale400),
      suffixIcon: controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: '清除'.tr,
              icon: Icon(Icons.cancel_rounded, color: TPColors.grayscale300),
              onPressed: () {
                controller.clear();
                onChanged('');
              },
            ),
      filled: true,
      fillColor: TPColors.white,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: TPColors.primary500, width: 2),
      ),
    ),
  );
}

class _KindTabs extends StatelessWidget {
  _KindTabs({required this.value, required this.counts, required this.onChanged});
  final _Kind value;
  final Map<_Kind, int> counts;
  final ValueChanged<_Kind> onChanged;

  static Map<_Kind, String> get _labels => {_Kind.all: '全部'.tr, _Kind.form: '表單'.tr, _Kind.service: '申辦業務'.tr};

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final k in _Kind.values)
        ChoiceChip(
          label: Text('${_labels[k]} ${counts[k] ?? 0}'),
          selected: value == k,
          onSelected: (_) {
            HapticFeedback.selectionClick();
            onChanged(k);
          },
          showCheckmark: false,
          labelStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: value == k ? TPColors.white : TPColors.grayscale700,
          ),
          selectedColor: TPColors.primary500,
          backgroundColor: TPColors.white,
          side: BorderSide(color: value == k ? TPColors.primary500 : TPColors.grayscale200),
          shape: const StadiumBorder(),
        ),
    ],
  );
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({required this.s, required this.onTap, this.dense = false});
  final Map<String, dynamic> s;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final form = _isForm(s);
    final sub = [
      if ('${s['agency'] ?? ''}'.isNotEmpty) s['agency'],
      if (s['estMinutes'] != null) trf('約 {0} 分鐘', [s['estMinutes']]),
    ].join('・');
    return Material(
      color: TPColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: dense ? 10 : 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: form ? TPColors.secondary50 : TPColors.primary50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  form ? Icons.description_outlined : Icons.assignment_ind_outlined,
                  color: form ? TPColors.secondary700 : TPColors.primary600,
                  size: context.iconSize(24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s['title']}', style: AssistText.headline.copyWith(fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(
                      [form ? '表單'.tr : '申辦業務'.tr, if (sub.isNotEmpty) sub].join('・'),
                      style: AssistText.footnote.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: TPColors.grayscale300),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text, this.action, this.onAction});
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: TPColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: TPColors.grayscale100),
    ),
    child: Row(
      children: [
        Icon(icon, color: TPColors.grayscale400, size: context.iconSize(28)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: AssistText.callout.copyWith(fontSize: 16))),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.scroll, required this.child});
  final String title;
  final ScrollController scroll;
  final Widget child;

  @override
  Widget build(BuildContext context) => PrimaryScrollController(
    controller: scroll,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 5,
            decoration: BoxDecoration(color: TPColors.grayscale300, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
          child: Row(
            children: [
              Expanded(child: Text(title, style: AssistText.title.copyWith(fontSize: 22))),
              IconButton(tooltip: '關閉'.tr, onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}

/// 幫好友辦：可搜尋的項目清單
class _CatalogPicker extends StatefulWidget {
  const _CatalogPicker({required this.catalog, required this.onPick});
  final List<Map<String, dynamic>> catalog;
  final ValueChanged<Map<String, dynamic>> onPick;
  @override
  State<_CatalogPicker> createState() => _CatalogPickerState();
}

class _CatalogPickerState extends State<_CatalogPicker> {
  final query = TextEditingController();

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = query.text.trim().toLowerCase();
    final list = [
      for (final s in widget.catalog)
        if (q.isEmpty || [s['title'], s['agency'], s['category']].any((v) => '${v ?? ''}'.toLowerCase().contains(q))) s,
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _SearchField(controller: query, onChanged: (_) => setState(() {})),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('找不到符合的項目'.tr, style: AssistText.callout))
              : ListView.separated(
                  primary: true,
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.paddingOf(context).bottom),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _CatalogRow(s: list[i], dense: true, onTap: () => widget.onPick(list[i])),
                ),
        ),
      ],
    );
  }
}

/// 幫某個項目：選好友，或用協助代碼／掃描找不是好友的人
class _PersonPicker extends StatelessWidget {
  const _PersonPicker({required this.onPick});
  final ValueChanged<String> onPick;

  static const scan = '__scan__';
  static const code = '__code__';

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    return Obx(() {
      final friends = service.helperTrusting.toList();
      return ListView(
        primary: true,
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.paddingOf(context).bottom),
        children: [
          if (friends.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('好友・選了就會通知對方確認'.tr, style: AssistText.footnote),
            ),
            _Group(children: [for (final e in friends) _FriendRow(e: e, onTap: () => onPick(e.elderId))]),
            const SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('對方不是好友'.tr, style: AssistText.footnote),
            ),
          ],
          _Group(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                leading: const Icon(Icons.pin_outlined, color: TPColors.primary600),
                title: Text('輸入對方的協助代碼'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                subtitle: Text('對方在「請人陪我辦」看到的 6 位數號碼'.tr),
                onTap: () => onPick(code),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                leading: const Icon(Icons.qr_code_scanner_rounded, color: TPColors.primary600),
                title: Text('掃描對方的 QR Code'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                subtitle: Text('對方在旁邊時最快'.tr),
                onTap: () => onPick(scan),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AssistNotice(
            icon: Icons.shield_outlined,
            color: TPColors.primary700,
            background: TPColors.primary50,
            text: '您看不到對方的身分證、地址、電話。每一項資料都要對方自己同意，最後也只有對方能按送出。'.tr,
          ),
        ],
      );
    });
  }
}
