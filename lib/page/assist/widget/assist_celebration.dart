import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:town_pass/util/tp_colors.dart';

/// 完成時的動畫：仿 Material 3 Expressive 的 LoadingIndicator（形狀變換）。
///
/// M3 的載入指示器會在形狀庫的幾個形狀之間「彈簧式」變形，每換一個形狀就轉 90°：
///   柔和爆炸星 → 九瓣餅乾 → 圓角五邊形 → 膠囊 → 太陽 → 四瓣餅乾
/// 長輩端停在四瓣形狀畫出勾勾，協助者端則變成一枚手托愛心的花形徽章。
class AssistCelebration extends StatefulWidget {
  const AssistCelebration({super.key, this.size = 156}) : _gratitude = false, animate = true;
  const AssistCelebration.gratitude({super.key, this.size = 156, this.animate = true}) : _gratitude = true;
  final double size;
  final bool _gratitude;
  final bool animate;

  @override
  State<AssistCelebration> createState() => _AssistCelebrationState();
}

class _AssistCelebrationState extends State<AssistCelebration> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(
    vsync: this,
    duration: (widget._gratitude ? _helperTimeline : _elderTimeline).total,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      a.value = 1;
    } else if (!a.isAnimating && a.value == 0) {
      a.forward();
    }
  }

  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return ExcludeSemantics(
      child: SizedBox(
        width: s * 1.6,
        height: s * 1.4,
        child: AnimatedBuilder(
          animation: a,
          builder: (context, _) => CustomPaint(painter: _Painter(t: a.value, size: s, gratitude: widget._gratitude)),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════ 形狀

/// 每個形狀都轉成「固定 N 個角度上的半徑」，變形時逐點內插半徑即可，
/// 形狀差異越大，變形越明顯（跟 M3 graphics-shapes 的 Morph 效果相近）。
const int _n = 360;

List<double> _polar(double Function(double th) f) =>
    _normalize(List.generate(_n, (i) => f(i / _n * 2 * math.pi)));

/// 由輪廓點（以原點為中心、星形可見）算出各角度的半徑：射線與每段邊求交點
List<double> _fromOutline(List<Offset> pts) {
  final out = List<double>.filled(_n, 0);
  for (var i = 0; i < _n; i++) {
    final th = i / _n * 2 * math.pi;
    final d = Offset(math.cos(th), math.sin(th));
    var best = 0.0;
    for (var k = 0; k < pts.length; k++) {
      final p = pts[k];
      final q = pts[(k + 1) % pts.length];
      final e = q - p;
      final den = d.dx * e.dy - d.dy * e.dx;
      if (den.abs() < 1e-9) continue;
      final t = (p.dx * e.dy - p.dy * e.dx) / den; // 射線長度
      final u = (p.dx * d.dy - p.dy * d.dx) / den; // 邊上位置
      if (t > 0 && u >= 0 && u <= 1 && t > best) best = t;
    }
    out[i] = best;
  }
  return _normalize(out);
}

List<double> _normalize(List<double> r) {
  final m = r.reduce(math.max);
  return r.map((v) => v / m).toList();
}

/// 圓角正多邊形：縮小的多邊形外面包一圈圓（Minkowski 和），角就變圓
List<double> _roundedPolygon(int sides, double rounding, {double start = -math.pi / 2}) {
  final pts = <Offset>[];
  final inner = 1 - rounding;
  for (var i = 0; i < sides; i++) {
    final a = start + i / sides * 2 * math.pi;
    final v = Offset(math.cos(a), math.sin(a)) * inner;
    // 這個頂點的圓弧：從前一條邊的法向量轉到下一條邊的法向量
    final n0 = a - math.pi / sides;
    final n1 = a + math.pi / sides;
    for (var k = 0; k <= 10; k++) {
      final ang = lerpDouble(n0, n1, k / 10)!;
      pts.add(v + Offset(math.cos(ang), math.sin(ang)) * rounding);
    }
  }
  return _fromOutline(pts);
}

/// 膠囊：一條線段外面包一圈圓，斜放 45°
List<double> _pill() {
  const half = 0.5, radius = 0.5, tilt = -math.pi / 4;
  final pts = <Offset>[];
  Offset rot(Offset p) => Offset(
    p.dx * math.cos(tilt) - p.dy * math.sin(tilt),
    p.dx * math.sin(tilt) + p.dy * math.cos(tilt),
  );
  for (var k = 0; k <= 24; k++) {
    final ang = -math.pi / 2 + k / 24 * math.pi;
    pts.add(rot(const Offset(half, 0) + Offset(math.cos(ang), math.sin(ang)) * radius));
  }
  for (var k = 0; k <= 24; k++) {
    final ang = math.pi / 2 + k / 24 * math.pi;
    pts.add(rot(const Offset(-half, 0) + Offset(math.cos(ang), math.sin(ang)) * radius));
  }
  return _fromOutline(pts);
}

/// 星形（尖端圓潤）：sharp 越大尖端越細
List<double> _star(int points, double inner, double sharp) =>
    _polar((th) => inner + (1 - inner) * math.pow((1 + math.cos(points * th)) / 2, sharp).toDouble());

/// 餅乾：圓圓的瓣、瓣與瓣之間是內凹
List<double> _cookie(int lobes, double depth) =>
    _polar((th) => 1 - depth * (1 - math.pow(math.cos(lobes * th / 2).abs(), 0.55).toDouble()));

final List<List<double>> _shapes = [
  _star(10, 0.74, 1.15), // 柔和爆炸星 soft burst
  _cookie(9, 0.16), // 九瓣餅乾 cookie 9
  _roundedPolygon(5, 0.24), // 圓角五邊形 pentagon
  _pill(), // 膠囊 pill
  _star(8, 0.78, 1.0), // 太陽 sunny
  _cookie(4, 0.26), // 四瓣餅乾 cookie 4（最後停在這裡）
];

// ═════════════════════════════════════════════ 時間軸

class _Timeline {
  _Timeline(this.shapes, {required this.pop, required this.step, required this.reveal, double hold = 0})
    : total = Duration(milliseconds: ((pop + step * (shapes.length - 1) + reveal + hold) * 1000).round());
  final List<List<double>> shapes;
  final double pop, step, reveal; // 秒
  final Duration total;
  int get morphs => shapes.length - 1;
  double get revealStart => pop + step * morphs;
}

final _elderTimeline = _Timeline(_shapes, pop: 0.32, step: 0.5, reveal: 0.5, hold: 0.4);
// 只變形一次，將最後 640 ms 留給掌心與愛心。
final _helperTimeline = _Timeline([_roundedPolygon(5, 0.24), _star(8, 0.83, 0.85)], pop: 0.22, step: 0.54, reveal: 0.64);

/// M3 用彈簧（damping 約 0.6），會稍微衝過頭再回來
double _spring(double x) {
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  const zeta = 0.55, omega = 11.0;
  final wd = omega * math.sqrt(1 - zeta * zeta);
  return 1 - math.exp(-zeta * omega * x) * (math.cos(wd * x) + zeta * omega / wd * math.sin(wd * x));
}

class _Painter extends CustomPainter {
  _Painter({required this.t, required this.size, required this.gratitude});
  final double t;
  final double size;
  final bool gratitude;

  @override
  void paint(Canvas canvas, Size box) {
    final timeline = gratitude ? _helperTimeline : _elderTimeline;
    final sec = t * timeline.total.inMilliseconds / 1000;
    final c = box.center(Offset.zero);
    final base = size / 2;

    // 出場
    final pop = _spring((sec / timeline.pop).clamp(0.0, 1.0) * 0.9 + (sec > 0 ? 0.1 : 0));

    // 目前在第幾段變形、段內進度（彈簧）
    final morphSec = (sec - timeline.pop).clamp(0.0, timeline.step * timeline.morphs);
    final idx = math.min((morphSec / timeline.step).floor(), timeline.morphs - 1);
    final local = ((morphSec - idx * timeline.step) / timeline.step).clamp(0.0, 1.0);
    final p = _spring(local);
    final from = timeline.shapes[idx];
    final to = timeline.shapes[idx + 1];
    // 每換一個形狀轉 90°（跟著彈簧）
    final rotation = (idx + p) * math.pi / 2;

    final done = sec >= timeline.revealStart;
    final revealT = t == 1 ? 1.0 : ((sec - timeline.revealStart) / timeline.reveal).clamp(0.0, 1.0);

    // M3 contained 樣式：淡色圓形底；完成時底色淡出、形狀放大
    final grow = _spring(revealT);
    final containerR = base * pop;
    canvas.drawCircle(
      c,
      containerR,
      Paint()..color = (gratitude ? TPColors.secondary100 : TPColors.primary100)
          .withValues(alpha: (1 - grow * 0.85).clamp(0.0, 1.0)),
    );

    final shapeR = base * pop * lerpDouble(0.72, 0.96, grow)!;
    final path = Path();
    for (var i = 0; i <= _n; i++) {
      final k = i % _n;
      final th = k / _n * 2 * math.pi;
      final r = shapeR * lerpDouble(from[k], to[k], p)!;
      final pt = c + Offset(math.cos(th + rotation), math.sin(th + rotation)) * r;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    if (done) {
      if (gratitude) {
        // 徽章下用柔和的圓影，避免每一幀都為多瓣輪廓計算陰影。
        canvas.drawCircle(
          c + Offset(0, shapeR * 0.06),
          shapeR * 0.88,
          Paint()
            ..color = TPColors.primary800.withValues(alpha: 0.22 * grow)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, shapeR * 0.09),
        );
      } else {
        canvas.drawShadow(path, TPColors.primary800.withValues(alpha: 0.4 * grow), 6, false);
      }
    }
    final ink = Color.lerp(TPColors.primary500, gratitude ? TPColors.primary700 : TPColors.primary600, grow)!;
    canvas.drawPath(path, Paint()..color = ink);

    if (revealT <= 0) return;
    if (gratitude) {
      _drawGratitude(canvas, c, shapeR, revealT);
    } else {
      final s = shapeR;
      final a = c + Offset(-0.33, 0.02) * s;
      final b = c + Offset(-0.09, 0.25) * s;
      final e = c + Offset(0.35, -0.21) * s;
      final l1 = (b - a).distance, l2 = (e - b).distance;
      final len = (l1 + l2) * Curves.easeOutCubic.transform(revealT);
      final cp = Path()..moveTo(a.dx, a.dy);
      if (len <= l1) {
        final q = Offset.lerp(a, b, len / l1)!;
        cp.lineTo(q.dx, q.dy);
      } else {
        cp.lineTo(b.dx, b.dy);
        final q = Offset.lerp(b, e, (len - l1) / l2)!;
        cp.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(
        cp,
        Paint()
          ..color = TPColors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.15
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  // 掌心先攤開，金色的心再從掌心升起。圖案保持正向，不隨外圈旋轉。
  static void _drawGratitude(Canvas canvas, Offset center, double radius, double progress) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(radius);
    final palm = Path()
      ..moveTo(-0.57, 0.28)
      ..quadraticBezierTo(-0.42, 0.08, -0.24, 0.10)
      ..lineTo(0.06, 0.17)
      ..quadraticBezierTo(0.21, 0.20, 0.15, 0.30)
      ..lineTo(-0.09, 0.29)
      ..quadraticBezierTo(0.09, 0.36, 0.24, 0.28)
      ..lineTo(0.48, 0.12)
      ..quadraticBezierTo(0.60, 0.04, 0.60, 0.18)
      ..quadraticBezierTo(0.41, 0.39, 0.15, 0.51)
      ..quadraticBezierTo(0.06, 0.55, -0.05, 0.52)
      ..lineTo(-0.33, 0.45)
      ..lineTo(-0.41, 0.51)
      ..close();
    final handT = Curves.easeOut.transform((progress / 0.6).clamp(0.0, 1.0));
    canvas.save();
    canvas.translate(0, 0.12 * (1 - handT));
    canvas.drawPath(palm, Paint()..color = TPColors.white.withValues(alpha: handT));
    canvas.restore();

    final heartT = ((progress - 0.18) / 0.82).clamp(0.0, 1.0);
    if (heartT > 0) {
      final lift = _spring(heartT);
      canvas.translate(0, -0.19 + 0.22 * (1 - lift));
      canvas.scale(0.60 + 0.40 * lift);
      final heart = Path()
        ..moveTo(0, 0.23)
        ..cubicTo(-0.07, 0.18, -0.34, 0.00, -0.34, -0.16)
        ..cubicTo(-0.34, -0.36, -0.12, -0.41, 0, -0.25)
        ..cubicTo(0.12, -0.41, 0.34, -0.36, 0.34, -0.16)
        ..cubicTo(0.34, 0.00, 0.07, 0.18, 0, 0.23)
        ..close();
      canvas.drawPath(heart, Paint()..color = TPColors.secondary300.withValues(alpha: Curves.easeOut.transform(heartT)));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Painter old) => old.t != t || old.size != size || old.gratitude != gratitude;
}
