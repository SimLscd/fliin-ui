import 'package:fliin_schema/fliin_schema.dart';

import '../../install/registry_port.dart';
import '../ports.dart';

/// Aucun élément n'exige de droit : les tests du serveur.
final class AllEntitled implements EntitlementResolver {
  const AllEntitled();

  @override
  Future<Entitlement> resolve(IndexEntry entry) async => Entitlement.granted;
}

/// Un élément Pro manque quand le registre n'en sert pas le code : le
/// registre officiel lu sans clé de licence (ADR 0020 §5).
final class RegistryEntitlement implements EntitlementResolver {
  const RegistryEntitlement(this.registry);

  final Registry registry;

  @override
  Future<Entitlement> resolve(IndexEntry entry) async =>
      entry.meta.tier == Tier.pro && !registry.servesPro
      ? Entitlement.missing
      : Entitlement.granted;
}

/// V1 : un processus local par client, aucun quota (ADR §2 règle 10).
final class Unlimited implements QuotaGate {
  const Unlimited();

  @override
  Future<QuotaDecision> admit(QuotaScope scope) async => const Admitted();
}
