import 'package:fliin_ui/components/field/fl_field.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: FlScope(
    brightness: Brightness.light,
    child: Center(child: child),
  ),
);

final _colors = FlTokens.defaults.light;

List<TextSpan> _spans(WidgetTester tester, Finder of) {
  final root = tester.widget<RichText>(find.descendant(of: of, matching: find.byType(RichText))).text;
  final spans = <TextSpan>[];
  root.visitChildren((span) {
    if (span is TextSpan && span.text != null) spans.add(span);
    return true;
  });
  return spans;
}

void main() {
  testWidgets('devrait tenir dans l’interligne d’Izydesk, libellé et description de 20, même requis', (tester) async {
    final scale = FlTokens.defaults.typography.ios;
    for (final required in [false, true]) {
      await tester.pumpWidget(
        _app(
          FlScope(
            platform: TargetPlatform.iOS,
            child: FlFieldScope(
              required: required,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [FlLabel('E-mail'), FlDescription('Professionnel')],
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(FlLabel)).height, scale.textSm.lineHeight, reason: 'requis : $required');
      expect(tester.getSize(find.byType(FlDescription)).height, scale.textSm.lineHeight);
    }
  });

  testWidgets(
    'devrait suivre un astérisque danger quand le champ est requis, et rester onSurface quand il est invalide',
    (tester) async {
      await tester.pumpWidget(_app(const FlFieldScope(required: true, child: FlLabel('E-mail'))));
      expect(_spans(tester, find.byType(FlLabel)).map((s) => s.text), ['E-mail', ' *']);
      expect(_spans(tester, find.byType(FlLabel)).last.style!.color, _colors.danger);
      await tester.pumpWidget(_app(const FlFieldScope(invalid: true, child: FlLabel('E-mail'))));
      expect(_spans(tester, find.byType(FlLabel)).map((s) => s.text), ['E-mail']);
      expect(
        tester
            .widget<RichText>(find.descendant(of: find.byType(FlLabel), matching: find.byType(RichText)))
            .text
            .style!
            .color,
        _colors.onSurface,
      );
    },
  );

  testWidgets('devrait préférer le réglage local à celui du champ', (tester) async {
    await tester.pumpWidget(_app(const FlFieldScope(required: true, child: FlLabel('E-mail', required: false))));
    expect(_spans(tester, find.byType(FlLabel)).map((s) => s.text), ['E-mail']);
  });

  testWidgets(
    'devrait montrer l’erreur en fondu quand le champ devient invalide, et la retirer quand il redevient valide',
    (tester) async {
      Widget field(bool invalid) => _app(FlFieldScope(invalid: invalid, child: const FlFieldError('Adresse invalide')));
      await tester.pumpWidget(field(false));
      expect(find.text('Adresse invalide'), findsNothing);
      await tester.pumpWidget(field(true));
      await tester.pump(const Duration(milliseconds: 50));
      final opacity = tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;
      expect(opacity, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.text('Adresse invalide'), findsOneWidget);
      await tester.pumpWidget(field(false));
      await tester.pumpAndSettle();
      expect(find.text('Adresse invalide'), findsNothing);
    },
  );

  testWidgets('devrait annoncer l’erreur dans une région vivante', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const FlFieldError('Adresse invalide', invalid: true)));
    expect(
      tester.getSemantics(find.text('Adresse invalide')),
      matchesSemantics(label: 'Adresse invalide', isLiveRegion: true),
    );
    semantics.dispose();
  });

  testWidgets('devrait retirer la description quand hideOnInvalid et le champ invalide', (tester) async {
    await tester.pumpWidget(
      _app(const FlFieldScope(invalid: true, child: FlDescription('Pour les reçus', hideOnInvalid: true))),
    );
    expect(find.text('Pour les reçus'), findsNothing);
    await tester.pumpWidget(_app(const FlFieldScope(invalid: true, child: FlDescription('Pour les reçus'))));
    expect(find.text('Pour les reçus'), findsOneWidget);
  });

  testWidgets('devrait retirer les parties de size.fieldInset dans un champ qui le demande', (tester) async {
    await tester.pumpWidget(_app(const FlFieldScope(inset: true, child: FlDescription('Aide'))));
    final inset = FlTokens.defaults.size.fieldInset;
    expect(tester.getTopLeft(find.byType(RichText)).dx - tester.getTopLeft(find.byType(FlDescription)).dx, inset);
  });

  testWidgets('devrait annoncer requis le libellé d’un champ requis, sans lire l’astérisque', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const FlFieldScope(required: true, child: FlLabel('E-mail'))));
    expect(
      tester.getSemantics(find.byType(RichText)),
      matchesSemantics(label: 'E-mail', hasRequiredState: true, isRequired: true),
    );
    await tester.pumpWidget(_app(const FlLabel('E-mail')));
    expect(tester.getSemantics(find.byType(RichText)), matchesSemantics(label: 'E-mail'));
    semantics.dispose();
  });

  testWidgets('devrait annoncer désactivées les parties d’un champ désactivé', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const FlFieldScope(disabled: true, child: FlLabel('E-mail'))));
    expect(tester.getSemantics(find.text('E-mail')), matchesSemantics(label: 'E-mail', hasEnabledState: true));
    semantics.dispose();
  });

  testWidgets('devrait poser labelTrailing au bout de la ligne du libellé, à droite en LTR et à gauche en RTL', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: FlScope(
            brightness: Brightness.light,
            child: const Center(
              child: SizedBox(
                width: 300,
                child: FlField(
                  label: 'Mot de passe',
                  labelTrailing: SizedBox(key: Key('trailing'), width: 40, height: 10),
                  child: SizedBox(key: Key('control'), height: 40),
                ),
              ),
            ),
          ),
        ),
      );
      final control = tester.getRect(find.byKey(const Key('control')));
      final trailing = tester.getRect(find.byKey(const Key('trailing')));
      final label = tester.getRect(find.text('Mot de passe'));
      expect(trailing.bottom, lessThanOrEqualTo(control.top), reason: 'au-dessus du contrôle');
      if (direction == TextDirection.ltr) {
        expect(trailing.right, control.right);
        expect(label.left, control.left);
      } else {
        expect(trailing.left, control.left);
        expect(label.right, control.right);
      }
    }
  });
}
