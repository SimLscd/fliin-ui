import 'package:fliin_ui/components/color_swatch/fl_color_swatch.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

void main() {
  test('devrait écrire une couleur en #RRGGBB majuscule, et son opacité quand alpha est demandé', () {
    const color = Color.fromARGB(0x80, 0x0A, 0x6C, 0xFF);
    expect(flColorHex(color), '#0A6CFF');
    expect(flColorHex(color, alpha: true), '#0A6CFF80');
  });

  test('devrait lire #RGB, #RRGGBB, sans # et entouré d’espaces, et refuser le reste', () {
    expect(flParseColorHex('#0a6cff'), const Color(0xFF0A6CFF));
    expect(flParseColorHex(' 0A6CFF '), const Color(0xFF0A6CFF));
    expect(flParseColorHex('#f00'), const Color(0xFFFF0000));
    expect(flParseColorHex('#0A6CFF80'), isNull, reason: 'l’opacité exige alpha');
    expect(flParseColorHex('#0A6CFF80', alpha: true), const Color(0x800A6CFF));
    expect(flParseColorHex('#F008', alpha: true), const Color(0x88FF0000));
    for (final text in ['', '#', '#12', '#12345', 'blue', '#GGGGGG', '#0A6CFF8']) {
      expect(flParseColorHex(text, alpha: true), isNull, reason: text);
    }
  });

  test('devrait lire et écrire la saturation et la clarté HSL d’une couleur tenue en HSV', () {
    const red = HSVColor.fromAHSV(1, 0, 1, 1);
    expect(red.lightness, 0.5);
    expect(red.hslSaturation, 1);
    final pink = red.withChannel(FlColorChannel.lightness, FlColorSpace.hsl, 0.75);
    expect(pink.toColor(), const Color(0xFFFF8080));
    expect(pink.channel(FlColorChannel.lightness, FlColorSpace.hsl), closeTo(0.75, 1e-9));
    expect(pink.channel(FlColorChannel.saturation, FlColorSpace.hsl), closeTo(1, 1e-9));
    final muted = red.withChannel(FlColorChannel.saturation, FlColorSpace.hsl, 0.5);
    expect(muted.channel(FlColorChannel.saturation, FlColorSpace.hsl), closeTo(0.5, 1e-9));
    expect(muted.lightness, closeTo(0.5, 1e-9));
  });

  test('devrait garder la saturation HSL d’une couleur qui passe par le noir, et la teinte d’un gris', () {
    const red = HSVColor.fromAHSV(1, 0, 1, 1);
    final black = red.withChannel(FlColorChannel.lightness, FlColorSpace.hsl, 0);
    expect(black.toColor(), const Color(0xFF000000));
    final back = black.withChannel(FlColorChannel.lightness, FlColorSpace.hsl, 0.5);
    expect(back.toColor(), const Color(0xFFFF0000));
    final gray = const HSVColor.fromAHSV(1, 210, 0.8, 0.9).withChannel(FlColorChannel.saturation, FlColorSpace.hsb, 0);
    expect(gray.channel(FlColorChannel.hue, FlColorSpace.hsb), 210);
  });

  testWidgets('devrait s’annoncer comme une image nommée, ou se taire sans nom', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      toggleApp(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlColorSwatch(color: Color(0xFF3B82F6), label: 'Bleu'),
            FlColorSwatch(color: Color(0xFFF43F5E), label: null),
          ],
        ),
      ),
    );
    expect(tester.getSemantics(find.bySemanticsLabel('Bleu')), matchesSemantics(label: 'Bleu', isImage: true));
    expect(find.bySemanticsLabel(RegExp('.')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('devrait peindre le damier sous une teinte translucide seulement, à la taille demandée', (tester) async {
    await tester.pumpWidget(
      toggleApp(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlColorSwatch(color: Color(0xFF3B82F6), label: 'Bleu', size: FlColorSwatchSize.xl),
            FlColorSwatch(color: Color(0x663B82F6), label: 'Voile', shape: FlColorSwatchShape.square),
          ],
        ),
      ),
    );
    expect(find.byType(FlColorChecker), findsOneWidget);
    expect(tester.getSize(find.bySemanticsLabel('Bleu')), const Size.square(40));
  });
}
