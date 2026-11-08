import 'package:fliin_ui/components/page_indicator/fl_page_indicator.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

String _label(int page, int count) => 'Page $page sur $count';

Widget _app(
  Widget child, {
  TargetPlatform platform = TargetPlatform.iOS,
  TextDirection dir = TextDirection.ltr,
  bool reduceMotion = false,
}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: Directionality(
    textDirection: dir,
    child: FlScope(
      platform: platform,
      child: Center(child: child),
    ),
  ),
);

final _dots = find.descendant(of: find.byType(FlPageIndicator), matching: find.byType(CustomPaint)).last;

/// Le nœud du lecteur d'écran, posé sous la cible tactile.
final _node = find.descendant(of: find.byType(FlPageIndicator), matching: find.byType(FlHitTarget));

/// Les points peints, du début à la fin en LTR : la pilule de 24 sur
/// [page], des points de 8 ailleurs, à 8 d'écart.
/// The other pages' dots: `onSurfaceMuted` at 40 %.
Color _dim(Color muted) => muted.withValues(alpha: muted.a * 0.4);

PaintPattern _rest(int count, int page, Color active, Color inactive) {
  var pattern = paints;
  var left = 0.0;
  for (var i = 0; i < count; i++) {
    final width = i == page ? 24.0 : 8.0;
    pattern = pattern
      ..rrect(
        rrect: RRect.fromLTRBR(left, 0, left + width, 8, const Radius.circular(4)),
        color: i == page ? active : inactive,
      );
    left += width + 8;
  }
  return pattern;
}

