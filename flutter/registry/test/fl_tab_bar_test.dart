import 'package:fliin_ui/components/page/fl_page.dart';
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
  const _Held({
    this.initial = 0,
    this.labels = FlBottomTabLabels.always,
    this.floating = false,
    this.discs = false,
    this.tabs,
  });

  final int initial;
  final FlBottomTabLabels labels;
  final bool floating;
  final bool discs;
  final List<FlBottomTab>? tabs;

  @override
  State<_Held> createState() => _HeldState();
}

class _HeldState extends State<_Held> {
  late int index = widget.initial;

  @override
  Widget build(BuildContext context) => widget.discs
      ? FlBottomTabBar.discs(tabs: widget.tabs ?? _tabs, index: index, onSelected: (i) => setState(() => index = i))
      : FlBottomTabBar(
          tabs: widget.tabs ?? _tabs,
          index: index,
          labels: widget.labels,
          floating: widget.floating,
          onSelected: (i) => setState(() => index = i),
        );
}

Widget _app(
  Widget child, {
  double bottom = 0,
  double scale = 1,
  bool reduced = false,
  TextDirection direction = TextDirection.ltr,
  Brightness brightness = Brightness.light,
  FlTokens? tokens,
  double width = 390,
}) => MediaQuery(
  data: MediaQueryData(
    padding: EdgeInsets.only(bottom: bottom),
    textScaler: TextScaler.linear(scale),
    disableAnimations: reduced,
  ),
  child: Directionality(
    textDirection: direction,
    child: FlScope(
      tokens: tokens,
      brightness: brightness,
      platform: TargetPlatform.iOS,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

Color _labelColor(WidgetTester tester, String label) => tester.widget<Text>(find.text(label)).style!.color!;

/// Les disques d'une barre en disques, dans l'ordre des onglets : leur
/// cadre et leur couleur.
List<(Rect, Color)> _discs(WidgetTester tester) => [
  for (final element
      in find.descendant(of: find.byType(FlBottomTabBar), matching: find.byType(DecoratedBox)).evaluate().where((
        element,
      ) {
        final decoration = (element.widget as DecoratedBox).decoration;
        return decoration is ShapeDecoration && decoration.shape is CircleBorder;
      }))
    (
      tester.getRect(find.byElementPredicate((e) => e == element)),
      ((element.widget as DecoratedBox).decoration as ShapeDecoration).color!,
    ),
];

/// La couleur de l'icône du disque d'indice [i].
Color _iconColor(WidgetTester tester, int i) => IconTheme.of(
  find
      .descendant(of: find.byType(FlBottomTabBar), matching: find.byType(SizedBox))
      .evaluate()
      .where((e) {
        final box = e.widget as SizedBox;
        return box.width == 24 && box.height == 24;
      })
      .elementAt(i),
).color!;

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

  testWidgets('devrait lire chaque libellé sans en afficher aucun quand labels vaut never', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const _Held(labels: FlBottomTabLabels.never)));
    expect(find.byType(Text), findsNothing);
    for (final label in ['Accueil', 'Messages\n3 non lus', 'Profil']) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    await tester.pumpWidget(_app(const _Held()));
    final labelled = tester.getSize(find.byType(FlBottomTabBar)).height;
    await tester.pumpWidget(_app(const _Held(labels: FlBottomTabLabels.never)));
    expect(tester.getSize(find.byType(FlBottomTabBar)).height, lessThan(labelled));
    semantics.dispose();
  });

  testWidgets(
    'devrait ne montrer que le libellé de l’onglet choisi, sans changer de hauteur, quand labels vaut selected',
    (tester) async {
      await tester.pumpWidget(_app(const _Held()));
      final labelled = tester.getSize(find.byType(FlBottomTabBar)).height;
      await tester.pumpWidget(_app(const _Held(labels: FlBottomTabLabels.selected)));
      expect(tester.getSize(find.byType(FlBottomTabBar)).height, labelled);
      Set<String> shown() => tester
          .widgetList<Text>(find.byType(Text))
          .where((text) => text.data != null)
          .map((text) => text.data!)
          // Le libellé fantôme qui garde la hauteur n'est pas peint.
          .where((data) => find.text(data).hitTestable().evaluate().isNotEmpty)
          .toSet();
      expect(shown(), {'Accueil'});
      await tester.tap(find.bySemanticsLabel('Profil'));
      await tester.pumpAndSettle();
      expect(shown(), {'Profil'});
      expect(tester.getSize(find.byType(FlBottomTabBar)).height, labelled);
    },
  );

  testWidgets('devrait fondre l’icône de l’onglet choisi dans selectedIcon', (tester) async {
    const outline = Key('outline');
    const filled = Key('filled');
    final tabs = [
      for (final label in _labels)
        FlBottomTab(
          icon: SizedBox.square(key: label == 'Profil' ? outline : null, dimension: 24),
          selectedIcon: label == 'Profil' ? const SizedBox.square(key: filled, dimension: 24) : null,
          label: label,
        ),
    ];
    double opacity(Key key) =>
        tester.widget<Opacity>(find.ancestor(of: find.byKey(key), matching: find.byType(Opacity)).first).opacity;
    await tester.pumpWidget(_app(_Held(tabs: tabs)));
    expect((opacity(outline), opacity(filled)), (1.0, 0.0));
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect((opacity(outline), opacity(filled)), (0.0, 1.0));
  });

  testWidgets('devrait détacher la barre flottante des bords et la poser au-dessus de l’indicateur d’accueil', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const _Held(floating: true), bottom: 34));
    final space = FlTokens.defaults.space;
    final bar = tester.getRect(find.byType(FlBottomTabBar));
    final tabs = tester.getRect(find.descendant(of: find.byType(FlBottomTabBar), matching: find.byType(Row)).first);
    final shape = tabs.inflate(space.xs);
    // Trois onglets plafonnés à 96 chacun : la capsule reste au centre.
    expect(shape.width, 3 * 96 + 2 * space.xs);
    expect(shape.center.dx, bar.center.dx);
    expect(bar.bottom - shape.bottom, 34 - space.sm);
  });

  group('en disques', () {
    final space = tokens.space;
    final side = tokens.size.controlSpacious;
    final chosen = side + space.sm;

    testWidgets('devrait lire chaque disque par son libellé, sans en afficher aucun, et un seul choisi', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(const _Held(discs: true, initial: 1)));
      expect(find.byType(Text), findsNothing);
      final bar = tester.getSemantics(
        find.descendant(of: find.byType(FlBottomTabBar), matching: find.byType(Row)).first,
      );
      expect(bar.role, SemanticsRole.tabBar);
      final tabs = <SemanticsNode>[];
      bar.visitChildren((node) {
        tabs.add(node);
        return true;
      });
      expect([for (final tab in tabs) tab.role], everyElement(SemanticsRole.tab));
      expect([for (final tab in tabs) tab.label], ['Accueil', 'Messages\n3 non lus', 'Profil']);
      expect([for (final tab in tabs) tab.flagsCollection.isSelected == Tristate.isTrue], [false, true, false]);
      semantics.dispose();
    });

    testWidgets(
      'devrait poser le disque choisi plus grand, en couleur primaire, sur le centre des autres quand un onglet est choisi',
      (tester) async {
        await tester.pumpWidget(_app(const _Held(discs: true, initial: 1)));
        final discs = _discs(tester);
        expect([for (final (rect, _) in discs) rect.width], [side, chosen, side]);
        expect([for (final (rect, _) in discs) rect.height], [side, chosen, side]);
        expect({for (final (rect, _) in discs) rect.center.dy}, hasLength(1));
        expect([for (final (_, color) in discs) color], [colors.surfaceRaised, colors.selected, colors.surfaceRaised]);
        expect(_iconColor(tester, 0), colors.onSurface);
        expect(_iconColor(tester, 1), colors.onSelected);
        // Le choisi n'a pas d'ombre ; les autres portent celle des cartes.
        final shadows = tester.widgetList<FlShadow>(
          find.descendant(of: find.byType(FlBottomTabBar), matching: find.byType(FlShadow)),
        );
        expect(
          [for (final shadow in shadows) shadow.layers.every((layer) => layer.color.a == 0)],
          [false, true, false],
        );
      },
    );

    testWidgets('devrait répartir les disques sur la largeur, aux marges du canevas, à 28 du bord bas', (tester) async {
      await tester.pumpWidget(_app(const _Held(discs: true), bottom: 34));
      final bar = tester.getRect(find.byType(FlBottomTabBar));
      final discs = _discs(tester);
      final margin = space.lg + space.xs;
      expect(discs.first.$1.left, bar.left + margin);
      expect(discs.last.$1.right, bar.right - margin);
      expect(discs[1].$1.left - discs[0].$1.right, closeTo(discs[2].$1.left - discs[1].$1.right, 0.01));
      // Le disque choisi à 28 du bord, dans la zone sûre de 34 ; 40 de
      // fondu au-dessus des autres.
      expect(bar.bottom - discs.first.$1.bottom, space.xl + space.xs);
      expect(discs[1].$1.top - bar.top, space.xxl + space.sm);
      // Sans zone sûre, toujours 28 du bord.
      await tester.pumpWidget(_app(const _Held(discs: true)));
      expect(tester.getRect(find.byType(FlBottomTabBar)).bottom - _discs(tester).first.$1.bottom, space.xl + space.xs);
    });

    testWidgets('devrait rétrécir cinq disques sans déborder ni passer sous la cible tactile quand l’écran fait 320', (
      tester,
    ) async {
      final five = [
        for (final label in ['Accueil', 'Rapports', 'Cartes', 'Alertes', 'Profil'])
          FlBottomTab(icon: const SizedBox.square(dimension: 24), label: label),
      ];
      await tester.pumpWidget(_app(_Held(discs: true, tabs: five), width: 320));
      expect(tester.takeException(), isNull);
      final discs = _discs(tester);
      expect(discs.first.$1.width, lessThan(chosen));
      expect(discs[1].$1.width, inInclusiveRange(44, side));
      for (final (i, (rect, _)) in discs.indexed.skip(1)) {
        expect(rect.left - discs[i - 1].$1.right, greaterThanOrEqualTo(space.xs - 0.01));
      }
    });

    testWidgets('devrait inverser l’ordre des disques quand le texte va de droite à gauche', (tester) async {
      await tester.pumpWidget(_app(const _Held(discs: true), direction: TextDirection.rtl));
      final discs = _discs(tester);
      expect(discs.first.$1.center.dx, greaterThan(discs.last.$1.center.dx));
      expect(discs.first.$1.width, chosen);
    });

    testWidgets('devrait faire passer le choix d’un disque à l’autre au ressort quand on touche un disque', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Held(discs: true)));
      await tester.tap(find.bySemanticsLabel('Profil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final midway = _discs(tester);
      expect(midway[2].$1.width, inExclusiveRange(side, chosen));
      expect(midway[0].$1.width, inExclusiveRange(side, chosen));
      expect(midway[2].$2, isNot(anyOf(colors.surfaceRaised, colors.selected)));
      await tester.pumpAndSettle();
      final settled = _discs(tester);
      expect([for (final (rect, _) in settled) rect.width], [side, side, chosen]);
      expect(settled[2].$2, colors.selected);
    });

    testWidgets('devrait changer de disque d’un coup sous mouvement réduit', (tester) async {
      await tester.pumpWidget(_app(const _Held(discs: true), reduced: true));
      await tester.tap(find.bySemanticsLabel('Profil'));
      await tester.pump();
      final discs = _discs(tester);
      expect([for (final (rect, _) in discs) rect.width], [side, side, chosen]);
      expect([for (final (_, color) in discs) color], [colors.surfaceRaised, colors.surfaceRaised, colors.selected]);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('devrait passer de disque en disque aux flèches et choisir par Entrée puis Espace', (tester) async {
      await tester.pumpWidget(
        Shortcuts(
          shortcuts: WidgetsApp.defaultShortcuts,
          child: Actions(
            actions: WidgetsApp.defaultActions,
            child: FocusScope(autofocus: true, child: _app(const _Held(discs: true))),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_discs(tester)[1].$1.width, chosen);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(_discs(tester)[2].$1.width, chosen);
    });

    testWidgets('devrait garder la pastille d’un onglet sur son disque', (tester) async {
      const dot = Key('dot');
      final tabs = [
        for (final label in _labels)
          FlBottomTab(
            icon: const SizedBox.square(dimension: 24),
            label: label,
            badge: label == 'Messages' ? const SizedBox.square(key: dot, dimension: 10) : null,
          ),
      ];
      for (final initial in [0, 1]) {
        await tester.pumpWidget(_app(_Held(discs: true, initial: initial, tabs: tabs)));
        final disc = _discs(tester)[1].$1;
        final badge = tester.getRect(find.byKey(dot));
        expect(disc.contains(badge.topLeft) && disc.contains(badge.bottomRight), isTrue);
      }
    });

    testWidgets('devrait fondre la page en background derrière les disques et laisser passer les touchers au-dessus', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          SizedBox(
            height: 300,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++),
                ),
                const Positioned(left: 0, right: 0, bottom: 0, child: _Held(discs: true)),
              ],
            ),
          ),
        ),
      );
      final gradient = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: find.byType(FlBottomTabBar), matching: find.byType(DecoratedBox)),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .single
          .gradient!;
      expect(gradient.colors, [colors.background.withValues(alpha: 0), colors.background]);
      final bar = tester.getRect(find.byType(FlBottomTabBar));
      final discs = _discs(tester);
      await tester.tapAt(Offset(bar.center.dx, bar.top + space.sm));
      expect(taps, 1);
      // Entre deux disques, la barre garde le toucher.
      await tester.tapAt(Offset((discs[0].$1.right + discs[1].$1.left) / 2, discs[0].$1.center.dy));
      expect(taps, 1);
    });

    testWidgets('devrait cerner d’un filet border les disques non choisis quand le thème n’a pas d’ombre', (
      tester,
    ) async {
      final shadows = tokens.shadow.light;
      // Le thème livré sous le préréglage shadow none : ombre surface à plat.
      final flat = FlTokens(
        light: tokens.light,
        dark: tokens.dark,
        shape: tokens.shape,
        shadow: FlShadowTokens(
          light: FlShadows(
            surface: const [],
            overlay: shadows.overlay,
            field: shadows.field,
            glow: shadows.glow,
            dangerGlow: shadows.dangerGlow,
            thumb: shadows.thumb,
          ),
          dark: tokens.shadow.dark,
        ),
        space: tokens.space,
        size: tokens.size,
        motion: tokens.motion,
        typography: tokens.typography,
      );
      Iterable<BorderSide> sides() => find
          .descendant(of: find.byType(FlBottomTabBar), matching: find.byType(DecoratedBox))
          .evaluate()
          .map((element) => (element.widget as DecoratedBox).decoration)
          .whereType<ShapeDecoration>()
          .map((decoration) => (decoration.shape as CircleBorder).side);
      await tester.pumpWidget(_app(const _Held(discs: true)));
      expect(sides(), everyElement(BorderSide.none));
      await tester.pumpWidget(_app(const _Held(discs: true), tokens: flat));
      expect(
        [for (final side in sides()) side.color],
        [colors.border.withValues(alpha: 0), colors.border, colors.border],
      );
    });

    testWidgets('devrait poser le disque choisi en couleur primaire du thème sombre, son icône en onSelected', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Held(discs: true), brightness: Brightness.dark));
      final dark = tokens.dark;
      expect(_discs(tester)[0].$2, dark.selected);
      expect(_iconColor(tester, 0), dark.onSelected);
    });

    testWidgets('devrait faire finir le contenu de la page au-dessus des disques quand extendBody est vrai', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const last = Key('last');
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844), padding: EdgeInsets.only(top: 47, bottom: 34)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: FlScope(
              brightness: Brightness.light,
              platform: TargetPlatform.iOS,
              child: FlPage(
                extendBody: true,
                tabBar: const _Held(discs: true),
                slivers: const [
                  SliverToBoxAdapter(child: SizedBox(height: 2000)),
                  SliverToBoxAdapter(child: SizedBox(key: last, height: 40)),
                ],
              ),
            ),
          ),
        ),
      );
      final bar = tester.getRect(find.byType(FlBottomTabBar));
      expect(bar.bottom, 844);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(last)).bottom, bar.top);
    });
  });
}
