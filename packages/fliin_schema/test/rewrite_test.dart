import 'package:fliin_schema/fliin_schema.dart';
import 'package:test/test.dart';

final ac = RenderConfig(root: 'lib/ui/fliin', prefix: 'Ac', package: 'mon_app');

void main() {
  test(
    "devrait viser le paquet de l'app sous root quand il réécrit un import",
    () {
      expect(
        applyRewrites("import 'package:fliin_ui/core/fliin.dart';", ac),
        "import 'package:mon_app/ui/fliin/core/fliin.dart';",
      );
    },
  );

  test(
    'devrait remplacer Fl devant une majuscule quand il réécrit le préfixe',
    () {
      expect(
        applyRewrites(
          'class FlButton extends StatelessWidget { FlTheme.of(c); }',
          ac,
        ),
        'class AcButton extends StatelessWidget { AcTheme.of(c); }',
      );
    },
  );

  test('ne devrait toucher ni Flutter, ni FlutterError, ni flex, ni Fl sans majuscule derrière', () {
    const source =
        "Flutter FlutterError flex Flex 'Fl' Fl_x isFlButton _FlButtonState";
    expect(applyRewrites(source, ac), source);
  });

  test('devrait garder le préfixe Fl quand la config le garde', () {
    final fl = RenderConfig(
      root: 'lib/ui/fliin',
      prefix: 'Fl',
      package: 'mon_app',
    );
    expect(applyRewrites('FlButton()', fl), 'FlButton()');
  });

  test(
    'devrait décrire les règles comme le bloc install de DESIGN.md §5.5',
    () {
      expect(
        [for (final rule in rewriteRules) rule.toJson()],
        [
          {
            'kind': 'import',
            'from': 'package:fliin_ui/',
            'to': 'package:{package}/{importRoot}/',
          },
          {
            'kind': 'prefix',
            'pattern': r'\bFl(?=[A-Z])',
            'replacement': '{prefix}',
          },
        ],
      );
    },
  );
}
