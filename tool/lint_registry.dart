// Lints du registre, que le SDK n'applique pas (DESIGN.md §2.2, §2.8 et §3, VERIFICATIONS.md §2.3) :
//   1. aucun import de material ou cupertino dans flutter/registry ;
//   2. aucun type non directionnel (EdgeInsets.fromLTRB, Alignment.centerLeft, TextAlign.left, Positioned(left:…) ;
//   3. aucune couleur, aucun rayon, aucune police littérale hors de core/tokens/ ;
//   4. aucune instruction sans accolades qui passerait à la ligne une fois l'élément formaté à 80 colonnes.
// Chaque fichier est lu en entier, commentaires et contenu des chaînes masqués : un appel que dart_style replie
// sur plusieurs lignes est vu, un `TextAlign.left` dans un libellé ne l'est pas.
// Code de sortie 1 si une règle échoue. `--self-test` vérifie que chaque piège est attrapé et l'affiche.
import 'dart:io';

// `readsStrings` : la règle regarde le contenu des chaînes (un import est une chaîne) ; sinon il est masqué.
typedef Rule = ({String id, Iterable<int> Function(String code) find, String message, String? exemptDir, bool readsStrings});

Iterable<int> Function(String code) _matching(RegExp pattern) =>
    (code) => pattern.allMatches(code).map((m) => m.start);

// Les appels dont la tête correspond à [head] (qui se termine sur la parenthèse ouvrante) et dont un argument nommé
// de premier niveau est dans [names]. Les parenthèses sont comptées, quelle que soit la profondeur des appels
// imbriqués dans les autres arguments : `EdgeInsets.only(top: f(g(1)), left: 8)` est vu, `inset(left: 2)` passé en
// argument ne l'est pas.
Iterable<int> Function(String code) _callNaming(RegExp head, Set<String> names) {
  final argument = RegExp(r'\s*(\w+)\s*:');
  bool namesOne(String code, int from) {
    var depth = 1;
    var argumentStart = from;
    for (var i = from; i < code.length && depth > 0; i++) {
      if (i == argumentStart && depth == 1) {
        final named = argument.matchAsPrefix(code, i);
        if (named != null && names.contains(named[1])) return true;
      }
      switch (code[i]) {
        case '(':
          depth++;
        case ')':
          depth--;
        case ',' when depth == 1:
          argumentStart = i + 1;
      }
    }
    return false;
  }

  return (code) => [
    for (final call in head.allMatches(code))
      if (namesOne(code, call.end)) call.start,
  ];
}

// Les instructions `if`, `for` ou `while` sans accolades dont le corps tient sur la ligne de la condition, mais pas
// dans 80 colonnes. Le registre se formate à 120 ; l'app de l'utilisateur se reformate à 80 à l'installation, le corps
// passe à la ligne et `curly_braces_in_flow_control_structures` de flutter_lints le refuse. Seule une ligne qui se
// termine par `;` et qui ouvre sa ligne est une instruction : un `if` ou un `for` de collection n'est pas vu.
Iterable<int> _unbracedOver80(String code) sync* {
  final head = RegExp(r'\b(if|for|while)\s*\(|\belse\b');
  var offset = 0;
  for (final line in code.split('\n')) {
    if (line.length > 80 && line.trimRight().endsWith(';')) {
      for (final match in head.allMatches(line)) {
        // Une instruction ouvre la ligne, ou suit `}` ou `else` : `[for (…) x]` et `a ? [if (…) b] : c` n'en sont pas.
        final before = line.substring(0, match.start).trim();
        if (before.isNotEmpty && !before.endsWith('}') && !before.endsWith('else')) continue;
        var i = match.end;
        if (match[1] != null) {
          var depth = 1;
          while (i < line.length && depth > 0) {
            if (line[i] == '(') depth++;
            if (line[i] == ')') depth--;
            i++;
          }
          if (depth > 0) continue;
        }
        final rest = line.substring(i).trimLeft();
        if (rest.isNotEmpty && !rest.startsWith('{') && !rest.startsWith('if')) {
          yield offset + match.start;
          break;
        }
      }
    }
    offset += line.length + 1;
  }
}

