import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/checkbox/fl_checkbox.dart';
import 'package:fliin_ui/components/close_button/fl_close_button.dart';
import 'package:fliin_ui/components/popover/fl_popover.dart';
import 'package:fliin_ui/components/radio/fl_radio.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_app.dart';

const _visual = Key('visual');

/// Un visuel de 20 × 20 qui se touche, sous sa cible.
Widget _tappable(VoidCallback onTap, {Key key = _visual}) => FlHitTarget(
  child: Semantics(
    button: true,
    label: 'Ok',
    onTap: onTap,
    child: GestureDetector(
      excludeFromSemantics: true,
      onTap: onTap,
      child: SizedBox(
        key: key,
        width: 20,
        height: 20,
        child: const ColoredBox(color: Color(0xFF000000)),
      ),
    ),
  ),
);

/// [child] sous un `FlScope` racine (qui pose l'hôte des cibles), centré.
Widget _app(Widget child, {TargetPlatform platform = TargetPlatform.android}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => Directionality(
    textDirection: TextDirection.ltr,
    child: FlScope(
      platform: platform,
      child: Center(child: child),
    ),
  ),
);

void main() {
  testWidgets(
    'devrait garder la taille du visuel en mise en page et annoncer une cible de 48 sur Android, 44 sur iOS',
    (tester) async {
      final semantics = tester.ensureSemantics();
      for (final (platform, side) in [(TargetPlatform.android, 48.0), (TargetPlatform.iOS, 44.0)]) {
        await tester.pumpWidget(_app(_tappable(() {}), platform: platform));
        expect(tester.getSize(find.byType(FlHitTarget)), const Size.square(20), reason: platform.name);
        final node = tester.getSemantics(find.byKey(_visual));
        expect(node.rect.size, Size.square(side), reason: platform.name);
        expect(node.rect.center, const Offset(10, 10), reason: platform.name);
      }
      semantics.dispose();
    },
  );

  for (final ratio in [1.0, 3.0]) {
    testWidgets(
      'devrait ramener dans l’écran la cible d’un visuel collé au bord, et la toucher là sous un hôte, au DPR $ratio',
      (tester) async {
        tester.view.physicalSize = const Size(390, 300) * ratio;
        tester.view.devicePixelRatio = ratio;
        addTearDown(tester.view.reset);
        // Dans le repère du visuel de 20 : la cible de 48, centrée loin des
        // bords, ramenée dans l’écran près d’eux.
        for (final hosted in [true, false]) {
          for (final (edge, target, inside) in [
            (Alignment.topLeft, const Rect.fromLTWH(0, 0, 48, 48), const Offset(40, 40)),
            (Alignment.bottomRight, const Rect.fromLTWH(-28, -28, 48, 48), const Offset(350, 260)),
            (Alignment.center, const Rect.fromLTWH(-14, -14, 48, 48), const Offset(195 + 10 + 10, 150)),
          ]) {
            var taps = 0;
            final tappable = Align(alignment: edge, child: _tappable(() => taps++));
            await tester.pumpWidget(
              hosted ? _app(tappable) : Directionality(textDirection: TextDirection.ltr, child: tappable),
            );
            final where = '$edge, hôte : $hosted, DPR $ratio';
            expect(tester.renderObject<RenderBox>(find.byType(FlHitTarget)).semanticBounds, target, reason: where);
            await tester.tapAt(inside);
            final centered = edge == Alignment.center;
            expect(
              taps,
              hosted || centered ? 1 : 0,
              reason: 'un toucher dans la cible ramenée : sous un hôte seulement, $where',
            );
          }
        }
      },
    );
  }

  testWidgets(
    'devrait laisser sans hôte au voisin peint avant elle le toucher de son visible, la cible au bord restant centrée',
    (tester) async {
      tester.view.physicalSize = const Size(390, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var neighbor = 0;
      var edge = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                _tappable(() => neighbor++, key: const Key('neighbor')),
                _tappable(() => edge++),
              ],
            ),
          ),
        ),
      );
      // Le visible du voisin va de 346 à 366 ; la cible centrée du contrôle du
      // bord commence à 356, ramenée elle commencerait à 342.
      await tester.tapAt(const Offset(350, 10));
      expect((neighbor, edge), (1, 0));
    },
  );

  testWidgets('devrait suivre le défilement : le rectangle sémantique ramené au bord, puis recentré', (tester) async {
    tester.view.physicalSize = const Size(390, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final scroll = ScrollController(initialScrollOffset: 100);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _app(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 390,
            height: 300,
            child: ListView(
              controller: scroll,
              children: [
                const SizedBox(height: 100),
                Align(alignment: AlignmentDirectional.centerStart, child: _tappable(() {})),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      ),
    );
    final box = tester.renderObject<RenderBox>(find.byType(FlHitTarget));
    expect(box.semanticBounds.top, 0, reason: 'au bord haut, ramenée vers le bas');
    expect(tester.getSemantics(find.byKey(_visual)).rect, box.semanticBounds);
    scroll.jumpTo(0);
    await tester.pump();
    expect(box.semanticBounds.top, -14, reason: 'loin du bord, centrée');
    expect(tester.getSemantics(find.byKey(_visual)).rect, box.semanticBounds, reason: 'le nœud suit');
    semantics.dispose();
  });

  testWidgets('devrait recevoir un toucher dans la marge à travers des ancêtres plus petits que la cible', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        Padding(
          padding: EdgeInsetsDirectional.zero,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(widthFactor: 1, heightFactor: 1, child: Stack(children: [_tappable(() => taps++)])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    final visual = tester.getRect(find.byKey(_visual));
    expect(tester.getSize(find.byType(Row)), visual.size);
    await tester.tapAt(visual.topLeft - const Offset(13, 13));
    await tester.tapAt(visual.bottomRight + const Offset(13, 13));
    expect(taps, 2);
    await tester.tapAt(visual.topLeft - const Offset(15, 15));
    expect(taps, 2, reason: 'hors de la cible de 48');
  });

  testWidgets('devrait prendre un toucher dans sa marge à l’intérieur d’un FlPressable parent', (tester) async {
    var inner = 0;
    var outer = 0;
    await tester.pumpWidget(
      _app(
        FlPressable(
          onPressed: () => outer++,
          borderRadius: BorderRadius.zero,
          builder: (context, _) => SizedBox(
            width: 200,
            height: 60,
            child: Align(alignment: AlignmentDirectional.centerEnd, child: _tappable(() => inner++)),
          ),
        ),
      ),
    );
    final visual = tester.getRect(find.byKey(_visual));
    await tester.tapAt(visual.centerLeft - const Offset(10, 0));
    expect((inner, outer), (1, 0));
    await tester.tapAt(visual.centerLeft - const Offset(30, 0));
    expect((inner, outer), (1, 1));
  });

  testWidgets('devrait donner à chaque option d’un groupe le toucher sur toute la hauteur de sa ligne de 44', (
    tester,
  ) async {
    final changes = <int?>[];
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 300,
          child: FlRadioGroup<int>(
            groupValue: null,
            onChanged: changes.add,
            children: const [
              FlRadioGroupItem(value: 0, label: 'Standard'),
              FlRadioGroupItem(value: 1, label: 'Express'),
            ],
          ),
        ),
        platform: TargetPlatform.iOS,
      ),
    );
    final rows = [
      for (final row in tester.widgetList(find.byType(FlRadioGroupItem<int>))) tester.getRect(find.byWidget(row)),
    ];
    expect(rows[0].height, 44);
    expect(rows[1].top - rows[0].bottom, 4);
    await tester.tapAt(rows[0].bottomCenter - const Offset(0, 1));
    await tester.tapAt(rows[1].topCenter + const Offset(0, 1));
    await tester.tapAt(rows[0].topCenter + const Offset(0, 1));
    expect(changes, [0, 1, 0]);
  });

  testWidgets('devrait garder l’écart d’une rangée de boutons et donner le toucher au plus proche', (tester) async {
    final presses = <int>[];
    await tester.pumpWidget(
      _app(
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            FlCloseButton(key: const Key('a'), label: 'A', onPressed: () => presses.add(0)),
            FlCloseButton(key: const Key('b'), label: 'B', onPressed: () => presses.add(1)),
          ],
        ),
        platform: TargetPlatform.iOS,
      ),
    );
    final a = tester.getRect(find.byKey(const Key('a')));
    final b = tester.getRect(find.byKey(const Key('b')));
    expect(b.left - a.right, 4, reason: 'les marges de 6 se chevauchent');
    await tester.tapAt(a.centerRight + const Offset(1, 0));
    await tester.tapAt(b.centerLeft - const Offset(1, 0));
    await tester.tapAt(a.centerRight + const Offset(1, 0));
    await tester.pumpAndSettle();
    expect(presses, [0, 1, 0]);
  });

  testWidgets('devrait borner la marge à un ancêtre qui découpe', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(ClipRect(child: _tappable(() => taps++))));
    final visual = tester.getRect(find.byKey(_visual));
    await tester.tapAt(visual.topLeft - const Offset(5, 5));
    expect(taps, 0);
    await tester.tap(find.byKey(_visual));
    expect(taps, 1);
  });

  testWidgets('devrait laisser défiler la liste quand un glisser part de la marge d’une cible', (tester) async {
    var taps = 0;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 100,
          height: 200,
          child: ListView(
            controller: controller,
            children: [
              for (var i = 0; i < 20; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
                  child: Center(child: _tappable(() => taps++, key: ValueKey(i))),
                ),
            ],
          ),
        ),
      ),
    );
    final visual = tester.getRect(find.byKey(const ValueKey(1)));
    final start = visual.centerLeft - const Offset(10, 0);
    await tester.tapAt(start);
    expect(taps, 1, reason: 'la marge reçoit le toucher dans la liste');
    await tester.dragFrom(start, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(taps, 1);
  });

  testWidgets('devrait refuser la marge d’une cible recouverte en son centre', (tester) async {
    var taps = 0;
    var cover = 0;
    await tester.pumpWidget(
      _app(
        Stack(
          children: [
            _tappable(() => taps++),
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => cover++),
            ),
          ],
        ),
      ),
    );
    final visual = tester.getRect(find.byKey(_visual));
    await tester.tapAt(visual.topLeft - const Offset(5, 5));
    await tester.tapAt(visual.center);
    expect((taps, cover), (0, 1));
  });

  testWidgets('devrait recevoir un toucher dans la marge sans FlScope quand le parent le laisse passer', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: _tappable(() => taps++)),
      ),
    );
    final visual = tester.getRect(find.byKey(_visual));
    await tester.tapAt(visual.topLeft - const Offset(5, 5));
    expect(taps, 1);
  });

  testWidgets('devrait laisser le visuel remplir des contraintes serrées plus grandes que la cible', (tester) async {
    await tester.pumpWidget(
      _app(ConstrainedBox(constraints: const BoxConstraints.tightFor(width: 200, height: 60), child: _tappable(() {}))),
    );
    expect(tester.getSize(find.byKey(_visual)), const Size(200, 60));
    expect(tester.getSize(find.byType(FlHitTarget)), const Size(200, 60));
  });

  testWidgets('devrait donner en layout sec la ligne de base de l’enfant', (tester) async {
    await tester.pumpWidget(_app(const FlHitTarget(child: Text('Ok', style: TextStyle(fontSize: 14)))));
    final box = tester.renderObject<RenderBox>(find.byType(FlHitTarget));
    final text = tester.renderObject<RenderBox>(find.byType(RichText));
    expect(box.size, text.size);
    expect(
      box.getDryBaseline(box.constraints, TextBaseline.alphabetic),
      text.getDryBaseline(text.constraints, TextBaseline.alphabetic),
    );
  });

  group('la vue du dessus gagne sur la marge d’une cible du dessous', () {
    testWidgets('devrait laisser le panneau d’un popover ouvert à lui-même, sans cocher la case de la page dessous', (
      tester,
    ) async {
      final controller = FlPopoverController();
      var box = 0;
      await tester.pumpWidget(
        overlayApp(
          Stack(
            children: [
              Align(
                alignment: AlignmentDirectional.topStart,
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: FlPopover(
                    controller: controller,
                    label: 'Filtres',
                    align: FlAlign.start,
                    content: Column(
                      key: const Key('content'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 200, height: 120, child: Text('Trier par date')),
                        FlButton(label: 'Appliquer', onPressed: () {}),
                      ],
                    ),
                    child: FlButton(label: 'Filtres', onPressed: controller.toggle),
                  ),
                ),
              ),
              Positioned(
                left: 278,
                top: 144,
                child: FlCheckbox(value: false, label: 'Sous le panneau', onChanged: (_) => box++),
              ),
            ],
          ),
          platform: TargetPlatform.iOS,
        ),
      );
      controller.open();
      await tester.pumpAndSettle();
      final content = tester.getRect(find.byKey(const Key('content')));
      final checkbox = tester.getRect(find.byType(FlCheckbox));
      final panel = Offset(content.right + 13, checkbox.center.dy);
      expect(checkbox.contains(panel), isFalse, reason: 'le point est hors de la partie visible de la case');
      expect(checkbox.left - panel.dx, lessThan(10), reason: 'le point est dans la marge de la case');
      await tester.tapAt(panel);
      await tester.pumpAndSettle();
      expect((box, controller.isOpen), (0, true));
    });

    testWidgets('devrait donner le toucher à une carte peinte au-dessus d’un bouton de fermeture', (tester) async {
      var card = 0;
      var close = 0;
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              children: [
                Positioned(
                  left: 84,
                  top: 84,
                  child: FlCloseButton(label: 'Fermer', onPressed: () => close++),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  width: 80,
                  height: 200,
                  child: GestureDetector(
                    key: const Key('card'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => card++,
                    child: const ColoredBox(color: Color(0xFFFF0000)),
                  ),
                ),
              ],
            ),
          ),
          platform: TargetPlatform.iOS,
        ),
      );
      await tester.tapAt(tester.getRect(find.byKey(const Key('card'))).centerRight - const Offset(2, 0));
      await tester.pumpAndSettle();
      expect((card, close), (1, 0));
    });

    testWidgets('devrait donner le toucher au détecteur de l’app peint après une case, à 2 pt d’elle', (tester) async {
      var app = 0;
      var box = 0;
      await tester.pumpWidget(
        _app(
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              FlCheckbox(value: false, label: 'Case', onChanged: (_) => box++),
              GestureDetector(
                key: const Key('app'),
                behavior: HitTestBehavior.opaque,
                onTap: () => app++,
                child: const SizedBox(width: 100, height: 40),
              ),
            ],
          ),
          platform: TargetPlatform.iOS,
        ),
      );
      await tester.tapAt(tester.getRect(find.byKey(const Key('app'))).centerLeft + const Offset(5, 0));
      await tester.pumpAndSettle();
      expect((app, box), (1, 0));
    });

    testWidgets('devrait donner le toucher à un lien posé sous un bouton de fermeture, donc peint après lui', (
      tester,
    ) async {
      var link = 0;
      var close = 0;
      final recognizer = TapGestureRecognizer()..onTap = () => link++;
      addTearDown(recognizer.dispose);
      await tester.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FlCloseButton(label: 'Fermer', onPressed: () => close++),
              Text.rich(
                TextSpan(text: 'Lire les conditions', recognizer: recognizer, style: const TextStyle(fontSize: 14)),
                key: const Key('link'),
              ),
            ],
          ),
          platform: TargetPlatform.iOS,
        ),
      );
      final text = tester.getRect(find.byKey(const Key('link')));
      await tester.tapAt(Offset(text.center.dx, text.top + 2));
      await tester.pumpAndSettle();
      expect((link, close), (1, 0));
    });

    testWidgets('devrait garder le curseur texte d’une zone peinte après une case, dans la marge de la case', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              FlCheckbox(value: false, label: 'Case', onChanged: (_) {}),
              const MouseRegion(
                key: Key('text'),
                cursor: SystemMouseCursors.text,
                child: SizedBox(width: 100, height: 40),
              ),
            ],
          ),
          platform: TargetPlatform.iOS,
        ),
      );
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      final text = tester.getRect(find.byKey(const Key('text')));
      await gesture.addPointer(location: text.center);
      await tester.pump();
      await gesture.moveTo(text.centerLeft + const Offset(4, 0));
      await tester.pump();
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.text);
      await gesture.moveTo(tester.getRect(find.byType(FlCheckbox)).center);
      await tester.pump();
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.click);
    });

    testWidgets('devrait garder la marge d’une cible peinte au-dessus de son voisin, comme React Native', (
      tester,
    ) async {
      var app = 0;
      var box = 0;
      await tester.pumpWidget(
        _app(
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              GestureDetector(
                key: const Key('app'),
                behavior: HitTestBehavior.opaque,
                onTap: () => app++,
                child: const SizedBox(width: 100, height: 40),
              ),
              FlCheckbox(value: false, label: 'Case', onChanged: (_) => box++),
            ],
          ),
          platform: TargetPlatform.iOS,
        ),
      );
      await tester.tapAt(tester.getRect(find.byKey(const Key('app'))).centerRight - const Offset(5, 0));
      await tester.pumpAndSettle();
      expect((app, box), (0, 1));
    });
  });

  testWidgets('devrait garder sur une cible le toucher de sa partie visible, dans la marge d’une sœur', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(
      _app(
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            _tappable(() => taps.add(0), key: const Key('a')),
            _tappable(() => taps.add(1), key: const Key('b')),
          ],
        ),
      ),
    );
    await tester.tapAt(tester.getRect(find.byKey(const Key('a'))).centerRight - const Offset(1, 0));
    expect(taps, [0]);
  });

  testWidgets('devrait oublier une cible retirée de l’arbre', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(_tappable(() => taps++)));
    final visual = tester.getRect(find.byKey(_visual));
    await tester.pumpWidget(_app(const SizedBox(width: 20, height: 20)));
    await tester.tapAt(visual.topLeft - const Offset(5, 5));
    expect(taps, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('devrait laisser une cible qui ne déborde pas se toucher comme sa boîte', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        FlHitTarget(
          child: GestureDetector(
            onTap: () => taps++,
            child: const SizedBox(
              key: _visual,
              width: 60,
              height: 60,
              child: Center(
                child: SizedBox(width: 10, height: 10, child: ColoredBox(color: Color(0xFF000000))),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(tester.getRect(find.byKey(_visual)).topLeft + const Offset(2, 2));
    expect(taps, 0, reason: 'le coin vide ne touche pas le détecteur, et rien ne le rejoue au centre');
    await tester.tap(find.byKey(_visual));
    expect(taps, 1);
  });
}
