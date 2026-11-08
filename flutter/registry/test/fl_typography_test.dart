import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// [base] avec la police du texte [body] et celle des titres [heading].
FlTypeScale withFamilies(FlTypeScale base, {String? body, String? heading}) => FlTypeScale(
    display: base.display,
    title1: base.title1,
    title2: base.title2,
    title3: base.title3,
    headline: base.headline,
    body: base.body,
    callout: base.callout,
    label: base.label,
    footnote: base.footnote,
    caption: base.caption,
    controlSm: base.controlSm,
    controlMd: base.controlMd,
    controlLg: base.controlLg,
    heading1: base.heading1,
    heading2: base.heading2,
    heading3: base.heading3,
    heading4: base.heading4,
    heading5: base.heading5,
    heading6: base.heading6,
    paragraph: base.paragraph,
    paragraphSm: base.paragraphSm,
    paragraphXs: base.paragraphXs,
    code: base.code,
    textXs: base.textXs,
    textSm: base.textSm,
    textBase: base.textBase,
    textLg: base.textLg,
    monospaceFamily: base.monospaceFamily,
    fontFamily: body,
    headingFamily: heading,
  );

void main() {
  final ios = FlTokens.defaults.typography.ios;
  final android = FlTokens.defaults.typography.android;

  test('devrait écrire le code dans la police à chasse fixe de la plateforme, sans approche', () {
    expect(ios.resolve(FlTextRole.code).fontFamily, 'Menlo');
    expect(android.resolve(FlTextRole.code).fontFamily, 'monospace');
    expect(ios.resolve(FlTextRole.code).letterSpacing, 0);
    expect(ios.strut(FlTextRole.code).fontFamily, 'Menlo');
    expect(ios.resolve(FlTextRole.paragraph).fontFamily, isNull);
  });

  test('devrait donner aux titres de HeroUI tracking-tight, plus l’approche de SF sur iOS seulement', () {
    final h6 = ios.resolve(FlTextRole.heading6);
    expect((h6.fontSize, h6.fontWeight), (16, FontWeight.w600));
    expect(h6.letterSpacing, closeTo(-0.025 * 16 - 0.3125, 1e-4));
    expect(android.resolve(FlTextRole.heading6).letterSpacing, closeTo(-0.025 * 16, 1e-4));
  });

  test('devrait donner aux rôles de HeroUI la même taille sur iOS et Android', () {
    for (final role in FlTextRole.values.skip(FlTextRole.controlSm.index)) {
      expect(ios.style(role).size, greaterThan(0), reason: role.name);
      expect(android.style(role).size, ios.style(role).size, reason: role.name);
    }
  });

  test('devrait écrire les titres dans la police des titres et le reste dans celle du texte quand les deux sont nommées', () {
    final scale = withFamilies(ios, body: 'Inter', heading: 'Lora');
    for (final role in FlTextRole.values) {
      final expected = switch (role) {
        FlTextRole.code => 'Menlo',
        _ when role.isHeading => 'Lora',
        _ => 'Inter',
      };
      expect(scale.resolve(role).fontFamily, expected, reason: role.name);
      expect(scale.strut(role).fontFamily, expected, reason: role.name);
    }
    expect(
      [for (final role in FlTextRole.values) if (role.isHeading) role.name],
      ['display', 'title1', 'title2', 'title3', 'heading1', 'heading2', 'heading3', 'heading4', 'heading5', 'heading6'],
    );
  });

  test('devrait donner aux titres la police du texte quand aucune police de titres n’est nommée', () {
    final scale = withFamilies(ios, body: 'Inter');
    expect(scale.resolve(FlTextRole.heading1).fontFamily, 'Inter');
    expect(withFamilies(ios, heading: 'Lora').resolve(FlTextRole.paragraph).fontFamily, isNull);
    expect(withFamilies(ios, heading: 'Lora').resolve(FlTextRole.heading1).letterSpacing, 0);
  });
}
