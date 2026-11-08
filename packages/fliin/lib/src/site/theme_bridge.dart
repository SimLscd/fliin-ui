import 'dart:convert';

import 'dart:math' as math;

import 'package:fliin_schema/fliin_schema.dart';

import '../tokens/preset_notes.dart';

/// The site's theme page: [requestJson] applied to the token file
/// [tokensJson], rendered as JSON. Pure Dart: `tool/site/theme_web.dart`
/// compiles it for the browser, and the VM renders the same text
/// (`theme_bridge_test.dart`).
///
/// A preset (ADR 0016) is requested by its code (`preset`, or whatever is
/// pasted around it, [presetCodeIn]), by the indices of its fields
/// (`fields`, those of [Preset.indices]) or at random (`shuffle`, a seed,
/// and `keep`, the locked fields); the answer is `preset` or `invalid`
/// (see [_presetAnswer]). Otherwise the request sets the
/// solver (`primary`, `neutral`, `button`, `radius`, each optional) and
/// the answer is `solved` (`patch`, `contrast`, `clashes` and the resulting
/// theme, `roles`, `radius`, `button`), `unsatisfiable` (`failing`,
/// `sameHue`, `nearestHue`) or `invalid` (`message`).
String solveThemeJson(String tokensJson, String requestJson) =>
    jsonEncode(portableJson(_respond(tokensJson, requestJson)));

Map<String, Object?> _respond(String tokensJson, String requestJson) {
  final Object? tokens;
  final Object? ask;
  try {
    tokens = jsonDecode(tokensJson);
    ask = jsonDecode(requestJson);
  } on FormatException catch (e) {
    return {'kind': 'invalid', 'message': e.message};
  }
  if (ask is Map<String, Object?> &&
      (ask.containsKey('preset') ||
          ask.containsKey('fields') ||
          ask.containsKey('shuffle'))) {
    return _presetAnswer(tokensJson, tokens, ask);
  }
  final ThemeRequest request;
  try {
    request = _request(ask);
  } on FormatException catch (e) {
    return {'kind': 'invalid', 'message': e.message};
  }
  try {
    switch (solveTheme(tokens, request)) {
      case ThemeSolved(:final patch, :final contrast, :final clashes):
        final theme = FliinTokens.read(
          resolveTokens(TokenDocument.fromJson(applyJsonPatch(tokens, patch))),
        );
        return {
          'kind': 'solved',
          'patch': [for (final op in patch) patchOpJson(op)],
          'contrast': [for (final check in contrast) _check(check)],
          'clashes': [
            for (final clash in clashes)
              {
                'mode': clash.appearance.name,
                'role': clash.role,
                'other': clash.other,
              },
          ],
          'roles': {'light': _hex(theme.light), 'dark': _hex(theme.dark)},
          'radius': theme.radius['control'],
          'button': theme.button.name,
        };
      case Unsatisfiable(:final failing, :final sameHue, :final nearestHue):
        return {
          'kind': 'unsatisfiable',
          'failing': _check(failing),
          'sameHue': sameHue?.primary.hex,
          'nearestHue': switch (nearestHue) {
            (:final hue, :final primary) => {
              'hue': hue,
              'primary': primary.hex,
            },
            null => null,
          },
        };
    }
  } on TokenError catch (e) {
    return {'kind': 'invalid', 'message': '$e'};
  } on JsonPatchError catch (e) {
    return {'kind': 'invalid', 'message': '$e'};
  }
}

ThemeRequest _request(Object? json) {
  if (json is! Map<String, Object?>) {
    throw const FormatException('a JSON object expected');
  }
  final primary = switch (json['primary']) {
    null => null,
    final String text => switch (Rgb8.tryParse(text)) {
      final color? => toOklch(color),
      null => throw FormatException('primary: #RRGGBB expected', text),
    },
    final other => throw FormatException('primary: #RRGGBB expected', '$other'),
  };
  T? named<T extends Enum>(String key, List<T> values) => switch (json[key]) {
    null => null,
    final String name when values.any((v) => v.name == name) => values.byName(
      name,
    ),
    final other => throw FormatException(
      '$key: ${values.map((v) => v.name).join(', ')} expected',
      '$other',
    ),
  };
  final radius = switch (json['radius']) {
    null => null,
    final num value when value >= 0 && value <= 9999 => value.toDouble(),
    final other => throw FormatException(
      'radius: a number from 0 to 9999 expected',
      '$other',
    ),
  };
  return ThemeRequest(
    primary: primary,
    neutral: named('neutral', NeutralTone.values),
    button: named('button', ButtonShape.values),
    radius: radius,
  );
}