void main() {
  final light = FlTokens.defaults.light;

  testWidgets('devrait allonger le point de la page courante en pilule selected', (tester) async {
    await tester.pumpWidget(_app(FlPageIndicator(count: 3, index: 1, pageLabel: _label)));
    expect(tester.getSize(_dots), const Size(3 * 8 + 16 + 2 * 8, 8));
    expect(tester.renderObject(_dots), _rest(3, 1, light.selected, _dim(light.onSurfaceMuted)));
  });

  testWidgets('devrait glisser la pilule vers la nouvelle page par le ressort, ou s’y poser en mouvement réduit', (
    tester,
  ) async {
    for (final reduced in [false, true]) {
      await tester.pumpWidget(_app(FlPageIndicator(count: 3, index: 0, pageLabel: _label), reduceMotion: reduced));
      await tester.pumpWidget(_app(FlPageIndicator(count: 3, index: 2, pageLabel: _label), reduceMotion: reduced));
      await tester.pump(const Duration(milliseconds: 16));
      final moving = !reduced;
      expect(
        tester.renderObject(_dots),
        moving
            ? isNot(_rest(3, 2, light.selected, _dim(light.onSurfaceMuted)))
            : _rest(3, 2, light.selected, _dim(light.onSurfaceMuted)),
        reason: 'mouvement réduit : $reduced',
      );
      await tester.pumpAndSettle();
      expect(tester.renderObject(_dots), _rest(3, 2, light.selected, _dim(light.onSurfaceMuted)));
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('devrait lire un seul nœud ajustable, « page 2 sur 3 », et changer de page par le lecteur d’écran', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final chosen = <int>[];
    await tester.pumpWidget(
      _app(
        FlPageIndicator(count: 3, index: 1, semanticLabel: 'Présentation', onChanged: chosen.add, pageLabel: _label),
      ),
    );
    final node = tester.getSemantics(_node);
    expect(node.label, 'Présentation');
    expect(node.value, 'Page 2 sur 3');
    expect(node.increasedValue, 'Page 3 sur 3');
    expect(node.decreasedValue, 'Page 1 sur 3');
    node.owner!
      ..performAction(node.id, SemanticsAction.increase)
      ..performAction(node.id, SemanticsAction.decrease);
    expect(chosen, [2, 0]);
    handle.dispose();
  });

  testWidgets('devrait couvrir la cible tactile de la plateforme', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(FlPageIndicator(count: 3, index: 0, onChanged: (_) {}, pageLabel: _label)));
    expect(tester.getSemantics(_node).rect.height, 44);
    await tester.pumpWidget(
      _app(
        FlPageIndicator(count: 3, index: 0, onChanged: (_) {}, pageLabel: _label),
        platform: TargetPlatform.android,
      ),
    );
    expect(tester.getSemantics(_node).rect.height, 48);
    handle.dispose();
  });

  testWidgets('devrait avancer ou reculer d’une page au toucher après ou avant le milieu sur iOS, retourné en RTL', (
    tester,
  ) async {
    for (final (dir, side, expected) in [
      (TextDirection.ltr, 0.9, 2),
      (TextDirection.ltr, 0.1, 0),
      (TextDirection.rtl, 0.9, 0),
      (TextDirection.rtl, 0.1, 2),
    ]) {
      final chosen = <int>[];
      await tester.pumpWidget(
        _app(
          FlPageIndicator(count: 3, index: 1, onChanged: chosen.add, pageLabel: _label),
          dir: dir,
        ),
      );
      final rect = tester.getRect(_dots);
      await tester.tapAt(Offset(rect.left + rect.width * side, rect.center.dy));
      expect(chosen, [expected], reason: '$dir $side');
    }
  });

  testWidgets('devrait parcourir les points au glisser sur iOS', (tester) async {
    final chosen = <int>[];
    await tester.pumpWidget(_app(FlPageIndicator(count: 5, index: 0, onChanged: chosen.add, pageLabel: _label)));
    final rect = tester.getRect(_dots);
    final gesture = await tester.startGesture(rect.centerLeft + const Offset(2, 0));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(rect.width / 10, 0));
    }
    await gesture.up();
    expect(chosen.last, 4);
  });

  testWidgets('devrait choisir le point touché sur Android, même dans la marge de la cible', (tester) async {
    final chosen = <int>[];
    await tester.pumpWidget(
      _app(
        FlPageIndicator(count: 5, index: 0, onChanged: chosen.add, pageLabel: _label),
        platform: TargetPlatform.android,
      ),
    );
    final rect = tester.getRect(_dots);
    // Pilule 0..24, puis des points de 8 tous les 16 : le point 3 est centré à 68.
    await tester.tapAt(rect.topLeft + const Offset(68, -12));
    expect(chosen, [3]);
  });

  testWidgets('devrait changer de page aux flèches, dans le sens de lecture', (tester) async {
    final chosen = <int>[];
    await tester.pumpWidget(
      toggleApp(
        FlPageIndicator(count: 3, index: 1, onChanged: chosen.add, pageLabel: _label),
        direction: TextDirection.rtl,
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    expect(chosen, [2, 0]);
  });

  testWidgets('devrait suivre la vue de pages, et l’animer vers le point choisi', (tester) async {
    final controller = PageController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 300,
              height: 200,
              child: PageView(controller: controller, children: const [SizedBox(), SizedBox(), SizedBox()]),
            ),
            FlPageIndicator.controller(count: 3, controller: controller, pageLabel: _label),
          ],
        ),
        platform: TargetPlatform.android,
      ),
    );
    controller.jumpTo(150);
    await tester.pump();
    final half = tester.renderObject(_dots);
    expect(half, isNot(_rest(3, 0, light.selected, _dim(light.onSurfaceMuted))));
    expect(half, isNot(_rest(3, 1, light.selected, _dim(light.onSurfaceMuted))));
    controller.jumpToPage(0);
    await tester.pump();
    final rect = tester.getRect(_dots);
    await tester.tapAt(rect.centerRight - const Offset(4, 0));
    await tester.pumpAndSettle();
    expect(controller.page, 2);
    expect(tester.renderObject(_dots), _rest(3, 2, light.selected, _dim(light.onSurfaceMuted)));
  });

  testWidgets('devrait faire sauter la vue de pages au fil du glisser sur iOS, sans relancer d’animation', (
    tester,
  ) async {
    final controller = _CountingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 300,
              height: 200,
              child: PageView(controller: controller, children: List.generate(5, (_) => const SizedBox())),
            ),
            FlPageIndicator.controller(count: 5, controller: controller, pageLabel: _label),
          ],
        ),
      ),
    );
    final rect = tester.getRect(_dots);
    final gesture = await tester.startGesture(rect.centerLeft + const Offset(2, 0));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(Offset(rect.width / 40, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.page, greaterThan(0));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(Offset(rect.width / 40, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.page, 4);
    expect(controller.animateCalls, 0);
  });

  testWidgets('devrait annoncer chaque page une fois au glisser, même quand le parent ne rebâtit pas', (tester) async {
    final chosen = <int>[];
    await tester.pumpWidget(_app(FlPageIndicator(count: 5, index: 0, onChanged: chosen.add, pageLabel: _label)));
    final rect = tester.getRect(_dots);
    final gesture = await tester.startGesture(rect.centerLeft + const Offset(2, 0));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(Offset(rect.width / 20, 0));
    }
    await gesture.up();
    expect(chosen, [1, 2, 3, 4]);
  });

  testWidgets('devrait laisser remonter une flèche qui ne changerait rien, en bout de rangée', (tester) async {
    final chosen = <int>[];
    final passed = <LogicalKeyboardKey>[];
    await tester.pumpWidget(
      toggleApp(
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) passed.add(event.logicalKey);
            return KeyEventResult.handled;
          },
          child: FlPageIndicator(count: 3, index: 2, onChanged: chosen.add, pageLabel: _label),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(passed, [LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.end]);
    expect(chosen, [1]);
  });

  testWidgets('devrait s’annoncer comme un curseur', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(FlPageIndicator(count: 3, index: 0, onChanged: (_) {}, pageLabel: _label)));
    expect(tester.getSemantics(_node).flagsCollection.isSlider, isTrue);
    handle.dispose();
  });

  testWidgets('devrait rester sur la dernière page quand le nombre de pages baisse sous la page courante', (
    tester,
  ) async {
    await tester.pumpWidget(_app(FlPageIndicator(count: 5, index: 4, onChanged: (_) {}, pageLabel: _label)));
    await tester.pumpWidget(_app(FlPageIndicator(count: 3, index: 2, onChanged: (_) {}, pageLabel: _label)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.renderObject(_dots),
      _rest(3, 2, FlTokens.defaults.light.selected, _dim(FlTokens.defaults.light.onSurfaceMuted)),
    );
  });

  testWidgets('devrait peindre la page courante en color et les autres à 40 %, ou en inactiveColor', (tester) async {
    final color = light.onAccent;
    await tester.pumpWidget(_app(FlPageIndicator(count: 3, index: 0, color: color, pageLabel: _label)));
    expect(tester.renderObject(_dots), _rest(3, 0, color, _dim(color)));
    await tester.pumpWidget(
      _app(FlPageIndicator(count: 3, index: 0, color: color, inactiveColor: light.accent, pageLabel: _label)),
    );
    expect(tester.renderObject(_dots), _rest(3, 0, color, light.accent));
  });
}

class _CountingController extends PageController {
  int animateCalls = 0;

  @override
  Future<void> animateToPage(int page, {required Duration duration, required Curve curve}) {
    animateCalls++;
    return super.animateToPage(page, duration: duration, curve: curve);
  }
}
