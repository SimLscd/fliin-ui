import 'package:fliin_schema/fliin_schema.dart'
    show PlatformCanvas, UniformCanvas, variantIds;
import 'package:fliin/src/verify/test_source.dart';
import 'package:test/test.dart';

void main() {
  test('devrait lister les seize variantes du harnais dans son ordre', () {
    expect(variantIds, hasLength(16));
    expect(variantIds.first, 'ios.light.1.0.ltr');
    expect(variantIds.last, 'android.dark.2.0.rtl');
  });

  test(
    'devrait passer canvas et settleMs au harnais quand le manifeste les donne',
    () {
      final source = verifyTestSource(
        item: 'menu',
        version: '0.1.0',
        prefix: 'Fl',
        entry: 'FlMenu()',
        imports: const {},
        outDir: 'build/fliin/verify/menu',
        variants: const [],
        canvas: const UniformCanvas((width: 390, height: 560)),
        settleMs: 400,
        goldens: 'build/fliin/verify/menu/golden',
      );
      expect(source, contains("goldens: 'build/fliin/verify/menu/golden',"));
      expect(source, contains('logicalSize: const Size(390, 560),'));
      expect(source, contains('settle: const Duration(milliseconds: 400),'));
    },
  );

  test('devrait donner sa taille à Android quand le manifeste en donne une par plateforme', () {
    final source = verifyTestSource(
      item: 'account-settings',
      version: '0.1.0',
      prefix: 'Fl',
      entry: 'const SizedBox()',
      imports: const {},
      outDir: 'build/fliin/verify/account-settings',
      variants: const [],
      canvas: const PlatformCanvas(
        ios: (width: 1560, height: 844),
        android: (width: 1648, height: 915),
      ),
    );
    expect(source, contains('logicalSize: const Size(1560, 844),'));
    expect(
      source,
      contains(
        'platformSizes: const {TargetPlatform.android: Size(1648, 915)},',
      ),
    );
  });

  test('devrait pomper l’entrée sous le scope préfixé et importer le harnais quand on génère le test', () {
    final source = verifyTestSource(
      item: 'button',
      version: '0.1.0',
      prefix: 'Ac',
      entry: 'AcButton(label: "Ok", onPressed: () {})',
      imports: {
        'package:app/ui/fliin/components/button/fl_button.dart',
        'package:app/ui/fliin/core/fliin.dart',
      },
      outDir: 'build/fliin/verify/button',
      variants: const [],
    );
    expect(source, contains("import 'fliin_harness.dart';"));
    expect(
      source,
      contains(
        "import 'package:app/ui/fliin/components/button/fl_button.dart';",
      ),
    );
    expect(source, contains('entry: (context, variant) => AcScope('));
    expect(
      source,
      contains(
        'Builder(builder: (context) => AcButton(label: "Ok", onPressed: () {}))',
      ),
    );
    expect(source, isNot(contains('variants:')));
    expect(source, isNot(contains('logicalSize:')));
    expect(source, isNot(contains('settle:')));
    expect(source, isNot(contains('goldens:')));
  });

  test('devrait échapper le dossier de sortie et les imports quand ils contiennent une apostrophe ou un dollar', () {
    final source = verifyTestSource(
      item: 'button',
      version: '0.1.0',
      prefix: 'Fl',
      entry: 'SizedBox()',
      imports: {"package:app/it's/a.dart"},
      outDir: r"build/it's $here",
      variants: const [],
    );
    expect(source, contains(r"outDir: 'build/it\'s \$here',"));
    expect(source, contains(r"import 'package:app/it\'s/a.dart';"));
  });

  test('devrait restreindre la matrice quand des variantes sont demandées', () {
    final source = verifyTestSource(
      item: 'button',
      version: '0.1.0',
      prefix: 'Fl',
      entry: 'SizedBox()',
      imports: const {},
      outDir: 'out',
      variants: const ['ios.dark.2.0.rtl', 'android.light.1.0.ltr'],
    );
    expect(
      source,
      contains(
        "const {'ios.dark.2.0.rtl', 'android.light.1.0.ltr'}.contains(variant.id)",
      ),
    );
  });
}
