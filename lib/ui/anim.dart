// Looping 3D mannequin animation for each exercise, seen from a three-quarter
// angle. Each pose is a set of joint angles in the side plane; the body is
// built from shaded capsules and spheres, and the muscles the exercise trains
// glow red (main) or orange (assisting).
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../logic.dart' show ex;

/// Angles in degrees: 0 = pointing down, 90 = forward (right), 180 = up, -90 = backward.
class Pose {
  final double trunk, th1, sh1, th2, sh2, ua1, fa1, ua2, fa2, lift;
  const Pose(this.trunk, this.th1, this.sh1, this.th2, this.sh2, this.ua1, this.fa1, this.ua2, this.fa2, [this.lift = 0]);
  Pose lerp(Pose b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return Pose(l(trunk, b.trunk), l(th1, b.th1), l(sh1, b.sh1), l(th2, b.th2), l(sh2, b.sh2), l(ua1, b.ua1), l(fa1, b.fa1),
        l(ua2, b.ua2), l(fa2, b.fa2), l(lift, b.lift));
  }
}

enum Prop { none, chair, wall, table }

class Anim {
  final List<Pose> frames;
  final Prop prop;
  final bool db; // dumbbell in hands
  final bool dbHip; // dumbbell resting on hips
  final bool oneDb; // single dumbbell held with both hands
  final double secs; // seconds per full cycle
  const Anim(this.frames, {this.prop = Prop.none, this.db = false, this.dbHip = false, this.oneDb = false, this.secs = 2.4});
}

const _stand = Pose(180, 0, 0, 0, 0, 0, 0, 0, 0);
const _lie = Pose(-90, 135, 15, 135, 15, 90, 90, 90, 90); // on back, knees bent, arms by the side

