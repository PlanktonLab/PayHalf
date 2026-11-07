import 'dart:ui' show ImageFilter;
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:town_pass/bean/assist.dart';
import 'package:town_pass/gen/fonts.gen.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_i18n.dart';

/// 陪辦頁面共用的設計元件。
///
/// 設計原則（參考 Apple HIG）：
/// - 支援動態字型：不使用固定高度，字放大時元件跟著長高、換行。
/// - 主要動作放在底部、全寬、至少 56pt 高；兩個選擇一律上下排列，避免大字時擠壓。
/// - 破壞性動作（結束、封鎖）用紅色並以系統樣式的對話框再確認一次。
/// - 不只靠顏色傳達狀態，一律搭配圖示與文字。
abstract final class AssistColors {
  static const green50 = TPColors.green50;
  static const green500 = TPColors.green500;
  static const green700 = TPColors.green700;
  static const blue500 = Color(0xFF4B8DBF);

  static const brandGradient = LinearGradient(
    colors: [TPColors.primary500, blue500],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// 長者友善字級：基準比 iOS 預設大一級，並隨系統字型大小縮放。
abstract final class AssistText {
  static const _f = FontFamily.pingFangTC;
  static const largeTitle = TextStyle(
    fontFamily: _f,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: TPColors.grayscale900,
  );
  static const title = TextStyle(
    fontFamily: _f,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: TPColors.grayscale900,
  );
  static const headline = TextStyle(
    fontFamily: _f,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: TPColors.grayscale900,
  );
  static const body = TextStyle(fontFamily: _f, fontSize: 19, height: 1.55, color: TPColors.grayscale800);
  static const callout = TextStyle(fontFamily: _f, fontSize: 17, height: 1.5, color: TPColors.grayscale600);
  static const footnote = TextStyle(fontFamily: _f, fontSize: 15, height: 1.45, color: TPColors.grayscale500);
  static const button = TextStyle(fontFamily: _f, fontSize: 20, fontWeight: FontWeight.w600, height: 1.3);
}

extension AssistScale on BuildContext {
  /// 已經很大的展示文字（倒數、案件編號）放大上限較低，避免一個字佔滿整行。
  TextScaler get cappedScaler => MediaQuery.textScalerOf(this).clamp(maxScaleFactor: 1.6);

  double get textScale => MediaQuery.textScalerOf(this).scale(1);

  /// 無障礙大字（約 iOS「更大的字體」以上）
  bool get largeText => textScale >= 1.35;

  double iconSize(double base) => MediaQuery.textScalerOf(this).clamp(maxScaleFactor: 1.6).scale(base);

  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);
}

// ─────────────────────────────────────────── 格式

String _two(int n) => n.toString().padLeft(2, '0');

String assistMmss(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${_two(s ~/ 60)}:${_two(s % 60)}';
}

/// 給 VoiceOver 念的倒數
String assistSpokenDuration(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return s >= 60 ? trf('{0} 分 {1} 秒', [s ~/ 60, s % 60]) : trf('{0} 秒', [s]);
}

String assistYmdhm(DateTime t) => '${t.year}/${_two(t.month)}/${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';

/// 預設遮蔽個資，避免旁人（包含協助者）從旁偷看。
String assistMask(String key, String? value) {
  if (value == null || value.isEmpty) return '';
  switch (key) {
    case 'idNo':
      return value.length < 4 ? value : '${value.substring(0, 2)}•••••${value.substring(value.length - 3)}';
    case 'phone':
      final d = value.replaceAll('-', '');
      return d.length < 7 ? value : '${d.substring(0, 4)}-•••-${d.substring(d.length - 3)}';
    case 'residentAddress':
      return value.length < 6 ? value : '${value.substring(0, 6)}••••';
    case 'birthday':
      return value.length < 4 ? value : trf('{0} 年 •• 月 •• 日', [value.substring(0, 4)]);
    default:
      return value;
  }
}

IconData assistHelperIcon(String helperType) => switch (helperType) {
  'village_chief' => Icons.holiday_village_rounded,
  'official' => Icons.support_agent_rounded,
  _ => Icons.family_restroom_rounded,
};

String assistHelperDisplayName(HelperInfo h) => h.helperType == 'village_chief'
    ? trf('{0} 里長', [h.name])
    : h.helperType == 'official'
    ? trf('{0}（1999 客服）', [h.name])
    : h.name;

// ─────────────────────────────────────────── 元件

/// 陪辦頁面的字級放大上限。
///
/// 基準字級本來就比 iOS 預設大一級（內文 19pt），因此放大到 iOS「AX3」倍率（約 2.35 倍）
/// 時內文已約 45pt，相當於系統 AX4 的內文大小。再大會讓單一按鈕超過一個螢幕，反而找不到。
const double kAssistMaxTextScale = 2.35;

class AssistTextScaleCap extends StatelessWidget {
  const AssistTextScaleCap({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      MediaQuery.withClampedTextScaling(maxScaleFactor: kAssistMaxTextScale, child: child);
}

/// 每秒重繪一次，用於倒數。
class AssistTicker extends StatefulWidget {
  const AssistTicker({super.key, required this.builder});
  final Widget Function(BuildContext context, DateTime now) builder;
  @override
  State<AssistTicker> createState() => _AssistTickerState();
}

class _AssistTickerState extends State<AssistTicker> {
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, DateTime.now());
}

enum AssistButtonStyle { primary, secondary, success, destructive, plain, destructivePlain }

class AssistButton extends StatelessWidget {
  const AssistButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.style = AssistButtonStyle.primary,
    this.icon,
    this.semanticsHint,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AssistButtonStyle style;
  final IconData? icon;
  final String? semanticsHint;

