import 'package:fliin/src/commands/add.dart';
import 'package:test/test.dart';

void main() {
  test('devrait retirer de quatre chaque ligne d’un extrait et laisser vide une ligne vide quand add l’affiche', () {
    expect(
      describeSnippet(
        'State (none)',
        'class A {\n  const A();\n\n  void b() {}\n}',
      ),
      [
        '  State (none):',
        '    class A {',
        '      const A();',
        '',
        '      void b() {}',
        '    }',
      ],
    );
  });

  test('devrait afficher un extrait d’une ligne sous son libellé', () {
    expect(describeSnippet('Route (go_router)', "GoRoute(path: '/a')"), [
      '  Route (go_router):',
      "    GoRoute(path: '/a')",
    ]);
  });

  test('devrait nommer les écrans à installer avec les extraits quand ils mènent à leur page', () {
    expect(
      describeSnippetScreens(['verify-code', 'sign-in']),
      '  The snippets lead to verify-code, sign-in. '
      'Install them (fliin add verify-code sign-in) and paste their snippets.',
    );
  });
}
