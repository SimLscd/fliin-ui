import 'dart:io';
import 'dart:math' as math;

import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'torture/torture.g.dart';

double _luminance(Color color) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [layers] du haut vers le bas, la dernière pleine, arrondies sur 8 bits
/// comme `composite` de fliin_schema.
Color _composite(List<Color> layers) {
  var (r, g, b) = (0.0, 0.0, 0.0);
  for (final layer in layers.reversed) {
    r = layer.r * 255 * layer.a + r * (1 - layer.a);
    g = layer.g * 255 * layer.a + g * (1 - layer.a);
    b = layer.b * 255 * layer.a + b * (1 - layer.a);
  }
  return Color.fromARGB(255, r.round(), g.round(), b.round());
}

double _pairContrast(FlContrastPair pair, FlColorTokens colors) =>
    _contrast(colors[pair.foreground], _composite([colors[pair.background], for (final role in pair.over) colors[role]]));

double _floor(double ratio) => (ratio * 100).floor() / 100;

bool _samePair(FlContrastPair a, FlContrastPair b) =>
    a.foreground == b.foreground && a.background == b.background && a.kind == b.kind && _sameRoles(a.over, b.over);

bool _sameRoles(List<FlColorRole> a, List<FlColorRole> b) => a.length == b.length && [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);

String _pairText(FlContrastPair pair) => [
  '`${pair.foreground.name}` sur `${pair.background.name}`',
  for (final role in pair.over) 'sur `${role.name}`',
].join(' ');

void main() {
  final themes = [('défaut', FlTokens.defaults), ('torture A', tortureA), ('torture B', tortureB)];
  const minimum = {FlContrastKind.text: 4.5, FlContrastKind.ui: 3.0};

  for (final (name, tokens) in themes) {
    for (final brightness in Brightness.values) {
      final colors = brightness == Brightness.light ? tokens.light : tokens.dark;
      test(
        'devrait respecter 4,5:1 (texte) et 3:1 (interface) pour chaque paire, hors exceptions déclarées, '
        'quand le thème est $name ${brightness.name}',
        () {
          expect(FlColorTokens.contrastPairs, isNotEmpty);
          for (final pair in FlColorTokens.contrastPairs) {
            final ratio = _pairContrast(pair, colors);
            if (ratio >= minimum[pair.kind]!) continue;
            final declared = tokens.contrastExceptions.where(
              (e) => e.brightness == brightness && _samePair(e.pair, pair),
            );
            expect(
              declared,
              hasLength(1),
              reason: '${_pairText(pair)} : ${ratio.toStringAsFixed(2)}:1 sans exception déclarée',
            );
            expect(declared.single.ratio, _floor(ratio), reason: _pairText(pair));
          }
        },
      );
    }
  }

  test('devrait garder les thèmes de torture en AA strict, sans aucune exception', () {
    expect(tortureA.contrastExceptions, isEmpty);
    expect(tortureB.contrastExceptions, isEmpty);
  });

  test('devrait ne déclarer d’exception que pour une paire qui échoue vraiment', () {
    for (final e in FlTokens.defaults.contrastExceptions) {
      final colors = e.brightness == Brightness.light ? FlTokens.defaults.light : FlTokens.defaults.dark;
      expect(_pairContrast(e.pair, colors), lessThan(minimum[e.pair.kind]!), reason: _pairText(e.pair));
    }
  });

  // L'export public du gratuit n'a pas docs/ (ADR 0020 §12) : le tableau ne s'y relit pas.
  final adrFile = File('../../docs/decisions/0019-habillage-izydesk.md');
  test('devrait trouver chaque exception du thème livré, et elles seules, dans le tableau de l’ADR 0019', skip: adrFile.existsSync() ? false : 'docs/ is not in the public repository', () {
    final adr = adrFile.readAsStringSync();
    final rows = adr.split('\n').where((line) => line.startsWith('| exception |')).toList();
    final exceptions = FlTokens.defaults.contrastExceptions;
    expect(rows, hasLength(exceptions.length), reason: 'une ligne « | exception | » par exception déclarée');
    for (final e in exceptions) {
      final mode = e.brightness == Brightness.light ? 'clair' : 'sombre';
      final ratio = e.ratio.toStringAsFixed(2).replaceAll('.', ',');
      final row = '| exception | $mode | ${_pairText(e.pair)} | $ratio:1 |';
      expect(rows.any((r) => r.startsWith(row)), isTrue, reason: row);
    }
  });

  test('devrait garder opaque le premier plan et la dernière couche de chaque paire, en clair et en sombre', () {
    for (final (name, tokens) in themes) {
      for (final colors in [tokens.light, tokens.dark]) {
        for (final pair in FlColorTokens.contrastPairs) {
          final ground = pair.over.isEmpty ? pair.background : pair.over.last;
          expect(colors[pair.foreground].a, 1.0, reason: '${pair.foreground.name}, $name');
          expect(colors[ground].a, 1.0, reason: '${ground.name}, $name');
        }
      }
    }
    expect(FlTokens.defaults.light.dangerSoft.a, lessThan(1), reason: 'hors paire, un rôle peut être translucide');
  });
}