/// The ratio truncated to the hundredth, as `fliin theme` shows it: the last
/// digit of a `pow` may differ between the VM and JavaScript, not that one.
Map<String, Object?> _check(ContrastCheck check) => {
  ...contrastCheckJson(check),
  'ratio': (check.ratio * 100).floor() / 100,
};

/// Opaque roles only: a `#RRGGBB` would turn a translucent role (the scrim,
/// a soft background) into a flat fill, so the catalog keeps its own.
Map<String, String> _hex(Map<String, int> roles) => {
  for (final MapEntry(key: role, value: argb) in roles.entries)
    if (argb >>> 24 == 0xFF) role: Rgb8(argb).hex,
};

/// The preset [ask] requests, applied to the shipped tokens [tokens]
/// (the file [source]) as `fliin theme --preset` applies it in a fresh
/// app: `kind` `preset`, then `code`, `fields` (the indices of
/// [Preset.indices]), `describe`, `tokens` (the resulting text of
/// `fliin.tokens.json`, the one the CLI writes), `fonts` and `pubspec` (what
/// the CLI prints for a named font), `contrast` (`count`, `failed`),
/// `clashes`, and `theme`, the tokens a catalog view applies without being
/// recreated.
///
/// A refusal is `kind` `invalid` with `error`, a code the page translates
/// (no interface text here): `request` (a malformed request), `refused`
/// (the decoder refuses; `message` is its text, the one
/// `fliin theme --preset` writes), `contrast` (no compliant theme;
/// `nearest`, the closest compliant brand when the solver finds one),
/// `tokens` (`message`, the refused token file).
Map<String, Object?> _presetAnswer(
  String source,
  Object? tokens,
  Map<String, Object?> ask,
) {
  final Preset preset;
  try {
    preset = switch (ask) {
      {'preset': final String code} => Preset.decode(presetCodeIn(code)),
      {'fields': final Map<String, Object?> fields} => Preset.fromIndices(
        _indices(fields),
      ),
      {'shuffle': final int seed} => _shuffled(
        tokens,
        seed,
        _indices(switch (ask['keep']) {
          final Map<String, Object?> keep => keep,
          _ => const {},
        }),
      ),
      _ => throw const FormatException('preset, fields or shuffle'),
    };
  } on FormatException {
    return const {'kind': 'invalid', 'error': 'request'};
  } on PresetError catch (e) {
    return {'kind': 'invalid', 'error': 'refused', 'message': e.message};
  }
  try {
    switch (applyPreset(tokens, tokens, preset)) {
      case ThemeSolved(:final patch, :final contrast, :final clashes):
        final result = applyJsonPatch(tokens, patch);
        final theme = FliinTokens.read(
          resolveTokens(TokenDocument.fromJson(result)),
        );
        return {
          'kind': 'preset',
          'code': preset.encode(),
          'fields': preset.indices,
          'describe': preset.describe,
          'tokens': presetTokensText(source, result, [
            for (final op in patch) op.path,
          ]),
          'fonts': [
            for (final family in {?preset.body, ?preset.heading})
              {'family': family.family, 'url': family.url},
          ],
          'pubspec': presetPubspecBlock(preset),
          'contrast': {
            'count': contrast.length,
            'failed': contrast.where((c) => !c.ok && !c.excused).length,
            'excused': contrast.where((c) => c.excused).length,
          },
          'clashes': clashes.length,
          'theme': {
            ..._catalogTheme(theme),
            'text': preset.text.scale,
            'motion': preset.motion.scale,
            'files': {
              for (final family in {?preset.body, ?preset.heading})
                family.family: previewFontFile(family),
            },
          },
        };
      case Unsatisfiable(:final sameHue, :final nearestHue):
        return {
          'kind': 'invalid',
          'error': 'contrast',
          'code': preset.encode(),
          'nearest': nearestHue?.primary.hex ?? sameHue?.primary.hex,
        };
    }
  } on PresetError catch (e) {
    return {'kind': 'invalid', 'error': 'refused', 'message': e.message};
  } on TokenError catch (e) {
    return {'kind': 'invalid', 'error': 'tokens', 'message': '$e'};
  } on JsonPatchError catch (e) {
    return {'kind': 'invalid', 'error': 'tokens', 'message': '$e'};
  }
}

