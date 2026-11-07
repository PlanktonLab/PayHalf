import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/bean/assist.dart';
import 'package:town_pass/page/assist/widget/assist_ui.dart';
import 'package:town_pass/service/assist_service.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:town_pass/util/tp_i18n.dart';

/// 陪辦進行中：整個畫面外圍亮起一圈流動的光框，狀態列下方出現「某某 正在陪您操作」。
///
/// 協助者換步驟時手機畫面會自己動，沒有提示會讓長輩以為手機壞了或被入侵。
/// 光框不擋操作（IgnorePointer），上方的提示可以點，點了回到協辦畫面。
class AssistRemoteFrame extends StatelessWidget {
  const AssistRemoteFrame({super.key, required this.child});
  final Widget child;

  static const double bannerHeight = 46;

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AssistService>();
    return Obx(() {
      service.sessions.length;
      final s = service.active;
      final on = s != null && s.helper != null;
      // 協辦畫面上方已經有「某某 正在陪您辦理」，膠囊就不再重複出現（光框保留）
      final banner = on && service.route.value != TPRoute.assistSession;
      final mq = MediaQuery.of(context);
      final top = mq.padding.top;
      return Stack(
        children: [
          // 把內容往下推，讓出提示列的位置（像通話中的狀態列）
          MediaQuery(
            data: banner
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
          ],
          if (banner) ...[
            Positioned(
              top: top,
              left: 0,
              right: 0,
              height: bannerHeight,
              // 這一層在 Navigator 之上，沒有 Material 的預設文字樣式，要自己包一層
              child: Material(
                type: MaterialType.transparency,
                child: _Banner(helper: s.helper!, sessionId: s.id),
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

/// 狀態列下方的膠囊：白底、外框是和光框同一組漸層，左邊頭像、右邊「›」可點
class _Banner extends StatefulWidget {
  const _Banner({required this.helper, required this.sessionId});
  final HelperInfo helper;
  final String sessionId;
  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  // 出現時從上面輕輕滑下來
  late final AnimationController enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))
    ..forward();

  @override
  void dispose() {
    enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = assistHelperDisplayName(widget.helper);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.1);
    final curve = CurvedAnimation(parent: enter, curve: Curves.easeOutBack);

    final capsule = Container(
      // 漸層外框
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: const LinearGradient(
          colors: [TPColors.primary300, TPColors.secondary300, TPColors.primary500],
        ),
        boxShadow: [
          BoxShadow(color: TPColors.primary600.withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Container(
        height: 36,
        padding: const EdgeInsets.fromLTRB(4, 0, 10, 0),
        decoration: BoxDecoration(color: TPColors.white, borderRadius: BorderRadius.circular(99)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AssistHelperAvatar(helper: widget.helper, size: 28),
                const Positioned(right: -2, bottom: -2, child: _LiveDot()),
              ],
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: name,
                      style: const TextStyle(color: TPColors.grayscale900, fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: '  正在陪您操作'.tr,
                      style: TextStyle(color: TPColors.primary700, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: scaler,
                style: const TextStyle(fontSize: 15, height: 1.2),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded, size: 20, color: TPColors.primary500),
          ],
        ),
      ),
    );

    return Center(
      child: Semantics(
        button: true,
        label: trf('{0} 正在陪您操作手機。點兩下回到協助畫面', [name]),
        child: GestureDetector(
          onTap: () {
            if (Get.currentRoute != TPRoute.assistSession) {
              Get.toNamed(TPRoute.assistSession, arguments: widget.sessionId);
            }
          },
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: reduce
                  ? capsule
                  : AnimatedBuilder(
                      animation: curve,
                      builder: (context, child) => Opacity(
                        opacity: enter.value,
                        child: Transform.translate(offset: Offset(0, -10 * (1 - curve.value)), child: child),
                      ),
                      child: capsule,
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
        final t = MediaQuery.disableAnimationsOf(context) ? 0.0 : Curves.easeInOut.transform(a.value);
        return SizedBox(
          width: 12,
          height: 12,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 往外擴散的光暈
              Container(
                width: 10 + 8 * t,
                height: 10 + 8 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TPColors.green500.withValues(alpha: 0.35 * (1 - t)),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TPColors.green500,
                  border: Border.all(color: TPColors.white, width: 2),
                ),
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