final rules = <Rule>[
  (
    id: 'no-material',
    find: _matching(RegExp(r'''import\s+['"]package:flutter/(material|cupertino)\.dart['"]''')),
    message: 'core/ et les composants ne dépendent que de widgets.dart',
    exemptDir: null,
    readsStrings: true,
  ),
  (
    id: 'directional-only',
    find: (code) => [
      ..._matching(
        RegExp(
          [
            r'\bEdgeInsets\.fromLTRB\b',
            r'\bAlignment\.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)\b',
            r'\bTextAlign\.(left|right)\b',
          ].join('|'),
        ),
      )(code),
      ..._callNaming(RegExp(r'\bEdgeInsets\.only\s*\('), const {'left', 'right'})(code),
      ..._callNaming(
        RegExp(r'\bBorderRadius\.(only|horizontal)\s*\('),
        const {'topLeft', 'topRight', 'bottomLeft', 'bottomRight', 'left', 'right'},
      )(code),
      ..._callNaming(RegExp(r'\bPositioned(\.fill)?\s*\('), const {'left', 'right'})(code),
    ]..sort(),
    message:
        'utiliser les types directionnels (EdgeInsetsDirectional, AlignmentDirectional, '
        'PositionedDirectional, BorderRadiusDirectional, TextAlign.start/end)',
    exemptDir: null,
    readsStrings: false,
  ),
  (
    id: 'braces-at-80',
    find: _unbracedOver80,
    message: 'accolades exigées : à 80 colonnes, chez l\'utilisateur, le corps passe à la ligne',
    exemptDir: null,
    readsStrings: false,
  ),
  (
    id: 'no-literal',
    find: _matching(RegExp(r'''\bColor\(\s*0x|\bBorderRadius(Directional)?\.circular\(\s*\d|\bfontFamily\s*:\s*['"]''')),
    message: 'couleur, rayon ou police littérale : passer par les jetons de core/tokens/',
    // Les jetons générés sont le seul endroit où ces valeurs s'écrivent en clair.
    exemptDir: 'lib/core/tokens/',
    readsStrings: false,
  ),
];

// Chaînes et commentaires dans l'ordre où ils apparaissent, pour qu'un `//` dans une chaîne ne masque pas la suite.
final _stringsAndComments = RegExp(
  r"""'''[\s\S]*?'''|"""
  r'''"""[\s\S]*?"""|'''
  r"""'(?:\\.|[^'\\\n])*'|"""
  r'''"(?:\\.|[^"\\\n])*"|'''
  r'//[^\n]*|/\*[\s\S]*?\*/',
);

// Un commentaire devient des espaces ; avec [strings], une chaîne garde ses guillemets et son contenu devient des
// espaces. Les lignes sont conservées pour que les numéros restent justes.
String _mask(String source, {required bool strings}) => source.replaceAllMapped(_stringsAndComments, (m) {
  final text = m[0]!;
  if (text.startsWith('/')) return text.replaceAll(RegExp(r'[^\n]'), ' ');
  return strings ? text.replaceAll(RegExp('[^\n\'"]'), ' ') : text;
});