/// The preset code in what is pasted: the bare code, a `--preset <code>`
/// option, a `fliin theme --preset <code>` command, a `?preset=<code>`
/// address. Without any of these, the text as is, which the decoder will
/// refuse with its message.
String presetCodeIn(String pasted) {
  final text = pasted.trim();
  final found = RegExp(
    r'(?:^|[\s=?&])(?:--preset[\s=]+|preset=)([a-z][0-9A-Za-z]+)',
  ).firstMatch(text);
  return found?.group(1) ?? text;
}

Map<String, int> _indices(Map<String, Object?> fields) => {
  for (final MapEntry(:key, :value) in fields.entries)
    key: switch (value) {
      final int index => index,
      _ => throw const FormatException('integer index'),
    },
};

/// [Preset.shuffle] drawn from the seed [seed], each field of [keep] (the
/// page's locks) kept at its index. The icon set is always kept: switching
/// sets reloads the catalog (one build per set, ADR 0016 §3.8), and it
/// touches no color. A draw whose colors fail contrast with the kept fields
/// (a locked free brand) is drawn again, at most 24 times; the last one goes
/// on to be refused.
Preset _shuffled(Object? tokens, int seed, Map<String, int> keep) {
  final random = math.Random(seed);
  late Preset drawn;
  for (var attempt = 0; attempt < 24; attempt++) {
    drawn = Preset.fromIndices({
      ...Preset.shuffle(random).indices,
      'icons': 0,
      ...keep,
    });
    if (_conforms(tokens, drawn)) return drawn;
  }
  return drawn;
}

/// True when [preset] applied to [tokens] resolves with no pair below its
/// threshold outside the declared exceptions: the page would not apply any
/// other draw.
bool _conforms(Object? tokens, Preset preset) {
  try {
    return switch (applyPreset(tokens, tokens, preset)) {
      ThemeSolved(:final contrast) => contrast.every((c) => c.ok || c.excused),
      Unsatisfiable() => false,
    };
  } on TokenError {
    return false;
  }
}

/// What a catalog view reads to recolor and remeasure itself: each role as
/// `#AARRGGBB`, light and dark; the eleven radii and the button shape; the
/// `space` steps and the `size` margins that spacing sets; the shadows; the
/// body and heading families (null: the platform's, or the body's for
/// headings). [_presetAnswer] adds `files`, the file of each named family in
/// the preview.
Map<String, Object?> _catalogTheme(FliinTokens theme) => {
  'roles': {'light': _argb(theme.light), 'dark': _argb(theme.dark)},
  'radius': theme.radius,
  'button': theme.button.name,
  'space': theme.space,
  'size': {
    for (final name in [...presetSpacingSizes, 'border', 'surfaceBorder'])
      name: ?theme.size[name],
  },
  'shadow': {
    for (final MapEntry(key: appearance, value: shadows)
        in theme.shadows.entries)
      appearance: {
        for (final MapEntry(key: name, value: layers) in shadows.entries)
          name: [
            for (final layer in layers)
              {
                'color': _hex8(layer.color),
                'x': layer.offsetX,
                'y': layer.offsetY,
                'blur': layer.blur,
                'spread': layer.spread,
                'inset': layer.inset,
              },
          ],
      },
  },
  'family': theme.fontFamily,
  'heading': theme.headingFamily,
};

/// The name of [family]'s files in `flutter/catalog/fonts/preview/`
/// (`tool/preview_fonts.sh`): its rank in [PresetFamily] from 1, on two
/// digits. A subset version does not carry the reserved name of a family
/// under the OFL.
String previewFontFile(PresetFamily family) =>
    '${family.index + 1}'.padLeft(2, '0');

Map<String, String> _argb(Map<String, int> roles) => {
  for (final MapEntry(key: role, value: argb) in roles.entries)
    role: _hex8(argb),
};

