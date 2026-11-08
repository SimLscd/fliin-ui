import 'dart:convert';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;

import '../install/registry_port.dart';
import '../project/fliin_yaml.dart';
import '../registry/public_api.dart';
import '../search/search_index.dart';
import 'project_command.dart';

class SearchCommand extends ProjectCommand {
  SearchCommand(super.openRegistry, super.io) {
    argParser
      ..addOption('kind', allowed: ['component', 'block', 'screen'])
      ..addOption('limit', defaultsTo: '5', help: 'From 1 to 10.')
      ..addOption('cursor', help: 'The nextCursor of the previous page.')
      ..addOption(
        'registry',
        help: 'An https:// or file:// URL to use instead of the registries in fliin.yaml.',
      )
      ..addMultiOption(
        'key',
        help:
            'An extra trusted public key, in base64. At least one with '
            '--registry.',
      );
  }

  @override
  String get name => 'search';

  @override
  String get description =>
      'Searches for an item by intent in the registries of fliin.yaml, or '
      'in the official registry.';

  @override
  String get invocation => 'fliin search "<intent>"';

  @override
  Future<int> execute() async {
    final args = argResults!;
    final limit = int.tryParse(args.option('limit')!);
    if (args.rest.isEmpty || limit == null) {
      usageException('Expected an intent and an integer --limit.');
    }
    final query = SearchQuery(
      args.rest.join(' '),
      kind: switch (args.option('kind')) {
        null => null,
        final kind => ItemType.values.byName(kind),
      },
      limit: limit,
      cursor: args.option('cursor'),
    );

    final entries = <IndexEntry>[];
    final registries = <Namespace, Registry>{};
    for (final source in _sources(
      args.option('registry'),
      args.multiOption('key'),
    )) {
      final registry = await openRegistry(source);
      for (final entry in await fetchEntries(registry)) {
        entries.add(entry);
        registries[entry.ref.namespace] = registry;
      }
    }

    final SearchPage page;
    try {
      page = SearchIndex.build(entries).search(query);
    } on InvalidInput catch (e) {
      if (jsonOutput) {
        io.out.writeln(jsonEncode(e.toJson()));
      } else {
        io.err.writeln(
          [
            e.message,
            for (final suggestion in e.suggestions) '  try: $suggestion',
          ].join('\n'),
        );
      }
      return 64;
    }
    if (!jsonOutput) return succeed(page.toJson(), [_human(page)]);
    return succeed({
      'results': await Future.wait([
        for (final result in page.results)
          _withApi(registries[result.id.namespace]!, result),
      ]),
      'nextCursor': page.nextCursor,
    }, const []);
  }

  /// Le résultat tel que le MCP le rend, sans ce qui demande `fliin mcp` :
  /// pas de serveur local, donc pas de `previewUrl`. Un élément Pro que le
  /// registre ne sert pas (sans clé de licence) n'a ni droit ni API. Un
  /// manifeste ou un fichier que le registre ne sert pas laisse le résultat
  /// sans `apiSummary`, avec la raison dans `unavailable`.
  static Future<Map<String, Object?>> _withApi(
    Registry registry,
    SearchResult result,
  ) async {
    final entitled = result.tier != Tier.pro || registry.servesPro;
    String? apiSummary;
    String? unavailable;
    try {
      if (entitled) {
        apiSummary = summarizeApi(
          await publishedApi(
            registry,
            await registry.fetchManifest(result.id, result.version),
          ),
          rest: 'see the files that fliin add ${result.id} installs',
        );
      }
    } on RegistryFailure catch (e) {
      unavailable = e.message;
    }
    return {
      ...result.toJson(),
      'entitled': entitled,
      'apiSummary': apiSummary,
      'previewUrl': null,
      'unavailable': ?unavailable,
    };
  }

  /// Les registres à interroger, `null` pour le registre officiel.
  /// `--registry` exige au moins une `--key` (sortie 64 sinon) et ne fait
  /// confiance qu'à elles ; un registre de `fliin.yaml` fait confiance à ses
  /// `trustedKeys`, plus `--key`. Les clés officielles s'ajoutent dans les
  /// deux cas, à l'ouverture du registre. Sans `fliin.yaml`, ou sans registre
  /// `@fliin` déclaré, le registre officiel tient sa place (ADR 0020 §5).
  List<RegistrySource?> _sources(String? url, List<String> keys) {
    if (url != null) return [_source(url, keys)];
    final config = readFliinConfig(projectDir);
    if (config == null) return const [null];
    return [
      if (!config.registries.containsKey(Namespace.fliin)) null,
      for (final source in config.registries.values)
        if (keys.isEmpty)
          source
        else
          _source('${source.url}', [...source.trustedKeys, ...keys]),
    ];
  }

  RegistrySource _source(String url, List<String> keys) {
    if (keys.isEmpty) usageException('--registry requires at least one --key.');
    try {
      return RegistrySource.fromJson({'url': url, 'trustedKeys': keys});
    } on ManifestError catch (e) {
      usageException('$e');
    }
  }

  static String _human(SearchPage page) => [
    if (page.results.isEmpty) 'No item matches.',
    for (final result in page.results) ...[
      '${result.id} ${result.version}',
      for (final why in result.why) '  $why',
      if (result.requires.isNotEmpty)
        '  requires: ${result.requires.join(', ')}',
      '  ${result.install}',
    ],
    if (page.nextCursor case final cursor?) 'More: --cursor $cursor',
  ].join('\n');
}
