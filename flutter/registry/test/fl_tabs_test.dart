import 'package:fliin_ui/components/tabs/fl_tabs.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

const _labels = ['Messages', 'Appels', 'Contacts'];

final _light = FlTokens.defaults.light;

class _Host extends StatefulWidget {
  const _Host({this.variant = FlTabsVariant.primary, this.disabled = const {}, this.separators = false});

  final FlTabsVariant variant;
  final Set<int> disabled;
  final bool separators;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final controller = FlTabController(length: _labels.length);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 480,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FlTabs(
          controller: controller,
          labels: _labels,
          variant: widget.variant,
          disabled: widget.disabled,
          separators: widget.separators,
        ),
        FlTabView(
          controller: controller,
          children: [
            for (final label in _labels)
              Focus(
                child: Builder(builder: (context) => Text('Contenu $label', textDirection: TextDirection.ltr)),
              ),
          ],
        ),
      ],
    ),
  );
}

FlTabController _controller(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host)).controller;

/// La rangée et son indicateur peint dessous.
Finder get _bar => find
    .descendant(
      of: find.byType(FlTabs),
      matching: find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter != null),
    )
    .first;

/// Le rectangle de l'onglet [label] dans le repère de la rangée.
Rect _tab(WidgetTester tester, String label) => tester
    .getRect(find.ancestor(of: find.text(label), matching: find.byType(FlHitTarget)).first)
    .shift(-tester.getTopLeft(_bar));

/// Les indicateurs peints : le pouce `segment` ou le soulignement
/// `selected`, avec leur opacité.
List<(Rect, double)> _indicators(WidgetTester tester) {
  final found = <(Rect, double)>[];
  bool same(Paint paint, Color color) => paint.color.withValues(alpha: 1).toARGB32() == color.toARGB32();
  expect(
    _bar,
    paints..everything((method, arguments) {
      final paint = arguments.isEmpty ? null : arguments.last;
      if (paint is! Paint || paint.maskFilter != null) return true;
      if (method == #drawRRect && (same(paint, _light.selected) || same(paint, _light.segment))) {
        found.add(((arguments[0] as RRect).outerRect, paint.color.a));
      } else if (method == #drawRect && same(paint, _light.selected)) {
        found.add((arguments[0] as Rect, paint.color.a));
      }
      return true;
    }),
  );
  return found.where((indicator) => indicator.$2 > 0).toList();
}