  /// 大字時固定在底部並排用：不顯示圖示、單行，字太大時等比縮小
  final bool compact;

  AssistButton asCompact() =>
      AssistButton(label, key: key, onPressed: onPressed, style: style, semanticsHint: semanticsHint, compact: true);

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (style) {
      AssistButtonStyle.primary => (TPColors.primary500, TPColors.white, null),
      AssistButtonStyle.success => (AssistColors.green500, TPColors.white, null),
      AssistButtonStyle.secondary => (TPColors.white, TPColors.grayscale700, TPColors.grayscale300),
      AssistButtonStyle.destructive => (TPColors.white, TPColors.red600, TPColors.red300),
      AssistButtonStyle.plain => (Colors.transparent, TPColors.primary600, null),
      AssistButtonStyle.destructivePlain => (Colors.transparent, TPColors.red600, null),
    };
    return Semantics(
      button: true,
      hint: semanticsHint,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56, minWidth: double.infinity),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: onPressed == null && bg != Colors.transparent ? TPColors.grayscale100 : bg,
            foregroundColor: fg,
            disabledForegroundColor: TPColors.grayscale400,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: border == null ? BorderSide.none : BorderSide(color: border, width: 1.5),
            ),
          ),
          child: compact
              // 並排的兩個按鈕用同一個字級上限，確保分量相同
              ? Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5),
                    style: AssistText.button,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, size: context.iconSize(24)), const SizedBox(width: 10)],
                    Flexible(
                      child: Text(label, textAlign: TextAlign.center, style: AssistText.button),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// iOS 設定 App 風格的圓角分組卡片
class AssistCard extends StatelessWidget {
  const AssistCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color, this.border});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BoxBorder? border;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(color: color ?? TPColors.white, borderRadius: BorderRadius.circular(18), border: border),
    child: child,
  );
}

class AssistNotice extends StatelessWidget {
  const AssistNotice({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
    this.title,
  });
  final IconData icon;
  final String? title;
  final String text;
  final Color color;
  final Color background;

