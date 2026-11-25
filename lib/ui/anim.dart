// Looping 3D character animation for each exercise, seen from a three-quarter
// angle. Each pose is a set of joint angles (side plane plus sideways
// abduction); the body is built from shaded capsules and spheres with skin,
// shirt, shorts, shoes and hair, and the muscles the exercise trains glow
// red (main) or orange (assisting).
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../logic.dart' show ex;

/// Angles in degrees: 0 = pointing down, 90 = forward (right), 180 = up, -90 = backward.
/// ab1/ab2 lift a leg sideways and aa1/aa2 an arm sideways (0 = none, 90 = straight out).
/// heel tilts the feet so the body rises onto the toes.
class Pose {
  final double trunk, th1, sh1, th2, sh2, ua1, fa1, ua2, fa2, lift;
  final double ab1, ab2, aa1, aa2, heel;
  final double fk; // how much of the arm's sideways angle the forearm follows (1 = straight arm)
  const Pose(this.trunk, this.th1, this.sh1, this.th2, this.sh2, this.ua1, this.fa1, this.ua2, this.fa2,
      [this.lift = 0, this.ab1 = 0, this.ab2 = 0, this.aa1 = 0, this.aa2 = 0, this.heel = 0, this.fk = 1]);
  const Pose.x(this.trunk, this.th1, this.sh1, this.th2, this.sh2, this.ua1, this.fa1, this.ua2, this.fa2,
      {this.lift = 0, this.ab1 = 0, this.ab2 = 0, this.aa1 = 0, this.aa2 = 0, this.heel = 0, this.fk = 1});
  Pose lerp(Pose b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return Pose(l(trunk, b.trunk), l(th1, b.th1), l(sh1, b.sh1), l(th2, b.th2), l(sh2, b.sh2), l(ua1, b.ua1), l(fa1, b.fa1),
        l(ua2, b.ua2), l(fa2, b.fa2), l(lift, b.lift), l(ab1, b.ab1), l(ab2, b.ab2), l(aa1, b.aa1), l(aa2, b.aa2), l(heel, b.heel), l(fk, b.fk));
  }
}

/// chair = seat behind the body; chairFront = chair back in front to hold;
/// bench = chair seat under hand and knee (one-arm row); footRest = chair
/// seat under the rear foot; backRest = sofa edge under the shoulders;
/// step = one stair step under the near foot.
enum Prop { none, chair, chairFront, wall, table, bench, footRest, backRest, step }

/// What stays put while the body moves: the hips (default), the feet
/// (push-ups against a wall or table), the back on the floor (lying), or the
/// near foot only (lunges, step-ups).
enum Pin { hip, feet, back, foot }

class Anim {
  final List<Pose> frames;
  final Prop prop;
  final Pin pin;
  final double pinX; // x of the pinned point (0..100)
  final bool db; // dumbbell in each hand
  final bool dbHip; // dumbbell resting on hips
  final bool oneDb; // single dumbbell held with both hands
  final bool bag; // backpack held with both hands
  final double secs; // seconds per full cycle
  const Anim(this.frames,
      {this.prop = Prop.none, this.pin = Pin.hip, this.pinX = 50, this.db = false, this.dbHip = false, this.oneDb = false, this.bag = false, this.secs = 2.4});
}

const _stand = Pose(180, 0, 0, 0, 0, 0, 0, 0, 0);
// on the back (head to the left), knees bent, arms by the side
const _lie = Pose(-90, 135, 15, 135, 15, 90, 90, 90, 90);

