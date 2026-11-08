import 'dart:io';

import 'package:fliin/fliin.dart' as fliin;

import 'https_registry.dart';

/// Le CLI tel que `bin/fliin.dart`, avec pour seules différences la
/// confiance en l'autorité de test de `FLIIN_TEST_CA`, injectée par
/// `HttpOverrides`, et un registre officiel de test : `FLIIN_TEST_REGISTRY`,
/// `FLIIN_TEST_PRO_REGISTRY` et sa clé `FLIIN_TEST_OFFICIAL_KEY`. Le code
/// livré n'a ni `badCertificateCallback`, ni option pour l'un ou l'autre.
Future<void> main(List<String> args) async {
  final environment = Platform.environment;
  final ca = environment['FLIIN_TEST_CA'];
  if (ca != null && ca.isNotEmpty) {
    HttpOverrides.global = TrustingOverrides(trusting(ca));
  }
  final official = switch ((
    environment['FLIIN_TEST_REGISTRY'],
    environment['FLIIN_TEST_PRO_REGISTRY'],
    environment['FLIIN_TEST_OFFICIAL_KEY'],
  )) {
    (final public?, final pro?, final key?) => fliin.OfficialRegistry(
      publicUrl: Uri.parse(public),
      proUrl: Uri.parse(pro),
      keys: [key],
    ),
    _ => null,
  };
  exitCode = await fliin.run(args, official: official);
}
