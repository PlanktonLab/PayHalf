import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:town_pass/util/tp_colors.dart';

/// 完成時的動畫：仿 Material 3 Expressive 的 LoadingIndicator（形狀變換）。
///
/// M3 的載入指示器會在形狀庫的幾個形狀之間「彈簧式」變形，每換一個形狀就轉 90°：
///   柔和爆炸星 → 九瓣餅乾 → 圓角五邊形 → 膠囊 → 太陽 → 四瓣餅乾
/// 這裡依序跑一輪，最後停在四瓣餅乾，畫出勾勾。底下有 M3「contained」樣式的圓形底。
class AssistCelebration extends StatefulWidget {
  const AssistCelebration({super.key, this.size = 156});
  final double size;

  @override
  State<AssistCelebration> createState() => _AssistCelebrationState();
}

class _AssistCelebrationState extends State<AssistCelebration> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: _Timeline.total);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
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
          builder: (context, _) => CustomPaint(painter: _Painter(t: a.value, size: s)),
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

abstract final class _Timeline {
  static const pop = 0.32; // 秒：從 0 彈出來
  static const step = 0.5; // 秒：每次變形
  static const check = 0.5; // 秒：畫勾勾
  static final morphs = _shapes.length - 1;
  static final Duration total = Duration(milliseconds: ((pop + step * morphs + check + 0.4) * 1000).round());
  static double get totalSec => total.inMilliseconds / 1000;
}

/// M3 用彈簧（damping 約 0.6），會稍微衝過頭再回來
double _spring(double x) {
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  const zeta = 0.55, omega = 11.0;
  final wd = omega * math.sqrt(1 - zeta * zeta);
  return 1 - math.exp(-zeta * omega * x) * (math.cos(wd * x) + zeta * omega / wd * math.sin(wd * x));
}

class _Painter extends CustomPainter {
  _Painter({required this.t, required this.size});
  final double t;
  final double size;

  @override
  void paint(Canvas canvas, Size box) {
    final sec = t * _Timeline.totalSec;
    final c = box.center(Offset.zero);
    final base = size / 2;

    // 出場
    final pop = _spring((sec / _Timeline.pop).clamp(0.0, 1.0) * 0.9 + (sec > 0 ? 0.1 : 0));

    // 目前在第幾段變形、段內進度（彈簧）
    final morphSec = (sec - _Timeline.pop).clamp(0.0, _Timeline.step * _Timeline.morphs);
    final idx = math.min((morphSec / _Timeline.step).floor(), _Timeline.morphs - 1);
    final local = ((morphSec - idx * _Timeline.step) / _Timeline.step).clamp(0.0, 1.0);
    final p = _spring(local);
    final from = _shapes[idx];
    final to = _shapes[idx + 1];
    // 每換一個形狀轉 90°（跟著彈簧）
    final rotation = (idx + p) * math.pi / 2;

    final done = sec >= _Timeline.pop + _Timeline.step * _Timeline.morphs;
    final checkT = ((sec - _Timeline.pop - _Timeline.step * _Timeline.morphs) / _Timeline.check).clamp(0.0, 1.0);

    // M3 contained 樣式：淡色圓形底；完成時底色淡出、形狀放大
    final grow = _spring(checkT);
    final containerR = base * pop;
    canvas.drawCircle(
      c,
      containerR,
      Paint()..color = TPColors.primary100.withValues(alpha: (1 - grow * 0.85).clamp(0.0, 1.0)),
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
    if (done) canvas.drawShadow(path, TPColors.primary800.withValues(alpha: 0.4 * grow), 6, false);
    canvas.drawPath(path, Paint()..color = Color.lerp(TPColors.primary500, TPColors.primary600, grow)!);

    // 勾勾
    if (checkT > 0) {
      final s = shapeR;
      final a = c + Offset(-0.33, 0.02) * s;
      final b = c + Offset(-0.09, 0.25) * s;
      final e = c + Offset(0.35, -0.21) * s;
      final l1 = (b - a).distance, l2 = (e - b).distance;
      final len = (l1 + l2) * Curves.easeOutCubic.transform(checkT);
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

  @override
  bool shouldRepaint(_Painter old) => old.t != t || old.size != size;
}
