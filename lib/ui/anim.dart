// Looping stick-figure animation for each exercise (side view, facing right).
// Each pose is a set of joint angles; frames are interpolated, so limbs move
// naturally and the lowest body point always rests on the floor.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

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
        builder: (_, _) => CustomPaint(painter: _FigurePainter(_a, _c.value, widget.color, dark)),
      ),
    );
  }
}

class _FigurePainter extends CustomPainter {
  final Anim a;
  final double t;
  final Color color;
  final bool dark;
  _FigurePainter(this.a, this.t, this.color, this.dark);

  Pose _pose() {
    final n = a.frames.length;
    if (n == 1) return a.frames.first;
    // ping-pong through frames with ease in/out
    final x = t * 2 * (n - 1);
    final seg = x < (n - 1) ? x : 2 * (n - 1) - x;
    final i = seg.floor().clamp(0, n - 2);
    final f = seg - i;
    final e = f < .5 ? 2 * f * f : 1 - math.pow(-2 * f + 2, 2) / 2;
    return a.frames[i].lerp(a.frames[i + 1], e.toDouble());
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);
    final b = _solve(_pose());
    final propPaint = Paint()
      ..color = (dark ? Colors.white : Colors.black).withValues(alpha: .22)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // floor
    canvas.drawLine(const Offset(6, 93.5), const Offset(94, 93.5), propPaint..strokeWidth = 2);
    propPaint.strokeWidth = 3;
    final first = _solve(a.frames.first);
    switch (a.prop) {
      case Prop.chair:
        final x = first.hip.dx - 6;
        final seatY = math.max(first.hip.dy + 1, 70.0);
        canvas.drawLine(Offset(x - 8, seatY), Offset(x + 10, seatY), propPaint);
        canvas.drawLine(Offset(x - 8, seatY), Offset(x - 8, 93), propPaint);
        canvas.drawLine(Offset(x + 10, seatY), Offset(x + 10, 93), propPaint);
        canvas.drawLine(Offset(x - 8, seatY), Offset(x - 10, seatY - 22), propPaint);
      case Prop.wall:
        final x = math.max(first.h1.dx, first.h2.dx) + 2;
        canvas.drawLine(Offset(x, 10), Offset(x, 93), propPaint..strokeWidth = 4);
      case Prop.table:
        final x = math.max(first.h1.dx, first.h2.dx);
        final y = math.max(first.h1.dy, first.h2.dy) + 1;
        canvas.drawLine(Offset(x - 12, y), Offset(x + 10, y), propPaint);
        canvas.drawLine(Offset(x - 9, y), Offset(x - 9, 93), propPaint);
        canvas.drawLine(Offset(x + 7, y), Offset(x + 7, 93), propPaint);
      case Prop.none:
        break;
    }
    final far = Paint()
      ..color = color.withValues(alpha: .45)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final near = Paint()
      ..color = color
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    void limb(Paint p, Offset a1, Offset a2, Offset a3) {
      final path = Path()
        ..moveTo(a1.dx, a1.dy)
        ..lineTo(a2.dx, a2.dy)
        ..lineTo(a3.dx, a3.dy);
      canvas.drawPath(path, p..strokeJoin = StrokeJoin.round);
    }

    limb(far, b.hip, b.k2, b.f2);
    limb(far, b.neck, b.e2, b.h2);
    canvas.drawLine(b.hip, b.neck, near..strokeWidth = 7);
    near.strokeWidth = 5.5;
    limb(near, b.hip, b.k1, b.f1);
    limb(near, b.neck, b.e1, b.h1);
    canvas.drawCircle(b.head, _head, Paint()..color = color);

    final dbPaint = Paint()..color = dark ? const Color(0xFFE9EDF5) : const Color(0xFF161A2B);
    void dumbbell(Offset c, {bool vertical = false}) {
      final d = vertical ? const Offset(0, 4) : const Offset(4, 0);
      canvas.drawLine(c - d, c + d, Paint()
        ..color = dbPaint.color
        ..strokeWidth = 1.8);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c - d, width: vertical ? 6 : 3, height: vertical ? 3 : 6), const Radius.circular(1)), dbPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c + d, width: vertical ? 6 : 3, height: vertical ? 3 : 6), const Radius.circular(1)), dbPaint);
    }

    if (a.db) {
      if (a.oneDb) {
        dumbbell(Offset.lerp(b.h1, b.h2, .5)!, vertical: true);
      } else {
        dumbbell(b.h2);
        dumbbell(b.h1);
      }
    }
    if (a.dbHip) dumbbell(b.hip + const Offset(0, -4));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FigurePainter o) => o.t != t || o.a != a || o.color != color;
}
