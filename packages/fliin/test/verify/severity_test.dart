import 'package:fliin/src/commands/exit_code.dart';
import 'package:fliin/src/commands/verify.dart';
import 'package:test/test.dart';

void main() {
  test('devrait rendre le code le plus grave quand plusieurs éléments sont vérifiés : 2, puis 1, puis 0', () {
    expect(mostSevere([ExitCode.ok, ExitCode.ok]), ExitCode.ok);
    expect(mostSevere([ExitCode.ok, ExitCode.failure]), ExitCode.failure);
    expect(mostSevere([ExitCode.failure, ExitCode.ok]), ExitCode.failure);
    expect(
      mostSevere([ExitCode.analysis, ExitCode.failure, ExitCode.ok]),
      ExitCode.analysis,
    );
    expect(
      mostSevere([ExitCode.ok, ExitCode.failure, ExitCode.analysis]),
      ExitCode.analysis,
    );
  });

  test('devrait placer l’environnement (3) au-dessus de l’analyse quand un élément a un fichier ou un rapport illisible', () {
    expect(
      mostSevere([ExitCode.environment, ExitCode.analysis, ExitCode.ok]),
      ExitCode.environment,
    );
  });

  test('devrait tenir un code inconnu de l’ordre pour le plus grave, jamais pour un succès', () {
    expect(mostSevere([ExitCode.integrity, ExitCode.ok]), ExitCode.integrity);
    expect(mostSevere([ExitCode.ok, ExitCode.integrity]), ExitCode.integrity);
    expect(
      mostSevere([ExitCode.environment, ExitCode.confirmation]),
      ExitCode.confirmation,
    );
  });
}