const anims = <String, Anim>{
  'march': Anim([Pose(180, 70, 0, 0, 0, -35, 50, 35, 90), Pose(180, 0, 0, 70, 0, 35, 90, -35, 50)], secs: 1.2),
  'wallpush': Anim([Pose(160, -20, -20, -20, -20, 105, 105, 105, 105), Pose(150, -30, -30, -30, -30, 40, 150, 40, 150)], prop: Prop.wall),
  'sitstand': Anim([Pose(160, 88, 0, 88, 0, 80, 85, 80, 85), Pose(180, 0, 0, 0, 0, 85, 90, 85, 90)], prop: Prop.chair, secs: 3),
  'sidestep': Anim([Pose(180, 20, 15, -20, -15, 40, 60, -40, 20), Pose(180, -20, -15, 20, 15, -40, 20, 40, 60)], secs: 1.2),
  'bridge': Anim([_lie, Pose(-60, 110, 5, 110, 5, 70, 70, 70, 70)], secs: 2.8),
  'row': Anim([Pose(130, 15, -10, 15, -10, 0, 0, 0, 0), Pose(130, 15, -10, 15, -10, -55, 45, -55, 45)], db: true),
  'birddog': Anim([Pose(90, 0, -90, 0, -90, 0, 0, 0, 0), Pose(90, 0, -90, -90, -90, 95, 95, 0, 0)], secs: 3),
  'knee': Anim([Pose(180, 0, 0, 0, 0, 160, 120, 160, 120), Pose(170, 90, 0, 0, 0, 60, 150, 160, 120)], secs: 1.2),
  'stepjack': Anim([_stand, Pose(180, 25, 20, -5, 0, 170, 175, 170, 175)], secs: 1.2),
  'box': Anim([Pose(175, 15, -5, -15, -15, 90, 90, 25, 150), Pose(175, 15, -5, -15, -15, 25, 150, 90, 90)], secs: .8),
  'squatpulse': Anim([Pose(155, 85, -10, 85, -10, 80, 85, 80, 85), Pose(180, 0, 0, 0, 0, 80, 85, 80, 85)], prop: Prop.chair, secs: 1.4),
  'calf': Anim([Pose(180, 0, 0, 0, 0, 50, 80, 50, 80), Pose(180, 0, 0, 0, 0, 50, 80, 50, 80, 4)], prop: Prop.chair, secs: 2),
  'stretch': Anim([Pose(180, 0, 0, 0, -165, 0, 0, -20, -150), Pose(115, -5, -5, -5, -5, 10, 10, 10, 10)], secs: 6),
  'goblet': Anim([Pose(180, 0, 0, 0, 0, 25, 165, 25, 165), Pose(150, 85, -20, 85, -20, 30, 165, 30, 165)], prop: Prop.chair, db: true, oneDb: true, secs: 3),
  'floorpress': Anim([Pose(-90, 135, 15, 135, 15, 180, 180, 180, 180), Pose(-90, 135, 15, 135, 15, 10, 175, 10, 175)], db: true, secs: 2.6),
  'row1': Anim([Pose(100, 20, -10, 90, -90, 0, 0, 0, 0), Pose(100, 20, -10, 90, -90, -60, 40, 0, 0)], prop: Prop.chair, db: true),
  'rdl': Anim([Pose(180, 0, 0, 0, 0, 5, 5, 5, 5), Pose(110, -12, 5, -12, 5, 2, 2, 2, 2)], db: true, secs: 3),
  'carry': Anim([Pose(180, 40, 0, 0, 0, 0, 0, 0, 0), Pose(180, 0, 0, 40, 0, 0, 0, 0, 0)], db: true, secs: 1.6),
  'sumo': Anim([Pose(180, 15, 15, -15, -15, 0, 0, 0, 0), Pose(160, 70, -10, -70, 10, 5, 5, 5, 5)], db: true, oneDb: true, secs: 3),
  'ohp': Anim([Pose(180, 90, 0, 90, 0, 30, 175, 30, 175), Pose(180, 90, 0, 90, 0, 178, 178, 178, 178)], prop: Prop.chair, db: true, secs: 2.4),
  'row2': Anim([Pose(135, 15, -10, 15, -10, 0, 0, 0, 0), Pose(135, 15, -10, 15, -10, -55, 45, -55, 45)], db: true),
  'dbbridge': Anim([_lie, Pose(-60, 110, 5, 110, 5, 70, 70, 70, 70)], dbHip: true, secs: 2.8),
  'curl': Anim([_stand, Pose(180, 0, 0, 0, 0, 5, 160, 5, 160)], db: true),
  'splitsquat': Anim([Pose(180, 30, -5, -25, -25, 0, 0, 0, 0), Pose(180, 80, -10, -10, -85, 0, 0, 0, 0)], db: true, secs: 3),
  'incline': Anim([Pose(140, -40, -40, -40, -40, 95, 95, 95, 95), Pose(125, -55, -55, -55, -55, 30, 140, 30, 140)], prop: Prop.table),
  'deadbug': Anim([Pose(-90, 180, 90, 180, 90, 180, 180, 180, 180), Pose(-90, 180, 90, 95, 95, -95, -95, 180, 180)], secs: 3),
};

const _lTrunk = 28.0, _lThigh = 21.0, _lShin = 21.0, _lUa = 15.0, _lFa = 14.0, _head = 6.5;

Offset _dir(double deg, double len) {
  final r = deg * math.pi / 180;
  return Offset(math.sin(r) * len, math.cos(r) * len); // y grows downward; 0deg = down
}

class _Body {
  final Offset hip, neck, head, k1, f1, k2, f2, e1, h1, e2, h2;
  _Body(this.hip, this.neck, this.head, this.k1, this.f1, this.k2, this.f2, this.e1, this.h1, this.e2, this.h2);
  List<Offset> get all => [hip, neck, head, k1, f1, k2, f2, e1, h1, e2, h2];
  _Body shift(Offset d) => _Body(hip + d, neck + d, head + d, k1 + d, f1 + d, k2 + d, f2 + d, e1 + d, h1 + d, e2 + d, h2 + d);
}

