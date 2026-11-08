import 'config.dart';

/// Une réécriture du brut à l'installation (DESIGN.md §4.1). Les gabarits
/// prennent `{package}`, `{importRoot}` et `{prefix}` dans la [RenderConfig].
sealed class RewriteRule {
  const RewriteRule();

  String apply(String source, RenderConfig config);

  /// La forme du bloc `install` de `get_item` (DESIGN.md §5.5).
  Map<String, Object?> toJson();
}

final class ImportRewrite extends RewriteRule {
  const ImportRewrite({required this.from, required this.to});

  final String from;
  final String to;

  @override
  String apply(String source, RenderConfig config) =>
      source.replaceAll(from, _expand(to, config));

  @override
  Map<String, Object?> toJson() => {'kind': 'import', 'from': from, 'to': to};
}

final class PrefixRewrite extends RewriteRule {
  const PrefixRewrite({required this.pattern, required this.replacement});

  final String pattern;
  final String replacement;

  @override
  String apply(String source, RenderConfig config) =>
      source.replaceAll(RegExp(pattern), _expand(replacement, config));

  @override
  Map<String, Object?> toJson() => {
    'kind': 'prefix',
    'pattern': pattern,
    'replacement': replacement,
  };
}

/// `{importRoot}` et non `{root}` : un URI `package:` part de `lib/`.
const rewriteRules = <RewriteRule>[
  ImportRewrite(
    from: 'package:fliin_ui/',
    to: 'package:{package}/{importRoot}/',
  ),
  PrefixRewrite(pattern: r'\bFl(?=[A-Z])', replacement: '{prefix}'),
];

String applyRewrites(String source, RenderConfig config) =>
    rewriteRules.fold(source, (text, rule) => rule.apply(text, config));

String _expand(String template, RenderConfig config) => template
    .replaceAll('{package}', config.package)
    .replaceAll('{importRoot}', config.importRoot)
    .replaceAll('{prefix}', config.prefix);
