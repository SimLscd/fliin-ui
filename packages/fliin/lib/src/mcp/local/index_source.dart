import '../../install/registry_port.dart';
import '../ports.dart';

/// Les fragments du registre configuré, relus avec le pointeur après un TTL
/// de 10 minutes (ADR §4.5) : un `fliin mcp` qui tourne des heures voit les
/// publications sans redémarrer.
final class LocalIndexSource implements IndexSource {
  LocalIndexSource(
    this._registry, {
    this.ttl = const Duration(minutes: 10),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Registry _registry;
  final Duration ttl;
  final DateTime Function() _clock;
  ({DateTime readAt, IndexSnapshot snapshot})? _cached;

  @override
  Future<IndexSnapshot> snapshot() async {
    final now = _clock();
    if (_cached case (:final readAt, :final snapshot)
        when now.difference(readAt) < ttl) {
      return snapshot;
    }
    final snapshot = IndexSnapshot(await fetchEntries(_registry));
    _cached = (readAt: now, snapshot: snapshot);
    return snapshot;
  }
}
