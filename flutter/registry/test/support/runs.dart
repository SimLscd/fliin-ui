import 'package:flutter_test/flutter_test.dart';

/// Les rapports de `fliinVerify` rendus dans cette exécution, par dossier de
/// sortie, remplis par `onReport`. Un test qui demande un rapport absent
/// échoue : il ne relit jamais le `report.json` d'une exécution passée, que
/// laisse un filtre de nom (`--plain-name`) ou un run interrompu.
final class FlRuns {
  final _reports = <String, Map<String, Object?>>{};

  void keep(String outDir, Map<String, Object?> report) => _reports[outDir] = report;

  Map<String, Object?> report(String outDir) =>
      _reports[outDir] ?? (throw TestFailure('$outDir : aucun rendu dans cette exécution'));

  List<Map<String, Object?>> variants(String outDir) =>
      (report(outDir)['variants']! as List<Object?>).cast<Map<String, Object?>>();
}

/// Le dossier des goldens, sous macOS seulement : les références sont des
/// rendus macOS (ADR 0005). Ailleurs, `--update-goldens` les remplacerait par
/// des rendus d'un autre hôte sans que rien ne le signale : c'est refusé.
String? macOSGoldens(String dir, {required bool macOS, required bool update}) {
  if (macOS) return dir;
  if (update) {
    throw StateError('--update-goldens refusé hors macOS : $dir contient des références macOS (ADR 0005)');
  }
  return null;
}
