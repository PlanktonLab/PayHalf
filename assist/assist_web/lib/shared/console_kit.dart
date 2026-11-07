import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tp_colors.dart';

/// 承辦工作台的設計語言：
/// 以灰階劃分區塊與資訊層級，台北通主題色只用在「需要被注意」的地方
/// （選取、焦點、主要動作、資料長條）。狀態以小圓點加文字表達，不用彩色側條。
abstract final class C {
  // 灰階層次：畫布 → 面板 → 內嵌區
  static const canvas = Color(0xFFF6F7F8);
  static const surface = TPColors.white;
  static const inset = Color(0xFFF2F4F5);
  static const hover = Color(0xFFF4F6F7);
  static const border = Color(0xFFE6E9EB);
  static const borderStrong = Color(0xFFD3D9DC);
  static const divider = Color(0xFFEEF0F2);

  // 文字層次
  static const ink = TPColors.grayscale900;
  static const ink2 = TPColors.grayscale700;
  static const ink3 = TPColors.grayscale500;
  static const ink4 = TPColors.grayscale400;

  // 主題色（台北通 primary）
  static const accent = TPColors.primary500;
  static const accentStrong = TPColors.primary600;
  static const accentInk = TPColors.primary700;
  static const accentSoft = TPColors.primary50;
  static const accentSoft2 = TPColors.primary100;

  // 語意色：只用在圓點、圖示與極淡底色
  static const ok = TPColors.green500;
  static const okInk = TPColors.green700;
  static const okSoft = TPColors.green50;
  static const warn = TPColors.secondary600;
  static const warnInk = TPColors.secondary800;
  static const warnSoft = TPColors.secondary50;
  static const danger = TPColors.red500;
  static const dangerInk = TPColors.red600;
  static const dangerSoft = TPColors.red50;

  static const rPanel = 12.0;
  static const rControl = 8.0;

  static const panelShadow = [BoxShadow(color: Color(0x08101828), blurRadius: 2, offset: Offset(0, 1))];
  static const popShadow = [
    BoxShadow(color: Color(0x14101828), blurRadius: 24, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x0A101828), blurRadius: 4, offset: Offset(0, 2)),
  ];
}

abstract final class CText {
  static const _f = 'PingFangTC';
  static const tabular = [FontFeature.tabularFigures()];
  static const pageTitle = TextStyle(
    fontFamily: _f,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    color: C.ink,
    height: 1.25,
  );
  static const title = TextStyle(fontFamily: _f, fontSize: 18, fontWeight: FontWeight.w600, color: C.ink, height: 1.35);
  static const panelTitle = TextStyle(
    fontFamily: _f,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: C.ink,
    height: 1.4,
  );
  static const body = TextStyle(fontFamily: _f, fontSize: 15, color: C.ink, height: 1.55);
  static const bodyStrong = TextStyle(
    fontFamily: _f,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: C.ink,
    height: 1.5,
  );
  static const secondary = TextStyle(fontFamily: _f, fontSize: 14, color: C.ink2, height: 1.55);
  static const small = TextStyle(fontFamily: _f, fontSize: 13, color: C.ink3, height: 1.5);
  static const caption = TextStyle(fontFamily: _f, fontSize: 12, color: C.ink3, height: 1.4, letterSpacing: 0.2);
  static const label = TextStyle(fontFamily: _f, fontSize: 13, fontWeight: FontWeight.w500, color: C.ink2, height: 1.4);
  static const kpi = TextStyle(
    fontFamily: _f,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: C.ink,
    height: 1.2,
    fontFeatures: tabular,
  );
  static const mono = TextStyle(fontFamily: 'monospace', fontSize: 13, color: C.ink3, height: 1.4);
}