  factory AssistNotice.fraud() => AssistNotice(
    icon: Icons.shield_rounded,
    color: TPColors.red700,
    background: TPColors.red50,
    title: '防詐騙提醒'.tr,
    text: '市府、里長、1999 都不會要您轉帳、給密碼或簡訊驗證碼。有人這樣要求，一定是詐騙。'.tr,
  );

  @override
  Widget build(BuildContext context) {
    if (context.largeText) {
      // 大字時圖示放上面，讓文字用滿整個寬度
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(icon, color: color, size: context.iconSize(26)),
            ),
            const SizedBox(height: 6),
            if (title != null) Text(title!, style: AssistText.headline.copyWith(color: color)),
            Text(text, style: AssistText.body.copyWith(color: color)),
          ],
        ),
      );
    }
    return _row(context);
  }

  Widget _row(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(icon, color: color, size: context.iconSize(26)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) Text(title!, style: AssistText.headline.copyWith(color: color)),
              Text(text, style: AssistText.body.copyWith(color: color)),
            ],
          ),
        ),
      ],
    ),
  );
}

class AssistPill extends StatelessWidget {
  const AssistPill(this.label, {super.key, required this.color, required this.background, this.icon});
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  factory AssistPill.forField(FieldState st) => switch (st.status) {
    'authorized' => AssistPill(
      '已同意'.tr,
      color: AssistColors.green700,
      background: AssistColors.green50,
      icon: Icons.check_circle_rounded,
    ),
    'filled' => AssistPill(
      '已選擇'.tr,
      color: AssistColors.green700,
      background: AssistColors.green50,
      icon: Icons.check_circle_rounded,
    ),
    'requested' => AssistPill(
      '等您確認'.tr,
      color: TPColors.secondary800,
      background: TPColors.secondary100,
      icon: Icons.hourglass_top_rounded,
    ),
    'denied' => AssistPill('未提供'.tr, color: TPColors.red700, background: TPColors.red50, icon: Icons.block_rounded),
    _ => AssistPill(
      '尚未提供'.tr,
      color: TPColors.grayscale600,
      background: TPColors.grayscale50,
      icon: Icons.radio_button_unchecked_rounded,
    ),
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          ExcludeSemantics(
            child: Icon(icon, size: context.iconSize(16), color: color),
          ),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            style: AssistText.footnote.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class AssistHelperBadge extends StatelessWidget {
  const AssistHelperBadge({super.key, required this.helper});
  final HelperInfo helper;
  @override
  Widget build(BuildContext context) => helper.verified
      ? AssistPill(
          helper.helperType == 'official' ? '市府認證客服'.tr : '市府認證里長'.tr,
          color: AssistColors.green700,
          background: AssistColors.green50,
          icon: Icons.verified_rounded,
        )
      : AssistPill(
          '非公務人員'.tr,
          color: TPColors.secondary800,
          background: TPColors.secondary100,
          icon: Icons.info_rounded,
        );
}

class AssistHelperAvatar extends StatelessWidget {
  const AssistHelperAvatar({super.key, required this.helper, this.size = 56});
  final HelperInfo helper;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: helper.verified ? TPColors.primary100 : TPColors.secondary100,
      ),
      child: Icon(
        assistHelperIcon(helper.helperType),
        size: size * 0.55,
        color: helper.verified ? TPColors.primary600 : TPColors.secondary700,
      ),
    ),
  );
}

/// 內容可捲動、主要動作固定在底部；字型很大時，動作改放在內容最後面，避免底部按鈕擋住半個畫面。
class AssistActionLayout extends StatelessWidget {
  const AssistActionLayout({super.key, required this.content, required this.actions, this.padding});
  final List<Widget> content;
  final List<AssistButton> actions;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final pad = padding ?? const EdgeInsets.fromLTRB(20, 20, 20, 24);
    List<Widget> spaced(List<Widget> list) => [
      for (var i = 0; i < list.length; i++) ...[if (i > 0) const SizedBox(height: 10), list[i]],
    ];