_Body _solve(Pose p) {
  const hip = Offset.zero;
  final neck = hip + _dir(p.trunk, _lTrunk);
  final head = neck + _dir(p.trunk, _head + 2);
  final k1 = hip + _dir(p.th1, _lThigh), f1 = k1 + _dir(p.sh1, _lShin);
  final k2 = hip + _dir(p.th2, _lThigh), f2 = k2 + _dir(p.sh2, _lShin);
  final e1 = neck + _dir(p.ua1, _lUa), h1 = e1 + _dir(p.fa1, _lFa);
  final e2 = neck + _dir(p.ua2, _lUa), h2 = e2 + _dir(p.fa2, _lFa);
  var b = _Body(hip, neck, head, k1, f1, k2, f2, e1, h1, e2, h2);
  // rest the lowest point on the floor (y = 92), hip centred at x = 50
  final lowest = b.all.map((o) => o.dy).reduce(math.max);
  b = b.shift(Offset(50, 92 - lowest - p.lift));
  return b;
}

class ExerciseAnim extends StatefulWidget {
  final String exId;
  final Color color;
  final bool playing;
  final double size;
  final double phase; // frame shown while paused (0 = start, .5 = end position)
  const ExerciseAnim({super.key, required this.exId, required this.color, this.playing = true, this.size = 160, this.phase = 0});
  @override
  State<ExerciseAnim> createState() => _ExerciseAnimState();
}

class _ExerciseAnimState extends State<ExerciseAnim> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  Anim get _a => anims[widget.exId] ?? anims['march']!;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: (_a.secs * 1000).round()), value: widget.phase);
    if (widget.playing) _c.repeat();
  }

  @override
  void didUpdateWidget(ExerciseAnim old) {
    super.didUpdateWidget(old);
    if (old.exId != widget.exId) {
      _c.duration = Duration(milliseconds: (_a.secs * 1000).round());
      if (widget.playing) _c.repeat();
    }
    if (old.playing != widget.playing) widget.playing ? _c.repeat() : _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(painter: _MannequinPainter(_a, _c.value, widget.color, dark, ex[widget.exId]?.m ?? const {})),
      ),
    );
  }
}


const muscleMain = Color(0xFFFF3B30), muscleHelp = Color(0xFFFF9F0A);

/// Small legend for the muscle colours.
class MuscleLegend extends StatelessWidget {
  final Color? textColor;
  const MuscleLegend({super.key, this.textColor});
  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(t, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600)),
        ]);
    return Wrap(spacing: 14, runSpacing: 4, alignment: WrapAlignment.center, children: [dot(muscleMain, 'Otot utama'), dot(muscleHelp, 'Otot pembantu')]);
  }
}

class _V {
  final double x, y, z;
  const _V(this.x, this.y, this.z);
}

class _Part {
  final double depth;
  final void Function() draw;
  _Part(this.depth, this.draw);
}

class _MannequinPainter extends CustomPainter {
  final Anim a;
  final double t;
  final Color color;
  final bool dark;
  final Map<String, double> m;
  _MannequinPainter(this.a, this.t, this.color, this.dark, this.m);

  static const _yaw = 32 * math.pi / 180;
  static final _cos = math.cos(_yaw), _sin = math.sin(_yaw);
  static const _shW = 8.0, _hipW = 5.2;

  Pose _pose() {
    final n = a.frames.length;
    if (n == 1) return a.frames.first;
    final x = t * 2 * (n - 1);
    final seg = x < (n - 1) ? x : 2 * (n - 1) - x;
    final i = seg.floor().clamp(0, n - 2);
    final f = seg - i;
    final e = f < .5 ? 2 * f * f : 1 - math.pow(-2 * f + 2, 2) / 2;
    return a.frames[i].lerp(a.frames[i + 1], e.toDouble());
  }

  // world (side-plane x/y plus sideways z) -> screen point and depth
  Offset _p(_V v) => Offset(50 + (v.x - 50) * _cos - v.z * _sin, v.y);
  double _d(_V v) => (v.x - 50) * _sin + v.z * _cos;
  _V _w(Offset o, double z) => _V(o.dx, o.dy, z);

  Color _heat(String k) {
    final v = m[k] ?? 0;
    if (v <= 0) return Colors.transparent;
    final pulse = .72 + .28 * math.sin(t * 4 * math.pi);
    return (v >= 1 ? muscleMain : muscleHelp).withValues(alpha: pulse);
  }

  Color get _skin => dark ? const Color(0xFF9AA8BF) : const Color(0xFFC3CEDE);