List<String> lint(String path, String source) {
  final code = _mask(source, strings: true);
  final withStrings = _mask(source, strings: false);
  final failures = <String>[];
  for (final rule in rules) {
    final exempt = rule.exemptDir;
    if (exempt != null && path.replaceAll(r'\', '/').contains(exempt)) continue;
    for (final start in rule.find(rule.readsStrings ? withStrings : code)) {
      final line = '\n'.allMatches(code.substring(0, start)).length + 1;
      failures.add('$path:$line: [${rule.id}] ${rule.message}');
    }
  }
  return failures;
}

typedef Trap = ({String rule, String path, String source});

const _component = 'flutter/registry/lib/components/trap/trap.dart';

const traps = <Trap>[
  (rule: 'no-material', path: _component, source: "import 'package:flutter/material.dart';\n"),
  (rule: 'directional-only', path: _component, source: 'final p = EdgeInsets.only(left: 8);\n'),
  (rule: 'directional-only', path: _component, source: 'final p = EdgeInsets.only(\n  top: 4,\n  left: 8,\n);\n'),
  (rule: 'directional-only', path: _component, source: 'final p = EdgeInsets.only(top: gap(2), right: 8);\n'),
  (rule: 'directional-only', path: _component, source: 'final p = EdgeInsets.only(top: f(g(1)), left: 8);\n'),
  (rule: 'directional-only', path: _component, source: 'final p = EdgeInsets.only(top: max(a, b(c)), left: 8);\n'),
  (rule: 'directional-only', path: _component, source: 'Positioned(top: MediaQuery.of(context).padding.top, left: 0, child: c)\n'),
  (rule: 'directional-only', path: _component, source: 'final p = EdgeInsets.fromLTRB(1, 2, 3, 4);\n'),
  (rule: 'directional-only', path: _component, source: 'Positioned(\n  top: 0,\n  left: 0,\n  child: child,\n)\n'),
  (rule: 'directional-only', path: _component, source: 'final r = BorderRadius.only(\n  topLeft: r,\n);\n'),
  (rule: 'directional-only', path: _component, source: 'final a = Alignment.centerLeft;\n'),
  (rule: 'directional-only', path: _component, source: 'Text(label, textAlign: TextAlign.left)\n'),
  (rule: 'directional-only', path: _component, source: 'Text(\n  label,\n  textAlign: TextAlign.right,\n)\n'),
  (
    rule: 'braces-at-80',
    path: _component,
    source: '    if (status.isCompleted) _panel.currentContext?.findRenderObject()?.markNeedsPaint();\n',
  ),
  (
    rule: 'braces-at-80',
    path: _component,
    source: '      for (final entry in entries) entry.controller.animateTo(target, curve: curve, duration: d);\n',
  ),
  (rule: 'no-literal', path: _component, source: 'const c = Color(0xFF112233);\n'),
  (rule: 'no-literal', path: _component, source: 'const c = Color(\n  0xFF112233,\n);\n'),
  (rule: 'no-literal', path: _component, source: 'final r = BorderRadius.circular(8);\n'),
  (rule: 'no-literal', path: _component, source: 'final r = BorderRadiusDirectional.circular(12.5);\n'),
  (rule: 'no-literal', path: _component, source: "const s = TextStyle(fontFamily: 'Inter');\n"),
];

// Un fichier propre : types directionnels, jetons, et des écarts seulement dans des commentaires et des chaînes,
// plus un littéral de couleur là où il est permis.
const _clean = <({String path, String source})>[
  (
    path: _component,
    source:
        "import 'package:flutter/widgets.dart';\n"
        "const url = 'https://exemple.fr'; // EdgeInsets.only(left: 8)\n"
        '/* Color(0xFF000000)\n   TextAlign.left */\n'
        'final p = EdgeInsetsDirectional.only(\n  start: 8,\n);\n'
        'final a = AlignmentDirectional.centerStart;\n'
        'Text(label, textAlign: TextAlign.start)\n'
        'final r = BorderRadius.circular(theme.radiusControl);\n'
        'final s = TextStyle(fontFamily: theme.fontFamily);\n'
        'final q = EdgeInsets.only(top: 4, bottom: inset(left: f(g(2))));\n'
        'Positioned(top: 0, child: Padding(padding: insets(right: 2)))\n'
        '    if (status.isCompleted) { _panel.currentContext?.findRenderObject()?.markNeedsPaint(); }\n'
        '    children: [if (showLeading) leadingWidgetBuiltFromTheCurrentThemeAndTheItemState(context), body],\n'
        '  if (a) return;\n'
        '    final colors = [for (final t in steps) color.withValues(alpha: 1 - ease.transform(t))];\n'
        "Text('Alignez avec TextAlign.left ou EdgeInsets.only(left: 8)')\n"
        "Text('''Color(0xFF000000)\nfromLTRB''')\n",
  ),
  (path: 'flutter/registry/lib/core/tokens/tokens.g.dart', source: 'surface: Color(0xFFFFFFFF),\n'),
];

int selfTest({bool verbose = false}) {
  var failed = 0;
  for (final trap in traps) {
    final hits = lint(trap.path, trap.source).where((f) => f.contains('[${trap.rule}]')).toList();
    final shown = trap.source.trim().replaceAll('\n', r'\n');
    if (hits.isEmpty) {
      stderr.writeln('self-test: la règle ${trap.rule} ne détecte pas le piège « $shown »');
      failed++;
    } else if (verbose) {
      stdout.writeln('piège « $shown » → ${hits.first}');
    }
  }
  for (final file in _clean) {
    final hits = lint(file.path, file.source);
    if (hits.isNotEmpty) {
      stderr.writeln('self-test: faux positif sur un fichier propre');
      hits.forEach(stderr.writeln);
      failed++;
    }
  }
  return failed == 0 ? 0 : 1;
}

void main(List<String> args) {
  if (args.contains('--self-test')) {
    exit(selfTest(verbose: true));
  }
  final root = Directory('flutter/registry/lib');
  if (!root.existsSync()) {
    stderr.writeln('lint_registry: ${root.path} introuvable, lancer depuis la racine du dépôt');
    exit(2);
  }
  final failures = <String>[];
  for (final entity in root.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      failures.addAll(lint(entity.path, entity.readAsStringSync()));
    }
  }
  if (selfTest() != 0) exit(1);
  if (failures.isNotEmpty) {
    failures.forEach(stderr.writeln);
    exit(1);
  }
  stdout.writeln('lint_registry: ${rules.length} règles, ${traps.length} pièges, aucun écart');
}