    // 無障礙大字：底部只固定前兩個動作，並排、分量相同（不偏袒「同意」），單行縮放；
    // 其餘動作放在內容最後。這樣不用捲到最下面才找得到決定鍵，也不會佔掉半個畫面。
    final big = context.largeText;
    final pinned = big
        ? [
            // 等高並排
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < actions.length && i < 2; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: actions[actions.length >= 2 ? 1 - i : i].asCompact()),
                  ],
                ],
              ),
            ),
          ]
        : spaced(actions);
    final trailing = big && actions.length > 2
        ? [const SizedBox(height: 24), ...spaced(actions.sublist(2))]
        : <Widget>[];

    return Column(
      children: [
        Expanded(
          child: ListView(padding: pad, children: [...content, ...trailing]),
        ),
        Container(
          decoration: const BoxDecoration(
            color: TPColors.white,
            border: Border(top: BorderSide(color: TPColors.grayscale100)),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Column(mainAxisSize: MainAxisSize.min, children: pinned),
            ),
          ),
        ),
      ],
    );
  }
}

/// 系統樣式的確認對話框（破壞性動作用）
Future<bool> assistConfirm({
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final ok = await showCupertinoDialog<bool>(
    context: Get.context!,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title, style: const TextStyle(fontFamily: FontFamily.pingFangTC, fontSize: 19)),
      content: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(message, style: const TextStyle(fontFamily: FontFamily.pingFangTC, fontSize: 16, height: 1.45)),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('取消'.tr, style: TextStyle(fontFamily: FontFamily.pingFangTC)),
        ),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          isDefaultAction: !destructive,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel, style: const TextStyle(fontFamily: FontFamily.pingFangTC)),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<bool> assistRun(Future<void> Function() action) async {
  try {
    await action();
    return true;
  } catch (e) {
    final msg = e is AssistApiException ? e.message : '連線失敗，請稍後再試'.tr;
    Get.closeAllSnackbars();
    Get.showSnackbar(
      GetSnackBar(
        messageText: Text(msg, style: AssistText.body.copyWith(color: TPColors.white)),
        backgroundColor: TPColors.grayscale800,
        borderRadius: 14,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        snackPosition: SnackPosition.TOP,
      ),
    );
    return false;
  }
}

/// 讓長輩修改一項要送出的資料。回傳新內容；按取消回傳 null。
Future<String?> assistEditValue({required String label, required String initial}) async {
  final service = Get.find<AssistService>();
  service.editingValue = true;
  try {
    return await _showEditSheet(label, initial);
  } finally {
    service.editingValue = false;
  }
}

Future<String?> _showEditSheet(String label, String initial) {
  return showModalBottomSheet<String>(
    context: Get.context!,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TPColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => _EditValueSheet(label: label, initial: initial),
  );
}

class _EditValueSheet extends StatefulWidget {
  const _EditValueSheet({required this.label, required this.initial});
  final String label;
  final String initial;
  @override
  State<_EditValueSheet> createState() => _EditValueSheetState();
}

