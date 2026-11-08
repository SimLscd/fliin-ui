import 'manifest_error.dart';

/// Un nœud d'un document décodé (JSON, ou YAML déjà converti en Map) et son
/// chemin. Chaque lecture lève une [ManifestError] située.
final class JsonNode {
  JsonNode(this.value, [this.path = r'$']);

  final Object? value;
  final String path;

  bool get isAbsent => value == null;

  JsonNode operator [](String key) => JsonNode(object[key], _child(key));

  /// Ce nœud, ou [empty] à sa place s'il est absent.
  JsonNode orElse(Object empty) => isAbsent ? JsonNode(empty, path) : this;

  T read<T>(T Function(Object? json, String at) fromJson) =>
      fromJson(value, path);

  T? readOptional<T>(T Function(Object? json, String at) fromJson) =>
      isAbsent ? null : fromJson(value, path);

  String get string => _as<String>('a string');

  String? get optionalString => isAbsent ? null : string;

  int get integer => _as<int>('an integer');

  bool get boolean => _as<bool>('a boolean');

  List<JsonNode> get items => [
    for (final (i, item) in _as<List<Object?>>('an array').indexed)
      JsonNode(item, '$path[$i]'),
  ];

  Map<String, JsonNode> get fields => {
    for (final key in object.keys) key: this[key],
  };

  List<String> get strings => [for (final item in items) item.string];

  Map<String, String> get stringMap => {
    for (final MapEntry(:key, :value) in fields.entries) key: value.string,
  };

  /// La chaîne lue, convertie par [parser]. Une [FormatException] devient
  /// [error], ou à défaut une [InvalidValue] qui reprend son message.
  T parse<T>(
    T Function(String text) parser, [
    ManifestError Function(String path, String text)? error,
  ]) {
    final text = string;
    try {
      return parser(text);
    } on FormatException catch (e) {
      throw error?.call(path, text) ??
          InvalidValue(path, '${e.message}: $text');
    }
  }

  /// La valeur de [values] dont la forme écrite, [wire], égale la chaîne lue.
  T oneOf<T extends Enum>(List<T> values, [String Function(T value)? wire]) {
    final text = string;
    final write = wire ?? (T value) => value.name;
    for (final value in values) {
      if (write(value) == text) return value;
    }
    throw UnknownValue(path, text, [for (final value in values) write(value)]);
  }

  /// Un chemin relatif sous la racine : ni absolu, ni `.`, ni `..`.
  String get relativePath => parse(checkRelativePath);

  DateTime get utc => parse((text) {
    final time = DateTime.tryParse(text);
    return time != null && time.isUtc
        ? time
        : throw FormatException('expected an ISO 8601 date in UTC', text);
  });

  /// Vérifie que l'entier lu vaut [expected], la seule version de format connue.
  void expectFormat(int expected) {
    if (integer != expected) {
      throw InvalidValue(path, 'expected $expected, the only known version');
    }
  }

  Map<String, Object?> get object => switch (value) {
    null => throw MissingField(path),
    final Map<Object?, Object?> map
        when map.keys.every((key) => key is String) =>
      map.cast<String, Object?>(),
    _ => throw WrongJsonType(path, 'an object'),
  };

  T _as<T>(String expected) => switch (value) {
    null => throw MissingField(path),
    final T value => value,
    _ => throw WrongJsonType(path, expected),
  };

  String _child(String key) =>
      _identifier.hasMatch(key) ? '$path.$key' : "$path['$key']";

  static final _identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
}

/// Lève une [FormatException] si [text] sort de sa racine ou n'est pas portable.
String checkRelativePath(String text) {
  final segments = text.split('/');
  if (text.contains(r'\') ||
      text.contains(':') ||
      segments.any((s) => s.isEmpty || s == '.' || s == '..')) {
    throw FormatException('expected a relative path without . or ..', text);
  }
  return text;
}