const anims = <String, Anim>{
  'march': Anim([Pose(180, 70, 0, 0, 0, -35, 50, 35, 90), Pose(180, 0, 0, 70, 0, 35, 90, -35, 50)], secs: 1.2),
  // hands stay on the wall, body leans in
  'wallpush': Anim([Pose(160, -20, -20, -20, -20, 80, 80, 80, 80), Pose(150, -30, -30, -30, -30, 40, 145, 40, 145)],
      prop: Prop.wall, pin: Pin.feet, pinX: 26),
  'sitstand': Anim([Pose(160, 88, 0, 88, 0, 80, 85, 80, 85), Pose(180, 0, 0, 0, 0, 85, 90, 85, 90)], prop: Prop.chair, secs: 3),
  // step out to the side, arms swing out
  'sidestep': Anim([
    Pose.x(175, 10, -5, 10, -5, 0, 20, 0, 20, ab1: 22, aa1: 35, aa2: 35),
    Pose.x(175, 10, -5, 10, -5, 0, 20, 0, 20, ab2: 22, aa1: 35, aa2: 35),
  ], secs: 1.4),
  'bridge': Anim([_lie, Pose(-60, 110, 5, 110, 5, 70, 70, 70, 70)], pin: Pin.back, pinX: 46, secs: 2.8),
  // backpack pulled to the belly
  'row': Anim([Pose(130, 15, -10, 15, -10, 0, 0, 0, 0), Pose(130, 15, -10, 15, -10, -55, 45, -55, 45)], bag: true),
  'birddog': Anim([Pose(90, 0, -90, 0, -90, 0, 0, 0, 0), Pose(90, 0, -90, -90, -90, 92, 92, 0, 0)], secs: 3),
  // knee up toward the opposite elbow
  'knee': Anim([
    Pose(180, 0, 0, 0, 0, 130, -99, 130, -99),
    Pose(168, 95, 0, 0, 0, 130, -99, 70, -135),
  ], secs: 1.2),
  // one foot steps to the side as both arms go overhead (no jump)
  'stepjack': Anim([
    Pose.x(180, 0, 0, 0, 0, 0, 0, 0, 0, aa1: 5, aa2: 5),
    Pose.x(180, 0, 0, 0, 0, 0, 0, 0, 0, ab1: 28, aa1: 165, aa2: 165),
    Pose.x(180, 0, 0, 0, 0, 0, 0, 0, 0, aa1: 5, aa2: 5),
    Pose.x(180, 0, 0, 0, 0, 0, 0, 0, 0, ab2: 28, aa1: 165, aa2: 165),
  ], secs: 2.4),
  'box': Anim([Pose(175, 15, -5, -15, -15, 90, 90, 25, 150), Pose(175, 15, -5, -15, -15, 25, 150, 90, 90)], secs: .8),
  'squatpulse': Anim([Pose(155, 85, -10, 85, -10, 80, 85, 80, 85), Pose(180, 0, 0, 0, 0, 80, 85, 80, 85)], prop: Prop.chair, secs: 1.4),
  // hold the chair back, rise onto the toes
  'calf': Anim([Pose.x(180, 0, 0, 0, 0, 40, 80, 40, 80), Pose.x(180, 0, 0, 0, 0, 40, 80, 40, 80, heel: 42)], prop: Prop.chairFront, secs: 2),
  // quad stretch (hand holds foot) then hamstring fold
  'stretch': Anim([Pose(180, 0, 0, -12, -170, 0, 0, -15, -15), Pose(110, -5, -5, -5, -5, 8, 8, 8, 8)], secs: 6),
  'goblet': Anim([Pose(180, 0, 0, 0, 0, 25, 165, 25, 165), Pose(150, 85, -20, 85, -20, 30, 165, 30, 165)], prop: Prop.chair, db: true, oneDb: true, secs: 3),
  'floorpress': Anim([Pose.x(-90, 135, 15, 135, 15, 180, 180, 180, 180), Pose.x(-90, 135, 15, 135, 15, 0, 180, 0, 180, aa1: 70, aa2: 70, fk: 0)],
      pin: Pin.back, pinX: 46, db: true, secs: 2.6),
  // one hand and one knee on the chair seat, other arm rows
  'row1': Anim([Pose(98, 15, 0, 0, -90, 0, 0, 40, 30), Pose(98, 15, 0, 0, -90, -60, 45, 40, 30)], prop: Prop.bench, pinX: 42, db: true),
  'rdl': Anim([Pose(180, 0, 0, 0, 0, 5, 5, 5, 5), Pose(110, -12, 5, -12, 5, 2, 2, 2, 2)], db: true, secs: 3),
  'carry': Anim([Pose(180, 40, 0, 0, 0, 0, 0, 0, 0), Pose(180, 0, 0, 40, 0, 0, 0, 0, 0)], db: true, secs: 1.6),
  'sumo': Anim([Pose.x(180, 0, 0, 0, 0, 0, 0, 0, 0, ab1: 25, ab2: 25), Pose.x(170, 40, -20, 40, -20, 5, 5, 5, 5, ab1: 40, ab2: 40)],
      db: true, oneDb: true, secs: 3),
  'ohp': Anim([Pose(180, 90, 0, 90, 0, 30, 175, 30, 175), Pose(180, 90, 0, 90, 0, 178, 178, 178, 178)], prop: Prop.chair, db: true, secs: 2.4),
  'row2': Anim([Pose(135, 15, -10, 15, -10, 0, 0, 0, 0), Pose(135, 15, -10, 15, -10, -55, 45, -55, 45)], db: true),
  'dbbridge': Anim([_lie, Pose(-60, 110, 5, 110, 5, 70, 70, 70, 70)], pin: Pin.back, pinX: 46, dbHip: true, secs: 2.8),
  'curl': Anim([_stand, Pose(180, 0, 0, 0, 0, 5, 160, 5, 160)], db: true),
  'splitsquat': Anim([Pose(180, 30, -5, -25, -25, 0, 0, 0, 0), Pose(180, 80, -10, -10, -85, 0, 0, 0, 0)], db: true, secs: 3),
  // hands stay on the table edge, body lowers toward it
  'incline': Anim([Pose(140, -40, -40, -40, -40, 50, 50, 50, 50), Pose(130, -50, -50, -50, -50, 106, -4, 106, -4)],
      prop: Prop.table, pin: Pin.feet, pinX: 16),
  // on the back: arms up, knees 90 deg; opposite arm and leg reach out
  'deadbug': Anim([
    Pose(-90, 180, 90, 180, 90, 180, 180, 180, 180),
    Pose(-90, 180, 90, 100, 100, -100, -100, 180, 180),
    Pose(-90, 180, 90, 180, 90, 180, 180, 180, 180),
    Pose(-90, 100, 100, 180, 90, 180, 180, -100, -100),
  ], pin: Pin.back, pinX: 50, secs: 4),
  // ---- harder rungs ----
  // knees on the floor, body straight from knee to head; hands stay put
  'kneepush': Anim([Pose(127.7, -52.3, -100, -52.3, -100, 0, 0, 0, 0), Pose(102, -78, -100, -78, -100, -101, 24.7, -101, 24.7)],
      pin: Pin.feet, pinX: 18, secs: 2.6),
  'pushup': Anim([Pose(115.1, -64.9, -64.9, -64.9, -64.9, 0, 0, 0, 0), Pose(102, -78, -78, -78, -78, -74.7, 42.8, -74.7, 42.8)],
      pin: Pin.feet, pinX: 16, secs: 2.6),
  'squat': Anim([Pose(180, 0, 0, 0, 0, 90, 90, 90, 90), Pose(145, 95, -25, 95, -25, 90, 90, 90, 90)], pin: Pin.feet, secs: 3),
  'rlunge': Anim([Pose(180, 0, 0, 0, 0, 10, 10, 10, 10), Pose(178, 80, -10, -25, -80, 10, 10, 10, 10)], pin: Pin.foot, pinX: 58, secs: 3),
  'gobletfull': Anim([Pose(180, 0, 0, 0, 0, 25, 165, 25, 165), Pose(155, 105, -30, 105, -30, 25, 165, 25, 165)],
      pin: Pin.feet, db: true, oneDb: true, secs: 3.2),
  // rear foot on a chair seat, front foot planted; hips drop straight down
  'bulgarian': Anim([Pose(178, 22.8, 10.6, -14.5, -99.1, 0, 0, 0, 0), Pose(174, 75.3, -20.4, -32.1, -138.8, 0, 0, 0, 0)],
      prop: Prop.footRest, pin: Pin.foot, pinX: 62, db: true, secs: 3.2),
  'slbridge': Anim([Pose(-90, 135, 15, 95, 95, 90, 90, 90, 90), Pose(-60, 110, 5, 120, 120, 70, 70, 70, 70)], pin: Pin.back, pinX: 46, secs: 2.8),
  // shoulders on the sofa edge, feet planted; hips drop then drive up
  'hipthrust': Anim([Pose(-90, 90, 0, 90, 0, 105.7, 85.7, 105.7, 85.7), Pose(-110.9, 117.2, 11.4, 117.2, 11.4, 94.8, 56.8, 94.8, 56.8)],
      prop: Prop.backRest, pin: Pin.feet, pinX: 70, dbHip: true, secs: 2.8),
  'plank': Anim([Pose(102.6, -77.4, -77.4, -77.4, -77.4, 0, 90, 0, 90), Pose(103.4, -76.6, -76.6, -76.6, -76.6, 0, 90, 0, 90)],
      pin: Pin.feet, pinX: 22, secs: 3),
  'ohps': Anim([Pose(180, 0, 0, 0, 0, 30, 175, 30, 175), Pose(180, 0, 0, 0, 0, 178, 178, 178, 178)], db: true, secs: 2.4),
  // near foot on the step, then stand on it with the other knee up
  'stepup': Anim([Pose(178, 60, -5, 0, 0, -20, 20, 30, 70), Pose.x(180, 0, 0, 70, 0, 30, 70, -20, 20, lift: 10.6)],
      prop: Prop.step, pin: Pin.foot, pinX: 56, secs: 1.4),
};

