import 'dart:typed_data';

import 'package:fliin_schema/fliin_schema.dart';
import 'package:pub_semver/pub_semver.dart';

import 'registry_port.dart';

/// Le registre tel que le projet le voit : chaque manifeste avec les
/// variantes de fichier de son préréglage (le jeu d'icônes, ADR 0016 §3.8).
/// L'installeur, `update`, `view` et `verify` lisent donc le fichier du jeu
/// choisi sans le savoir, et le lockfile garde son brut (règle 3). Lève
/// [MissingVariant] quand une version d'`icons` ne sert pas ce jeu.
final class SelectedRegistry implements Registry {
  SelectedRegistry(this._inner, this.variant);

  final Registry _inner;

  /// Nul : le jeu par défaut, les manifestes tels quels.
  final String? variant;

  @override
  Future<IndexPointer> fetchPointer() => _inner.fetchPointer();

  @override
  Future<IndexFragment> fetchFragment(FragmentRef fragment) =>
      _inner.fetchFragment(fragment);

  @override
  Future<ItemManifest> fetchManifest(ItemRef ref, Version version) async =>
      (await _inner.fetchManifest(ref, version)).select(variant);

  @override
  Future<Uint8List> fetchBlob(Sha256 sha256) => _inner.fetchBlob(sha256);

  @override
  bool get servesPro => _inner.servesPro;
}