/// Material 元件的共用外觀，讓沒有特別包裝的元件也長得一致。
ThemeData buildConsoleTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: C.accent,
    primary: C.accentStrong,
    onPrimary: TPColors.white,
    secondary: C.accent,
    error: C.dangerInk,
    surface: C.surface,
    onSurface: C.ink,
    outline: C.borderStrong,
    outlineVariant: C.border,
  );
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'PingFangTC',
    colorScheme: scheme,
    scaffoldBackgroundColor: C.canvas,
    splashFactory: NoSplash.splashFactory,
    hoverColor: C.hover,
    highlightColor: Colors.transparent,
    focusColor: C.accentSoft2,
    visualDensity: VisualDensity.standard,
  );
  OutlineInputBorder ob(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(C.rControl),
    borderSide: BorderSide(color: c, width: w),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: C.ink, displayColor: C.ink, fontFamily: 'PingFangTC'),
    dividerTheme: const DividerThemeData(color: C.divider, thickness: 1, space: 1),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: C.accentStrong, selectionColor: C.accentSoft2),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: C.surface,
      hoverColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: const TextStyle(color: C.ink4, fontSize: 15),
      labelStyle: CText.label,
      helperStyle: CText.small,
      errorStyle: const TextStyle(color: C.dangerInk, fontSize: 13),
      border: ob(C.borderStrong),
      enabledBorder: ob(C.borderStrong),
      disabledBorder: ob(C.border),
      focusedBorder: ob(C.accent, 1.6),
      errorBorder: ob(C.danger),
      focusedErrorBorder: ob(C.danger, 1.6),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(TPColors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? C.accentStrong : C.borderStrong,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      thumbIcon: const WidgetStatePropertyAll(null),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.accentStrong : null),
      side: const BorderSide(color: C.ink4, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.accentStrong : C.ink4),
    ),
    menuTheme: const MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(C.surface),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(8),
        shadowColor: WidgetStatePropertyAll(Color(0x33101828)),
        padding: WidgetStatePropertyAll(EdgeInsets.all(6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            side: BorderSide(color: C.border),
          ),
        ),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(180, 40)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14, fontFamily: 'PingFangTC')),
        foregroundColor: const WidgetStatePropertyAll(C.ink),
        iconColor: const WidgetStatePropertyAll(C.ink3),
        overlayColor: const WidgetStatePropertyAll(C.hover),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titleTextStyle: CText.title,
      contentTextStyle: CText.secondary,
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: C.surface,
      headerForegroundColor: C.ink,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(color: TPColors.white, fontSize: 12, fontFamily: 'PingFangTC'),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.ink,
      contentTextStyle: const TextStyle(color: TPColors.white, fontSize: 14, fontFamily: 'PingFangTC'),
      actionTextColor: TPColors.primary200,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      width: 440,
    ),
    scrollbarTheme: const ScrollbarThemeData(
      thickness: WidgetStatePropertyAll(6),
      radius: Radius.circular(3),
      thumbColor: WidgetStatePropertyAll(Color(0x33475259)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: C.accent, linearTrackColor: C.inset),
  );
}

// ═════════════════════════════════════════════ 版面

/// 白色面板：細邊框、極淡陰影。資訊分區的基本單位。
class CPanel extends StatelessWidget {
  const CPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = C.surface,
    this.borderColor = C.border,
    this.onTap,
    this.clip = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final VoidCallback? onTap;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(C.rPanel),
      side: BorderSide(color: borderColor),
    );
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(C.rPanel), boxShadow: C.panelShadow),
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: clip || onTap != null ? Clip.antiAlias : Clip.none,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
  }
}

/// 面板標題列（如 Pages／Sources）：標題、副標，右側放切換或動作。
class CPanelHeader extends StatelessWidget {
  const CPanelHeader({super.key, required this.title, this.subtitle, this.icon, this.trailing});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[Icon(icon, size: 18, color: C.ink3), const SizedBox(width: 8)],
                  Flexible(child: Text(title, style: CText.panelTitle)),
                ],
              ),
              if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: CText.small)],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

/// 頁首：大標題 + 灰色副標，右側為工具列。
class CPageHeader extends StatelessWidget {
  const CPageHeader({super.key, required this.title, this.subtitle, this.leading, this.actions = const []});
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: CText.pageTitle),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: CText.secondary.copyWith(color: C.ink3)),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        final stack = box.maxWidth < 640 && actions.isNotEmpty;
        final titleRow = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(child: head),
          ],
        );
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleRow,
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleRow),
            for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(width: 8), actions[i]],
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════ 按鈕

enum CButtonKind { primary, secondary, ghost, danger, dangerSolid }

