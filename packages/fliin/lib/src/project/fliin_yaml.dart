import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;

import 'invalid_project_file.dart';
import 'pubspec.dart';

const fliinYamlName = 'fliin.yaml';

/// Lève une [InvalidProjectFile] si le fichier n'est pas du YAML ou pas une
/// config.
FliinConfig? readFliinConfig(Directory dir) {
  final file = File(p.join(dir.path, fliinYamlName));
  if (!file.existsSync()) return null;
  try {
    return FliinConfig.fromJson(readYaml(file));
  } on ManifestError catch (e) {
    throw InvalidProjectFile(file.path, '$e');
  }
}

void writeFliinConfig(Directory dir, FliinConfig config) =>
    File(p.join(dir.path, fliinYamlName))
        .writeAsStringSync(emitYaml(config.toJson()));

/// YAML en style bloc pour ce que `FliinConfig.toJson` produit : des Map, des
/// listes de scalaires et des scalaires. Le paquet yaml ne fait que lire.
String emitYaml(Map<String, Object?> map) {
  final out = StringBuffer();
  _emitMap(out, map, 0);
  return out.toString();
}

void _emitMap(StringBuffer out, Map<String, Object?> map, int indent) {
  final pad = '  ' * indent;
  for (final MapEntry(:key, :value) in map.entries) {
    final name = '$pad${_scalar(key)}';
    switch (value) {
      case Map<String, Object?>() when value.isNotEmpty:
        out.writeln('$name:');
        _emitMap(out, value, indent + 1);
      case List<Object?>() when value.isNotEmpty:
        out.writeln('$name:');
        for (final item in value) {
          out.writeln('$pad- ${_scalar(item)}');
        }
      case Map<String, Object?>():
        out.writeln('$name: {}');
      case List<Object?>():
        out.writeln('$name: []');
      default:
        out.writeln('$name: ${_scalar(value)}');
    }
  }
}

String _scalar(Object? value) => switch (value) {
  null => 'null',
  bool() || int() => '$value',
  String() when _plain.hasMatch(value) && !_reserved.contains(value) => value,
  String() => "'${value.replaceAll("'", "''")}'",
  _ => throw ArgumentError.value(value, 'value', 'expected a YAML scalar'),
};

final _plain = RegExp(r'^[A-Za-z_][A-Za-z0-9_./-]*$');
const _reserved = {'true', 'false', 'null', 'yes', 'no', 'on', 'off', 'y', 'n'};
