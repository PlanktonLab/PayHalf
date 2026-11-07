import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_route.dart';

/// 陪辦進行中：整個畫面外圍亮起一圈流動的光框，狀態列下方出現「某某 正在陪您操作」。
///
/// 協助者換步驟時手機畫面會自己動，沒有提示會讓長輩以為手機壞了或被入侵。
/// 光框不擋操作（IgnorePointer），上方的提示可以點，點了回到協辦畫面。
class AssistRemoteFrame extends StatelessWidget {
  const AssistRemoteFrame({super.key, required this.child});
  final Widget child;

  static const double bannerHeight = 40;

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    return Obx(() {
      service.sessions.length;
      final s = service.active;
      final on = s != null && s.helper != null;
      final mq = MediaQuery.of(context);
      final top = mq.padding.top;
      return Stack(
        children: [
          // 把內容往下推，讓出提示列的位置（像通話中的狀態列）
          MediaQuery(
            data: on
                ? mq.copyWith(
                    padding: mq.padding.copyWith(top: top + bannerHeight),
                    viewPadding: mq.viewPadding.copyWith(top: mq.viewPadding.top + bannerHeight),
                  )
                : mq,
            child: child,
          ),
          if (on) ...[
            Positioned.fill(
              child: IgnorePointer(
                child: _GlowFrame(radius: _screenRadius(top), reduceMotion: mq.disableAnimations),
              ),
            ),
            Positioned(
              top: top,
              left: 0,
              right: 0,
              height: bannerHeight,
              // 這一層在 Navigator 之上，沒有 Material 的預設文字樣式，要自己包一層
              child: Material(
                type: MaterialType.transparency,
                child: _Banner(name: assistHelperDisplayName(s.helper!), sessionId: s.id),
              ),
            ),
          ],
        ],
      );
    });
  }

  /// 手機螢幕圓角的近似值（依瀏海／動態島高度判斷機型）
  static double _screenRadius(double topPadding) {
    if (topPadding >= 59) return 55;
    if (topPadding >= 47) return 47;
    if (topPadding > 24) return 39;
    return 0;
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.name, required this.sessionId});
  final String name;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: '$name 正在陪您操作手機。點兩下回到協助畫面',
        child: GestureDetector(
          onTap: () {
            if (Get.currentRoute != TPRoute.assistSession) Get.toNamed(TPRoute.assistSession, arguments: sessionId);
          },
          child: ExcludeSemantics(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
              decoration: BoxDecoration(
                color: TPColors.grayscale900.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(color: TPColors.primary500.withValues(alpha: 0.45), blurRadius: 14, spreadRadius: 0.5),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _LiveDot(),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const TextSpan(text: ' 正在陪您操作'),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15),
                      style: const TextStyle(color: TPColors.white, fontSize: 15, height: 1.2),
                    ),
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

/// 呼吸中的小圓點，表示「即時連線中」
class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: a,
      builder: (context, _) {
        final t = MediaQuery.disableAnimationsOf(context) ? 1.0 : Curves.easeInOut.transform(a.value);
        return SizedBox(
          width: 14,
          height: 14,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 8 + 6 * t,
                height: 8 + 6 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TPColors.primary300.withValues(alpha: 0.35 * (1 - t) + 0.1),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: TPColors.primary300),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 沿著螢幕圓角流動的漸層光框
class _GlowFrame extends StatefulWidget {
  const _GlowFrame({required this.radius, required this.reduceMotion});
  final double radius;
  final bool reduceMotion;
  @override
  State<_GlowFrame> createState() => _GlowFrameState();
}

class _GlowFrameState extends State<_GlowFrame> with TickerProviderStateMixin {
  late final AnimationController spin = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  late final AnimationController appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) spin.repeat();
  }

  @override
  void dispose() {
    spin.dispose();
    appear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([spin, appear]),
      builder: (context, _) => CustomPaint(
        painter: _GlowPainter(
          turn: spin.value,
          opacity: Curves.easeOut.transform(appear.value),
          radius: widget.radius,
        ),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({required this.turn, required this.opacity, required this.radius});
  final double turn;
  final double opacity;
  final double radius;

  static const _colors = [
    TPColors.primary400,
    TPColors.primary200,
    TPColors.secondary300,
    TPColors.primary500,
    TPColors.primary300,
    TPColors.primary400,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final glowShader = SweepGradient(
      colors: _colors.map((c) => c.withValues(alpha: opacity * 0.55)).toList(),
      transform: GradientRotation(turn * 2 * math.pi),
    ).createShader(rect);
    final shader = SweepGradient(
      colors: _colors.map((c) => c.withValues(alpha: opacity)).toList(),
      transform: GradientRotation(turn * 2 * math.pi),
    ).createShader(rect);

    // 外暈
    final glow = Paint()
      ..shader = glowShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    // 實線
    final line = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final rr = RRect.fromRectAndRadius(rect.deflate(2), Radius.circular(math.max(0, radius - 2)));
    canvas.drawRRect(rr, glow);
    canvas.drawRRect(rr, line);
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.turn != turn || old.opacity != opacity || old.radius != radius;
}
