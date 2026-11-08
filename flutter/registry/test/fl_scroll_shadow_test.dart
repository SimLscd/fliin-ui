import 'dart:ui' as ui;

import 'package:fliin_ui/components/scroll_shadow/fl_scroll_shadow.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _frame = Key('frame');

/// Un défilant de 200 × 200 sur 500 points de contenu `accent`, dans une
/// ombre de 40 points : pleine dès 10 points cachés d'un côté.
Widget _app({
  Key? key,
  FlScrollShadowVisibility visibility = FlScrollShadowVisibility.auto,
  bool enabled = true,
  Axis axis = Axis.vertical,
  bool reverse = false,
  double content = 500,
  TextDirection direction = TextDirection.ltr,
  ScrollController? controller,
  bool mask = false,
  ValueChanged<FlScrollShadowVisibility>? onVisibilityChange,
}) => Directionality(
  textDirection: direction,
  child: FlScope(
    brightness: Brightness.light,
    child: Builder(
      builder: (context) => ColoredBox(
        color: FlScope.of(context).colors.surface,
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: RepaintBoundary(
            key: _frame,
            child: SizedBox.square(
              dimension: 200,
              child: FlScrollShadow(
                key: key,
                size: 40,
                visibility: visibility,
                enabled: enabled,
                mask: mask,
                onVisibilityChange: onVisibilityChange,
                child: SingleChildScrollView(
                  controller: controller,
                  scrollDirection: axis,
                  reverse: reverse,
                  child: SizedBox(
                    width: axis == Axis.horizontal ? content : null,
                    height: axis == Axis.vertical ? content : null,
                    child: ColoredBox(color: FlScope.of(context).colors.accent),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

/// La part de l'ombre au pixel logique ([x], [y]) du cadre : 0 sur le
/// contenu, 1 sur la couleur de la page.
Future<double> _shade(WidgetTester tester, int x, int y) async {
  final colors = FlTokens.defaults.light;
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_frame));
  // Le contenu se lit au centre du cadre, hors des deux ombres de 40 : la
  // mesure ne dépend pas de la couleur du contenu.
  final (red, content) = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    int at(int x, int y) => data!.getUint8((y * image.width + x) * 4);
    final pixel = (at(x, y), at(100, 100));
    image.dispose();
    return pixel;
  }))!;
  return (red - content) / (colors.surface.r * 255 - content);
}

Future<(double, double)> _edges(WidgetTester tester, {Axis axis = Axis.vertical}) async => axis == Axis.vertical
    ? (await _shade(tester, 100, 0), await _shade(tester, 100, 199))
    : (await _shade(tester, 0, 100), await _shade(tester, 199, 100));

/// The content's opacity at the logical pixel ([x], [y]) of the frame: 1
/// where it shows whole, 0 where a mask removed it.
Future<double> _opacity(WidgetTester tester, int x, int y) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_frame));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final alpha = data!.getUint8((y * image.width + x) * 4 + 3);
    image.dispose();
    return alpha / 255;
  }))!;
}

Matcher _about(double value) => closeTo(value, 0.03);

/// La part de l'ombre au bord de départ (haut, ou gauche) et au bord opposé.
Future<void> _expectEdges(
  WidgetTester tester,
  double first,
  double second, {
  Axis axis = Axis.vertical,
  String? reason,
}) async {
  final (a, b) = await _edges(tester, axis: axis);
  expect(a, _about(first), reason: reason);
  expect(b, _about(second), reason: reason);
}

