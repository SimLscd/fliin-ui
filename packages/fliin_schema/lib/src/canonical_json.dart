import 'dart:convert';

/// JSON canonique : clés triées par unités UTF-16, aucun espace, nombres sans
/// exposant. La signature du pointeur et l'empreinte des manifestes portent sur
/// cette forme.
String canonicalJson(Object? value) {
  final out = StringBuffer();
  _write(out, value);
  return out.toString();
}

void _write(StringBuffer out, Object? value) {
  switch (value) {
    case null || bool() || String():
      out.write(jsonEncode(value));
    case int():
      out.write(value);
    case double():
      out.write(_decimal(value));
    case List<Object?>():
      out.write('[');
      for (final (i, item) in value.indexed) {
        if (i > 0) out.write(',');
        _write(out, item);
      }
      out.write(']');
    case Map<Object?, Object?>():
      final keys = [
        for (final key in value.keys)
          key is String
              ? key
              : throw ArgumentError.value(key, 'key', 'key is not a string'),
      ]..sort();
      out.write('{');
      for (final (i, key) in keys.indexed) {
        if (i > 0) out.write(',');
        out
          ..write(jsonEncode(key))
          ..write(':');
        _write(out, value[key]);
      }
      out.write('}');
    default:
      throw ArgumentError.value(
        value,
        'value',
        'cannot be represented in JSON',
      );
  }
}

String _decimal(double value) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'number is not finite');
  }
  if (value == 0) return '0';
  final text = value.abs().toString();
  final e = text.indexOf('e');
  final mantissa = e < 0 ? text : text.substring(0, e);
  final exponent = e < 0 ? 0 : int.parse(text.substring(e + 1));
  final dot = mantissa.indexOf('.');
  final digits = mantissa.replaceFirst('.', '');
  final point = (dot < 0 ? mantissa.length : dot) + exponent;
  final whole = point <= 0
      ? '0'
      : digits.padRight(point, '0').substring(0, point);
  final fraction = point < 0
      ? '${'0' * -point}$digits'
      : point >= digits.length
      ? ''
      : digits.substring(point);
  final trimmed = fraction.replaceFirst(_trailingZeros, '');
  final sign = value < 0 ? '-' : '';
  return '$sign${whole.replaceFirst(_leadingZeros, '')}'
      '${trimmed.isEmpty ? '' : '.$trimmed'}';
}

final _trailingZeros = RegExp(r'0+$');
final _leadingZeros = RegExp(r'^0+(?=\d)');
