import 'package:fliin_ui/components/text/fl_text.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'torture/themes.dart';
import 'torture/torture.g.dart';

Widget _app(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: FlScope(
    brightness: Brightness.light,
    platform: TargetPlatform.iOS,
    child: Center(child: child),
  ),
);

TextStyle _style(WidgetTester tester) => tester.widget<RichText>(find.byType(RichText)).text.style!;

void main() {
  testWidgets('devrait annoncer un titre comme en-tête, pas un paragraphe', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const FlText('Réglages', type: FlTextType.h2)));
    expect(tester.getSemantics(find.text('Réglages')), matchesSemantics(label: 'Réglages', isHeader: true));
    await tester.pumpWidget(_app(const FlText('Bonjour')));
    expect(tester.getSemantics(find.text('Bonjour')), matchesSemantics(label: 'Bonjour'));
    semantics.dispose();
  });

  testWidgets('devrait écrire atténué en onSurfaceMuted, et la graisse demandée à la place de celle du type', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const FlText('Note', tone: FlTextTone.muted, weight: FontWeight.w700)));
    expect(_style(tester).color, FlTokens.defaults.light.onSurfaceMuted);
    expect(_style(tester).fontWeight, FontWeight.w700);
  });

  testWidgets('devrait écrire le code en Menlo sur un fond control, sans s’étirer', (tester) async {
    await tester.pumpWidget(_app(const SizedBox(width: 300, child: FlText('pub get', type: FlTextType.code))));
    expect(_style(tester).fontFamily, 'Menlo');
    expect(find.byType(FlText), paints..rrect(color: FlTokens.defaults.light.control));
    expect(tester.getSize(find.byType(DecoratedBox)).width, lessThan(300));
  });

  testWidgets('devrait tenir dans l’interligne de HeroUI pour la police système', (tester) async {
    await tester.pumpWidget(_app(const FlText('Titre', type: FlTextType.h1)));
    final h1 = FlTokens.defaults.typography.ios.heading1;
    expect(tester.getSize(find.byType(RichText)).height, h1.lineHeight);
  });

  testWidgets(
    'devrait remonter un h1 de la moitié de l’excès de l’interligne de la police sur celui de HeroUI, comme Core Text',
    (tester) async {
      await loadTortureFonts();
      final family = tortureA.typography.ios.fontFamily!;
      final h1 = FlTokens.defaults.typography.ios.heading1;
      final painter = TextPainter(
        text: TextSpan(
          style: TextStyle(fontFamily: family, fontSize: h1.size, fontWeight: h1.weight, letterSpacing: h1.tracking),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final excess = painter.preferredLineHeight - h1.lineHeight;
      painter.dispose();
      expect(excess, greaterThan(0), reason: 'la police de torture A dépasse l’interligne du h1');

      await tester.pumpWidget(
        _app(
          DefaultTextStyle(
            style: TextStyle(fontFamily: family),
            child: const FlText('Titre', type: FlTextType.h1),
          ),
        ),
      );
      final shift = tester.getTopLeft(find.byType(RichText)).dy - tester.getTopLeft(find.byType(FlText)).dy;
      expect(shift, closeTo(-excess / 2, 0.01));
    },
  );

  testWidgets('devrait prendre color au lieu du ton', (tester) async {
    final light = FlTokens.defaults.light;
    await tester.pumpWidget(_app(FlText('Nouveau', tone: FlTextTone.muted, color: light.accent)));
    expect(_style(tester).color, light.accent);
  });

  testWidgets('devrait poser les morceaux de spans dans le style du type et lire data', (tester) async {
    const bold = TextStyle(fontWeight: FontWeight.w700);
    await tester.pumpWidget(
      _app(
        const FlText(
          'Lancez fliin add',
          type: FlTextType.bodySm,
          spans: [
            TextSpan(text: 'Lancez '),
            TextSpan(text: 'fliin add', style: bold),
          ],
        ),
      ),
    );
    final text = tester.widget<RichText>(find.byType(RichText)).text;
    expect(text.toPlainText(), 'Lancez fliin add');
    expect(text.style!.fontSize, FlTokens.defaults.typography.ios.textSm.size);
    expect(find.text('Lancez fliin add'), findsOneWidget);
  });
}