class CButton extends StatelessWidget {
  const CButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.kind = CButtonKind.secondary,
    this.large = false,
    this.kbd,
    this.expand = false,
    this.tooltip,
  });
  const CButton.primary(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.large = false,
    this.kbd,
    this.expand = false,
    this.tooltip,
  }) : kind = CButtonKind.primary;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final CButtonKind kind;
  final bool large;
  final String? kbd;
  final bool expand;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final (Color bg, Color fg, Color side, Color hover) = switch (kind) {
      CButtonKind.primary => (C.accentStrong, TPColors.white, C.accentStrong, C.accentInk),
      CButtonKind.secondary => (C.surface, C.ink, C.border, C.hover),
      CButtonKind.ghost => (Colors.transparent, C.ink2, Colors.transparent, C.hover),
      CButtonKind.danger => (C.surface, C.dangerInk, C.border, C.dangerSoft),
      CButtonKind.dangerSolid => (C.dangerInk, TPColors.white, C.dangerInk, TPColors.red700),
    };
    final filled = kind == CButtonKind.primary || kind == CButtonKind.dangerSolid;
    final h = large ? 48.0 : 38.0;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: large ? 20 : 18), const SizedBox(width: 8)],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: large ? 16 : 14, fontWeight: FontWeight.w600, height: 1.2),
          ),
        ),
        if (trailingIcon != null) ...[const SizedBox(width: 6), Icon(trailingIcon, size: large ? 20 : 18)],
        if (kbd != null) ...[const SizedBox(width: 10), CKbd(kbd!, onDark: filled)],
      ],
    );
    final btn = TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(h, h)),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: large ? 20 : 14)),
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (!enabled) return filled ? C.inset : (kind == CButtonKind.ghost ? Colors.transparent : C.surface);
          if (s.contains(WidgetState.hovered) || s.contains(WidgetState.pressed)) return hover;
          return bg;
        }),
        foregroundColor: WidgetStatePropertyAll(enabled ? fg : C.ink4),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(C.rControl),
            side: BorderSide(color: enabled ? side : (kind == CButtonKind.ghost ? Colors.transparent : C.border)),
          ),
        ),
      ),
      child: child,
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// 圖示按鈕：一律附 tooltip（也就是無障礙名稱）。
class CIconButton extends StatelessWidget {
  const CIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.selected = false,
    this.bordered = false,
    this.size = 36,
    this.color,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final bool bordered;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        selected: selected,
        child: Material(
          color: selected ? C.accentSoft : (bordered ? C.surface : Colors.transparent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(C.rControl),
            side: BorderSide(color: selected ? C.accentSoft2 : (bordered ? C.border : Colors.transparent)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(C.rControl),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                size: size * 0.52,
                color: onPressed == null ? C.ink4 : (selected ? C.accentInk : (color ?? C.ink2)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 鍵盤快捷鍵提示（側欄與工具列右側的小方塊）。
class CKbd extends StatelessWidget {
  const CKbd(this.k, {super.key, this.onDark = false});
  final String k;
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minWidth: 20),
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onDark ? TPColors.white.withValues(alpha: 0.16) : C.surface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: onDark ? TPColors.white.withValues(alpha: 0.3) : C.border),
        ),
        child: Text(
          k,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: onDark ? TPColors.white : C.ink3,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════ 表單元件

/// 文字輸入框：標籤在上、說明在下。錯誤訊息用文字說清楚怎麼改，不只變紅。
/// autofocus 會在畫面建好後主動取得焦點（即使外層已有其他焦點）。
class CField extends StatefulWidget {
  const CField({
    super.key,
    this.label,
    this.optional = false,
    this.help,
    this.error,
    this.controller,
    this.initialValue,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.autofocus = false,
    this.style,
    this.textAlign = TextAlign.start,
    this.prefixIcon,
    this.suffix,
    this.width,
    this.focusNode,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
  });
  final String? label;
  final bool optional;
  final String? help;
  final String? error;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool autofocus;
  final TextStyle? style;
  final TextAlign textAlign;
  final IconData? prefixIcon;
  final Widget? suffix;
  final double? width;
  final FocusNode? focusNode;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  State<CField> createState() => _CFieldState();
}

class _CFieldState extends State<CField> {
  FocusNode? _own;

  FocusNode? get _node => widget.focusNode ?? _own;

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      if (widget.focusNode == null) _own = FocusNode();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _node?.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final label = w.label;
    final optional = w.optional;
    final help = w.help;
    final error = w.error;
    final controller = w.controller;
    final initialValue = w.initialValue;
    final hint = w.hint;
    final onChanged = w.onChanged;
    final onSubmitted = w.onSubmitted;
    final maxLines = w.maxLines;
    final minLines = w.minLines;
    final keyboardType = w.keyboardType;
    final inputFormatters = w.inputFormatters;
    final maxLength = w.maxLength;
    final style = w.style;
    final textAlign = w.textAlign;
    final prefixIcon = w.prefixIcon;
    final suffix = w.suffix;
    final width = w.width;
    final enabled = w.enabled;
    final readOnly = w.readOnly;
    final onTap = w.onTap;
    final field = TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      focusNode: _node,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      textAlign: textAlign,
      style: style ?? CText.body,
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        errorText: error,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 18, color: C.ink3),
        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 20),
        suffixIcon: suffix,
        semanticCounterText: '',
      ),
    );
    final col = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text.rich(
            TextSpan(
              text: label,
              children: [
                if (optional)
                  const TextSpan(
                    text: '（選填）',
                    style: TextStyle(color: C.ink4, fontWeight: FontWeight.w400),
                  ),
              ],
            ),
            style: CText.label,
          ),
          const SizedBox(height: 6),
        ],
        field,
        if (help != null && error == null) ...[const SizedBox(height: 6), Text(help, style: CText.small)],
      ],
    );
    return width == null ? col : SizedBox(width: width, child: col);
  }
}

