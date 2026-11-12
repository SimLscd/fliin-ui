import 'dart:math' as math;

import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'torture/torture.g.dart';

/// Le rapport de contraste WCAG 2 de [a] sur [b], opaques.
double _contrast(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final themes = [('défaut', FlTokens.defaults), ('torture A', tortureA), ('torture B', tortureB)];

  for (final (name, tokens) in themes) {
    test('devrait poser les surfaces sur l’accent et le texte en onAccent, en AA, sous le thème $name', () {
      final derived = FlAccentScope.tokensOf(tokens);
      for (final (mode, base, on) in [('clair', tokens.light, derived.light), ('sombre', tokens.dark, derived.dark)]) {
        expect(on.surface, base.accent, reason: mode);
        expect(on.background, base.accent, reason: mode);
        expect(on.onSurface, base.onAccent, reason: mode);
        for (final (role, text, under) in [
          ('onSurface', on.onSurface, on.surface),
          ('onSurfaceMuted', on.onSurfaceMuted, on.surface),
          ('onAccent sur accent (l’action principale)', on.onAccent, on.accent),
        ]) {
          expect(_contrast(text, under), greaterThanOrEqualTo(4.5), reason: '$mode, $role');
        }
        // Une icône sur un disque teinté : 3:1, le seuil d'un élément graphique.
        expect(_contrast(on.onControl, on.control), greaterThanOrEqualTo(3), reason: '$mode, onControl sur control');
        expect(on.separator, on.surface, reason: '$mode : les filets disparaissent');
      }
      expect(identical(derived.shape, tokens.shape), isTrue, reason: 'seules les couleurs changent');
    });
  }

  test('devrait rendre les mêmes jetons d’un appel à l’autre, et ne rien changer à des jetons déjà dérivés', () {
    final derived = FlAccentScope.tokensOf(FlTokens.defaults);
    expect(identical(FlAccentScope.tokensOf(FlTokens.defaults), derived), isTrue);
    expect(identical(FlAccentScope.tokensOf(derived), derived), isTrue);
  });

  testWidgets('devrait peindre l’accent et donner sa palette aux composants dessous, même sous une seconde portée', (
    tester,
  ) async {
    late FlTheme inner;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: FlScope(
          brightness: Brightness.light,
          platform: TargetPlatform.iOS,
          child: FlAccentScope(
            child: FlAccentScope(
              fill: false,
              child: Builder(
                builder: (context) {
                  inner = FlScope.of(context);
                  return Center(
                    child: FlButton(label: 'Play', onPressed: () {}),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    final base = FlTokens.defaults.light;
    expect(tester.widget<ColoredBox>(find.byType(ColoredBox).first).color, base.accent);
    expect(inner.colors.surface, base.accent);
    expect(inner.colors.accent, base.onAccent, reason: 'l’action principale en onAccent');
    final label = tester.widget<Text>(find.text('Play'));
    expect(label.style?.color, base.accent, reason: 'son texte en accent');
  });
}