class _EditValueSheetState extends State<_EditValueSheet> {
  late final TextEditingController text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void save() {
    final v = text.text.trim();
    if (v.isEmpty) return;
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return AssistTextScaleCap(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text(trf('修改「{0}」', [widget.label]), style: AssistText.title)),
            const SizedBox(height: 6),
            Text('改成正確的內容。送出前，您還會再看到一次全部的資料。'.tr, style: AssistText.callout),
            const SizedBox(height: 16),
            ValueListenableBuilder(
              valueListenable: text,
              builder: (context, value, _) => TextField(
                controller: text,
                autofocus: true,
                maxLength: 100,
                minLines: 1,
                maxLines: 3,
                style: AssistText.headline,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => save(),
                decoration: InputDecoration(
                  labelText: widget.label,
                  counterText: '',
                  errorText: value.text.trim().isEmpty ? '不能是空白'.tr : null,
                  filled: true,
                  fillColor: TPColors.grayscale50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除'.tr,
                          onPressed: text.clear,
                          icon: const Icon(Icons.cancel_rounded, color: TPColors.grayscale400),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder(
              valueListenable: text,
              builder: (context, value, _) =>
                  AssistButton('改好了'.tr, icon: Icons.check_rounded, onPressed: value.text.trim().isEmpty ? null : save),
            ),
            const SizedBox(height: 10),
            AssistButton('取消'.tr, style: AssistButtonStyle.secondary, onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

/// 說明資料去哪裡：陪辦的人看不到，但會直接填進申請表交給承辦機關
String assistWhereDataGoes(String helperName, String? recipient) =>
    trf('{0} 看不到內容。這項資料會直接填進申請表，交給{1}。', [helperName, recipient ?? '承辦機關']);


/// 敏感資料：整格模糊，中間寫「點一下查看{label}」，點了才顯示；再點一下又遮起來。
/// 比「遮一半＋眼睛圖示」直覺：長輩不用猜眼睛是什麼意思。
/// 不需要遮的欄位（例如姓名）直接顯示。
class AssistRevealValue extends StatefulWidget {
  const AssistRevealValue({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.style,
    this.initiallyRevealed = false,
  });
  final String fieldKey;
  final String label;
  final String? value;
  final TextStyle style;
  final bool initiallyRevealed;
  @override
  State<AssistRevealValue> createState() => _AssistRevealValueState();
}

class _AssistRevealValueState extends State<AssistRevealValue> {
  late bool reveal = widget.initiallyRevealed;

  @override
  Widget build(BuildContext context) {
    final v = widget.value ?? '';
    if (assistMask(widget.fieldKey, v) == v) return Text(v, style: widget.style);
    return Semantics(
      button: true,
      label: reveal ? trf('{0}：{1}。點兩下遮住', [widget.label, v]) : trf('{0}已遮住。點兩下查看', [widget.label]),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => reveal = !reveal);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: double.infinity),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ImageFiltered(
                  enabled: !reveal,
                  imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9, tileMode: TileMode.decal),
                  child: Text(v, style: widget.style),
                ),
              ),
              if (!reveal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: TPColors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded, size: context.iconSize(20), color: TPColors.primary700),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          trf('點一下查看{0}', [widget.label]),
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: TPColors.primary700),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Positioned(
                  right: 0,
                  child: Text('點一下遮住'.tr, style: TextStyle(fontSize: 14, color: TPColors.grayscale500)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


/// 協助者名字；是長輩信任的人就在名字後面加一顆愛心（像社群平台的認證勾勾），不另外寫一段說明。
class AssistHelperName extends StatelessWidget {
  const AssistHelperName(
    this.helper, {
    super.key,
    required this.style,
    this.trusted = false,
    this.suffix = '',
    this.textAlign,
  });
  final HelperInfo helper;
  final TextStyle style;
  final bool trusted;
  final String suffix;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final size = (style.fontSize ?? 20) * 0.8;
    return Semantics(
      label: '${assistHelperDisplayName(helper)}${trusted ? '，您信任的人' : ''}$suffix',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: assistHelperDisplayName(helper)),
            if (trusted)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: AssistTrustedMark(size: size),
                ),
              ),
            if (suffix.isNotEmpty) TextSpan(text: suffix),
          ],
        ),
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}

/// 「信任的人」標記：白底圓圈裡一顆紅色愛心
class AssistTrustedMark extends StatelessWidget {
  const AssistTrustedMark({super.key, this.size = 18});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(size * 0.18),
    decoration: const BoxDecoration(color: TPColors.white, shape: BoxShape.circle),
    child: Icon(Icons.favorite_rounded, size: size, color: TPColors.red500),
  );
}
