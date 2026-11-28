import 'package:flutter_test/flutter_test.dart';
import 'package:puasa_gerak/data.dart';
import 'package:puasa_gerak/native.dart';

void main() {
  test('parsePending reads widget taps and skips junk', () {
    expect(parsePending(''), isEmpty);
    expect(parsePending('s:100;e:200;x:5;e:abc;'), [('s', 100), ('e', 200)]);
  });

  test('applyPending starts and ends fasts in order', () {
    final d = AppData();
    d.profile.plan = 16;
    expect(applyPending(d, [('s', 1000)]), isTrue);
    expect(d.active?.start, 1000);
    expect(d.active?.target, 16);

    expect(applyPending(d, [('e', 5000), ('s', 9000)]), isTrue);
    expect(d.fasts.last.start, 1000);
    expect(d.fasts.last.end, 5000);
    expect(d.active?.start, 9000);
  });

  test('applyPending ignores taps that do not fit the current state', () {
    final d = AppData();
    expect(applyPending(d, [('e', 5000)]), isFalse);
    d.active = ActiveFast(8000, 16);
    expect(applyPending(d, [('s', 9000), ('e', 7000)]), isFalse);
    expect(d.active?.start, 8000);
  });
}
