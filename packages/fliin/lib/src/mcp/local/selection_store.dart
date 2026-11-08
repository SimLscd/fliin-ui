import 'dart:convert';
import 'dart:math';

import 'package:fliin_schema/fliin_schema.dart';

import '../ports.dart';

/// Les sélections vivent dans le processus `fliin mcp` et meurent avec lui.
final class MemorySelectionStore implements SelectionStore {
  MemorySelectionStore({
    DateTime Function()? clock,
    this.ttl = const Duration(minutes: 30),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration ttl;
  final Random _random = Random.secure();
  final Map<SelectionHandle, Selection> _selections = {};

  /// 128 bits tirés au hasard, en base64url sans remplissage.
  String _secret() => base64Url
      .encode([for (var i = 0; i < 16; i++) _random.nextInt(256)])
      .replaceAll('=', '');

  @override
  Future<Selection> open({
    required List<ItemRef> candidates,
    required String question,
    required GoldenVariant variant,
  }) async {
    final now = _clock();
    _selections.removeWhere((_, old) => !now.isBefore(old.expires));
    final selection = Selection(
      handle: SelectionHandle(_secret()),
      candidates: List.unmodifiable(candidates),
      question: question,
      variant: variant,
      formToken: _secret(),
      status: const Pending(),
      expires: now.add(ttl),
    );
    _selections[selection.handle] = selection;
    return selection;
  }

  /// Les sélections gardées en mémoire, expirées comprises jusqu'à la
  /// prochaine ouverture.
  int get length => _selections.length;

  @override
  Future<Selection?> find(SelectionHandle handle) async {
    final selection = _selections[handle];
    if (selection == null) return null;
    if (!_clock().isBefore(selection.expires)) {
      _selections.remove(handle);
      return null;
    }
    return selection;
  }

  @override
  Future<Selection?> settle(
    SelectionHandle handle,
    SelectionOutcome outcome,
  ) async {
    final current = await find(handle);
    if (current == null || current.status is SelectionOutcome) return current;
    final settled = Selection(
      handle: current.handle,
      candidates: current.candidates,
      question: current.question,
      variant: current.variant,
      formToken: current.formToken,
      status: outcome,
      expires: current.expires,
    );
    _selections[handle] = settled;
    return settled;
  }
}