/// 分段切換（灰色軌道＋白色選中塊），對應參考圖的 Top／Entry。
class CSegmented<T> extends StatelessWidget {
  const CSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.large = false,
  });
  final List<(T, String, IconData?)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool large;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: C.inset, borderRadius: BorderRadius.circular(C.rControl + 2)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            Semantics(
              button: true,
              selected: o.$1 == value,
              child: GestureDetector(
                onTap: () => onChanged(o.$1),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(horizontal: large ? 16 : 12, vertical: large ? 9 : 6),
                    decoration: BoxDecoration(
                      color: o.$1 == value ? C.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(C.rControl - 1),
                      boxShadow: o.$1 == value ? C.panelShadow : null,
                      border: Border.all(color: o.$1 == value ? C.border : Colors.transparent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (o.$3 != null) ...[
                          Icon(o.$3, size: 16, color: o.$1 == value ? C.accentInk : C.ink3),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          o.$2,
                          style: TextStyle(
                            fontSize: large ? 15 : 14,
                            fontWeight: o.$1 == value ? FontWeight.w600 : FontWeight.w400,
                            color: o.$1 == value ? C.ink : C.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 頁內分頁（底線式），用在表單編輯器的「問題／回覆／設定」。
class CTabs extends StatelessWidget {
  const CTabs({super.key, required this.tabs, required this.index, required this.onChanged});
  final List<(String, String?)> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: C.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Semantics(
              button: true,
              selected: i == index,
              child: InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                  margin: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: i == index ? C.ink : Colors.transparent, width: 2)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        tabs[i].$1,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: i == index ? FontWeight.w600 : FontWeight.w400,
                          color: i == index ? C.ink : C.ink3,
                        ),
                      ),
                      if (tabs[i].$2 != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(color: C.inset, borderRadius: BorderRadius.circular(99)),
                          child: Text(tabs[i].$2!, style: CText.caption.copyWith(fontFeatures: CText.tabular)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 開關列：左邊標題與說明、右邊開關。整列都可點。
class CSwitchRow extends StatelessWidget {
  const CSwitchRow({super.key, required this.title, this.desc, required this.value, required this.onChanged});
  final String title;
  final String? desc;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(C.rControl),
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: CText.bodyStrong),
                    if (desc != null) ...[const SizedBox(height: 2), Text(desc!, style: CText.small)],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════ 狀態與資料

enum CTone { neutral, accent, ok, warn, danger }

Color toneDot(CTone t) => switch (t) {
  CTone.neutral => C.ink4,
  CTone.accent => C.accent,
  CTone.ok => C.ok,
  CTone.warn => C.warn,
  CTone.danger => C.danger,
};

Color toneInk(CTone t) => switch (t) {
  CTone.neutral => C.ink2,
  CTone.accent => C.accentInk,
  CTone.ok => C.okInk,
  CTone.warn => C.warnInk,
  CTone.danger => C.dangerInk,
};

Color toneSoft(CTone t) => switch (t) {
  CTone.neutral => C.inset,
  CTone.accent => C.accentSoft,
  CTone.ok => C.okSoft,
  CTone.warn => C.warnSoft,
  CTone.danger => C.dangerSoft,
};

/// 狀態：小圓點＋文字（參考圖的「○ 0 online」）。顏色只是輔助，文字本身就說清楚。
class CStatus extends StatelessWidget {
  const CStatus(this.label, {super.key, this.tone = CTone.neutral, this.pulse = false, this.size = 14});
  final String label;
  final CTone tone;
  final bool pulse;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: toneDot(tone),
            boxShadow: pulse ? [BoxShadow(color: toneDot(tone).withValues(alpha: 0.35), spreadRadius: 3)] : null,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: size, color: tone == CTone.neutral ? C.ink2 : toneInk(tone), height: 1.3),
          ),
        ),
      ],
    );
  }
}

/// 標籤：灰底小膠囊。tone 只影響前面的圖示或圓點。
class CTag extends StatelessWidget {
  const CTag(this.label, {super.key, this.icon, this.tone, this.size = 12});
  final String label;
  final IconData? icon;
  final CTone? tone;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.65, vertical: size * 0.22),
      decoration: BoxDecoration(color: C.inset, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: size + 2, color: tone == null ? C.ink3 : toneDot(tone!)),
            SizedBox(width: size * 0.35),
          ] else if (tone != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: toneDot(tone!)),
            ),
            SizedBox(width: size * 0.45),
          ],
          Text(
            label,
            style: TextStyle(fontSize: size, color: C.ink2, fontWeight: FontWeight.w500, height: 1.3),
          ),
        ],
      ),
    );
  }
}

