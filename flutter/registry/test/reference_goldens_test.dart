import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:fliin_harness/fliin_harness.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reference/verify_entries.g.dart';
import 'support/allowances.dart';
import 'support/runs.dart';

/// Les goldens de référence que `fliin registry build` publie (ADR 0011) :
/// `verify.entry` de chaque manifeste, rendu comme `fliin verify` le rend
/// dans une app aux jetons par défaut. Les régénérer après un changement
/// voulu : `flutter test --update-goldens test/reference_goldens_test.dart`.
String _out(String item) => 'build/fliin/verify/reference/$item';

String _goldens(String item) => 'test/goldens/reference/$item';

/// Ce que `registry build` publie dans `verify.goldens.rendering` : ce dont
/// ces pixels dépendent hors du code (ADR 0011).
Map<String, Object?> _rendering(Map<String, Object?> report) => {
  'abi': report['host'],
  'flutter': report['flutter'],
  'fonts': report['fonts'],
};

final File _renderingFile = File('test/goldens/reference/rendering.json');

void main() {
  final runs = FlRuns();

  for (final MapEntry(key: item, value: spec) in verifyEntries.entries) {
    fliinVerify(
      item: item,
      version: spec.version,
      contrastExceptions: allowancesOf(FlTokens.defaults),
      outDir: _out(item),
      goldens: macOSGoldens(_goldens(item), macOS: Platform.isMacOS, update: autoUpdateGoldenFiles),
      onReport: (report) {
        runs.keep(_out(item), report);
        if (autoUpdateGoldenFiles && Platform.isMacOS) {
          _renderingFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(_rendering(report))}\n');
        }
      },
      logicalSize: spec.canvas ?? const Size(390, 300),
      platformSizes: spec.platformCanvas,
      settle: spec.settle,
      entry: spec.entry,
    );
  }

  test('devrait décrire dans rendering.json l’hôte, Flutter et les polices de ce rendu', () {
    final reports = [for (final item in verifyEntries.keys) runs.report(_out(item))];
    expect(jsonDecode(_renderingFile.readAsStringSync()), _rendering(reports.first));
    for (final report in reports) {
      expect(_rendering(report), _rendering(reports.first));
    }
  }, skip: Platform.isMacOS ? false : 'goldens de référence produits sous macOS seulement (ADR 0005)');

  for (final item in verifyEntries.keys) {
    test('devrait faire passer les 16 variantes de verify.entry de $item', () {
      expect(runs.report(_out(item))['summary'], ['16/16 variants pass']);
    });

    test('devrait rendre verify.entry de $item au pixel près de son golden de référence macOS', () {
      final drifted = {
        for (final variant in runs.variants(_out(item)))
          if ((variant['golden']! as Map<String, Object?>)['diffPct'] != 0.0)
            variant['id']: (variant['golden']! as Map<String, Object?>)['diffPct'],
      };
      expect(
        drifted,
        isEmpty,
        reason:
            'références ${_goldens(item)}, produites sous macOS 27.2 arm64 (ADR 0005), '
            'hôte ${Platform.operatingSystemVersion} ${Abi.current()} ; régénérer après un changement voulu : '
            'flutter test --update-goldens test/reference_goldens_test.dart',
      );
    }, skip: Platform.isMacOS ? false : 'goldens de référence produits sous macOS seulement (ADR 0005)');
  }
}
