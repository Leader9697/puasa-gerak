import 'package:flutter_test/flutter_test.dart';
import 'package:puasa_gerak/data.dart';
import 'package:puasa_gerak/logic.dart';
import 'package:puasa_gerak/ui/anim.dart';

void main() {
  test('plan simulation reaches the goal for 180 cm, 107 kg to 90 kg', () {
    final p = Profile()
      ..sex = 'm'
      ..age = 35
      ..height = 180
      ..goal = 90
      ..pKg = 107
      ..pStart = DateTime(2026, 11, 25).millisecondsSinceEpoch;
    for (final pace in paces.keys) {
      final wk = simulate(pace, p);
      expect(wk.last.kg, closeTo(90, 0.01));
      expect(wk.length, lessThan(200));
    }
    expect(simulate('cepat', p).length, lessThan(simulate('santai', p).length));
  });

  test('backup from web version restores', () {
    final d = AppData.from({
      'profile': {'height': 180, 'goal': 90, 'plan': 14},
      'fasts': [
        {'start': 0, 'end': 14 * hourMs, 'target': 14}
      ],
      'weights': [
        {'d': '2026-11-25', 'kg': 107}
      ],
      'loads': {'goblet': 12, 'bogus': 3},
      'moves': [
        {'t': 1, 'min': 20, 'name': 'Dumbbell A', 'kind': 'str'}
      ],
    });
    expect(d.profile.plan, 14);
    expect(d.fasts.single.done, isTrue);
    expect(d.loads, {'goblet': 12.0});
    expect(xpOf(d), 50 + 30 + 10 + 10);
  });

  test('level and streak helpers', () {
    expect(levelOf(0).lv, 1);
    expect(levelOf(150).lv, 2);
    expect(fmt1(107), '107,0');
    expect(kcal(2140), '2.150');
  });

  test('manual strength entry counts toward muscles and steers next suggestion', () {
    final legs = strengthSets(50, ['Kaki']);
    expect(legs['kaki'], 20);
    expect(legs['bokong'], 15);
    expect(legs.containsKey('dada'), isFalse);

    final d = AppData();
    d.profile.equip = 'db';
    // yesterday: a heavy leg day logged manually instead of the suggested cardio
    d.moves.add(Move(nowMs() - 20 * hourMs, 50, 'Angkat beban', 'str', m: legs, c: 0));
    final an = analyze(d);
    expect(an.sets['kaki'], 20);
    expect(an.fatigued('kaki'), isTrue);
    expect(an.cardioMin, 0);
    final r = recommendToday(d);
    // legs are recovering, so today's suggestion must not target them
    expect(r.focus.contains('kaki'), isFalse);
    expect(r.rest, isFalse);
  });

  test('every exercise has an animation and program moves cite a source', () {
    for (final p in programs) {
      for (final st in p.seq(3)) {
        expect(anims.containsKey(st.ex), isTrue, reason: st.ex);
      }
      for (final id in p.exIds) {
        expect(ex[id], isNotNull, reason: id);
        if (!ex[id]!.cardio && ex[id]!.m.values.any((v) => v >= 1)) expect(ex[id]!.why, isNotEmpty, reason: id);
      }
    }
  });

  test('pace locks and weigh-ins follow the plan', () {
    final d = AppData();
    d.profile
      ..sex = 'm'
      ..age = 35
      ..pKg = 107
      ..pStart = DateTime(2026, 11, 4).millisecondsSinceEpoch
      ..lock = 1;
    expect(fromMs(weighAt(d.profile, 3)).weekday, DateTime(2026, 11, 4).weekday);
    expect(fromMs(weighAt(d.profile, 3)).hour, weighHour);
    d.weights = [Weight(ymd(fromMs(weighAt(d.profile, 1))), 105.6)];
    expect(weighLogged(d, 1)!.kg, 105.6);
    expect(weighLogged(d, 2), isNull);
    final again = simulateFrom(d.profile, d.weights.last);
    expect(again.first.kg, 105.6);
  });

  test('short fasts keep the streak and suggest a fitting target', () {
    final d = AppData();
    d.profile.plan = 20;
    final now = nowMs();
    for (var i = 1; i <= 5; i++) {
      final end = now - i * dayMs;
      d.fasts.add(Fast(end - 18 * hourMs, end, 20));
    }
    d.fasts.sort((a, b) => a.end.compareTo(b.end));
    expect(d.fasts.first.done, isFalse);
    expect(d.fasts.first.kept, isTrue);
    expect(streaks(d).cur, 5);
    final f = fastFit(d);
    expect(f.suggest, 18);
    // a 15 h fast against 20 h is not enough to keep the streak
    expect(Fast(0, 15 * hourMs, 20).kept, isFalse);
  });

  test('dumbbell sessions pause to change the load between exercises', () {
    final seq = programs.firstWhere((p) => p.id == 'd1').seq(1);
    final swaps = seq.where((x) => x.swap).toList();
    expect(swaps.length, 5); // before the first move + 4 changes
    expect(swaps.skip(1).every((x) => x.sec >= 60), isTrue);
  });
}