/// 比例長條列（參考圖的 Pages 清單）：底色長條代表占比，右側是數字。
class CBarRow extends StatelessWidget {
  const CBarRow({super.key, required this.label, required this.value, required this.fraction, this.icon, this.onTap});
  final String label;
  final String value;
  final double fraction;
  final IconData? icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label，$value',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        height: 34,
                        width: (box.maxWidth * fraction.clamp(0.0, 1.0)).clamp(6.0, box.maxWidth),
                        decoration: BoxDecoration(color: C.accentSoft, borderRadius: BorderRadius.circular(6)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            if (icon != null) ...[Icon(icon, size: 16, color: C.ink3), const SizedBox(width: 8)],
                            Expanded(
                              child: Text(label, overflow: TextOverflow.ellipsis, style: CText.body),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                value,
                style: CText.body.copyWith(fontFeatures: CText.tabular, color: C.ink2),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// 指標列（參考圖最上方的 Total Visits…）：一個面板，內含數個以細線分隔的指標。
class CStatStrip extends StatelessWidget {
  const CStatStrip({super.key, required this.items});
  final List<CStat> items;
  @override
  Widget build(BuildContext context) {
    return CPanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, box) {
          final perRow = box.maxWidth < 560 ? 2 : items.length;
          final rows = <List<CStat>>[];
          for (var i = 0; i < items.length; i += perRow) {
            rows.add(items.sublist(i, (i + perRow).clamp(0, items.length)));
          }
          return Column(
            children: [
              for (var r = 0; r < rows.length; r++) ...[
                if (r > 0) const Divider(),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < perRow; i++) ...[
                        if (i > 0) const VerticalDivider(width: 1, color: C.divider),
                        Expanded(child: i < rows[r].length ? rows[r][i] : const SizedBox()),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class CStat extends StatelessWidget {
  const CStat({super.key, required this.icon, required this.label, required this.value, this.note});
  final IconData icon;
  final String label;
  final String value;
  final String? note;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value${note != null ? '，$note' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: C.ink3),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: CText.secondary.copyWith(color: C.ink2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: CText.kpi),
                if (note != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(note!, overflow: TextOverflow.ellipsis, style: CText.small),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 提示區塊：淡底色＋圖示，不用彩色側條。
class CNotice extends StatelessWidget {
  const CNotice({super.key, required this.text, this.icon, this.tone = CTone.neutral, this.action, this.title});
  final String text;
  final String? title;
  final IconData? icon;
  final CTone tone;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: toneSoft(tone), borderRadius: BorderRadius.circular(C.rControl + 2)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon ?? Icons.info_outline_rounded,
              size: 18,
              color: tone == CTone.neutral ? C.ink3 : toneDot(tone),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: CText.bodyStrong.copyWith(
                      fontSize: 14,
                      color: tone == CTone.neutral ? C.ink : toneInk(tone),
                    ),
                  ),
                Text(text, style: CText.secondary.copyWith(color: tone == CTone.neutral ? C.ink2 : toneInk(tone))),
                if (action != null) ...[const SizedBox(height: 8), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CEmpty extends StatelessWidget {
  const CEmpty({super.key, required this.icon, required this.title, this.body, this.action});
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: C.inset, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: C.ink3),
          ),
          const SizedBox(height: 14),
          Text(title, style: CText.bodyStrong, textAlign: TextAlign.center),
          if (body != null) ...[
            const SizedBox(height: 4),
            Text(body!, style: CText.small, textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// 圖示方塊（灰底），用在清單前方。
class CIconTile extends StatelessWidget {
  const CIconTile(this.icon, {super.key, this.size = 36, this.tone});
  final IconData icon;
  final double size;
  final CTone? tone;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone == null ? C.inset : toneSoft(tone!),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, size: size * 0.5, color: tone == null ? C.ink2 : toneDot(tone!)),
    );
  }
}

/// 表格：表頭為小字灰色，列與列以細線分隔，整列可點。
class CTable extends StatelessWidget {
  const CTable({super.key, required this.columns, required this.rows, this.onTap, this.flex});
  final List<String> columns;
  final List<List<Widget>> rows;
  final List<int>? flex;
  final ValueChanged<int>? onTap;
  @override
  Widget build(BuildContext context) {
    Widget line(List<Widget> cells, {bool head = false, int? i}) {
      final row = Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: head ? 10 : 14),
        child: Row(
          children: [
            for (var c = 0; c < cells.length; c++) ...[
              if (c > 0) const SizedBox(width: 16),
              Expanded(flex: flex?[c] ?? 1, child: cells[c]),
            ],
          ],
        ),
      );
      if (head || onTap == null) return row;
      return InkWell(onTap: () => onTap!(i!), child: row);
    }

    return CPanel(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        children: [
          Container(
            color: C.canvas,
            child: line([for (final c in columns) Text(c, style: CText.caption)], head: true),
          ),
          const Divider(),
          for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(), line(rows[i], i: i)],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════ 回饋

void cToast(BuildContext context, String msg, {String? action, VoidCallback? onAction}) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: Duration(milliseconds: action == null ? 2800 : 7000),
        action: action == null ? null : SnackBarAction(label: action, onPressed: onAction ?? () {}),
      ),
    );
}

/// 確認對話框：危險動作的按鈕寫清楚後果。
Future<bool> cConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  String cancel = '取消',
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => CDialog(
      title: title,
      body: Text(body, style: CText.secondary),
      actions: [
        CButton(cancel, onPressed: () => Navigator.pop(ctx, false)),
        CButton(
          confirm,
          kind: danger ? CButtonKind.dangerSolid : CButtonKind.primary,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  return ok == true;
}

class CDialog extends StatelessWidget {
  const CDialog({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.width = 460,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final double width;
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: CText.title),
              if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: CText.small)],
              const SizedBox(height: 16),
              body,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: actions),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 下拉選單按鈕（MenuAnchor 的薄包裝）。
class CMenu extends StatelessWidget {
  const CMenu({super.key, required this.items, required this.builder});
  final List<CMenuItem> items;
  final Widget Function(BuildContext context, VoidCallback toggle) builder;
  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        for (final it in items)
          if (it.divider)
            const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider())
          else
            MenuItemButton(
              leadingIcon: it.icon == null ? null : Icon(it.icon, size: 18, color: it.danger ? C.dangerInk : null),
              trailingIcon: it.selected ? const Icon(Icons.check_rounded, size: 18, color: C.accentInk) : null,
              onPressed: it.onTap,
              child: Text(it.label, style: TextStyle(color: it.danger ? C.dangerInk : C.ink)),
            ),
      ],
      builder: (context, ctl, _) => builder(context, () => ctl.isOpen ? ctl.close() : ctl.open()),
    );
  }
}

class CMenuItem {
  const CMenuItem(this.label, {this.icon, this.onTap, this.danger = false, this.selected = false}) : divider = false;
  const CMenuItem.divider() : label = '', icon = null, onTap = null, danger = false, selected = false, divider = true;
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool danger;
  final bool selected;
  final bool divider;
}
