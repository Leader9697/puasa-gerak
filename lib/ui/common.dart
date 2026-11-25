import 'package:material_ui/material_ui.dart';

class C {
  static const orange = Color(0xFFE8590C);
  static const blue = Color(0xFF1E6FE0);
  static const purple = Color(0xFF7C4DDB);
  static const pink = Color(0xFFE0336E);
  static const green = Color(0xFF0E9461);
  static const yellow = Color(0xFFFFC53D);
  static const red = Color(0xFFD93A3F);
  static const progColors = [green, blue, purple, pink, red];
}

class Pal {
  final Color bg, surface, surface2, ink, muted, line, good, warn;
  const Pal(this.bg, this.surface, this.surface2, this.ink, this.muted, this.line, this.good, this.warn);
  static const light = Pal(Color(0xFFF3F5FA), Colors.white, Color(0xFFE9EDF5), Color(0xFF161A2B), Color(0xFF5A6178),
      Color(0xFFDFE4EE), Color(0xFF0E9461), Color(0xFFC77700));
  static const dark = Pal(Color(0xFF11131C), Color(0xFF1B1F2D), Color(0xFF262B3D), Color(0xFFEEF0F7), Color(0xFFA3A9BF),
      Color(0xFF2C3247), Color(0xFF2BC48A), Color(0xFFF5B544));
  static Pal of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? dark : light;
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Pal.dark : Pal.light;
  final base = ThemeData(
    brightness: b,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: C.green, brightness: b, surface: p.surface),
    scaffoldBackgroundColor: p.bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.line, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.line, width: 1.5)),
      labelStyle: TextStyle(color: p.muted, fontWeight: FontWeight.w600),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(color: p.bg, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

void toast(BuildContext c, String t) {
  final m = ScaffoldMessenger.of(c);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(t, textAlign: TextAlign.center), duration: const Duration(milliseconds: 2600)));
}

const tnum = [FontFeature.tabularFigures()];

TextStyle display(double size, {Color? color, FontWeight w = FontWeight.w800}) =>
    TextStyle(fontSize: size, fontWeight: w, color: color, letterSpacing: -0.3, height: 1.15, fontFeatures: tnum);

/// Card with an optional solid hero color (white text on top).
class Box extends StatelessWidget {
  final Widget child;
  final Color? hero;
  final Color? tint;
  final EdgeInsets padding;
  const Box({super.key, required this.child, this.hero, this.tint, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final inner = Material(
      color: hero ?? tint ?? p.surface,
      borderRadius: BorderRadius.circular(20),
      textStyle: hero != null ? Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white) : null,
      child: SizedBox(width: double.infinity, child: Padding(padding: padding, child: child)),
    );
    if (hero == null) return inner;
    return HeroScope(color: hero!, child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: IconTheme(data: const IconThemeData(color: Colors.white), child: inner)));
  }
}

/// Lets children know they sit on a solid colored card.
class HeroScope extends InheritedWidget {
  final Color color;
  const HeroScope({super.key, required this.color, required super.child});
  static Color? of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<HeroScope>()?.color;
  @override
  bool updateShouldNotify(HeroScope old) => old.color != color;
}

Color mutedOf(BuildContext c) => HeroScope.of(c) != null ? Colors.white.withValues(alpha: .85) : Pal.of(c).muted;
Color inkOf(BuildContext c) => HeroScope.of(c) != null ? Colors.white : Pal.of(c).ink;
Color softOf(BuildContext c) => HeroScope.of(c) != null ? Colors.white.withValues(alpha: .18) : Pal.of(c).surface2;
Color lineOf(BuildContext c) => HeroScope.of(c) != null ? Colors.white.withValues(alpha: .3) : Pal.of(c).line;

class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: TextStyle(fontSize: 11.5, letterSpacing: 1.0, fontWeight: FontWeight.w700, color: mutedOf(context)));
}

class Muted extends StatelessWidget {
  final String text;
  final double size;
  final TextAlign? align;
  const Muted(this.text, {super.key, this.size = 13.5, this.align});
  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: align, style: TextStyle(fontSize: size, color: mutedOf(context), height: 1.4, fontFeatures: tnum));
}

class H2 extends StatelessWidget {
  final String text;
  const H2(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text, style: display(22, color: inkOf(context)));
}

class H3 extends StatelessWidget {
  final String text;
  const H3(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Text(text, style: display(17, color: inkOf(context), w: FontWeight.w700));
}

class Pill extends StatelessWidget {
  final String text;
  final Color? color;
  const Pill(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    final hero = HeroScope.of(context);
    final c = color ?? (hero != null ? Colors.white : Pal.of(context).good);
    final onHero = hero != null && color == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: onHero ? Colors.white.withValues(alpha: .22) : c.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: onHero ? Colors.white : c, fontFeatures: tnum)),
    );
  }
}

