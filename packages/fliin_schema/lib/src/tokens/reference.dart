import 'token_error.dart';

/// Une référence telle qu'écrite dans le fichier : alias `{a.b}` (Format
/// §7.1.1) ou pointeur JSON `#/a/b/$value` (§7.1.2, RFC 6901).
sealed class Reference {
  const Reference(this.text);

  /// Le texte d'origine, rendu tel quel par la sérialisation.
  final String text;

  /// Lève [MalformedTokenReference] si [text] n'est ni l'un ni l'autre.
  static Reference parse(String text, String at) => text.startsWith('{')
      ? CurlyAlias.parse(text, at)
      : JsonPointer.parse(text, at);
}

/// `{group.token}` : la valeur entière d'un jeton.
final class CurlyAlias extends Reference {
  const CurlyAlias._(super.text, this.segments);

  static CurlyAlias parse(String text, String at) {
    final inner = _shape.firstMatch(text)?[1];
    if (inner == null) {
      throw MalformedTokenReference(
        at,
        text,
        'expected an alias {group.token}',
      );
    }
    return CurlyAlias._(text, inner.split('.'));
  }

  final List<String> segments;

  static final _shape = RegExp(r'^\{([^{}]+)\}$');
}

/// `#/group/token/$value/components/0` : n'importe quel emplacement du
/// document. Les segments sont désencodés (`~1` → `/`, `~0` → `~`).
final class JsonPointer extends Reference {
  const JsonPointer._(super.text, this.segments);

  static JsonPointer parse(String text, String at) {
    if (!text.startsWith('#/')) {
      throw MalformedTokenReference(at, text, 'expected a JSON pointer #/…');
    }
    final segments = text.substring(2).split('/');
    for (final segment in segments) {
      if (segment.isEmpty) {
        throw MalformedTokenReference(at, text, 'empty segment in the pointer');
      }
      if (segment.contains('{') || segment.contains('}')) {
        throw MalformedTokenReference(
          at,
          text,
          'a pointer cannot contain an alias {…}',
        );
      }
    }
    return JsonPointer._(text, [
      for (final segment in segments)
        segment.replaceAll('~1', '/').replaceAll('~0', '~'),
    ]);
  }

  final List<String> segments;
}
