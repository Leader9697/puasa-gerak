import 'package:flutter_test/flutter_test.dart';
import 'package:puasa_gerak/data.dart';
import 'package:puasa_gerak/logic.dart';

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
}
