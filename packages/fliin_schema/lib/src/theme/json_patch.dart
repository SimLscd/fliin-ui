import 'dart:convert';

enum PatchOperation { test, replace, add }

/// Une opération JSON Patch (RFC 6902) ; [path] est un pointeur RFC 6901.
/// `fliin theme` émet `test` (la valeur d'avant) suivi de `replace`, pour
/// qu'un patch appliqué à un autre fichier que celui qu'il a lu échoue ; un
/// préréglage ajoute par `add` un groupe que le fichier n'a pas encore.
typedef PatchOp = ({PatchOperation op, String path, Object? value});

Map<String, Object?> patchOpJson(PatchOp op) => {
  'op': op.op.name,
  'path': op.path,
  'value': op.value,
};

/// [value] avec chaque nombre entier en `int` : `jsonEncode` l'écrit alors
/// sans « .0 » sur la VM comme en JavaScript, où `1.0` n'existe pas. Le site
/// rend ainsi au caractère près le texte de la VM (ADR 0004 §1) ; `1` et
/// `1.0` restent égaux pour un `test` (RFC 6902 §4.6).
Object? portableJson(Object? value) => switch (value) {
  final double number when number.isFinite && number == number.truncate() =>
    number.truncate(),
  final List<Object?> list => [for (final item in list) portableJson(item)],
  final Map<String, Object?> map => {
    for (final MapEntry(:key, :value) in map.entries) key: portableJson(value),
  },
  _ => value,
};

/// L'égalité de RFC 6902 §4.6 : un nombre vaut par sa valeur (`1` et `1.0`
/// sont égaux), un objet par ses membres quel que soit leur ordre, un
/// tableau par ses éléments dans l'ordre.
bool jsonEquals(Object? a, Object? b) => switch ((a, b)) {
  (final List<Object?> a, final List<Object?> b) =>
    a.length == b.length &&
        [for (var i = 0; i < a.length; i++) jsonEquals(a[i], b[i])]
            .every((x) => x),
  (final Map<String, Object?> a, final Map<String, Object?> b) =>
    a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && jsonEquals(a[key], b[key])),
  (final num a, final num b) => a == b,
  _ => a == b,
};

/// Le pointeur RFC 6901 de [segments] : `~` devient `~0`, `/` devient `~1`.
String jsonPointer(List<String> segments) => [
  '',
  for (final segment in segments)
    segment.replaceAll('~', '~0').replaceAll('/', '~1'),
].join('/');

/// La valeur de [document] à [pointer], sinon [JsonPatchError].
Object? valueAt(Object? document, String pointer) {
  var node = document;
  for (final segment in _segments(pointer)) {
    node = switch (node) {
      final Map<String, Object?> map when map.containsKey(segment) =>
        map[segment],
      _ => throw JsonPatchError(pointer, 'location not found'),
    };
  }
  return node;
}

/// [document] après [patch], sans toucher à [document] ; l'ordre des clés
/// est gardé, une valeur remplacée reste à sa place. Lève [JsonPatchError]
/// sur un `test` qui ne correspond pas ou un emplacement absent.
Object? applyJsonPatch(Object? document, List<PatchOp> patch) {
  final copy = jsonDecode(jsonEncode(document));
  for (final op in patch) {
    switch (op.op) {
      case PatchOperation.test:
        if (!jsonEquals(valueAt(copy, op.path), op.value)) {
          throw JsonPatchError(
            op.path,
            'the value changed since it was computed',
          );
        }
      case PatchOperation.replace:
        valueAt(copy, op.path);
        _parent(copy, op.path)[_segments(op.path).last] = op.value;
      case PatchOperation.add:
        _parent(copy, op.path)[_segments(op.path).last] = op.value;
    }
  }
  return copy;
}

Map<String, Object?> _parent(Object? document, String pointer) {
  final segments = _segments(pointer);
  return switch (valueAt(
    document,
    jsonPointer(segments.sublist(0, segments.length - 1)),
  )) {
    final Map<String, Object?> parent => parent,
    _ => throw JsonPatchError(pointer, 'the parent is not an object'),
  };
}

List<String> _segments(String pointer) => [
  for (final segment in pointer.split('/').skip(1))
    segment.replaceAll('~1', '/').replaceAll('~0', '~'),
];

final class JsonPatchError implements Exception {
  const JsonPatchError(this.path, this.reason);

  final String path;
  final String reason;

  @override
  String toString() => '$path: $reason';
}