const _lTrunk = 28.0, _lThigh = 21.0, _lShin = 21.0, _lUa = 15.0, _lFa = 14.0, _head = 6.3, _lFoot = 6.5;
const _shW = 7.5, _hipW = 4.8;

class _V {
  final double x, y, z;
  const _V(this.x, this.y, this.z);
  _V operator +(_V o) => _V(x + o.x, y + o.y, z + o.z);
  _V operator -(_V o) => _V(x - o.x, y - o.y, z - o.z);
  _V operator *(double k) => _V(x * k, y * k, z * k);
  Offset get xy => Offset(x, y);
  _V lerp(_V o, double t) => this + (o - this) * t;
}

/// Unit direction from a side-plane angle and a sideways (abduction) angle.
_V _d3(double a, double ab, double side) {
  final r = a * math.pi / 180, b = ab * math.pi / 180;
  return _V(math.sin(r) * math.cos(b), math.cos(r) * math.cos(b), side * math.sin(b));
}

class _J {
  final _V hip, neck, head;
  final List<_V> hp, sh, kn, ft, toe, el, ha; // [near, far]
  _J(this.hip, this.neck, this.head, this.hp, this.sh, this.kn, this.ft, this.toe, this.el, this.ha);
  Iterable<_V> get all => [hip, neck, head, ...kn, ...ft, ...toe, ...el, ...ha];
  _J shift(double dx, double dy) {
    final d = _V(dx, dy, 0);
    List<_V> m(List<_V> l) => [for (final v in l) v + d];
    return _J(hip + d, neck + d, head + d, m(hp), m(sh), m(kn), m(ft), m(toe), m(el), m(ha));
  }
}