String _hex8(int argb) =>
    '#${argb.toRadixString(16).toUpperCase().padLeft(8, '0')}';

/// `fliin.tokens.json` as `fliin theme --preset` writes it
/// (`tokensJsonText`, `JsonEncoder.withIndent` on the VM), computed in
/// JavaScript as well. The text of a number depends on its type on the VM,
/// which JavaScript does not know (`1.0` and `1` are the same number there):
/// a number outside the patch's [written] paths keeps its text from
/// [source]; a color component the solver writes is a `double`
/// (`toStringAsFixed`), hence `0.0`; the other written numbers, rounded
/// dimensions and flat shadows, are integers when they come out whole.
String presetTokensText(String source, Object? result, List<String> written) {
  final lexemes = _numberLexemes(source);
  bool isWritten(String path) =>
      written.any((prefix) => path == prefix || path.startsWith('$prefix/'));
  final out = StringBuffer();
  void write(Object? value, String path, String indent) {
    switch (value) {
      case final Map<String, Object?> map when map.isEmpty:
        out.write('{}');
      case final Map<String, Object?> map:
        out.write('{\n');
        var first = true;
        for (final MapEntry(:key, value: child) in map.entries) {
          if (!first) out.write(',\n');
          first = false;
          out.write('$indent  ${jsonEncode(key)}: ');
          write(child, '$path/${_escapePointer(key)}', '$indent  ');
        }
        out.write('\n$indent}');
      case final List<Object?> list when list.isEmpty:
        out.write('[]');
      case final List<Object?> list:
        out.write('[\n');
        for (var i = 0; i < list.length; i++) {
          if (i > 0) out.write(',\n');
          out.write('$indent  ');
          write(list[i], '$path/$i', '$indent  ');
        }
        out.write('\n$indent]');
      case final num number:
        final kept = isWritten(path) ? null : lexemes[path];
        if (kept != null) {
          out.write(kept);
        } else if (_componentPath.hasMatch(path)) {
          out.write(_doubleText(number));
        } else {
          out.write(
            number == number.truncateToDouble() && number.abs() < 1e21
                ? '${number.toInt()}'
                : _doubleText(number),
          );
        }
      default:
        out.write(jsonEncode(value));
    }
  }

  write(TokenDocument.fromJson(result).toJson(), '', '');
  out.write('\n');
  return '$out';
}

final _componentPath = RegExp(r'/\$value/components/\d+$');

/// The text a `double` has on the VM: `0.0` for zero.
String _doubleText(num value) {
  if (value == value.truncateToDouble() && value.abs() < 1e21) {
    return '${value.toInt()}.0';
  }
  return '$value';
}

String _escapePointer(String key) =>
    key.replaceAll('~', '~0').replaceAll('/', '~1');

/// The text of each number in [source], a JSON document, by JSON pointer:
/// `1.0` and `1` are told apart here, not after `jsonDecode` in JavaScript.
Map<String, String> _numberLexemes(String source) {
  final lexemes = <String, String>{};
  var at = 0;
  void space() {
    while (at < source.length && ' \t\n\r'.contains(source[at])) {
      at++;
    }
  }

  String string() {
    final start = at;
    at++;
    while (source[at] != '"') {
      at += source[at] == r'\' ? 2 : 1;
    }
    at++;
    return jsonDecode(source.substring(start, at)) as String;
  }

  void value(String path) {
    space();
    switch (source[at]) {
      case '{':
        at++;
        space();
        if (source[at] == '}') {
          at++;
          return;
        }
        while (true) {
          space();
          final key = string();
          space();
          at++;
          value('$path/${_escapePointer(key)}');
          space();
          if (source[at++] == '}') return;
        }
      case '[':
        at++;
        space();
        if (source[at] == ']') {
          at++;
          return;
        }
        for (var i = 0; ; i++) {
          value('$path/$i');
          space();
          if (source[at++] == ']') return;
        }
      case '"':
        string();
      default:
        final start = at;
        while (at < source.length && !',}] \t\n\r'.contains(source[at])) {
          at++;
        }
        final text = source.substring(start, at);
        if (text != 'true' && text != 'false' && text != 'null') {
          lexemes[path] = text;
        }
    }
  }

  value('');
  return lexemes;
}
