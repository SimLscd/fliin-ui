import 'package:fliin/src/verify/reference.dart';
import 'package:fliin_schema/fliin_schema.dart';
import 'package:test/test.dart';

final _rendering = Rendering(
  abi: 'macos-arm64',
  flutter: '3.47.7',
  fonts: {
    'SFNS.ttf': '2f7e3871468bf56b',
    'Roboto-Regular.ttf': 'a7dac8d2b46311d9',
  },
);

final _goldens = ItemGoldens(
  host: GoldenHost.macos,
  rendering: _rendering,
  variants: {for (final id in variantIds) id: Sha256.ofString(id)},
);

ReferencePlan _plan({
  ItemGoldens? goldens,
  bool customEntry = false,
  String host = 'macos',
  bool defaultTheme = true,
  bool defaultIcons = true,
  Rendering? rendered,
}) => planReference(
  goldens: goldens,
  customEntry: customEntry,
  host: host,
  defaultTheme: defaultTheme,
  defaultIcons: defaultIcons,
  rendered: rendered,
);

Matcher _skipped(ReferenceGap gap) =>
    isA<SkipReference>().having((s) => s.gap, 'gap', gap);

void main() {
  test('devrait comparer quand la référence est publiée, l’hôte le même et le thème celui de core', () {
    expect(
      _plan(goldens: _goldens),
      isA<CompareToReference>().having((c) => c.goldens, 'goldens', _goldens),
    );
  });

  test(
    'ne devrait pas comparer quand la version ne publie pas de référence',
    () {
      expect(_plan(), _skipped(ReferenceGap.unpublished));
    },
  );

  test(
    'ne devrait pas comparer quand --entry rend autre chose que verify.entry',
    () {
      expect(
        _plan(goldens: _goldens, customEntry: true),
        _skipped(ReferenceGap.customEntry),
      );
    },
  );

  test('ne devrait pas comparer quand l’hôte n’est pas celui des références, et le dire', () {
    final plan = _plan(goldens: _goldens, host: 'linux');
    expect(plan, _skipped(ReferenceGap.otherHost));
    expect((plan as SkipReference).reason, contains('macos'));
    expect(plan.reason, contains('linux'));
  });

  test('ne devrait pas comparer quand fliin.tokens.json a changé depuis core (thème)', () {
    expect(
      _plan(goldens: _goldens, defaultTheme: false),
      _skipped(ReferenceGap.customTheme),
    );
  });

  test('ne devrait pas comparer quand l’élément dessine des icônes d’un autre jeu que Gravity UI, et le dire', () {
    final plan = _plan(goldens: _goldens, defaultIcons: false);
    expect(plan, _skipped(ReferenceGap.otherIconSet));
    expect((plan as SkipReference).reason, contains('Gravity UI'));
  });

  test('devrait comparer quand le rendu a la même architecture, le même Flutter et les mêmes polices', () {
    expect(
      _plan(
        goldens: _goldens,
        rendered: Rendering(
          abi: 'macos-arm64',
          flutter: '3.47.7',
          fonts: {
            'Roboto-Regular.ttf': 'a7dac8d2b46311d9',
            'SFNS.ttf': '2f7e3871468bf56b',
          },
        ),
      ),
      isA<CompareToReference>(),
    );
  });

  for (final (label, rendered, value) in [
    (
      'une autre architecture',
      Rendering(abi: 'macos-x64', flutter: '3.47.7', fonts: _rendering.fonts),
      'architecture macos-arm64 ≠ macos-x64',
    ),
    (
      'un autre Flutter',
      Rendering(abi: 'macos-arm64', flutter: '3.48.0', fonts: _rendering.fonts),
      'Flutter 3.47.7 ≠ 3.48.0',
    ),
    (
      'une police changée par le système',
      Rendering(
        abi: 'macos-arm64',
        flutter: '3.47.7',
        fonts: {..._rendering.fonts, 'SFNS.ttf': '0000000000000000'},
      ),
      'font SFNS.ttf 2f7e3871468bf56b ≠ 0000000000000000',
    ),
    (
      'une police absente',
      Rendering(
        abi: 'macos-arm64',
        flutter: '3.47.7',
        fonts: {'SFNS.ttf': '2f7e3871468bf56b'},
      ),
      'font Roboto-Regular.ttf a7dac8d2b46311d9 ≠ missing',
    ),
  ]) {
    test(
      'ne devrait pas comparer quand le rendu a $label, et nommer la valeur',
      () {
        final plan = _plan(goldens: _goldens, rendered: rendered);
        expect(plan, _skipped(ReferenceGap.otherHost));
        expect((plan as SkipReference).drift, [value]);
        expect(plan.reason, contains(value));
        expect(plan.toJson(), containsPair('drift', [value]));
      },
    );
  }
}