  Color _mix(Color base, Color heat) => heat.a == 0 ? base : Color.lerp(base, heat.withValues(alpha: 1), heat.a * .85)!;

  void _capsule(Canvas c, Offset p1, Offset p2, double r1, double r2, Color base) {
    final d = p2 - p1;
    final len = d.distance;
    if (len < .01) {
      _sphere(c, p1, math.max(r1, r2), base);
      return;
    }
    final u = d / len, n = Offset(-u.dy, u.dx);
    final path = Path()
      ..moveTo((p1 + n * r1).dx, (p1 + n * r1).dy)
      ..lineTo((p2 + n * r2).dx, (p2 + n * r2).dy)
      ..arcToPoint(p2 - n * r2, radius: Radius.circular(r2), clockwise: true)
      ..lineTo((p1 - n * r1).dx, (p1 - n * r1).dy)
      ..arcToPoint(p1 + n * r1, radius: Radius.circular(r1), clockwise: true)
      ..close();
    // light comes from the upper left
    final lightSide = (n.dx * -1 + n.dy * -1) > 0 ? 1.0 : -1.0;
    final r = math.max(r1, r2);
    final mid = (p1 + p2) / 2;
    final hsl = HSLColor.fromColor(base);
    final hi = hsl.withLightness((hsl.lightness + .18).clamp(0, 1)).toColor();
    final lo = hsl.withLightness((hsl.lightness - .22).clamp(0, 1)).toColor();
    c.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(colors: [hi, base, lo], stops: const [0, .45, 1])
              .createShader(Rect.fromPoints(mid + n * r * lightSide, mid - n * r * lightSide)));
  }

  void _sphere(Canvas c, Offset o, double r, Color base) {
    final hsl = HSLColor.fromColor(base);
    final hi = hsl.withLightness((hsl.lightness + .2).clamp(0, 1)).toColor();
    final lo = hsl.withLightness((hsl.lightness - .25).clamp(0, 1)).toColor();
    c.drawCircle(
        o,
        r,
        Paint()
          ..shader = RadialGradient(center: const Alignment(-.4, -.45), radius: 1.05, colors: [hi, base, lo], stops: const [0, .5, 1])
              .createShader(Rect.fromCircle(center: o, radius: r)));
  }

  void _glow(Canvas c, Offset o, double rx, double ry, double rot, Color heat, {bool hidden = false}) {
    if (heat.a == 0) return;
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(rot);
    final rect = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
    c.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(colors: [heat.withValues(alpha: heat.a * (hidden ? .55 : .95)), heat.withValues(alpha: 0)], stops: const [.45, 1])
              .createShader(rect));
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);
    final b = _solve(_pose());
    final first = _solve(a.frames.first);
    final propCol = (dark ? Colors.white : const Color(0xFF3A4660)).withValues(alpha: dark ? .28 : .32);
    final propPaint = Paint()
      ..color = propCol
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final propFill = Paint()..color = propCol.withValues(alpha: propCol.a * .45);

    // floor and soft shadow
    final feet = [b.f1, b.f2, b.hip].map((o) => o.dx).toList();
    final fx = (feet.reduce(math.min) + feet.reduce(math.max)) / 2;
    canvas.drawOval(Rect.fromCenter(center: _p(_V(fx, 93.5, 0)), width: 46, height: 7),
        Paint()..color = (dark ? Colors.black : const Color(0xFF1B2440)).withValues(alpha: dark ? .35 : .12));

    void quad(List<_V> q, {bool fill = true}) {
      final path = Path()..moveTo(_p(q[0]).dx, _p(q[0]).dy);
      for (final v in q.skip(1)) {
        path.lineTo(_p(v).dx, _p(v).dy);
      }
      path.close();
      if (fill) canvas.drawPath(path, propFill);
      canvas.drawPath(path, propPaint);
    }

    void line(_V p1, _V p2) => canvas.drawLine(_p(p1), _p(p2), propPaint);

    // props sit behind the body (drawn first)
    switch (a.prop) {
      case Prop.chair:
        final x = first.hip.dx - 6;
        final y = math.max(first.hip.dy + 1, 70.0);
        quad([_V(x - 8, y, -8), _V(x + 10, y, -8), _V(x + 10, y, 8), _V(x - 8, y, 8)]);
        for (final z in [-8.0, 8.0]) {
          line(_V(x - 8, y, z), _V(x - 8, 93, z));
          line(_V(x + 10, y, z), _V(x + 10, 93, z));
        }
        quad([_V(x - 8, y, -8), _V(x - 10, y - 22, -8), _V(x - 10, y - 22, 8), _V(x - 8, y, 8)]);
      case Prop.wall:
        final x = math.max(first.h1.dx, first.h2.dx) + 2;
        quad([_V(x, 8, -16), _V(x, 93, -16), _V(x, 93, 16), _V(x, 8, 16)]);
      case Prop.table:
        final x = math.max(first.h1.dx, first.h2.dx);
        final y = math.max(first.h1.dy, first.h2.dy) + 1;
        quad([_V(x - 12, y, -12), _V(x + 10, y, -12), _V(x + 10, y, 12), _V(x - 12, y, 12)]);
        for (final z in [-12.0, 12.0]) {
          line(_V(x - 9, y, z), _V(x - 9, 93, z));
          line(_V(x + 7, y, z), _V(x + 7, 93, z));
        }
      case Prop.none:
        break;
    }

    // body frame
    final tv = b.neck - b.hip;
    final tu = tv / tv.distance;
    final front = Offset(-tu.dy, tu.dx); // chest side, in the side plane
    final skin = _skin;
    final parts = <_Part>[];

    for (final side in [1.0, -1.0]) {
      final near = side > 0;
      final zs = _shW * side, zh = _hipW * side;
      final sh = _w(b.neck + tu * -1.5, zs), el = _w(near ? b.e1 : b.e2, zs), ha = _w(near ? b.h1 : b.h2, zs);
      final hp = _w(b.hip, zh), kn = _w(near ? b.k1 : b.k2, zh), ft = _w(near ? b.f1 : b.f2, zh);
      final legHeat = _heat('kaki').a > 0 ? _heat('kaki') : _heat('pahaBlk');
      final armHeat = _heat('lengan');
      // leg: thigh, shin, foot
      final shinU = (Offset(ft.x, ft.y) - Offset(kn.x, kn.y));
      final su = shinU / math.max(.01, shinU.distance);
      final toe = _V(ft.x + su.dy * 6.5, ft.y - su.dx * 6.5, zh);
      parts.add(_Part((_d(hp) + _d(kn)) / 2, () {
        _capsule(canvas, _p(hp), _p(kn), 4.4, 3.4, _mix(skin, legHeat));
      }));
      parts.add(_Part((_d(kn) + _d(ft)) / 2 - .01, () {
        _capsule(canvas, _p(kn), _p(ft), 3.3, 2.4, _mix(skin, _heat('betis')));
        _sphere(canvas, _p(kn), 3.4, _mix(skin, legHeat));
      }));
      parts.add(_Part(_d(ft) + .02, () {
        _capsule(canvas, _p(ft), _p(toe), 2.6, 2.1, dark ? const Color(0xFF3B4558) : const Color(0xFF4A5670));
      }));
      // arm: upper arm, forearm, hand
      parts.add(_Part((_d(sh) + _d(el)) / 2 + .05, () {
        _capsule(canvas, _p(sh), _p(el), 2.9, 2.4, _mix(skin, armHeat));
        _sphere(canvas, _p(sh), 3.5, _mix(skin, _heat('bahu')));
      }));
      parts.add(_Part((_d(el) + _d(ha)) / 2 + .06, () {
        _capsule(canvas, _p(el), _p(ha), 2.4, 1.9, _mix(skin, armHeat.withValues(alpha: armHeat.a * .6)));
        _sphere(canvas, _p(el), 2.5, _mix(skin, armHeat));
        _sphere(canvas, _p(ha), 2.2, skin);
      }));
    }

    // torso (with chest/abs/back/glute glow) and head
    final hipC = _w(b.hip, 0), neckC = _w(b.neck, 0);
    parts.add(_Part(_d(hipC) * .5 + _d(neckC) * .5, () {
      final shL = _p(_w(b.neck + tu * -1.5, _shW)), shR = _p(_w(b.neck + tu * -1.5, -_shW));
      final hpL = _p(_w(b.hip, _hipW)), hpR = _p(_w(b.hip, -_hipW));
      final body = Path()
        ..moveTo(shL.dx, shL.dy)
        ..lineTo(shR.dx, shR.dy)
        ..lineTo(hpR.dx, hpR.dy)
        ..lineTo(hpL.dx, hpL.dy)
        ..close();
      final hsl = HSLColor.fromColor(skin);
      canvas.drawPath(body, Paint()
        ..color = hsl.withLightness((hsl.lightness - .06).clamp(0, 1)).toColor()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeJoin = StrokeJoin.round);
      canvas.drawPath(body, Paint()..color = hsl.withLightness((hsl.lightness - .06).clamp(0, 1)).toColor());
      _capsule(canvas, _p(hipC), _p(_w(b.neck + tu * -2, 0)), 5.6, 6.6, skin);
      // muscle glows in the side plane; front-facing ones are fully visible
      final rot = math.atan2(tu.dy, tu.dx) + math.pi / 2;
      final frontSeen = front.dx >= -.2; // chest turned toward the camera
      for (final z in [3.6, -3.6]) {
        _glow(canvas, _p(_w(b.neck + tu * -6 + front * 3.8, z)), 4.2, 3.6, rot, _heat('dada'), hidden: !frontSeen);
        _glow(canvas, _p(_w(b.neck + tu * -9 + front * -3.8, z)), 4.0, 7.5, rot, _heat('punggung'), hidden: frontSeen);
        _glow(canvas, _p(_w(b.hip + front * -3.6 + tu * 1, z * .9)), 4.2, 4.2, rot, _heat('bokong'), hidden: frontSeen);
      }
      _glow(canvas, _p(_w(b.hip + tu * 10 + front * 4, 0)), 3.8, 7.5, rot, _heat('inti'), hidden: !frontSeen);
      // neck and head
      final headC = _w(b.head + tu * -1, 0);
      _capsule(canvas, _p(neckC), _p(headC), 2.3, 2.3, skin);
      _sphere(canvas, _p(headC), _head, skin);
      // face direction: a small visor on the front of the head
      final visor = _p(_w(b.head + tu * -1 + front * 4.2, 0));
      canvas.drawCircle(visor, 1.6, Paint()..color = (dark ? Colors.white : const Color(0xFF2A3550)).withValues(alpha: .35));
    }));

    // dumbbells
    if (a.db || a.dbHip) {
      parts.add(_Part(99, () {
        if (a.dbHip) {
          _dumbbell(canvas, _w(b.hip + front * 2 + tu * 3, 0), vertical: false);
        } else if (a.oneDb) {
          final mid = Offset.lerp(b.h1, b.h2, .5)!;
          _dumbbell(canvas, _w(mid, 0), vertical: true);
        } else {
          _dumbbell(canvas, _w(b.h2, -_shW), vertical: false);
          _dumbbell(canvas, _w(b.h1, _shW), vertical: false);
        }
      }));
    }

    parts.sort((x, y) => x.depth.compareTo(y.depth));
    for (final p in parts) {
      p.draw();
    }
    canvas.restore();
  }

  void _dumbbell(Canvas c, _V h, {required bool vertical}) {
    final metal = dark ? const Color(0xFFD5DBE6) : const Color(0xFF2B3245);
    final a1 = vertical ? _V(h.x, h.y - 4.5, h.z) : _V(h.x, h.y, h.z + 4.5);
    final a2 = vertical ? _V(h.x, h.y + 4.5, h.z) : _V(h.x, h.y, h.z - 4.5);
    _capsule(c, _p(a1), _p(a2), .9, .9, metal);
    for (final e in [a1, a2]) {
      _sphere(c, _p(e), 2.8, metal);
    }
  }

  @override
  bool shouldRepaint(_MannequinPainter o) => o.t != t || o.a != a || o.color != color || o.dark != dark;
}
