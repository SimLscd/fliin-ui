import 'package:fliin/src/commands/exit_code.dart';
import 'package:fliin/src/verify/report.dart';
import 'package:test/test.dart';

VerifyReport _report(List<String> statuses) => VerifyReport.parse({
  'variants': [
    for (final (i, status) in statuses.indexed)
      {'id': 'v$i', 'status': status, 'golden': null},
  ],
  'summary': const <String>[],
});

void main() {
  test('devrait échouer quand flutter test a échoué ou qu’une variante demandée manque, même si chaque variante rendue passe (synthèse #3)', () {
    final report = _report(['pass', 'pass']);
    expect(report.verdict(strict: false), ExitCode.ok);
    expect(report.verdict(strict: false, testExitCode: 1), ExitCode.failure);
    expect(
      report.verdict(strict: false, missing: ['android.dark.2.0.rtl']),
      ExitCode.failure,
    );
    expect(_report(['pass', 'fail']).verdict(strict: false), ExitCode.failure);
    expect([for (final v in report.variants) v.id], ['v0', 'v1']);
  });
}
