import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/models.dart';
import 'tp_colors.dart';

/// 每秒重繪一次，用於倒數與計時。
class EverySecond extends StatefulWidget {
  const EverySecond({super.key, required this.builder});
  final Widget Function(BuildContext context, DateTime now) builder;
  @override
  State<EverySecond> createState() => _EverySecondState();
}

class _EverySecondState extends State<EverySecond> {
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

class TPCard extends StatelessWidget {
  const TPCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color = TPColors.white,
    this.radius = 20,
    this.border,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final BoxBorder? border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: const [
          BoxShadow(color: Color(0x0F0B0D0E), blurRadius: 24, offset: Offset(0, 8)),
          BoxShadow(color: Color(0x0A0B0D0E), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: box),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    required this.color,
    required this.background,
    this.icon,
    this.fontSize = 13,
  });
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;
  final double fontSize;

  factory StatusPill.forField(FieldState st, {bool sensitive = true, double fontSize = 13}) {
    return switch (st.status) {
      'authorized' => StatusPill(
        '長輩已授權',
        color: TPColors.green700,
        background: TPColors.green50,
        icon: Icons.verified_user_rounded,
        fontSize: fontSize,
      ),
      'filled' => StatusPill(
        '長輩已選擇',
        color: TPColors.green700,
        background: TPColors.green50,
        icon: Icons.check_circle_rounded,
        fontSize: fontSize,
      ),
      'requested' => StatusPill(
        '等待長輩授權',
        color: TPColors.secondary800,
        background: TPColors.secondary100,
        icon: Icons.hourglass_top_rounded,
        fontSize: fontSize,
      ),
      'denied' => StatusPill(
        '長輩不同意',
        color: TPColors.red700,
        background: TPColors.red50,
        icon: Icons.block_rounded,
        fontSize: fontSize,
      ),
      _ => StatusPill(
        sensitive ? '尚未授權' : '尚未選擇',
        color: TPColors.grayscale600,
        background: TPColors.grayscale50,
        icon: Icons.radio_button_unchecked_rounded,
        fontSize: fontSize,
      ),
    };
  }

  factory StatusPill.forSession(AssistSession s) {
    final label = statusLabel(s);
    return switch (s.status) {
      'pending' => StatusPill(
        label,
        color: TPColors.secondary800,
        background: TPColors.secondary100,
        icon: Icons.hourglass_top_rounded,
      ),
      'active' => StatusPill(
        label,
        color: TPColors.primary700,
        background: TPColors.primary100,
        icon: Icons.sync_rounded,
      ),
      'completed' => StatusPill(
        label,
        color: TPColors.green700,
        background: TPColors.green50,
        icon: Icons.check_circle_rounded,
      ),
      _ => StatusPill(
        label,
        color: TPColors.grayscale600,
        background: TPColors.grayscale100,
        icon: Icons.remove_circle_outline_rounded,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.8, vertical: fontSize * 0.35),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: fontSize + 2, color: color), SizedBox(width: fontSize * 0.35)],
          Text(
            label,
            style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w600, height: 1.2),
          ),
        ],
      ),
    );
  }
}

/// 協助者身分徽章：公務身分綠色認證，家人親友橘色提醒。
class HelperBadge extends StatelessWidget {
  const HelperBadge({super.key, required this.helperType, required this.verified, this.large = false});
  final String helperType;
  final bool verified;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final fs = large ? 18.0 : 12.0;
    if (verified) {
      return StatusPill(
        helperType == 'official' ? '市府認證客服' : '市府認證里長',
        color: TPColors.green700,
        background: TPColors.green50,
        icon: Icons.verified_rounded,
        fontSize: fs,
      );
    }
    return StatusPill(
      '非公務人員',
      color: TPColors.secondary800,
      background: TPColors.secondary100,
      icon: Icons.info_rounded,
      fontSize: fs,
    );
  }
}

IconData helperIcon(String helperType) => switch (helperType) {
  'village_chief' => Icons.holiday_village_rounded,
  'official' => Icons.support_agent_rounded,
  _ => Icons.family_restroom_rounded,
};

class TownPassLogo extends StatelessWidget {
  const TownPassLogo({super.key, this.size = 24});
  final double size;
  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/app_bar_logo.png', height: size, filterQuality: FilterQuality.medium);
}

void showApiError(BuildContext context, Object e) {
  final msg = e is ApiException ? e.message : '連線失敗，請確認後端是否啟動';
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 15)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: TPColors.grayscale800,
        width: 480,
      ),
    );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.size = 18});
  final String text;
  final Widget? trailing;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: TPColors.grayscale900),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}
