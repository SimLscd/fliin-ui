import 'dart:async';

import 'package:fliin_ui/components/sheet/fl_sheet.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'écran du test fait 800 × 600 : la hauteur disponible est 600.
const _height = 600.0;

Widget _app(Widget sheet, {EdgeInsets keyboard = EdgeInsets.zero}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => MediaQuery(
    data: MediaQuery.of(context).copyWith(viewInsets: keyboard),
    child: FlScope(
      brightness: Brightness.light,
      platform: TargetPlatform.android,
      child: FocusScope(
        autofocus: true,
        child: Stack(
          children: [
            Align(
              alignment: AlignmentDirectional.topStart,
              child: GestureDetector(
                onTap: () {},
                child: Focus(
                  autofocus: true,
                  debugLabel: 'derrière',
                  child: const Text('Derrière', textDirection: TextDirection.ltr),
                ),
              ),
            ),
            Positioned.fill(child: sheet),
          ],
        ),
      ),
    ),
  ),
);

class _Content extends StatelessWidget {
  const _Content();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final label in ['Premier', 'Second'])
        Focus(
          debugLabel: label,
          child: Builder(builder: (context) => Text(label, textDirection: TextDirection.ltr)),
        ),
    ],
  );
}

Finder get _panel => find.descendant(of: find.byType(FlSheet), matching: find.byType(FadeTransition)).last;

double _top(WidgetTester tester) => tester.getTopLeft(_panel).dy;

FlSheet _sheet({
  List<double> snaps = const [0.5, 1],
  VoidCallback? onDismiss,
  bool animateIn = false,
  bool modal = true,
}) => FlSheet(
  label: 'Partager',
  barrierLabel: 'Fermer la feuille',
  snaps: snaps,
  onDismiss: onDismiss,
  animateIn: animateIn,
  modal: modal,
  child: const _Content(),
);

String? _focused() => FocusManager.instance.primaryFocus?.debugLabel;

