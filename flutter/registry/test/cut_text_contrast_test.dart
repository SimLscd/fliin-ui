import 'package:fliin_harness/fliin_harness.dart';
import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/page/fl_page.dart';
import 'package:fliin_ui/components/text/fl_text.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'torture/themes.dart';
import 'torture/torture.g.dart';

const _phone = Size(390, 844);

const _marked = 20;

/// Une page de lignes sous torture A, au-dessus de la barre d'action, rendue
/// comme le harnais (pixel 2) ; [line] écrit chaque ligne. La page défile
/// d'un point à la fois sur 80, et la ligne [_marked] passe sous le bord de
/// la barre. Rend, pour chaque décalage où le bord coupe cette ligne sans
/// cacher son centre (la règle de flutter_test ne mesure que le texte qu'on
/// peut toucher en son centre), la raison de l'échec de la mesure, vide
/// quand elle passe.
Future<List<String>> _whileCut(WidgetTester tester, Brightness brightness, Widget Function(int index) line) async {
  tester.view.physicalSize = _phone * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final semantics = tester.ensureSemantics();
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: _phone, devicePixelRatio: 2, padding: EdgeInsets.only(top: 47, bottom: 34)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: FlScope(
          tokens: tortureA,
          brightness: brightness,
          platform: TargetPlatform.iOS,
          child: FlPage(
            controller: controller,
            tabBar: FlPageBar(
              action: FlButton(label: 'Réserver', onPressed: () {}),
            ),
            slivers: [
              SliverList.list(children: [for (var i = 0; i < 40; i++) line(i)]),
            ],
          ),
        ),
      ),
    ),
  );
  final edge = tester.getRect(find.byType(FlPageBar)).top;
  final reasons = <String>[];
  for (var offset = 0.0; offset < 80; offset++) {
    controller.jumpTo(offset);
    await tester.pump();
    final rect = tester.getRect(find.byKey(const ValueKey(_marked), skipOffstage: false));
    if (rect.center.dy >= edge || rect.bottom <= edge) continue;
    reasons.add((await flTextContrastGuideline.evaluate(tester)).reason ?? '');
  }
  semantics.dispose();
  expect(reasons.length, greaterThan(10), reason: 'la ligne passe au bord de la barre');
  return reasons;
}

Widget _good(int i) => FlText(key: ValueKey(i), 'Voyageurs et plafond $i');

/// Les avis d'une [FlPageBar] trop haute pour sa part, à 2,0 : ils défilent
/// sous l'ombre de `FlScrollShadow`. Rend, pour chaque décalage et chaque avis
/// que le bord de la part coupe sans cacher son centre, l'avis et la raison
/// de l'échec de la mesure. La couleur déclarée de l'avis passe toujours :
/// seule la mesure par pixels, qui voit l'ombre, peut le refuser.
Future<List<(String, String)>> _cutUnderShadow(WidgetTester tester) async {
  const phone = Size(375, 667);
  tester.view.physicalSize = phone * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final semantics = tester.ensureSemantics();
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: phone, devicePixelRatio: 2, textScaler: TextScaler.linear(2)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: FlScope(
          brightness: Brightness.light,
          platform: TargetPlatform.iOS,
          child: FlPage(
            tabBar: FlPageBar(
              info: [for (var i = 0; i < 12; i++) FlText('Avis $i')],
              action: FlButton(label: 'Réserver', onPressed: () {}),
            ),
            slivers: const [SliverToBoxAdapter(child: SizedBox(height: 10))],
          ),
        ),
      ),
    ),
  );
  final info = find.descendant(of: find.byType(FlPageBar), matching: find.byType(Scrollable)).first;
  final part = tester.getRect(info);
  final position = tester.state<ScrollableState>(info).position;
  final cut = <(String, String)>[];
  for (var offset = 0.0; offset < 60; offset++) {
    position.jumpTo(offset);
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 12; i++) {
      final rect = tester.getRect(find.text('Avis $i', skipOffstage: false));
      final atTop = rect.top < part.top && rect.center.dy > part.top;
      final atBottom = rect.bottom > part.bottom && rect.center.dy < part.bottom;
      if (!atTop && !atBottom) continue;
      cut.add(('Avis $i', (await flTextContrastGuideline.evaluate(tester)).reason ?? ''));
    }
  }
  semantics.dispose();
  expect(cut, isNotEmpty, reason: 'un avis passe au bord de sa part');
  return cut;
}

void main() {
  setUpAll(loadTortureFonts);

  for (final brightness in Brightness.values) {
    testWidgets('devrait passer une ligne bien contrastée coupée au bord de la barre quand torture A '
        "n'en laisse voir que le haut des lettres (${brightness.name})", (tester) async {
      final reasons = await _whileCut(tester, brightness, _good);
      expect(reasons, everyElement(isEmpty));
    });

    testWidgets(
      'devrait refuser encore une ligne trop pâle coupée au bord de la barre sous torture A (${brightness.name})',
      (tester) async {
        final colors = brightness == Brightness.light ? tortureA.light : tortureA.dark;
        final faint = Color.lerp(colors.surface, colors.onSurface, 0.15)!;
        final reasons = await _whileCut(
          tester,
          brightness,
          (i) => i != _marked
              ? _good(i)
              : Text(
                  key: ValueKey(i),
                  'Voyageurs et plafond $i',
                  style: TextStyle(fontFamily: tortureA.typography.ios.fontFamily, fontSize: 16, color: faint),
                ),
        );
        expect(reasons, everyElement(contains('"Voyageurs et plafond $_marked"')));
      },
    );

    testWidgets('devrait refuser une ligne bien contrastée mais effacée par une opacité, coupée au bord de la barre '
        '(${brightness.name})', (tester) async {
      final reasons = await _whileCut(
        tester,
        brightness,
        (i) => i != _marked ? _good(i) : Opacity(key: ValueKey(i), opacity: 0.15, child: _good(-i)),
      );
      expect(reasons, everyElement(contains('"Voyageurs et plafond -$_marked"')));
    });
  }

  testWidgets("devrait mesurer par pixels, et refuser comme avant le lot, un avis coupé sous l'ombre de la barre "
      "d'action, qui le recouvre (relecture D23, H2)", (tester) async {
    final cut = await _cutUnderShadow(tester);
    expect(cut.where((c) => c.$2.contains('"${c.$1}"')), isNotEmpty);
  });
}