void main() {
  testWidgets("devrait s'annoncer comme une barre d'onglets, chaque onglet sélectionnable, et un panneau", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host()));
    expect(
      tester.getSemantics(_bar),
      matchesSemantics(
        role: SemanticsRole.tabBar,
        children: [
          matchesSemantics(
            label: 'Messages',
            role: SemanticsRole.tab,
            hasSelectedState: true,
            isSelected: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
            hasFocusAction: true,
            isFocusable: true,
          ),
          for (final label in _labels.skip(1))
            matchesSemantics(
              label: label,
              role: SemanticsRole.tab,
              hasSelectedState: true,
              hasEnabledState: true,
              isEnabled: true,
              hasTapAction: true,
              hasFocusAction: true,
              isFocusable: true,
            ),
        ],
      ),
    );
    expect(
      tester.getSemantics(find.byType(FlTabView)),
      matchesSemantics(
        role: SemanticsRole.tabPanel,
        children: [matchesSemantics(label: 'Contenu Messages', isFocusable: true, hasFocusAction: true)],
      ),
    );
    semantics.dispose();
  });

  testWidgets('devrait partager la largeur de la capsule entre ses onglets, sans défiler', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final list = tester.getRect(find.byType(DecoratedBox).first);
    expect(list.left, tester.getRect(find.byType(_Host)).left);
    expect(list.width, 480);
    final tabs = [for (final label in _labels) _tab(tester, label)];
    expect(tabs.first.left, 0);
    expect(tabs[1].left - tabs[0].right, moreOrLessEquals(FlTokens.defaults.space.xs, epsilon: 0.01));
    expect(tabs[0].width, moreOrLessEquals(tabs[2].width, epsilon: 0.01));
    // controlSm (20) plus py-1.5, dans la marge space.xs de la capsule.
    expect(tabs.first.height, 32);
    expect(list.height, 32 + 2 * FlTokens.defaults.space.xs);
    expect(find.byType(Scrollable), findsNothing);
  });

  testWidgets('devrait offrir la cible tactile de la plateforme à chaque onglet', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host(), platform: TargetPlatform.iOS));
    expect(
      tester.getSemantics(find.ancestor(of: find.text('Appels'), matching: find.byType(FlHitTarget)).first).rect.height,
      FlTokens.defaults.size.hitTargetIos,
    );
    semantics.dispose();
  });

  testWidgets("devrait choisir l'onglet touché, montrer son contenu et faire glisser la pastille par ressort", (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final first = _indicators(tester).single.$1;
    expect(first, rectMoreOrLessEquals(_tab(tester, 'Messages'), epsilon: 0.01));
    await tester.tap(find.text('Contacts'));
    await tester.pump();
    expect(_controller(tester).index, 2);
    expect(find.text('Contenu Contacts').hitTestable(), findsOneWidget);
    expect(find.text('Contenu Messages').hitTestable(), findsNothing);
    await tester.pump(const Duration(milliseconds: 16));
    final moving = _indicators(tester).single.$1;
    await tester.pumpAndSettle();
    final last = _indicators(tester).single.$1;
    expect(moving.left, greaterThan(first.left));
    expect(moving.left, lessThan(last.left));
    expect(last, rectMoreOrLessEquals(_tab(tester, 'Contacts'), epsilon: 0.01));
  });

  testWidgets(
    "devrait effacer l'indicateur et le faire apparaître sur l'onglet choisi, sans glisser, quand le mouvement est réduit",
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(toggleApp(const _Host()));
      await tester.tap(find.text('Contacts'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      final fading = _indicators(tester);
      expect(fading.map((indicator) => indicator.$1), [
        rectMoreOrLessEquals(_tab(tester, 'Messages'), epsilon: 0.01),
        rectMoreOrLessEquals(_tab(tester, 'Contacts'), epsilon: 0.01),
      ]);
      expect(fading.map((indicator) => indicator.$2), everyElement(inExclusiveRange(0, 1)));
      await tester.pumpAndSettle();
      expect(_indicators(tester).single.$1, rectMoreOrLessEquals(_tab(tester, 'Contacts'), epsilon: 0.01));
    },
  );

  testWidgets('devrait souligner l’onglet choisi de selected sur le filet, à space.md de ses bords, en secondary', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const _Host(variant: FlTabsVariant.secondary)));
    final tab = _tab(tester, 'Messages');
    final md = FlTokens.defaults.space.md;
    final border = FlTokens.defaults.size.border;
    expect(tester.widget<Text>(find.text('Messages')).style?.color, _light.onSurface);
    expect(
      _indicators(tester).single.$1,
      rectMoreOrLessEquals(
        Rect.fromLTRB(tab.left + md, tab.bottom + border - 2, tab.right - md, tab.bottom + border),
        epsilon: 0.01,
      ),
    );
    final list = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration as BoxDecoration;
    expect((list.border! as Border).bottom.color, _light.border);
  });

  testWidgets(
    "devrait n'offrir qu'un arrêt de Tab, sur l'onglet choisi, et changer d'onglet aux flèches, à Début et à Fin",
    (tester) async {
      await tester.pumpWidget(toggleApp(const _Host()));
      _controller(tester).index = 1;
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(Focus.of(tester.element(find.text('Appels'))).hasPrimaryFocus, isTrue);
      for (final (key, index) in [
        (LogicalKeyboardKey.arrowRight, 2),
        (LogicalKeyboardKey.arrowRight, 2),
        (LogicalKeyboardKey.home, 0),
        (LogicalKeyboardKey.arrowLeft, 0),
        (LogicalKeyboardKey.end, 2),
        (LogicalKeyboardKey.arrowLeft, 1),
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(_controller(tester).index, index, reason: key.keyLabel);
        expect(Focus.of(tester.element(find.text(_labels[index]))).hasPrimaryFocus, isTrue, reason: key.keyLabel);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(Focus.of(tester.element(find.text('Contenu Appels'))).hasPrimaryFocus, isTrue);
    },
  );

  testWidgets('devrait ignorer un onglet désactivé au toucher et le sauter aux flèches', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host(disabled: {1})));
    expect(
      tester.getSemantics(find.text('Appels')),
      matchesSemantics(
        label: 'Appels',
        role: SemanticsRole.tab,
        hasSelectedState: true,
        hasEnabledState: true,
        isFocusable: false,
      ),
    );
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Appels'), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, FlTokens.defaults.size.disabledOpacity);
    await tester.tap(find.text('Appels'));
    await tester.pump();
    expect(_controller(tester).index, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_controller(tester).index, 2);
    semantics.dispose();
  });

  testWidgets('devrait effacer le séparateur qui touche l’onglet choisi', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(separators: true)));
    List<double> opacities() => [
      for (final element in find.byType(AnimatedOpacity).evaluate()) (element.widget as AnimatedOpacity).opacity,
    ];
    expect(opacities(), [0, 1]);
    expect(_tab(tester, 'Appels').left - _tab(tester, 'Messages').right, 2 * FlTokens.defaults.space.xs + 1);
    await tester.tap(find.text('Contacts'));
    await tester.pumpAndSettle();
    expect(opacities(), [1, 0]);
  });

  testWidgets("devrait montrer l'anneau de focus dans l'onglet focalisé au clavier", (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    bool ring() => tester.widgetList<FlFocusRing>(find.byType(FlFocusRing)).any((ring) => ring.visible);
    expect(ring(), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(ring(), isTrue);
  });

  testWidgets('devrait placer le premier onglet à droite et avancer avec la flèche gauche quand le sens est RTL', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const _Host(), direction: TextDirection.rtl));
    expect(tester.getCenter(find.text('Messages')).dx, greaterThan(tester.getCenter(find.text('Contacts')).dx));
    expect(_indicators(tester).single.$1, rectMoreOrLessEquals(_tab(tester, 'Messages'), epsilon: 0.01));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(_controller(tester).index, 1);
    expect(_indicators(tester).single.$1, rectMoreOrLessEquals(_tab(tester, 'Appels'), epsilon: 0.01));
  });

  testWidgets(
    "devrait défiler quand les onglets dépassent, sans couper un libellé, et amener l'onglet choisi à l'écran",
    (tester) async {
      const labels = ['Messages', 'Appels', 'Contacts', 'Favoris', 'Paramètres'];
      final controller = FlTabController(length: labels.length);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        toggleApp(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SizedBox(
              width: 360,
              child: FlTabs(controller: controller, labels: labels),
            ),
          ),
        ),
      );
      for (final label in labels) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
        final lines = paragraph
            .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: label.length))
            .map((box) => box.top)
            .toSet();
        expect(lines, hasLength(1), reason: label);
      }
      expect(tester.state<ScrollableState>(find.byType(Scrollable)).position.maxScrollExtent, greaterThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(controller.index, labels.length - 1);
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      final last = tester.getRect(find.text('Paramètres'));
      expect(last.left, greaterThanOrEqualTo(viewport.left));
      expect(last.right, lessThanOrEqualTo(viewport.right));
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('devrait garder la cible tactile de ${platform.name} à chaque onglet quand la rangée défile', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      const labels = ['Messages', 'Appels', 'Contacts', 'Favoris', 'Paramètres'];
      final controller = FlTabController(length: labels.length);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        toggleApp(
          SizedBox(
            width: 320,
            child: FlTabs(controller: controller, labels: labels),
          ),
          platform: platform,
        ),
      );
      expect(find.byType(SingleChildScrollView), findsOne);
      expect(tester.getSize(find.byType(FlTabs)).height, 32 + 2 * FlTokens.defaults.space.xs);
      final target = platform == TargetPlatform.iOS
          ? FlTokens.defaults.size.hitTargetIos
          : FlTokens.defaults.size.hitTargetAndroid;
      for (final label in labels.take(3)) {
        final tab = find.ancestor(of: find.text(label), matching: find.byType(FlHitTarget)).first;
        expect(tester.getSemantics(tab).rect.height, target, reason: label);
      }
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
    });
  }

  testWidgets('devrait garder le focus et poser l’indicateur quand on passe un autre contrôleur de même longueur', (
    tester,
  ) async {
    final a = FlTabController(length: 3);
    final b = FlTabController(length: 3, initialIndex: 2);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    Widget bar(FlTabController controller) => toggleApp(
      SizedBox(
        width: 480,
        child: FlTabs(controller: controller, labels: _labels),
      ),
    );
    await tester.pumpWidget(bar(a));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(Focus.of(tester.element(find.text('Messages'))).hasPrimaryFocus, isTrue);
    await tester.pumpWidget(bar(b));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'FlTab 0');
    expect(_indicators(tester).single.$1, _tab(tester, 'Contacts'));
  });

  testWidgets("devrait accepter un index posé pendant le build d'un widget voisin", (tester) async {
    final controller = FlTabController(length: 3);
    addTearDown(controller.dispose);
    Widget bar(int index) => toggleApp(
      SizedBox(
        width: 480,
        child: Column(
          children: [
            Builder(
              builder: (context) {
                controller.index = index;
                return const SizedBox.shrink();
              },
            ),
            FlTabs(controller: controller, labels: _labels),
          ],
        ),
      ),
    );
    await tester.pumpWidget(bar(0));
    await tester.pumpWidget(bar(2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_indicators(tester).single.$1, _tab(tester, 'Contacts'));
  });

  testWidgets('devrait poser une icône avant chaque libellé, dans sa couleur, et peindre aux couleurs données', (
    tester,
  ) async {
    final controller = FlTabController(length: 2);
    addTearDown(controller.dispose);
    final tokens = FlTokens.defaults;
    await tester.pumpWidget(
      toggleApp(
        SizedBox(
          width: 360,
          child: FlTabs(
            controller: controller,
            labels: const ['Messages', 'Appels'],
            icons: const [
              SizedBox(key: Key('icon')),
              null,
            ],
            indicatorColor: _light.accent,
            selectedLabelColor: _light.onAccent,
          ),
        ),
      ),
    );
    final icon = tester.getRect(find.byKey(const Key('icon')));
    final label = tester.getRect(find.text('Messages'));
    expect(label.left - icon.right, tokens.size.buttonGapSm);
    final theme = IconTheme.of(tester.element(find.byKey(const Key('icon'))));
    expect((theme.size, theme.color), (tokens.size.buttonIconSm, _light.onAccent));
    expect(tester.widget<Text>(find.text('Messages')).style!.color, _light.onAccent);
    var accent = false;
    expect(
      _bar,
      paints..everything((method, arguments) {
        final paint = arguments.isEmpty ? null : arguments.last;
        if (method == #drawRRect && paint is Paint && paint.maskFilter == null) {
          accent |= paint.color.toARGB32() == _light.accent.toARGB32();
        }
        return true;
      }),
    );
    expect(accent, isTrue);
  });
}