void main() {
  testWidgets("devrait s'ouvrir sur son premier arrêt et s'annoncer comme un dialogue nommé qu'on peut fermer", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_sheet(onDismiss: () {})));
    expect(_top(tester), _height / 2);
    expect(
      tester.getSemantics(find.descendant(of: _panel, matching: find.byType(GestureDetector)).first),
      matchesSemantics(
        label: 'Partager',
        role: SemanticsRole.dialog,
        scopesRoute: true,
        namesRoute: true,
        hasDismissAction: true,
        hasIncreaseAction: true,
        children: [
          matchesSemantics(label: 'Premier', isFocusable: true, hasFocusAction: true),
          matchesSemantics(label: 'Second', isFocusable: true, hasFocusAction: true),
        ],
      ),
    );
    expect(find.semantics.byLabel('Fermer la feuille'), findsOne);
    expect(find.semantics.byLabel('Derrière'), findsNothing);
    semantics.dispose();
  });

  testWidgets('devrait laisser le contenu derrière lisible et ne pas poser de voile quand elle n’est pas modale', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_sheet(modal: false)));
    expect(find.semantics.byLabel('Derrière'), findsOne);
    expect(find.byType(FlPopupOverlay), findsNothing);
    semantics.dispose();
  });

  testWidgets('devrait entrer depuis le bas par ressort quand animateIn est vrai', (tester) async {
    await tester.pumpWidget(_app(_sheet(animateIn: true)));
    expect(_top(tester), _height);
    await tester.pump(const Duration(milliseconds: 50));
    expect(_top(tester), inExclusiveRange(_height / 2, _height));
    await tester.pumpAndSettle();
    expect(_top(tester), _height / 2);
  });

  testWidgets('devrait entrer en fondu, sans glisser, quand le mouvement est réduit', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_app(_sheet(animateIn: true)));
    await tester.pump(const Duration(milliseconds: 75));
    expect(_top(tester), _height / 2);
    expect(tester.widget<FadeTransition>(_panel).opacity.value, closeTo(0.5, 0.05));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.widget<FadeTransition>(_panel).opacity.value, 1);
  });

  testWidgets(
    "devrait monter à l'arrêt suivant quand on la lance vers le haut, et revenir au plus proche quand on la pose",
    (tester) async {
      await tester.pumpWidget(_app(_sheet()));
      await tester.fling(find.text('Premier'), const Offset(0, -150), 1500);
      await tester.pumpAndSettle();
      expect(_top(tester), 0);

      await tester.timedDrag(find.text('Premier'), const Offset(0, 200), const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(_top(tester), _height / 2);
    },
  );

  testWidgets('devrait partir de la vitesse du doigt quand on la lâche lancée', (tester) async {
    await tester.pumpWidget(_app(_sheet()));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Premier')));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, -20), timeStamp: Duration(milliseconds: 16 * (i + 1)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final released = _top(tester);
    await gesture.up(timeStamp: const Duration(milliseconds: 96));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(released - _top(tester), greaterThan(10), reason: 'environ 1 250 px/s au lâcher, soit 20 px par frame');
  });

  testWidgets('devrait se fermer et appeler onDismiss une fois sortie quand on la glisse sous son premier arrêt', (
    tester,
  ) async {
    var dismissed = 0;
    await tester.pumpWidget(_app(_sheet(onDismiss: () => dismissed++)));
    await tester.fling(find.text('Premier'), const Offset(0, 100), 1000);
    await tester.pump();
    expect(dismissed, 0);
    await tester.pumpAndSettle();
    expect(dismissed, 1);
    expect(_top(tester), closeTo(_height, 1));
  });

  testWidgets('devrait rester à son premier arrêt quand on la glisse vers le bas sans onDismiss', (tester) async {
    await tester.pumpWidget(_app(_sheet()));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Premier')));
    await gesture.moveBy(const Offset(0, 100));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    expect(_top(tester), _height / 2);
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.fling(find.text('Premier'), const Offset(0, 200), 1000);
    await tester.pumpAndSettle();
    expect(_top(tester), _height / 2);
  });

  testWidgets('devrait se fermer quand on touche le voile ou quand on presse Échap', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(_app(_sheet(onDismiss: () => dismissed++)));
    await tester.tapAt(const Offset(400, 100));
    await tester.pumpAndSettle();
    expect(dismissed, 1);

    await tester.pumpWidget(Container());
    await tester.pumpWidget(_app(_sheet(onDismiss: () => dismissed++)));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(dismissed, 2);
  });

  testWidgets('devrait sortir en fondu, sans glisser, quand le mouvement est réduit', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    var dismissed = 0;
    await tester.pumpWidget(_app(_sheet(onDismiss: () => dismissed++)));
    await tester.tapAt(const Offset(400, 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    expect(_top(tester), _height / 2);
    expect(tester.widget<FadeTransition>(_panel).opacity.value, closeTo(0.5, 0.05));
    await tester.pumpAndSettle();
    expect(dismissed, 1);
  });

  testWidgets('devrait garder le focus dans la feuille modale et le rendre à son ancien détenteur quand elle part', (
    tester,
  ) async {
    var open = false;
    late StateSetter setOpen;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            setOpen = setState;
            return open ? _sheet(onDismiss: () {}) : const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    expect(_focused(), 'derrière');
    setOpen(() => open = true);
    await tester.pump();
    final visited = <String?>[];
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      visited.add(_focused());
    }
    expect(visited, ['Premier', 'Second', 'Premier', 'Second']);
    setOpen(() => open = false);
    await tester.pump();
    await tester.pump();
    expect(_focused(), 'derrière');
  });

  testWidgets('devrait se poser au-dessus du clavier logiciel', (tester) async {
    await tester.pumpWidget(_app(_sheet(), keyboard: const EdgeInsets.only(bottom: 200)));
    expect(_top(tester), (_height - 200) / 2);
    expect(tester.getBottomLeft(_panel).dy, lessThanOrEqualTo(_height - 200 + (_height - 200) / 2));
    expect(find.text('Premier').hitTestable(), findsOne);
  });

  testWidgets('devrait sortir avant que la route ne parte, et rendre la valeur, quand le retour système la ferme', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        navigatorKey: key,
        onGenerateRoute: (settings) => PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (context, _, _) => FlScope(platform: TargetPlatform.android, child: const SizedBox.expand()),
        ),
      ),
    );
    final result = showFlSheet<String>(
      key.currentContext!,
      label: 'Partager',
      barrierLabel: 'Fermer la feuille',
      snaps: const [0.5],
      builder: (context) => const _Content(),
    );
    await tester.pumpAndSettle();
    expect(_top(tester), _height / 2);

    final popped = key.currentState!.maybePop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(FlSheet), findsOne);
    expect(_top(tester), greaterThan(_height / 2));
    await tester.pumpAndSettle();
    expect(find.byType(FlSheet), findsNothing);
    expect(await popped, isTrue);
    expect(await result, isNull);
  });

  testWidgets(
    'devrait rester à son arrêt quand une PopScope du contenu refuse la fermeture, puis partir quand elle accepte',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          navigatorKey: key,
          onGenerateRoute: (settings) => PageRouteBuilder<void>(
            settings: settings,
            pageBuilder: (context, _, _) => FlScope(platform: TargetPlatform.android, child: const SizedBox.expand()),
          ),
        ),
      );
      var canPop = false;
      var refused = 0;
      final result = showFlSheet<String>(
        key.currentContext!,
        label: 'Partager',
        barrierLabel: 'Fermer la feuille',
        snaps: const [0.5],
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => PopScope<Object?>(
            canPop: canPop,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) refused++;
            },
            child: const _Content(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_top(tester), _height / 2);

      // La barrière, au-dessus de la feuille.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.drag(find.text('Premier'), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(refused, 3, reason: 'la barrière, Échap et le geste vers le bas demandent tous à la route');
      expect(find.byType(FlSheet), findsOne);
      expect(_top(tester), _height / 2, reason: 'la feuille retourne à son arrêt');

      canPop = true;
      (tester.element(find.byType(StatefulBuilder)) as StatefulElement).markNeedsBuild();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(FlSheet), findsNothing);
      expect(await result, isNull);
    },
  );

  testWidgets('devrait laisser le retour système à la page, qui part avec la feuille, quand onDismiss est nul', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        navigatorKey: key,
        onGenerateRoute: (settings) => PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (context, _, _) => FlScope(platform: TargetPlatform.android, child: const SizedBox.expand()),
        ),
      ),
    );
    unawaited(
      key.currentState!.push(
        PageRouteBuilder<void>(
          pageBuilder: (context, _, _) => FlScope(
            platform: TargetPlatform.android,
            child: FlSheet(label: 'Lecteur', snaps: const [0.5], child: const _Content()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FlSheet), findsOne);

    expect(await key.currentState!.maybePop(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(FlSheet), findsNothing);
    expect(key.currentState!.canPop(), isFalse);
  });

  testWidgets(
    "devrait mettre le contenu à la hauteur visible, pour qu'une liste défile jusqu'à son dernier élément à l'arrêt bas",
    (tester) async {
      await tester.pumpWidget(
        _app(
          FlSheet(
            label: 'Liste',
            snaps: const [0.5, 1],
            child: ListView(
              children: [
                for (var i = 0; i < 40; i++) SizedBox(height: 40, child: Text('L$i', textDirection: TextDirection.ltr)),
              ],
            ),
          ),
        ),
      );
      await tester.dragUntilVisible(find.text('L39'), find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.text('L39').hitTestable(), findsOne);
      expect(tester.getBottomLeft(find.text('L39')).dy, lessThanOrEqualTo(_height));
    },
  );

  testWidgets("devrait passer à l'arrêt voisin avec Alt+↑ et Alt+↓, et par les actions increase et decrease", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_sheet()));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(_top(tester), 0);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(_top(tester), _height / 2);

    tester.semantics.performAction(find.semantics.byLabel('Partager'), SemanticsAction.increase);
    await tester.pumpAndSettle();
    expect(_top(tester), 0);
    tester.semantics.performAction(find.semantics.byLabel('Partager'), SemanticsAction.decrease);
    await tester.pumpAndSettle();
    expect(_top(tester), _height / 2);
    semantics.dispose();
  });

  testWidgets("devrait rendre la valeur de Navigator.pop après l'animation de sortie de showFlSheet", (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        navigatorKey: key,
        onGenerateRoute: (settings) => PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (context, _, _) => FlScope(platform: TargetPlatform.android, child: const SizedBox.expand()),
        ),
      ),
    );
    String? value;
    var done = false;
    unawaited(
      showFlSheet<String>(
        key.currentContext!,
        label: 'Partager',
        barrierLabel: 'Fermer la feuille',
        snaps: const [0.5],
        builder: (context) => const _Content(),
      ).then((result) {
        value = result;
        done = true;
      }),
    );
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Premier'))).pop('ok');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(FlSheet), findsOne);
    expect(_top(tester), inExclusiveRange(_height / 2, _height));
    expect(done, isFalse);
    await tester.pumpAndSettle();
    expect(find.byType(FlSheet), findsNothing);
    expect(done, isTrue);
    expect(value, 'ok');
  });

  testWidgets('devrait foncer le voile avec la feuille pendant un glisser et pendant le fondu du mouvement réduit', (
    tester,
  ) async {
    final strength = FlTokens.defaults.size.scrimOpacity;
    final curve = FlTokens.defaults.motion.easeInOutQuad;
    // Le voile de FlPopup : scrim à scrimOpacity, dont l'opacité suit
    // l'ouverture le long de motion.curve.easeInOutQuad.
    double alpha() =>
        strength *
        tester
            .widget<FadeTransition>(
              find.descendant(of: find.byType(FlPopupOverlay), matching: find.byType(FadeTransition)),
            )
            .opacity
            .value;

    await tester.pumpWidget(_app(_sheet(onDismiss: () {})));
    expect(alpha(), closeTo(strength, 0.01));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Premier')));
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 150));
    await tester.pump();
    // Les 170 du glisser comptent dès l'appui, pente de départ comprise.
    expect(alpha(), closeTo(strength * curve.transform((300 - 170) / 300), 0.03));
    await gesture.up();
    await tester.pumpAndSettle();

    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(Container());
    await tester.pumpWidget(_app(_sheet(onDismiss: () {}, animateIn: true)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    expect(alpha(), closeTo(strength * curve.transform(0.5), 0.03));
  });

  testWidgets(
    'devrait appeler onDismiss une fois sous une double fermeture, et jamais quand elle est retirée en sortant',
    (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(_app(_sheet(onDismiss: () => dismissed++)));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(400, 50));
      await tester.pumpAndSettle();
      expect(dismissed, 1);

      await tester.pumpWidget(Container());
      await tester.pumpWidget(_app(_sheet(onDismiss: () => dismissed++)));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
    },
  );

  testWidgets("devrait aller à l'arrêt le plus proche quand snaps change après le montage", (tester) async {
    await tester.pumpWidget(_app(_sheet(snaps: const [0.5])));
    await tester.pumpWidget(_app(_sheet(snaps: const [0.8])));
    await tester.pumpAndSettle();
    expect(_top(tester), closeTo(_height * 0.2, 0.01));
  });

  testWidgets('devrait refuser des arrêts qui ne sont pas strictement croissants dans ]0, 1]', (tester) async {
    for (final snaps in [
      const [0.0, 1.0],
      const [0.8, 0.5],
      const [0.5, 1.2],
    ]) {
      await tester.pumpWidget(_app(_sheet(snaps: snaps)));
      expect(tester.takeException(), isAssertionError, reason: '$snaps');
    }
  });

  testWidgets('devrait isoler la feuille animée dans un RepaintBoundary', (tester) async {
    await tester.pumpWidget(_app(_sheet()));
    expect(find.ancestor(of: _panel, matching: find.byType(RepaintBoundary)), findsWidgets);
    expect(
      find
          .descendant(of: find.byType(FlSheet), matching: find.byType(RepaintBoundary))
          .evaluate()
          .where(
            (element) => find.descendant(of: find.byWidget(element.widget), matching: _panel).evaluate().isNotEmpty,
          ),
      isNotEmpty,
    );
  });

  testWidgets(
    'devrait poser titre et texte en tête, le bouton de fermeture au bout de la ligne du titre, et fermer par ce bouton',
    (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        _app(
          FlSheet(
            label: 'Partager',
            barrierLabel: 'Fermer la feuille',
            title: 'Partager le fichier',
            description: 'Choisissez où l’envoyer.',
            closeLabel: 'Fermer',
            snaps: const [0.5],
            onDismiss: () => dismissed++,
            child: const _Content(),
          ),
        ),
      );
      final close = tester.getRect(find.bySemanticsLabel('Fermer'));
      final title = tester.getRect(find.text('Partager le fichier'));
      final description = tester.getRect(find.text('Choisissez où l’envoyer.'));
      final content = tester.getRect(find.text('Premier'));
      expect(close.left, greaterThan(title.right));
      expect(close.top, lessThan(title.bottom));
      expect(close.bottom, greaterThan(title.top));
      expect(title.bottom, lessThanOrEqualTo(description.top));
      expect(description.bottom, lessThan(content.top));
      final titleStyle = tester.renderObject<RenderParagraph>(find.text('Partager le fichier')).text.style!;
      expect(titleStyle.fontSize, FlTokens.defaults.typography.android.textLg.size);
      expect(titleStyle.fontWeight, FlTokens.defaults.typography.weight.medium);
      await tester.tap(find.bySemanticsLabel('Fermer'));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
    },
  );

  testWidgets('devrait peindre la feuille : surfaceOverlay, poignée de 36 × 5 en separator à 60 % à space.sm du bord', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_sheet()));
    final tokens = FlTokens.defaults;
    final handle = find.descendant(
      of: find.byType(FlSheet),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                tokens.light.separator.withValues(alpha: tokens.light.separator.a * 0.6),
      ),
    );
    expect(tester.getSize(handle), const Size(36, 5));
    expect(tester.getRect(handle).top - _top(tester), tokens.space.sm);
    expect(
      find
          .descendant(
            of: _panel,
            matching: find.byWidgetPredicate((widget) => widget is CustomPaint && widget.child is Column),
          )
          .first,
      paints..rrect(color: tokens.light.surfaceOverlay),
    );
  });

  testWidgets('devrait faire défiler l’en-tête au-delà de la moitié de la feuille et laisser l’autre au contenu', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3)),
        child: _app(
          FlSheet(
            label: 'Partager',
            barrierLabel: 'Fermer la feuille',
            title: 'Partager le fichier annuel',
            description: List.filled(12, 'Choisissez où l’envoyer.').join(' '),
            snaps: const [0.5],
            onDismiss: () {},
            child: const _Content(),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final content = tester.getRect(find.text('Premier'));
    final xs = FlTokens.defaults.space.xs;
    // Sous la poignée (2,5 + 1 + 2,5 unités) et la marge haute (5), la zone
    // intérieure s'arrête à la marge basse (3) : l'en-tête en prend la moitié au plus.
    final inner = _height * 0.5 - xs * 6 - xs * 5 - xs * 3;
    expect(content.top, lessThanOrEqualTo(_height * 0.5 + xs * 6 + xs * 5 + inner / 2));
    expect(find.descendant(of: find.byType(FlSheet), matching: find.byType(SingleChildScrollView)), findsOne);
  });

  testWidgets('devrait prendre la hauteur du contenu avec fitContent, la suivre quand il change, et défiler au-delà', (
    tester,
  ) async {
    var height = 200.0;
    late StateSetter grow;
    await tester.pumpWidget(
      _app(
        FlSheet(
          label: 'Partager',
          fitContent: true,
          child: StatefulBuilder(
            builder: (context, setState) {
              grow = setState;
              return SizedBox(key: const ValueKey('contenu'), height: height);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final content = find.byKey(const ValueKey('contenu'));
    double gap() => tester.getRect(_panel).bottom - tester.getRect(content).bottom;
    final first = gap();
    expect(_top(tester), greaterThan(_height - 200 - 150));
    grow(() => height = 300);
    await tester.pumpAndSettle();
    expect(gap(), closeTo(first, 0.5));
    expect(tester.getRect(content).height, closeTo(300, 1e-9));
    grow(() => height = 2000);
    await tester.pumpAndSettle();
    expect(_top(tester), closeTo(0, 0.5));
    expect(find.descendant(of: find.byType(FlSheet), matching: find.byType(Scrollable)), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('devrait centrer l’en-tête sous l’icône, dans un disque de space.xxl × 2 que le lecteur d’écran ignore', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        FlSheet(
          label: 'Mise à jour',
          barrierLabel: 'Fermer la feuille',
          icon: const SizedBox(key: ValueKey('icône'), width: 10, height: 10),
          iconTone: FlSheetIconTone.success,
          title: 'Restez protégé',
          description: 'Installez la dernière version.',
          onDismiss: () {},
        ),
      ),
    );
    final panel = tester.getRect(_panel);
    final space = FlTokens.defaults.space;
    final disc = tester.getRect(
      find.ancestor(of: find.byKey(const ValueKey('icône')), matching: find.byType(DecoratedBox)).first,
    );
    expect(disc.size, Size.square(space.xxl * 2));
    for (final rect in [
      disc,
      tester.getRect(find.text('Restez protégé')),
      tester.getRect(find.text('Installez la dernière version.')),
    ]) {
      expect(rect.center.dx, closeTo(panel.center.dx, 0.5));
    }
    expect(tester.getRect(find.text('Restez protégé')).top - disc.bottom, closeTo(space.lg, 0.5));
    expect(find.bySemanticsLabel('Restez protégé'), findsOne);
    expect(find.descendant(of: find.byType(ExcludeSemantics), matching: find.byKey(const ValueKey('icône'))), findsOne);
  });

  testWidgets('devrait empiler les actions en pleine largeur en bas de la feuille, sous le contenu', (tester) async {
    await tester.pumpWidget(
      _app(
        FlSheet(
          label: 'Partager',
          barrierLabel: 'Fermer la feuille',
          title: 'Partager',
          snaps: const [0.8],
          onDismiss: () {},
          actions: const [
            SizedBox(key: ValueKey('un'), height: 40),
            SizedBox(key: ValueKey('deux'), height: 40),
          ],
          child: const _Content(),
        ),
      ),
    );
    final space = FlTokens.defaults.space;
    final panel = tester.getRect(_panel);
    final one = tester.getRect(find.byKey(const ValueKey('un')));
    final two = tester.getRect(find.byKey(const ValueKey('deux')));
    // p-5 de chaque côté, et la marge basse (3) sous le dernier bouton.
    expect(one.width, closeTo(panel.width - space.xs * 10, 1e-9));
    expect(two.width, one.width);
    expect(two.top - one.bottom, space.md);
    expect(panel.bottom - two.bottom, closeTo(space.xs * 3, 1e-9));
    expect(one.top, greaterThan(tester.getRect(find.text('Second')).bottom + space.lg));
  });

  testWidgets('devrait prendre la hauteur de l’en-tête et des actions avec fitContent, sans couper le texte', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        FlSheet(
          label: 'Mise à jour',
          barrierLabel: 'Fermer la feuille',
          fitContent: true,
          icon: const SizedBox(width: 10, height: 10),
          title: 'Restez protégé',
          description: List.filled(6, 'Installez la dernière version.').join(' '),
          onDismiss: () {},
          actions: const [SizedBox(key: ValueKey('action'), height: 40)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final space = FlTokens.defaults.space;
    final panel = tester.getRect(_panel);
    final text = tester.getRect(find.textContaining('Installez'));
    final action = tester.getRect(find.byKey(const ValueKey('action')));
    expect(panel.top, greaterThan(_height / 3));
    expect(action.top - text.bottom, closeTo(space.xl, 0.5));
    expect(panel.bottom - action.bottom, closeTo(space.xs * 3, 1e-9));
    expect(tester.takeException(), isNull);
  });
}
