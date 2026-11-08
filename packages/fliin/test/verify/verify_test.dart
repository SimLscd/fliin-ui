@Tags(['slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/cli.dart';
import '../support/temp_project.dart';

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await createFlutterProject('verify_app');
    expect((await fliin(dir, ['init'])).code, 0);
    expect((await fliin(dir, ['add', 'button'])).code, 0);
  });
  tearDownAll(deleteCreatedProjects);

  test('devrait sortir 0 avec 16 PNG, overview.png et report.json quand on vérifie button (preuve 6)', () async {
    final stopwatch = Stopwatch()..start();
    final run = await fliin(dir, ['verify', 'button', '--json']);
    stopwatch.stop();
    expect(run.code, 0, reason: run.err);
    final out = Directory(p.join(dir.path, 'build/fliin/verify/button'));
    final pngs = out
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .where((n) => n.endsWith('.png'))
        .toList();
    expect(pngs, hasLength(17));
    expect(pngs, contains('overview.png'));
    final report = jsonOf(run);
    expect(report['item'], 'button');
    expect(report['summary'], ['16/16 variants pass']);
    expect(
      (report['analyze']! as Map<String, Object?>)['diagnostics'],
      isEmpty,
    );
    expect(File(p.join(out.path, 'report.json')).existsSync(), isTrue);
    expect(
      File(p.join(dir.path, 'test/.fliin/button_verify_test.dart'))
          .existsSync(),
      isTrue,
    );
    stdout.writeln(
      'verify button : ${stopwatch.elapsedMilliseconds} ms, harnais ${report['elapsedMs']} ms',
    );
  });

  test('devrait sortir 1 quand une variante déborde, avec le widget fautif dans le rapport', () async {
    final run = await fliin(dir, [
      'verify',
      'button',
      '--json',
      '--variants',
      'ios.light.1.0.ltr,ios.light.2.0.ltr',
      '--entry',
      "Row(children: [const SizedBox(width: 300), {prefix}Button(label: 'Enregistrer les modifications', onPressed: () {})])",
      '--import',
      'lib/ui/fliin/components/button/fl_button.dart',
    ]);
    expect(run.code, 1, reason: run.err);
    final variants = (jsonOf(run)['variants']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(variants, hasLength(2));
    expect(variants.map((v) => v['status']), contains('fail'));
    final failed = variants.firstWhere((v) => v['status'] == 'fail');
    final error =
        ((failed['layoutErrors']! as List<Object?>).single
            as Map<String, Object?>);
    expect(error['message'], contains('overflowed'));
    expect(error['widget'], 'Row');
  });

  test('devrait sortir 1 quand flutter test échoue sans que le rapport le dise, comme un minuteur laissé en attente (synthèse #3)', () async {
    final run = await fliin(dir, [
      'verify',
      'button',
      '--json',
      '--variants',
      'ios.light.1.0.ltr',
      '--entry',
      'Builder(builder: (c) { Future<void>.delayed(const Duration(days: 1)); return const SizedBox(width: 100, height: 48); })',
    ]);
    expect(run.code, 1, reason: run.err);
    expect(run.err, contains('flutter test failed'));
    expect(run.err, contains('Timer'));
    final report = jsonOf(run);
    expect(report['summary'], ['1/1 variants pass']);
    final test = report['test']! as Map<String, Object?>;
    expect(test['exitCode'], isNot(0));
    expect(test['missingVariants'], isEmpty);
  });

  test('devrait sortir 2 quand l’entrée ne compile pas', () async {
    final run = await fliin(dir, [
      'verify',
      'button',
      '--entry',
      'Inexistant()',
      '--variants',
      'ios.light.1.0.ltr',
    ]);
    expect(run.code, 2);
    expect(run.err, contains('produced no report'));
  });

  test('devrait sortir 1 quand l’élément n’est pas installé', () async {
    final run = await fliin(dir, ['verify', 'carousel']);
    expect(run.code, 1);
    expect(run.err, contains('is not installed'));
  });
}
