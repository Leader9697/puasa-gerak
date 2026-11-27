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

  test('every exercise has an animation and a research source', () {
    for (final id in ex.keys) {
      expect(anims.containsKey(id), isTrue, reason: id);
      expect(ex[id]!.why, isNotEmpty, reason: id);
    }
    for (final l in ladders.entries) {
      expect(l.value.first.id, l.key);
      for (final r in l.value) {
        expect(ex[r.id], isNotNull, reason: r.id);
        if (ex[r.id]!.range != null) expect(exKeys.contains(r.id), isTrue, reason: r.id);
      }
    }
  });

  test('ladders climb with level and lower body weight, and can step down', () {
    final d = AppData()..weights = [Weight('2026-11-25', 107)];
    syncLadder(d);
    final p2 = programs.firstWhere((p) => p.id == 'p2');
    expect(p2.exIdsAt(1), contains('wallpush'));
    expect(p2.exIdsAt(2), containsAll(['incline', 'squat', 'slbridge']));
    // level 3 at BMI 33: knee push-up, not a full push-up yet
    expect(p2.exIdsAt(3), contains('kneepush'));
    expect(nextRungTxt('wallpush', 3), contains('BMI di bawah 30'));
    d.weights.add(Weight('2027-06-01', 96));
    syncLadder(d);
    expect(p2.exIdsAt(3), contains('pushup'));
    d.down['wallpush'] = 1;
    syncLadder(d);
    expect(p2.exIdsAt(3), contains('kneepush'));
    final st = p2.seq(3).firstWhere((x) => x.ex == 'kneepush');
    expect(st.root, 'wallpush');
    final back = AppData.from(d.toJson());
    expect(back.down, {'wallpush': 1});
    syncLadder(AppData());
  });

  test('every program move has an animation', () {
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
    expect(swaps.length, 4); // before the first move + 3 changes (deadbug has no load)
    expect(swaps.skip(1).every((x) => x.sec >= 60), isTrue);
  });

  test('strength sets count reps, one-side moves run right then left', () {
    syncLadder(AppData());
    final d1 = programs.firstWhere((p) => p.id == 'd1').seq(1);
    final goblet = d1.firstWhere((x) => x.ex == 'goblet' && x.type == 'work');
    expect(goblet.reps, 10);
    final row = d1.where((x) => x.ex == 'row1' && x.type == 'work').toList();
    expect(row.length, 6); // 3 sets x 2 sides
    expect(row.take(2).map((x) => x.side), ['kanan', 'kiri']);
    // one side does not count as an extra set
    expect(programs.firstWhere((p) => p.id == 'd1').musclesAt(1)['punggung'], 3);
    // cardio intervals stay timed
    expect(programs.firstWhere((p) => p.id == 'p3').seq(1).where((x) => x.type == 'work').every((x) => x.reps == null), isTrue);
    // a single dumbbell turns two-hand moves into one arm at a time
    final one = AppData()..gear.count = 1;
    syncLadder(one);
    expect(programs.firstWhere((p) => p.id == 'd1').seq(1).where((x) => x.ex == 'floorpress' && x.type == 'work').first.side, 'kanan');
    syncLadder(AppData());
  });

  test('each dumbbell day has one leg pattern and days rotate A B C', () {
    const legs = {'goblet', 'gobletfull', 'rdl', 'splitsquat', 'bulgarian', 'sitstand', 'squat', 'rlunge', 'sumo', 'dbbridge', 'hipthrust'};
    for (final p in programs.where((p) => p.db)) {
      for (final l in [1, 2, 3]) {
        expect(p.exIdsAt(l).where(legs.contains).length, 1, reason: '${p.id} L$l');
      }
    }
    final p = Profile()
      ..equip = 'db'
      ..days = 4;
    final w0 = sessionTypes(p, 2, 0).whereType<String>().where((x) => x.startsWith('d')).toList();
    final w1 = sessionTypes(p, 2, 1).whereType<String>().where((x) => x.startsWith('d')).toList();
    expect([...w0, ...w1], ['d1', 'd2', 'd3', 'd1']);
  });

  test('loads snap to the plates and plate changes stay small', () {
    final g = Gear()..handle = 1.5;
    final l = dbLoads(g);
    expect(l.first, 1.5);
    expect(l.contains(4.5), isTrue); // 1.5 + 2 x 1.5
    expect(snapLoad(12, g), anyOf(11.5, 12.5));
    expect(_sum(sidePlates(9.5, const [], g)), 4);
    // 9.5 -> 6.5 kg: the session plan loads 9.5 as 2.5 + 1.5 so the next
    // move only needs one plate off
    final d = AppData()
      ..gear = g
      ..loads = {'goblet': 9.5, 'row1': 6.5};
    syncLadder(d);
    final plan = platePlan(programs.firstWhere((p) => p.id == 'd1').seq(1), d);
    expect(plan[0].side, [2.5, 1.5]);
    expect(plan[1].change, 'Lepas 1,5 kg di tiap sisi');
    syncLadder(AppData());
  });

  test('forecast is slower with adaptation, exercise compensation and partial adherence', () {
    final p = Profile()
      ..sex = 'm'
      ..age = 35
      ..height = 180
      ..goal = 90
      ..pKg = 107
      ..pStart = DateTime(2026, 11, 25).millisecondsSinceEpoch;
    final full = simulate('sedang', p), real = simulate('sedang', p, adh: .75);
    expect(real.length, greaterThan(full.length));
    // average loss stays within the usual 0.5-1 kg/week guidance
    final perWk = 17 / (full.length - 1);
    expect(perWk, inInclusiveRange(.4, 1.0));
  });
}

double _sum(List<double> l) => l.fold(0.0, (a, b) => a + b);
