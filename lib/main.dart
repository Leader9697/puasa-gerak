import 'package:material_ui/material_ui.dart';

import 'cloud.dart';
import 'data.dart';
import 'logic.dart';
import 'native.dart';
import 'notify.dart';
import 'state.dart';
import 'ui/common.dart';
import 'ui/fast_tab.dart';
import 'ui/me_tab.dart';
import 'ui/move_tab.dart';
import 'ui/plan_tab.dart';
import 'ui/weight_tab.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifier.init();
  await Cloud.init();
  final state = AppState();
  await state.init();
  runApp(PuasaGerakApp(state: state));
}

class PuasaGerakApp extends StatelessWidget {
  final AppState state;
  const PuasaGerakApp({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (_, _) => MaterialApp(
          title: 'Puasa & Gerak',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: state.themeMode,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const tabs = ['plan', 'fast', 'move', 'weight', 'me'];
  int tab = 1;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Store.getInt('tab', -1).then((v) {
      if (!mounted) return;
      final s = AppScope.read(context);
      setState(() {
        if (v >= 0 && v < tabs.length) tab = v;
        if (!hasPlan(s.p) && s.d.fasts.isEmpty && s.d.moves.isEmpty) tab = 0;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final remind = AppScope.read(context).p.remind;
      final asked = await Store.getInt('askedNotif', 0);
      if (asked == 0 && remind) {
        await Store.setInt('askedNotif', 1);
        await Notifier.requestPermissions();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.resumed) {
      final s = AppScope.read(context);
      if (s.p.steps) s.refreshSteps();
      NativeBridge.sync(s.d);
      if (Cloud.user != null) s.syncNow();
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  void go(int i) {
    setState(() => tab = i);
    Store.setInt('tab', i);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void toTop() {
    if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pal = Pal.of(context);
    final lv = levelOf(xpOf(s.d));
    final st = streaks(s.d);
    const colors = [C.green, C.orange, C.blue, C.purple, C.pink];

    final body = switch (tab) {
      0 => PlanTab(toTop: toTop),
      1 => FastTab(openPlan: () => go(0)),
      2 => MoveTab(openSettings: () => go(4)),
      3 => const WeightTab(),
      _ => const MeTab(),
    };

    return Scaffold(
      backgroundColor: pal.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(TextSpan(style: display(21, color: pal.ink), children: const [
                    TextSpan(text: 'Puasa '),
                    TextSpan(text: '&', style: TextStyle(color: C.pink)),
                    TextSpan(text: ' Gerak'),
                  ])),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('Level ${lv.lv}', style: TextStyle(fontSize: 12.5, color: pal.muted, fontFeatures: tnum)),
                    const SizedBox(width: 8),
                    Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 140), child: Meter(lv.into / lv.need, color: C.purple, height: 6))),
                  ]),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: C.orange, borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.local_fire_department, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('${st.cur} hari', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, fontFeatures: tnum)),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: body)),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: pal.surface,
          indicatorColor: colors[tab].withValues(alpha: .16),
          labelTextStyle: WidgetStateProperty.resolveWith((st) => TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: st.contains(WidgetState.selected) ? colors[tab] : pal.muted)),
          iconTheme: WidgetStateProperty.resolveWith((st) => IconThemeData(color: st.contains(WidgetState.selected) ? colors[tab] : pal.muted)),
        ),
        child: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: go,
          height: 68,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Rencana'),
            NavigationDestination(icon: Icon(Icons.timer_outlined), selectedIcon: Icon(Icons.timer), label: 'Puasa'),
            NavigationDestination(icon: Icon(Icons.directions_run), label: 'Olahraga'),
            NavigationDestination(icon: Icon(Icons.monitor_weight_outlined), selectedIcon: Icon(Icons.monitor_weight), label: 'Berat'),
            NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Saya'),
          ],
        ),
      ),
    );
  }
}
