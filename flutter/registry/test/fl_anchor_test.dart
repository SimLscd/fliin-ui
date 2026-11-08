import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _bounds = Rect.fromLTWH(0, 0, 400, 800);
const _child = Size(200, 100);

FlAnchorFit _fit(
  Rect anchor, {
  FlSide side = FlSide.bottom,
  FlAlign align = FlAlign.start,
  TextDirection direction = TextDirection.ltr,
  Size child = _child,
  Rect bounds = _bounds,
}) => flAnchor(anchor: anchor, child: child, bounds: bounds, side: side, align: align, direction: direction, gap: 4);

void main() {
  group('flAnchor', () {
    test('devrait poser l’enfant sous l’ancre, aligné sur son bord de début, quand il y a la place', () {
      expect(_fit(const Rect.fromLTWH(50, 100, 80, 40)), (offset: const Offset(50, 144), side: FlSide.bottom));
    });

    test('devrait aligner le début sur le bord droit de l’ancre quand le sens est RTL', () {
      final fit = _fit(const Rect.fromLTWH(250, 100, 80, 40), direction: TextDirection.rtl);
      expect(fit.offset, const Offset(130, 144));
    });

    test('devrait centrer l’enfant sur l’ancre quand l’alignement est centré', () {
      expect(_fit(const Rect.fromLTWH(150, 100, 100, 40), align: FlAlign.center).offset, const Offset(100, 144));
    });

    test('devrait se retourner au-dessus quand il ne tient pas dessous et tient au-dessus', () {
      expect(_fit(const Rect.fromLTWH(50, 700, 80, 40)), (offset: const Offset(50, 596), side: FlSide.top));
    });

    test('devrait se retourner dessous quand il est demandé au-dessus d’une ancre collée en haut', () {
      expect(_fit(const Rect.fromLTWH(50, 10, 80, 40), side: FlSide.top).side, FlSide.bottom);
    });

    test('devrait garder le côté le plus grand et rester dans la zone quand il ne tient d’aucun côté', () {
      final fit = _fit(const Rect.fromLTWH(50, 60, 80, 40), bounds: const Rect.fromLTWH(0, 0, 400, 180));
      expect(fit.side, FlSide.bottom);
      expect(fit.offset, const Offset(50, 80));
    });

    test('devrait glisser le long de l’ancre pour rester dans la zone quand l’ancre est près du bord', () {
      expect(_fit(const Rect.fromLTWH(350, 100, 40, 40)).offset, const Offset(200, 144));
      expect(_fit(const Rect.fromLTWH(10, 100, 40, 40), direction: TextDirection.rtl).offset, const Offset(0, 144));
    });

    test('devrait coller au bord de début un enfant plus large que la zone, à droite en RTL', () {
      const anchor = Rect.fromLTWH(100, 100, 40, 40);
      const wide = Size(500, 100);
      expect(_fit(anchor, child: wide).offset.dx, 0);
      expect(_fit(anchor, child: wide, direction: TextDirection.rtl).offset.dx, 400 - 500);
    });

    test('devrait poser l’enfant à droite pour le côté fin en LTR et à gauche en RTL', () {
      const anchor = Rect.fromLTWH(150, 100, 40, 40);
      expect(_fit(anchor, side: FlSide.end, child: const Size(100, 60)), (
        offset: const Offset(194, 100),
        side: FlSide.end,
      ));
      expect(_fit(anchor, side: FlSide.end, child: const Size(100, 60), direction: TextDirection.rtl), (
        offset: const Offset(46, 100),
        side: FlSide.end,
      ));
    });

    test('devrait retourner le côté fin vers le début quand il touche le bord, en gardant un côté directionnel', () {
      final fit = _fit(
        const Rect.fromLTWH(10, 100, 40, 40),
        side: FlSide.end,
        child: const Size(100, 60),
        direction: TextDirection.rtl,
      );
      expect(fit, (offset: const Offset(54, 100), side: FlSide.start));
    });
  });

  group('flAnchorBounds', () {
    test('devrait retirer encoche, barres système et clavier, plus la marge, de la zone', () {
      final bounds = flAnchorBounds(
        overlay: const Size(400, 800),
        padding: const EdgeInsets.only(top: 47, bottom: 34),
        viewInsets: const EdgeInsets.only(bottom: 300),
        margin: 8,
      );
      expect(bounds, const Rect.fromLTRB(8, 55, 392, 492));
    });
  });

  group('FlAnchoredLayout', () {
    setUp(() {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
      view
        ..physicalSize = const Size(400, 800)
        ..devicePixelRatio = 1;
      addTearDown(view.reset);
    });

    Widget host(Widget child, {EdgeInsets viewInsets = EdgeInsets.zero, TextDirection direction = TextDirection.ltr}) =>
        MediaQuery(
          data: MediaQueryData(size: const Size(400, 800), viewInsets: viewInsets),
          child: Directionality(
            textDirection: direction,
            child: FlScope(
              child: Stack(children: [Positioned.fill(child: child)]),
            ),
          ),
        );

    const box = SizedBox(key: Key('panel'), width: 200, height: 100);
    final space = FlTokens.defaults.space;

    testWidgets('devrait poser l’enfant sous l’ancre à space.xs quand il y a la place', (tester) async {
      await tester.pumpWidget(host(const FlAnchoredLayout(anchor: Rect.fromLTWH(50, 100, 80, 40), child: box)));
      expect(tester.getTopLeft(find.byKey(const Key('panel'))), Offset(50, 140 + space.xs));
    });

    testWidgets('devrait passer au-dessus de l’ancre quand le clavier couvre le dessous', (tester) async {
      await tester.pumpWidget(
        host(
          const FlAnchoredLayout(anchor: Rect.fromLTWH(50, 400, 80, 40), child: box),
          viewInsets: const EdgeInsets.only(bottom: 300),
        ),
      );
      expect(tester.getBottomLeft(find.byKey(const Key('panel'))), Offset(50, 400 - space.xs));
    });

    testWidgets('devrait rester à space.sm du bord quand l’ancre est près du bord de fin', (tester) async {
      await tester.pumpWidget(host(const FlAnchoredLayout(anchor: Rect.fromLTWH(360, 100, 30, 40), child: box)));
      expect(tester.getTopRight(find.byKey(const Key('panel'))).dx, 400 - space.sm);
    });

    testWidgets('devrait rapprocher l’enfant de l’ancre de travel, du côté retenu', (tester) async {
      await tester.pumpWidget(
        host(const FlAnchoredLayout(anchor: Rect.fromLTWH(50, 700, 80, 40), travel: 6, child: box)),
      );
      expect(tester.getBottomLeft(find.byKey(const Key('panel'))), Offset(50, 700 - space.xs + 6));
    });

    testWidgets('devrait borner l’enfant à la zone sûre quand il est plus grand qu’elle', (tester) async {
      await tester.pumpWidget(
        host(
          const FlAnchoredLayout(
            anchor: Rect.fromLTWH(50, 100, 80, 40),
            child: SizedBox(key: Key('panel'), width: 1000, height: 100),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const Key('panel'))).width, 400 - 2 * space.sm);
    });

    testWidgets('devrait poser l’enfant à gap de l’ancre quand gap est donné', (tester) async {
      await tester.pumpWidget(host(const FlAnchoredLayout(anchor: Rect.fromLTWH(50, 100, 80, 40), gap: 9, child: box)));
      expect(tester.getTopLeft(find.byKey(const Key('panel'))), const Offset(50, 149));
    });

    testWidgets('devrait garder gap de l’ancre quand l’enfant se retourne au-dessus', (tester) async {
      await tester.pumpWidget(host(const FlAnchoredLayout(anchor: Rect.fromLTWH(50, 700, 80, 40), gap: 9, child: box)));
      expect(tester.getBottomLeft(find.byKey(const Key('panel'))), const Offset(50, 691));
    });

    testWidgets('devrait rester à margin du bord quand margin est donnée', (tester) async {
      await tester.pumpWidget(
        host(const FlAnchoredLayout(anchor: Rect.fromLTWH(360, 100, 30, 40), margin: 12, child: box)),
      );
      expect(tester.getTopRight(find.byKey(const Key('panel'))).dx, 388);
    });

    testWidgets('devrait retourner l’enfant quand margin lui retire la place du côté demandé', (tester) async {
      // Dessous, la marge de 60 ne laisse que 800 − 60 − 640 − 9 = 91 points,
      // moins que les 100 de l'enfant ; avec space.sm, il tiendrait.
      await tester.pumpWidget(
        host(const FlAnchoredLayout(anchor: Rect.fromLTWH(50, 600, 80, 40), gap: 9, margin: 60, child: box)),
      );
      expect(tester.getBottomLeft(find.byKey(const Key('panel'))), const Offset(60, 591));
    });
  });
}
