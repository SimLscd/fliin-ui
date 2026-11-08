import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _snapped(double width, {double left = 10.3}) => MediaQuery(
  data: const MediaQueryData(devicePixelRatio: 2),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(
      children: [
        Positioned(
          left: left,
          top: 5.2,
          child: FlPixelSnap(
            child: SizedBox(key: const Key('child'), width: width, height: 20.1),
          ),
        ),
      ],
    ),
  ),
);

/// Pompe jusqu'à ce que plus aucun frame ne soit demandé, au plus [limit]
/// frames, et rend le nombre de frames pompés.
Future<int> _drain(WidgetTester tester, {int limit = 10}) async {
  var frames = 0;
  while (tester.binding.hasScheduledFrame && frames < limit) {
    await tester.pump();
    frames++;
  }
  return frames;
}

void main() {
  testWidgets(
    'devrait arrondir la taille au demi-point supérieur et peindre au pixel le plus proche quand le ratio vaut 2',
    (tester) async {
      await tester.pumpWidget(_snapped(30.2));
      final rect = tester.getRect(find.byKey(const Key('child')));
      expect(rect.size, const Size(30.5, 20.5));
      expect(rect.topLeft, const Offset(10.5, 5.0));
    },
  );

  testWidgets('devrait suivre l’enfant quand sa taille naturelle change après un premier arrondi', (tester) async {
    await tester.pumpWidget(_snapped(30.2));
    expect(tester.getSize(find.byKey(const Key('child'))).width, 30.5);
    await tester.pumpWidget(_snapped(48.3));
    expect(tester.getSize(find.byKey(const Key('child'))).width, 48.5);
  });

  testWidgets('devrait faire suivre le toucher au décalage de la peinture', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 2),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(
                left: 10.3,
                top: 5.2,
                child: FlPixelSnap(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps++,
                    child: const SizedBox(width: 30, height: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(40.4, 15));
    expect(taps, 1, reason: 'le bord droit peint est à 40,5 : 40,4 est dedans');
  });

  testWidgets('devrait garder le toucher sur la peinture quand un ancêtre bouge sans la relancer', (tester) async {
    var taps = 0;
    Widget at(double dx) => MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 2),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned(
              left: 10.3,
              top: 5.2,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: RepaintBoundary(
                  child: FlPixelSnap(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => taps++,
                      child: const SizedBox(width: 30, height: 20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(at(0));
    // La couche de la RepaintBoundary est reprise telle quelle : peinte avec
    // un décalage de 0,2, elle glisse de 0,2 et montre son bord gauche à 10,7.
    // Recalculé au toucher, le décalage vaudrait 0 et mettrait ce bord à 10,5.
    await tester.pumpWidget(at(0.2));
    await tester.tapAt(const Offset(10.6, 15));
    expect(taps, 0, reason: 'le bord gauche montré est à 10,7 : 10,6 est dehors');
    await tester.tapAt(const Offset(10.8, 15));
    expect(taps, 1, reason: '10,8 est dedans');
  });

  group('sous une frontière de peinture', () {
    Widget nested(double scale) => MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 2),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned(
              left: 10.3,
              top: 5.2,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topLeft,
                child: FlPixelSnap(
                  child: RepaintBoundary(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 3.3, top: 2.1),
                      child: FlPixelSnap(child: SizedBox(key: const Key('inner'), width: 10, height: 10)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    bool onGrid(Offset o) => (o.dx * 2) % 1 == 0 && (o.dy * 2) % 1 == 0;

    testWidgets(
      'devrait réaligner l’enfant, sa place posée, quand l’ancêtre change de place à l’écran sans repeindre la frontière',
      (tester) async {
        await tester.pumpWidget(nested(0.97));
        await _drain(tester);
        await tester.pumpWidget(nested(1));
        await _drain(tester);
        final inner = tester.getTopLeft(find.byKey(const Key('inner')));
        expect(onGrid(inner), isTrue, reason: '$inner');
        expect(inner, const Offset(14, 7));
      },
    );

    testWidgets('devrait cesser de demander des frames quand les places sont stables', (tester) async {
      await tester.pumpWidget(nested(0.97));
      await _drain(tester);
      await tester.pumpWidget(nested(1));
      expect(await _drain(tester), lessThanOrEqualTo(5), reason: 'les frames s’arrêtent');
      expect(tester.binding.hasScheduledFrame, isFalse);
      final before = tester.getTopLeft(find.byKey(const Key('inner')));
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(const Key('inner'))), before);
    });
  });

  group('coût du réalignement', () {
    Widget host(Widget child) => MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 2),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );

    /// Un [FlPixelSnap] dont l'enfant, derrière une frontière de peinture,
    /// est un autre [FlPixelSnap] qui compte ses peintures.
    Widget row(_Paints paints, {bool apart = true}) {
      final inner = FlPixelSnap(
        child: CustomPaint(painter: paints, size: const Size(10, 10)),
      );
      return FlPixelSnap(
        child: Padding(
          padding: const EdgeInsets.only(left: 3.3, top: 2.1),
          child: apart ? RepaintBoundary(child: inner) : inner,
        ),
      );
    }

    testWidgets('devrait ne pas repeindre la descendance quand l’ancêtre se repeint à la même place', (tester) async {
      final paints = _Paints();
      final tick = ValueNotifier(0);
      addTearDown(tick.dispose);
      await tester.pumpWidget(
        host(
          Stack(
            children: [
              Positioned(left: 10.3, top: 5.2, child: row(paints)),
              // Repeint la frontière de l'ancêtre sans le déplacer.
              Positioned.fill(child: CustomPaint(painter: _Repaints(tick))),
            ],
          ),
        ),
      );
      await _drain(tester);
      final before = paints.count;
      tick.value++;
      await _drain(tester);
      expect(paints.count, before);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('devrait ne pas remettre à peindre un descendant de sa propre frontière', (tester) async {
      final paints = _Paints();
      Widget at(double scale) => host(
        Stack(
          children: [
            Positioned(
              left: 10.3,
              top: 5.2,
              child: Transform.scale(scale: scale, alignment: Alignment.topLeft, child: row(paints, apart: false)),
            ),
          ],
        ),
      );
      await tester.pumpWidget(at(0.97));
      await _drain(tester);
      final before = paints.count;
      await tester.pumpWidget(at(1));
      await _drain(tester);
      expect(paints.count, before + 1, reason: 'repeint une fois, avec son ancêtre');
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets(
      'devrait réaligner une fois, à la fin, vingt lignes derrière une frontière dont l’ancêtre s’anime pendant dix frames',
      (tester) async {
        final paints = _Paints();
        final scale = ValueNotifier(0.9);
        addTearDown(scale.dispose);
        await tester.pumpWidget(
          host(
            ValueListenableBuilder<double>(
              valueListenable: scale,
              builder: (context, value, _) => Transform.scale(
                scale: value,
                alignment: Alignment.topLeft,
                child: FlPixelSnap(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (var i = 0; i < 20; i++) row(paints)],
                  ),
                ),
              ),
            ),
          ),
        );
        await _drain(tester);
        final before = paints.count;
        var during = 0;
        for (var i = 1; i <= 10; i++) {
          scale.value = 0.9 + 0.01 * i;
          // Une animation demande le frame suivant : le pipeline n'est
          // jamais au repos avant la fin.
          if (i < 10) tester.binding.scheduleFrame();
          await tester.pump(const Duration(milliseconds: 16));
          during = paints.count - before;
        }
        await _drain(tester);
        final total = paints.count - before;
        expect((during, total), (0, 20), reason: 'aucune pendant l’animation, une par ligne à la fin');
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );

    testWidgets('devrait réaligner une fois chaque ligne qui entre, le défilement arrêté', (tester) async {
      final paints = _Paints();
      await tester.pumpWidget(
        host(
          ListView.builder(
            itemCount: 200,
            itemBuilder: (context, i) => Padding(padding: const EdgeInsets.all(8.3), child: row(paints)),
          ),
        ),
      );
      await _drain(tester);
      final before = paints.count;
      final gesture = await tester.startGesture(const Offset(100, 300));
      for (var i = 0; i < 30; i++) {
        await gesture.moveBy(const Offset(0, -3.3));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      // Quatre lignes entrent : leur première peinture (4 sur main), puis un
      // réalignement chacune, une fois le défilement arrêté.
      expect(paints.count - before, 8);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}

class _Paints extends CustomPainter {
  int count = 0;

  @override
  void paint(Canvas canvas, Size size) => count++;

  @override
  bool shouldRepaint(_Paints oldDelegate) => false;
}

class _Repaints extends CustomPainter {
  _Repaints(Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(_Repaints oldDelegate) => false;
}
