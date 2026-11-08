import 'package:fliin_ui/components/tab_bar/fl_tab_bar.dart';
import 'package:fliin_ui/core/fliin.dart';

import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _labels = ['Accueil', 'Messages', 'Profil'];

final _tabs = [
  for (final label in _labels)
    FlBottomTab(
      icon: const SizedBox.square(dimension: 24),
      label: label,
      badge: label == 'Messages' ? Semantics(label: '3 non lus', child: const SizedBox.square(dimension: 16)) : null,
    ),
];

/// La barre sous l'onglet que garde la scène, qui le change au toucher.
class _Held extends StatefulWidget {
  const _Held({this.initial = 0});

  final int initial;

  @override
  State<_Held> createState() => _HeldState();
}

class _HeldState extends State<_Held> {
  late int index = widget.initial;

  @override
  Widget build(BuildContext context) =>
      FlBottomTabBar(tabs: _tabs, index: index, onSelected: (i) => setState(() => index = i));
}

Widget _app(Widget child, {double bottom = 0, double scale = 1, bool reduced = false}) => MediaQuery(
  data: MediaQueryData(
    padding: EdgeInsets.only(bottom: bottom),
    textScaler: TextScaler.linear(scale),
    disableAnimations: reduced,
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: FlScope(
      brightness: Brightness.light,
      platform: TargetPlatform.iOS,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(width: 390, child: child),
      ),
    ),
  ),
);

Color _labelColor(WidgetTester tester, String label) => tester.widget<Text>(find.text(label)).style!.color!;

void main() {
  final tokens = FlTokens.defaults;
  final colors = tokens.light;

  testWidgets('devrait annoncer une barre d’onglets dont seul l’onglet choisi est sélectionné', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const _Held(initial: 1)));
    final bar = tester.getSemantics(find.descendant(of: find.byType(FlBottomTabBar), matching: find.byType(Row)).first);
    expect(bar.role, SemanticsRole.tabBar);
    final tabs = <SemanticsNode>[];
    bar.visitChildren((node) {
      tabs.add(node);
      return true;
    });
    expect([for (final tab in tabs) tab.role], everyElement(SemanticsRole.tab));
    expect([for (final tab in tabs) tab.flagsCollection.isSelected == Tristate.isTrue], [false, true, false]);
    expect(tabs[1].label, 'Messages\n3 non lus');
    semantics.dispose();
  });

  testWidgets('devrait choisir l’onglet touché et donner sa couleur à son libellé une fois le ressort posé', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const _Held()));
    expect(_labelColor(tester, 'Accueil'), colors.onSurface);
    expect(_labelColor(tester, 'Profil'), colors.onSurfaceMuted);
    await tester.tap(find.text('Messages'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(_labelColor(tester, 'Messages'), isNot(anyOf(colors.onSurface, colors.onSurfaceMuted)));
    await tester.pumpAndSettle();
    expect(_labelColor(tester, 'Messages'), colors.onSurface);
    expect(_labelColor(tester, 'Accueil'), colors.onSurfaceMuted);
  });

  testWidgets('devrait changer d’onglet d’un coup et fondre la pastille sous mouvement réduit', (tester) async {
    await tester.pumpWidget(_app(const _Held(), reduced: true));
    await tester.tap(find.text('Profil'));
    await tester.pump();
    expect(_labelColor(tester, 'Profil'), colors.onSurface);
    expect(_labelColor(tester, 'Messages'), colors.onSurfaceMuted);
    await tester.pumpAndSettle();
  });

  testWidgets('devrait refuser moins de trois ou plus de cinq onglets', (tester) async {
    expect(() => FlBottomTabBar(tabs: _tabs.sublist(0, 2), index: 0, onSelected: (_) {}), throwsAssertionError);
    expect(() => FlBottomTabBar(tabs: [..._tabs, ..._tabs], index: 0, onSelected: (_) {}), throwsAssertionError);
  });

  testWidgets('devrait poser ses onglets au-dessus de la zone sûre du bas', (tester) async {
    await tester.pumpWidget(_app(const _Held()));
    final flat = tester.getSize(find.byType(FlBottomTabBar)).height;
    await tester.pumpWidget(_app(const _Held(), bottom: 34));
    expect(tester.getSize(find.byType(FlBottomTabBar)).height, flat + 34);
    expect(
      tester.getRect(find.text('Accueil')).bottom,
      lessThan(tester.getRect(find.byType(FlBottomTabBar)).bottom - 34),
    );
  });

  testWidgets('devrait passer d’onglet en onglet aux flèches et choisir par Entrée', (tester) async {
    await tester.pumpWidget(
      Shortcuts(
        shortcuts: WidgetsApp.defaultShortcuts,
        child: Actions(
          actions: WidgetsApp.defaultActions,
          child: FocusScope(autofocus: true, child: _app(const _Held())),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_labelColor(tester, 'Messages'), colors.onSurface);
  });

  testWidgets('devrait plafonner le libellé à iconMaxScale quand le texte est agrandi', (tester) async {
    await tester.pumpWidget(_app(const _Held(), scale: 2));
    expect(tester.widget<Text>(find.text('Accueil')).textScaler!.scale(10), 10 * tokens.size.iconMaxScale);
    expect(tester.takeException(), isNull);
  });

  testWidgets('devrait garder les onglets hors de l’encoche en paysage', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(left: 47, right: 47, bottom: 21)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: FlScope(
            brightness: Brightness.light,
            platform: TargetPlatform.iOS,
            child: const Align(
              alignment: Alignment.bottomLeft,
              child: SizedBox(width: 844, child: _Held()),
            ),
          ),
        ),
      ),
    );
    final bar = tester.getRect(find.byType(FlBottomTabBar));
    expect(bar.width, 844);
    final tabs = tester.getRect(find.descendant(of: find.byType(FlBottomTabBar), matching: find.byType(Row)).first);
    final side = FlTokens.defaults.space.sm;
    expect((tabs.left, tabs.right), (47 + side, 844 - 47 - side));
  });
}