const _floor = 91.5; // centre line of feet / back resting on the floor

_J _solve(Pose p, Anim a) {
  const hip = _V(0, 0, 0);
  final t = _d3(p.trunk, 0, 0);
  final neck = hip + t * _lTrunk;
  final head = neck + t * (_head + 2.2);
  final hp = <_V>[], sh = <_V>[], kn = <_V>[], ft = <_V>[], toe = <_V>[], el = <_V>[], ha = <_V>[];
  for (final side in [1.0, -1.0]) {
    final n = side > 0;
    final h = _V(0, 0, _hipW * side);
    final s = neck + t * -1.6 + _V(0, 0, _shW * side);
    final k = h + _d3(n ? p.th1 : p.th2, n ? p.ab1 : p.ab2, side) * _lThigh;
    final f = k + _d3(n ? p.sh1 : p.sh2, n ? p.ab1 : p.ab2, side) * _lShin;
    // foot points forward, perpendicular to the shin; heel lifts it toward the floor
    final su = (f - k) * (1 / _lShin);
    final fwd = _V(su.y, -su.x, 0), down = su;
    final hr = p.heel * math.pi / 180;
    final tp = f + (fwd * math.cos(hr) + down * math.sin(hr)) * _lFoot;
    final e = s + _d3(n ? p.ua1 : p.ua2, n ? p.aa1 : p.aa2, side) * _lUa;
    final w = e + _d3(n ? p.fa1 : p.fa2, (n ? p.aa1 : p.aa2) * p.fk, side) * _lFa;
    hp.add(h);
    sh.add(s);
    kn.add(k);
    ft.add(f);
    toe.add(tp);
    el.add(e);
    ha.add(w);
  }
  var j = _J(hip, neck, head, hp, sh, kn, ft, toe, el, ha);
  double dy;
  if (a.pin == Pin.back) {
    // the lower of hip / shoulders rests on the floor
    dy = (_floor - 4.5) - math.max(j.hip.y, j.neck.y);
  } else {
    final lowest = j.all.map((v) => v.y).reduce(math.max);
    dy = _floor - lowest - p.lift;
  }
  final px = switch (a.pin) {
    Pin.feet => (j.ft[0].x + j.ft[1].x) / 2,
    Pin.foot => j.ft[0].x,
    _ => j.hip.x,
  };
  return j.shift(a.pinX - px, dy);
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

  static const _skin = Color(0xFFE0A47E);
  static const _shorts = Color(0xFF2E3650);
  static const _hair = Color(0xFF2A1C15);
  static const _shoe = Color(0xFFEDEFF4);

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

  // world -> screen (three-quarter view) and depth (larger = closer)
  Offset _p(_V v) => Offset(50 + (v.x - 50) * _cos - v.z * _sin, v.y);
  double _d(_V v) => (v.x - 50) * _sin + v.z * _cos;

  Color _heat(String k) {
    final v = m[k] ?? 0;
    if (v <= 0) return Colors.transparent;
    final pulse = .7 + .3 * math.sin(t * 4 * math.pi);
    return (v >= 1 ? muscleMain : muscleHelp).withValues(alpha: pulse);
  }

  Color _shade(Color c, double dl) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness + dl).clamp(0.0, 1.0)).toColor();
  }

  Path _capPath(Offset p1, Offset p2, double r1, double r2) {
    final d = p2 - p1;
    final len = math.max(.01, d.distance);
    final u = d / len, n = Offset(-u.dy, u.dx);
    return Path()
      ..moveTo((p1 + n * r1).dx, (p1 + n * r1).dy)
      ..lineTo((p2 + n * r2).dx, (p2 + n * r2).dy)
      ..arcToPoint(p2 - n * r2, radius: Radius.circular(r2), clockwise: false)
      ..lineTo((p1 - n * r1).dx, (p1 - n * r1).dy)
      ..arcToPoint(p1 + n * r1, radius: Radius.circular(r1), clockwise: false)
      ..close();
  }

  void _capsule(Canvas c, Offset p1, Offset p2, double r1, double r2, Color base) {
    if ((p2 - p1).distance < .01) {
      _sphere(c, p1, math.max(r1, r2), base);
      return;
    }
    final d = p2 - p1;
    final u = d / d.distance, n = Offset(-u.dy, u.dx);
    final lightSide = (-n.dx - n.dy) > 0 ? 1.0 : -1.0; // light from upper left
    final r = math.max(r1, r2), mid = (p1 + p2) / 2;
    c.drawPath(
        _capPath(p1, p2, r1, r2),
        Paint()
          ..shader = LinearGradient(colors: [_shade(base, .14), base, _shade(base, -.2)], stops: const [0, .42, 1])
              .createShader(Rect.fromPoints(mid + n * r * lightSide, mid - n * r * lightSide)));
  }

  void _sphere(Canvas c, Offset o, double r, Color base) {
    c.drawCircle(
        o,
        r,
        Paint()
          ..shader = RadialGradient(center: const Alignment(-.4, -.45), radius: 1.05, colors: [_shade(base, .16), base, _shade(base, -.22)], stops: const [0, .5, 1])
              .createShader(Rect.fromCircle(center: o, radius: r)));
  }

  /// Red/orange tint laid over a limb segment.
  void _heatCap(Canvas c, Offset p1, Offset p2, double r1, double r2, Color heat) {
    if (heat.a == 0) return;
    c.drawPath(_capPath(p1, p2, r1 * .92, r2 * .92), Paint()..color = heat.withValues(alpha: heat.a * .72));
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
          ..shader = RadialGradient(colors: [heat.withValues(alpha: heat.a * (hidden ? .5 : .9)), heat.withValues(alpha: 0)], stops: const [.5, 1])
              .createShader(rect));
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);
    final p = _pose();
    final b = _solve(p, a);
    final first = _solve(a.frames.first, a);
    final propCol = (dark ? Colors.white : const Color(0xFF3A4660)).withValues(alpha: dark ? .3 : .34);
    final propPaint = Paint()
      ..color = propCol
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final propFill = Paint()..color = propCol.withValues(alpha: propCol.a * .45);

    // shadow under the body
    final xs = [b.ft[0].x, b.ft[1].x, b.hip.x, b.neck.x];
    final fx = (xs.reduce(math.min) + xs.reduce(math.max)) / 2;
    canvas.drawOval(Rect.fromCenter(center: _p(_V(fx, 94, 0)), width: 52, height: 7),
        Paint()..color = (dark ? Colors.black : const Color(0xFF1B2440)).withValues(alpha: dark ? .35 : .12));

    void quad(List<_V> q) {
      final path = Path()..moveTo(_p(q[0]).dx, _p(q[0]).dy);
      for (final v in q.skip(1)) {
        path.lineTo(_p(v).dx, _p(v).dy);
      }
      path.close();
      canvas.drawPath(path, propFill);
      canvas.drawPath(path, propPaint);
    }

    void line(_V p1, _V p2) => canvas.drawLine(_p(p1), _p(p2), propPaint);
    void legs(double x0, double x1, double y, double zw) {
      for (final z in [-zw, zw]) {
        line(_V(x0, y, z), _V(x0, 93.5, z));
        line(_V(x1, y, z), _V(x1, 93.5, z));
      }
    }

    switch (a.prop) {
      case Prop.chair:
        final x = first.hip.x - 6;
        final y = math.max(first.hip.y + 5, 70.0);
        quad([_V(x - 8, y, -9), _V(x + 10, y, -9), _V(x + 10, y, 9), _V(x - 8, y, 9)]);
        legs(x - 8, x + 10, y, 9);
        quad([_V(x - 8, y, -9), _V(x - 10, y - 22, -9), _V(x - 10, y - 22, 9), _V(x - 8, y, 9)]);
      case Prop.chairFront:
        final hx = (first.ha[0].x + first.ha[1].x) / 2 + 2, hy = (first.ha[0].y + first.ha[1].y) / 2 + 1;
        const seat = 70.0;
        quad([_V(hx, hy, -9), _V(hx + 1.5, seat, -9), _V(hx + 1.5, seat, 9), _V(hx, hy, 9)]);
        quad([_V(hx + 1.5, seat, -9), _V(hx + 19, seat, -9), _V(hx + 19, seat, 9), _V(hx + 1.5, seat, 9)]);
        legs(hx + 1.5, hx + 19, seat, 9);
      case Prop.wall:
        final x = (first.ha[0].x + first.ha[1].x) / 2 + 2.2;
        quad([_V(x, 6, -18), _V(x, 93.5, -18), _V(x, 93.5, 18), _V(x, 6, 18)]);
      case Prop.table:
        final x = (first.ha[0].x + first.ha[1].x) / 2;
        final y = (first.ha[0].y + first.ha[1].y) / 2 + 2.2;
        quad([_V(x - 10, y, -14), _V(x + 14, y, -14), _V(x + 14, y, 14), _V(x - 10, y, 14)]);
        legs(x - 7, x + 11, y, 12);
      case Prop.bench:
        final x0 = first.kn[1].x - 6, x1 = first.ha[1].x + 6;
        final y = math.max(first.kn[1].y + 3.4, first.ha[1].y + 2.2);
        quad([_V(x0, y, -11), _V(x1, y, -11), _V(x1, y, 3), _V(x0, y, 3)]);
        legs(x0 + 1, x1 - 1, y, 9);
      case Prop.footRest:
        final f = first.ft[1];
        final y = f.y + 2.2;
        quad([_V(f.x - 10, y, -9), _V(f.x + 8, y, -9), _V(f.x + 8, y, 9), _V(f.x - 10, y, 9)]);
        legs(f.x - 9, f.x + 7, y, 9);
      case Prop.backRest:
        final x = first.neck.x;
        final y = first.neck.y + 5;
        quad([_V(x - 18, y, -14), _V(x + 4, y, -14), _V(x + 4, y, 14), _V(x - 18, y, 14)]);
        quad([_V(x + 4, y, -14), _V(x + 4, 93.5, -14), _V(x + 4, 93.5, 14), _V(x + 4, y, 14)]);
      case Prop.step:
        final f = first.ft[0];
        final y = f.y + 2;
        quad([_V(f.x - 7, y, -12), _V(f.x + 12, y, -12), _V(f.x + 12, y, 12), _V(f.x - 7, y, 12)]);
        quad([_V(f.x - 7, y, -12), _V(f.x - 7, 93.5, -12), _V(f.x - 7, 93.5, 12), _V(f.x - 7, y, 12)]);
      case Prop.none:
        break;
    }

    final tv = b.neck - b.hip;
    final tl = math.max(.01, tv.xy.distance);
    final tu = tv * (1 / tl); // trunk direction (hip -> neck), side plane
    final front = _V(-tu.y, tu.x, 0); // chest side
    final shirt = color;
    final parts = <_Part>[];

    for (final i in [0, 1]) {
      final hp = b.hp[i], kn = b.kn[i], ft = b.ft[i], toe = b.toe[i];
      final sh = b.sh[i], el = b.el[i], ha = b.ha[i];
      final legHeat = _heat('kaki').a > 0 ? _heat('kaki') : _heat('pahaBlk');
      final armHeat = _heat('lengan');
      // thigh with shorts over the top half
      parts.add(_Part((_d(hp) + _d(kn)) / 2, () {
        _capsule(canvas, _p(hp), _p(kn), 4.5, 3.4, _skin);
        _capsule(canvas, _p(hp), _p(hp.lerp(kn, .55)), 5.0, 4.3, _shorts);
        _heatCap(canvas, _p(hp), _p(kn), 4.5, 3.4, legHeat);
      }));
      // shin, knee, shoe
      parts.add(_Part((_d(kn) + _d(ft)) / 2 - .01, () {
        _capsule(canvas, _p(kn), _p(ft), 3.3, 2.3, _skin);
        _heatCap(canvas, _p(kn), _p(ft), 3.3, 2.3, _heat('betis'));
        _sphere(canvas, _p(kn), 3.4, _skin);
        _heatCap(canvas, _p(kn), _p(kn), 3.4, 3.4, legHeat);
      }));
      parts.add(_Part(_d(ft) + .02, () {
        _capsule(canvas, _p(ft), _p(toe), 2.6, 2.2, _shoe);
        canvas.drawPath(_capPath(_p(ft), _p(toe), 2.6, 2.2),
            Paint()
              ..color = _shade(_shoe, -.45)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .5);
      }));
      // upper arm with sleeve, forearm, hand
      parts.add(_Part((_d(sh) + _d(el)) / 2 + .05, () {
        _capsule(canvas, _p(sh), _p(el), 3.0, 2.4, _skin);
        _heatCap(canvas, _p(sh), _p(el), 3.0, 2.4, armHeat);
        _capsule(canvas, _p(sh), _p(sh.lerp(el, .45)), 3.6, 3.2, shirt);
        _sphere(canvas, _p(sh), 3.7, shirt);
        _heatCap(canvas, _p(sh), _p(sh), 3.7, 3.7, _heat('bahu'));
      }));
      parts.add(_Part((_d(el) + _d(ha)) / 2 + .06, () {
        _capsule(canvas, _p(el), _p(ha), 2.4, 1.9, _skin);
        _sphere(canvas, _p(el), 2.4, _skin);
        _heatCap(canvas, _p(el), _p(el), 2.4, 2.4, armHeat);
        _sphere(canvas, _p(ha), 2.2, _shade(_skin, -.03));
      }));
    }

    // torso: shirt, shorts at the waist, muscle glows, neck and head
    parts.add(_Part((_d(b.hip) + _d(b.neck)) / 2, () {
      final shL = _p(b.sh[0]), shR = _p(b.sh[1]);
      final hpL = _p(b.hp[0]), hpR = _p(b.hp[1]);
      final body = Path()
        ..moveTo(shL.dx, shL.dy)
        ..lineTo(shR.dx, shR.dy)
        ..lineTo(hpR.dx, hpR.dy)
        ..lineTo(hpL.dx, hpL.dy)
        ..close();
      final sd = _shade(shirt, -.08);
      canvas.drawPath(body, Paint()
        ..color = sd
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.5
        ..strokeJoin = StrokeJoin.round);
      canvas.drawPath(body, Paint()..color = sd);
      final chest = b.neck + tu * -5;
      _capsule(canvas, _p(b.hip + tu * 3), _p(chest), 5.4, 6.6, shirt);
      final waist = Paint()..color = _shorts;
      canvas.drawPath(_capPath(_p(b.hp[0]), _p(b.hp[1]), 4.9, 4.9), waist);
      canvas.drawPath(_capPath(_p(b.hip), _p(b.hip + tu * 4), 5.6, 5.6), waist);
      // muscle glows; ones on the far side of the body show fainter
      final rot = math.atan2(_p(b.neck).dy - _p(b.hip).dy, _p(b.neck).dx - _p(b.hip).dx) + math.pi / 2;
      final frontSeen = front.x >= -.2;
      for (final z in [3.4, -3.4]) {
        _glow(canvas, _p(b.neck + tu * -6 + front * 3.8 + _V(0, 0, z)), 4.0, 3.4, rot, _heat('dada'), hidden: !frontSeen);
        _glow(canvas, _p(b.neck + tu * -10 + front * -3.8 + _V(0, 0, z)), 3.8, 7.5, rot, _heat('punggung'), hidden: frontSeen);
        _glow(canvas, _p(b.hip + front * -3.6 + tu * 1 + _V(0, 0, z * .9)), 4.2, 4.2, rot, _heat('bokong'), hidden: frontSeen);
      }
      _glow(canvas, _p(b.hip + tu * 10 + front * 4), 3.8, 7.5, rot, _heat('inti'), hidden: !frontSeen);
      // neck
      final hc = b.head;
      _capsule(canvas, _p(b.neck + tu * -1), _p(b.neck + tu * 3), 2.4, 2.3, _skin);
      // head: hair at the back and top, face toward the front, ear, nose
      _sphere(canvas, _p(hc + tu * .9 + front * -1.1), _head * .98, _hair);
      _sphere(canvas, _p(hc + front * .5 + tu * -.4), _head * .9, _skin);
      _sphere(canvas, _p(hc + tu * 1.9 + front * -1.4), _head * .7, _hair);
      _sphere(canvas, _p(hc + _V(0, 0, _head * .82) + front * -.6), 1.3, _shade(_skin, -.05));
      _sphere(canvas, _p(hc + front * (_head * .95) + tu * -.6), 1.1, _shade(_skin, -.04));
    }));

    // what the hands hold
    if (a.db || a.dbHip || a.bag) {
      parts.add(_Part(99, () {
        if (a.bag) {
          final mid = b.ha[0].lerp(b.ha[1], .5) + _V(0, 5.5, 0);
          final o = _p(mid);
          final r = RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 11, height: 12), const Radius.circular(3));
          canvas.drawRRect(
              r,
              Paint()
                ..shader = const LinearGradient(colors: [Color(0xFF3E8E7E), Color(0xFF23594E)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    .createShader(r.outerRect));
          canvas.drawLine(o + const Offset(-3.5, -6), o + const Offset(3.5, -6), Paint()
            ..color = const Color(0xFF1C463E)
            ..strokeWidth = 1.2);
        } else if (a.dbHip) {
          _dumbbell(canvas, b.hip + front * 2.5 + tu * 3, true);
        } else if (a.oneDb) {
          final mid = b.ha[0].lerp(b.ha[1], .5);
          _dumbbell(canvas, mid, false, vertical: true);
        } else {
          _dumbbell(canvas, b.ha[1], true);
          _dumbbell(canvas, b.ha[0], true);
        }
      }));
    }

    parts.sort((x, y) => x.depth.compareTo(y.depth));
    for (final pt in parts) {
      pt.draw();
    }
    canvas.restore();
  }

  void _dumbbell(Canvas c, _V h, bool sideways, {bool vertical = false}) {
    final metal = dark ? const Color(0xFFC9D0DC) : const Color(0xFF2B3245);
    final axis = vertical ? const _V(0, 1, 0) : const _V(0, 0, 1);
    final a1 = h + axis * 4.6, a2 = h - axis * 4.6;
    final s1 = _p(a1), s2 = _p(a2);
    _capsule(c, s1, s2, .8, .8, _shade(metal, .15));
    final d = s2 - s1;
    final ang = math.atan2(d.dy, d.dx);
    for (final e in [s1, s2]) {
      c.save();
      c.translate(e.dx, e.dy);
      c.rotate(ang);
      final r = Rect.fromCenter(center: Offset.zero, width: 2.6, height: 7.2);
      c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(1.2)),
          Paint()
            ..shader = LinearGradient(colors: [_shade(metal, .2), metal, _shade(metal, -.15)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                .createShader(r));
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_MannequinPainter o) => o.t != t || o.a != a || o.color != color || o.dark != dark;
}