class Stat extends StatelessWidget {
  final String label, value;
  final String? sub;
  final Color? bg;
  final bool valueFirst;
  const Stat(this.label, this.value, {super.key, this.sub, this.bg, this.valueFirst = false});
  @override
  Widget build(BuildContext context) {
    final l = Text(label, style: TextStyle(fontSize: 12, color: mutedOf(context)));
    final v = FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: display(21, color: inkOf(context))));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: bg ?? softOf(context), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (valueFirst) ...[v, l] else ...[l, v],
        if (sub != null) Text(sub!, style: TextStyle(fontSize: 11.5, color: mutedOf(context))),
      ]),
    );
  }
}

class Meter extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;
  const Meter(this.value, {super.key, this.color, this.height = 12});
  @override
  Widget build(BuildContext context) {
    final hero = HeroScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: softOf(context),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0, 1).toDouble(),
          child: Container(decoration: BoxDecoration(color: color ?? (hero != null ? Colors.white : C.green), borderRadius: BorderRadius.circular(height))),
        ),
      ),
    );
  }
}

/// Primary button. On a hero card it turns white with the hero color as text.
class Btn extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool ghost, small, danger;
  final Color? color;
  const Btn(this.text, {super.key, this.onTap, this.ghost = false, this.small = false, this.danger = false, this.color});
  @override
  Widget build(BuildContext context) {
    final hero = HeroScope.of(context);
    final p = Pal.of(context);
    final pad = small ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8) : const EdgeInsets.symmetric(horizontal: 16, vertical: 13);
    final minH = small ? 38.0 : 48.0;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(small ? 10 : 12));
    final ts = TextStyle(fontWeight: FontWeight.w700, fontSize: small ? 14 : 15.5);
    if (ghost || danger) {
      final c = danger ? C.red : inkOf(context);
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
            foregroundColor: c, side: BorderSide(color: danger ? C.red : lineOf(context), width: 1.5), padding: pad,
            minimumSize: Size(0, minH), shape: shape, textStyle: ts),
        child: Text(text, textAlign: TextAlign.center),
      );
    }
    final bg = color ?? (hero != null ? Colors.white : C.green);
    final fg = color != null ? Colors.white : (hero ?? (p == Pal.dark ? const Color(0xFF06231A) : Colors.white));
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(backgroundColor: bg, foregroundColor: hero != null && color == null ? hero : fg, padding: pad,
          minimumSize: Size(0, minH), shape: shape, textStyle: ts),
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}

/// Segmented choice row (wraps).
class Seg<T> extends StatelessWidget {
  final List<(T, String)> opts;
  final T value;
  final ValueChanged<T> onChanged;
  final Color color;
  const Seg({super.key, required this.opts, required this.value, required this.onChanged, this.color = C.green});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final o in opts)
        Material(
          color: o.$1 == value ? color : p.surface2,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onChanged(o.$1),
            child: Container(
              constraints: const BoxConstraints(minHeight: 40, minWidth: 44),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Text(o.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: o.$1 == value ? Colors.white : p.ink)),
            ),
          ),
        ),
    ]);
  }
}

class Gap extends StatelessWidget {
  final double h;
  const Gap(this.h, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(height: h, width: h);
}

/// Vertical stack with spacing.
class Col extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  const Col(this.children, {super.key, this.gap = 12});
  @override
  Widget build(BuildContext context) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) out.add(SizedBox(height: gap));
      out.add(children[i]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: out);
  }
}

class ListRow extends StatelessWidget {
  final Widget title;
  final Widget? sub;
  final List<Widget> trailing;
  final VoidCallback? onDelete;
  final bool first;
  const ListRow({super.key, required this.title, this.sub, this.trailing = const [], this.onDelete, this.first = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: lineOf(context)))),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, ?sub])),
        ...trailing.expand((w) => [const SizedBox(width: 8), w]),
        if (onDelete != null)
          IconButton(onPressed: onDelete, icon: Icon(Icons.close, size: 20, color: mutedOf(context)), tooltip: 'Hapus', visualDensity: VisualDensity.compact),
      ]),
    );
  }
}

class Note extends StatelessWidget {
  final String title;
  final List<String> items;
  final String? footer;
  const Note(this.title, this.items, {super.key, this.footer});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Color.alphaBlend(C.yellow.withValues(alpha: .26), p.surface), borderRadius: BorderRadius.circular(14)),
      child: Col([
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        for (final i in items)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('•  '),
            Expanded(child: Text(i, style: const TextStyle(fontSize: 13.5, height: 1.4))),
          ]),
        if (footer != null) Text(footer!, style: const TextStyle(fontSize: 13, height: 1.4)),
      ], gap: 6),
    );
  }
}

Color tintOf(BuildContext c, Color col, [double a = .16]) => Color.alphaBlend(col.withValues(alpha: a), Pal.of(c).surface);
