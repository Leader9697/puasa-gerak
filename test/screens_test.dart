import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puasa_gerak/data.dart';
import 'package:puasa_gerak/main.dart';
import 'package:puasa_gerak/state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _state({bool plan = true}) async {
  SharedPreferences.setMockInitialValues({});
  final s = AppState();
  await s.init();
  if (plan) {
    s.savePlan(sex: 'm', age: 35, h: 180, kg: 107, goal: 90, act: 1.2, days: 4, sess: 30, exp: 'new', equip: 'db');
    s.d.weights.insert(0, Weight('2026-11-01', 108.4));
    s.d.fasts.add(Fast(nowMs() - 20 * hourMs, nowMs() - 6 * hourMs, 14));
    s.d.moves.add(Move(nowMs() - hourMs, 32, 'Dumbbell A · Seluruh Tubuh', 'str'));
  }
  return s;
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('all tabs render on a phone (${dark ? 'dark' : 'light'})', (t) async {
      t.view.physicalSize = const Size(1080, 2340);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      final s = await _state();
      s.p.theme = dark ? 'dark' : 'light';
      await t.pumpWidget(PuasaGerakApp(state: s));
      await t.pump(const Duration(milliseconds: 100));
      for (final label in ['Rencana', 'Puasa', 'Olahraga', 'Berat', 'Saya']) {
        await t.tap(find.text(label).last);
        await t.pump(const Duration(milliseconds: 300));
        // scroll through the whole tab to build every card
        for (var i = 0; i < 12; i++) {
          await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
          await t.pump(const Duration(milliseconds: 50));
        }
        expect(t.takeException(), isNull, reason: label);
      }
      await t.tap(find.text('Puasa').last);
      await t.pump();
      await t.tap(find.textContaining('Mulai puasa'));
      await t.pump(const Duration(seconds: 2));
      expect(find.text('Sedang puasa'.toUpperCase()), findsOneWidget);
    });
  }

  testWidgets('first run opens plan form', (t) async {
    final s = await _state(plan: false);
    await t.pumpWidget(PuasaGerakApp(state: s));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Buat rencana saya'), findsOneWidget);
  });
}