void main() {
  testWidgets('devrait ombrer le bas seul quand le défilant est au début', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    final (top, bottom) = await _edges(tester);
    expect(top, _about(0));
    expect(bottom, _about(1));
  });

  testWidgets('devrait ombrer chaque bord selon le contenu caché de son côté quand on défile', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller: controller));
    await tester.pump();
    controller.jumpTo(4);
    await tester.pump();
    expect((await _edges(tester)).$1, _about(0.4));
    controller.jumpTo(150);
    await tester.pump();
    await _expectEdges(tester, 1, 1);
    controller.jumpTo(300);
    await tester.pump();
    await _expectEdges(tester, 1, 0);
  });

  testWidgets('devrait fondre le dégradé vers l’intérieur le long de easeInOut', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    // À un quart de la profondeur de l'ombre du bas (10,5 points du bord),
    // easeInOut garde 0,85 de l'ombre, là où un dégradé linéaire en
    // garderait 0,74.
    expect(await _shade(tester, 100, 189), _about(0.854));
    expect(await _shade(tester, 100, 159), _about(0));
  });

  testWidgets('devrait n’ombrer que les bords permis par la visibilité', (tester) async {
    final controller = ScrollController(initialScrollOffset: 150);
    addTearDown(controller.dispose);
    for (final (visibility, expected) in [
      (FlScrollShadowVisibility.top, (1.0, 0.0)),
      (FlScrollShadowVisibility.bottom, (0.0, 1.0)),
      (FlScrollShadowVisibility.both, (1.0, 1.0)),
      (FlScrollShadowVisibility.none, (0.0, 0.0)),
    ]) {
      await tester.pumpWidget(_app(key: ValueKey(visibility), visibility: visibility, controller: controller));
      await tester.pump();
      await _expectEdges(tester, expected.$1, expected.$2, reason: visibility.name);
    }
  });

  testWidgets('devrait effacer les ombres en short4 quand on les désactive', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pumpWidget(_app(enabled: false));
    await tester.pump(const Duration(milliseconds: 100));
    expect((await _edges(tester)).$2, inExclusiveRange(0.1, 0.9));
    await tester.pump(const Duration(milliseconds: 100));
    expect((await _edges(tester)).$2, _about(0));
  });

  testWidgets('devrait effacer les ombres d’un coup sous mouvement réduit', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pumpWidget(_app(enabled: false));
    expect((await _edges(tester)).$2, _about(0));
  });

  testWidgets('devrait ombrer la fin, à gauche, quand un défilant horizontal RTL est au début', (tester) async {
    await tester.pumpWidget(_app(axis: Axis.horizontal, direction: TextDirection.rtl));
    await tester.pump();
    final (left, right) = await _edges(tester, axis: Axis.horizontal);
    expect(left, _about(1));
    expect(right, _about(0));
  });

  testWidgets('devrait garder start et end au début et à la fin de lecture en RTL', (tester) async {
    await tester.pumpWidget(
      _app(axis: Axis.horizontal, direction: TextDirection.rtl, visibility: FlScrollShadowVisibility.end),
    );
    await tester.pump();
    await _expectEdges(tester, 1, 0, axis: Axis.horizontal);
  });

  testWidgets('devrait ombrer le haut quand un défilant inversé est à son début', (tester) async {
    await tester.pumpWidget(_app(reverse: true));
    await tester.pump();
    await _expectEdges(tester, 1, 0);
  });

  testWidgets('devrait ne rien ombrer quand tout le contenu tient', (tester) async {
    await tester.pumpWidget(_app(content: 200));
    await tester.pump();
    await _expectEdges(tester, 0, 0);
  });

  testWidgets('devrait fondre le contenu lui-même aux bords, selon le défilement, quand mask est vrai', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    Future<void> edges(double top, double bottom) async {
      expect(await _opacity(tester, 100, 0), _about(top));
      expect(await _opacity(tester, 100, 199), _about(bottom));
    }

    await tester.pumpWidget(_app(controller: controller, mask: true));
    await tester.pump();
    await edges(1, 0);
    // The same easeInOut ramp as the painted shadow.
    expect(await _opacity(tester, 100, 189), _about(1 - 0.854));
    expect(await _opacity(tester, 100, 100), _about(1));
    controller.jumpTo(150);
    await tester.pump();
    await edges(0, 0);
    controller.jumpTo(300);
    await tester.pump();
    await edges(0, 1);
  });

  testWidgets('devrait annoncer les bords qui cachent du contenu à chaque changement', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final seen = <FlScrollShadowVisibility>[];
    await tester.pumpWidget(_app(controller: controller, onVisibilityChange: seen.add));
    await tester.pump();
    controller.jumpTo(100);
    await tester.pump();
    controller.jumpTo(120);
    await tester.pump();
    controller.jumpTo(300);
    await tester.pump();
    expect(seen, [FlScrollShadowVisibility.bottom, FlScrollShadowVisibility.both, FlScrollShadowVisibility.top]);
  });

  testWidgets('devrait annoncer start et end pour un défilement horizontal', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final seen = <FlScrollShadowVisibility>[];
    await tester.pumpWidget(_app(axis: Axis.horizontal, controller: controller, onVisibilityChange: seen.add));
    await tester.pump();
    controller.jumpTo(300);
    await tester.pump();
    expect(seen, [FlScrollShadowVisibility.end, FlScrollShadowVisibility.start]);
  });
}
