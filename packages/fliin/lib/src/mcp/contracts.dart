import 'package:fliin_schema/fliin_schema.dart';
import 'package:pub_semver/pub_semver.dart';

import '../search/analyzer.dart';
import '../search/search_index.dart';
import '../verify/entry_example.dart';
import 'ports.dart';

/// Les contrats des trois outils MCP (DESIGN.md §5.3) : les arguments sont
/// parsés une fois à la frontière en types, les sorties rendent leur JSON, et
/// chaque côté porte son schéma draft-07, écrit à la main et testé.
enum ToolErrorCode {
  invalidInput('INVALID_INPUT'),
  notFound('NOT_FOUND'),
  entitlementRequired('ENTITLEMENT_REQUIRED'),
  quotaExceeded('QUOTA_EXCEEDED', retryable: true),
  registryUnavailable('REGISTRY_UNAVAILABLE', retryable: true);

  const ToolErrorCode(this.wire, {this.retryable = false});

  final String wire;

  /// Le même appel peut réussir plus tard sans que l'agent change rien.
  final bool retryable;
}

/// La commande qui lève l'erreur (`fix` de DESIGN.md §5.2).
final class CommandFix {
  const CommandFix(this.command);

  final String command;

  Map<String, Object?> toJson() => {'kind': 'command', 'command': command};
}

/// Une erreur métier, rendue `isError: true` avec le JSON de DESIGN.md §5.2.
/// Les outils ne lèvent rien d'autre.
final class ToolError implements Exception {
  const ToolError(
    this.code,
    this.message, {
    this.details = const {},
    this.retryAfter,
    this.fix,
  });

  /// Un argument hors contrat, situé par son chemin : `$.limit`.
  ToolError.invalidArgument(String path, String reason)
    : this(
        ToolErrorCode.invalidInput,
        'invalid argument: $path: $reason',
        details: {'path': path, 'reason': reason},
      );

  final ToolErrorCode code;
  final String message;
  final Map<String, Object?> details;
  final Duration? retryAfter;
  final CommandFix? fix;

  Map<String, Object?> toJson() => {
    'code': code.wire,
    'message': message,
    'retryable': code.retryable,
    'retryAfterSec': retryAfter?.inSeconds,
    'fix': fix?.toJson(),
    'details': details,
  };

  @override
  String toString() => '${code.wire}: $message';
}

/// Les types qu'une recherche peut filtrer : les autres (core, primitive,
/// theme, icon, lib, file) ne sont pas des réponses à une intention.
const _searchableKinds = [ItemType.component, ItemType.block, ItemType.screen];

final class SearchItemsInput {
  const SearchItemsInput({
    required this.intent,
    this.kind,
    this.platforms = const [],
    this.states = const [],
    this.tier,
    this.lang,
    this.limit = 5,
    this.cursor,
  });

  /// Lève une [ToolError] `INVALID_INPUT` pour tout argument hors contrat.
  factory SearchItemsInput.fromJson(Map<String, Object?> json) {
    final args = _Args(json);
    return SearchItemsInput(
      intent: args.string('intent'),
      kind: args.enumValue('kind', _searchableKinds),
      platforms: args.enumValues('platforms', Platform.values),
      states: args.strings('states'),
      tier: args.enumValue('tier', Tier.values),
      lang: args.enumValue('lang', Lang.values),
      limit: args.integer('limit') ?? 5,
      cursor: args.optionalString('cursor'),
    );
  }

  final String intent;
  final ItemType? kind;
  final List<Platform> platforms;
  final List<String> states;
  final Tier? tier;
  final Lang? lang;
  final int limit;
  final String? cursor;

  SearchQuery get query => SearchQuery(
    intent,
    kind: kind,
    platforms: platforms,
    states: states,
    tier: tier,
    lang: lang,
    limit: limit,
    cursor: cursor,
  );

  static const inputSchema = <String, Object?>{
    r'$schema': _draft7,
    'type': 'object',
    'properties': {
      'intent': {
        'type': 'string',
        'minLength': 1,
        'description':
            'The need, in three words or more, in English or French: '
            '"primary action button", "bouton d\'action principal".',
      },
      'kind': {
        'type': 'string',
        'enum': ['component', 'block', 'screen'],
      },
      'platforms': {
        'type': 'array',
        'items': {
          'type': 'string',
          'enum': ['ios', 'android', 'web', 'macos', 'windows', 'linux'],
        },
        'uniqueItems': true,
        'description': 'The item must cover all of them.',
      },
      'states': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Required states, for example ["empty", "offline"].',
      },
      'tier': {
        'type': 'string',
        'enum': ['free', 'pro'],
      },
      'lang': {
        'type': 'string',
        'enum': ['fr', 'en'],
        'description': 'Without a language, intents in both languages count.',
      },
      'limit': {'type': 'integer', 'minimum': 1, 'maximum': 10, 'default': 5},
      'cursor': {
        'type': 'string',
        'description': 'The nextCursor of the previous page.',
      },
    },
    'required': ['intent'],
    'additionalProperties': false,
  };

  static const outputSchema = <String, Object?>{
    r'$schema': _draft7,
    'type': 'object',
    'properties': {
      'results': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'version': {'type': 'string'},
            'tier': {
              'type': 'string',
              'enum': ['free', 'pro'],
            },
            'entitled': {'type': 'boolean'},
            'score': {'type': 'number'},
            'why': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'The fields that matched.',
            },
            'apiSummary': {
              'type': ['string', 'null'],
              'description':
                  'The public signatures, one per line, at most 40 lines. '
                  'null for a Pro item without a license (entitled: false).',
            },
            'requires': {
              'type': 'array',
              'items': {'type': 'string'},
              'description':
                  'The closure of registry dependencies, with versions, to '
                  'compare with fliin.lock.json.',
            },
            'previewUrl': {
              'type': ['string', 'null'],
              'description':
                  'The published reference golden (iOS, light, text 1.0×, '
                  'left to right), served by fliin mcp on 127.0.0.1 while it '
                  'runs. null without a golden.',
            },
            'install': {'type': 'string', 'description': 'The command to run.'},
            'unavailable': {
              'type': 'string',
              'description':
                  'Why apiSummary and previewUrl are missing: the registry '
                  'does not serve the manifest or a file.',
            },
          },
          'required': [
            'id',
            'version',
            'tier',
            'entitled',
            'score',
            'why',
            'apiSummary',
            'requires',
            'previewUrl',
            'install',
          ],
          'additionalProperties': false,
        },
      },
      'nextCursor': {
        'type': ['string', 'null'],
      },
    },
    'required': ['results', 'nextCursor'],
    'additionalProperties': false,
  };
}

/// Un résultat de [SearchIndex], complété de ce que la recherche ne sait
/// pas : le droit (port [EntitlementResolver]), les signatures publiques et
/// l'aperçu, lus dans le manifeste de la version trouvée. Quand le registre
/// ne sert pas ce manifeste ou ses fichiers, le résultat reste, sans eux, et
/// [unavailable] dit pourquoi.
final class SearchItem {
  const SearchItem({
    required this.result,
    required this.entitled,
    required this.apiSummary,
    required this.previewUrl,
    this.unavailable,
  });

  final SearchResult result;
  final bool entitled;

  /// Au plus `maxApiSummaryLines` lignes.
  final String? apiSummary;

  /// Nul quand la version ne publie pas de golden de référence.
  final Uri? previewUrl;
  final String? unavailable;

  Map<String, Object?> toJson() => {
    ...result.toJson(),
    'entitled': entitled,
    'apiSummary': apiSummary,
    'previewUrl': previewUrl?.toString(),
    'unavailable': ?unavailable,
  };
}

final class SearchItemsOutput {
  const SearchItemsOutput(this.results, this.nextCursor);

  final List<SearchItem> results;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'results': [for (final result in results) result.toJson()],
    'nextCursor': nextCursor,
  };
}

enum IncludeSection { source, api, examples, docs, install, verifyHarness }

final class GetItemInput {
  const GetItemInput({
    required this.id,
    this.version,
    this.include = const {},
    this.cursor,
  });

  /// Lève une [ToolError] `INVALID_INPUT` pour tout argument hors contrat.
  factory GetItemInput.fromJson(Map<String, Object?> json) {
    final args = _Args(json);
    return GetItemInput(
      id:
          args.parsed('id', ItemRef.parseUnversioned) ??
          (throw ToolError.invalidArgument(r'$.id', 'missing field')),
      version: args.parsed('version', Version.parse),
      include: args.enumValues('include', IncludeSection.values).toSet(),
      cursor: args.optionalString('cursor'),
    );
  }

  final ItemRef id;

  /// Sans version, la plus haute publiée.
  final Version? version;
  final Set<IncludeSection> include;

  /// Reprend `source` là où la page précédente s'est arrêtée.
  final String? cursor;

  static const inputSchema = <String, Object?>{
    r'$schema': _draft7,
    'type': 'object',
    'properties': {
      'id': {
        'type': 'string',
        'pattern': _idPattern,
        'description': '`button` or `@acme/button`, without a version.',
      },
      'version': {
        'type': 'string',
        'description':
            'An exact version. Without it, the highest published one.',
      },
      'include': {
        'type': 'array',
        'items': {
          'type': 'string',
          'enum': [
            'source',
            'api',
            'examples',
            'docs',
            'install',
            'verifyHarness',
          ],
        },
        'uniqueItems': true,
        'default': <String>[],
      },
      'cursor': {
        'type': 'string',
        'description': 'The nextCursor of the previous page of `source`.',
      },
    },
    'required': ['id'],
    'additionalProperties': false,
  };

  static const outputSchema = <String, Object?>{
    r'$schema': _draft7,
    'type': 'object',
    'properties': {
      'item': {
        'type': 'object',
        'description': 'The manifest, in the registry format.',
      },
      'source': {
        'type': 'array',
        'items': _rawFileSchema,
        'description': 'The raw files, not adapted, paginated by nextCursor.',
      },
      'api': {
        'type': 'string',
        'description': 'The public signatures of the Dart files, one per line.',
      },
      'examples': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'Formatted widget expressions that render the item, with the Fl '
            'prefix like `api`. Empty for a screen: its route and state '
            'snippets are in `item.snippets`.',
      },
      'docs': {
        'type': ['string', 'null'],
      },
      'install': {
        'type': 'object',
        'properties': {
          'files': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'rawPath': {'type': 'string'},
                'targetTemplate': {
                  'type': 'string',
                  'description': 'The path in the project, with {root}.',
                },
                'sha256': {'type': 'string'},
              },
              'required': ['rawPath', 'targetTemplate', 'sha256'],
              'additionalProperties': false,
            },
          },
          'rewriteRules': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'kind': {
                  'type': 'string',
                  'enum': ['import', 'prefix'],
                },
              },
              'required': ['kind'],
            },
            'description':
                'To apply in order, with {package}, {importRoot} and '
                '{prefix} from fliin.yaml.',
          },
          'closure': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                'The registry dependencies at their version, dependencies '
                'first. Skip the ones in fliin.lock.json.',
          },
          'pubDependencies': {
            'type': 'object',
            'additionalProperties': {'type': 'string'},
          },
          'l10n': {'type': 'object'},
          'snippets': {
            'type': 'object',
            'properties': {
              'route': {
                'type': 'object',
                'description':
                    'Per router, the <name>_route.dart file, next to the '
                    'page. It wires the page’s navigation.',
              },
              'state': {
                'type': 'object',
                'description':
                    'Per state management, the <name>_page.dart file. Their '
                    'package:fliin_ui/ imports are rewritten by '
                    'rewriteRules, like the files.',
              },
              'screens': {
                'type': 'array',
                'items': {'type': 'string'},
                'description':
                    'The screens the snippets lead to, to install and wire '
                    'too.',
              },
            },
            'required': ['route', 'state', 'screens'],
          },
          'lockEntry': {
            'type': 'object',
            'properties': {
              'ref': {'type': 'string'},
              'item': {
                'type': 'object',
                'description':
                    'To merge into fliin.lock.json under ref, with raw set '
                    'and pending: true.',
              },
            },
            'required': ['ref', 'item'],
            'additionalProperties': false,
          },
        },
        'required': [
          'files',
          'rewriteRules',
          'closure',
          'pubDependencies',
          'l10n',
          'snippets',
          'lockEntry',
        ],
        'additionalProperties': false,
      },
      'verifyHarness': {
        'type': 'object',
        'properties': {
          'harness': _projectFileSchema,
          'test': {
            'oneOf': [
              _projectFileSchema,
              {'type': 'null'},
            ],
          },
        },
        'required': ['harness', 'test'],
        'additionalProperties': false,
      },
      'nextCursor': {
        'type': ['string', 'null'],
      },
    },
    'required': ['item', 'nextCursor'],
    'additionalProperties': false,
  };
}

/// Un fichier publié, lu tel quel dans le registre.
final class RawFile {
  const RawFile({
    required this.path,
    required this.sha256,
    required this.content,
  });

  final String path;
  final Sha256 sha256;
  final String content;

  Map<String, Object?> toJson() => {
    'path': path,
    'sha256': sha256.value,
    'content': content,
  };
}

/// Un fichier à écrire dans le projet : le chemin porte `{root}`,
/// `{package}` ou `{importRoot}` que l'agent lit dans `fliin.yaml`.
typedef ProjectFile = ({String path, String content});

Map<String, Object?> _projectFileJson(ProjectFile file) => {
  'path': file.path,
  'content': file.content,
};

/// Le bloc `install` de DESIGN.md §5.5, pour un agent sans terminal.
final class InstallBlock {
  const InstallBlock({
    required this.ref,
    required this.files,
    required this.closure,
    required this.manifest,
    required this.lockEntry,
  });

  /// Sans version, comme la clé du lockfile.
  final ItemRef ref;
  final List<({String rawPath, String targetTemplate, Sha256 sha256})> files;

  /// Dépendances d'abord, sans l'élément lui-même.
  final List<ItemRef> closure;
  final ItemManifest manifest;
  final LockedItem lockEntry;

  Map<String, Object?> toJson() => {
    'files': [
      for (final file in files)
        {
          'rawPath': file.rawPath,
          'targetTemplate': file.targetTemplate,
          'sha256': file.sha256.value,
        },
    ],
    'rewriteRules': [for (final rule in rewriteRules) rule.toJson()],
    'closure': [for (final ref in closure) '$ref'],
    'pubDependencies': {
      for (final MapEntry(:key, :value) in manifest.dependencies.entries)
        key: '$value',
    },
    'l10n': manifest.l10n,
    'snippets': {
      'route': manifest.snippets.route,
      'state': manifest.snippets.state,
      'screens': manifest.snippets.screens,
    },
    'lockEntry': {'ref': '$ref', 'item': lockEntry.toJson()},
  };
}

final class GetItemOutput {
  const GetItemOutput({
    required this.manifest,
    required this.include,
    this.source,
    this.api,
    this.install,
    this.harness,
    this.test,
    this.nextCursor,
  });

  final ItemManifest manifest;
  final Set<IncludeSection> include;
  final List<RawFile>? source;

  /// Toutes les signatures publiques, une par ligne.
  final String? api;
  final InstallBlock? install;
  final ProjectFile? harness;

  /// Le test généré, nul quand le manifeste n'a pas de `verify`.
  final ProjectFile? test;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'item': manifest.toJson(),
    if (source case final source?)
      'source': [for (final file in source) file.toJson()],
    'api': ?api,
    if (include.contains(IncludeSection.examples))
      'examples': [
        if (manifest.verify case final verify?
            when manifest.type != ItemType.screen)
          entryExpression(verify.entry),
      ],
    if (include.contains(IncludeSection.docs)) 'docs': manifest.docs,
    if (install case final install?) 'install': install.toJson(),
    if (harness case final harness?)
      'verifyHarness': {
        'harness': _projectFileJson(harness),
        'test': test == null ? null : _projectFileJson(test!),
      },
    'nextCursor': nextCursor,
  };
}

/// Les arguments de `request_selection` : ouvrir une sélection, ou relire
/// celle d'une poignée.
sealed class RequestSelectionInput {
  const RequestSelectionInput();

  /// Lève une [ToolError] `INVALID_INPUT` pour tout argument hors contrat.
  factory RequestSelectionInput.fromJson(Map<String, Object?> json) {
    final args = _Args(json);
    final handle = args.optionalString('selectionHandle');
    if (handle != null) {
      if (json.length > 1) {
        throw ToolError.invalidArgument(
          r'$.selectionHandle',
          'is used alone, to read a selection again',
        );
      }
      return ReadSelection(SelectionHandle(handle));
    }
    final candidates = args.parsedList('candidates', ItemRef.parseUnversioned);
    if (candidates.length < 2 || candidates.length > 6) {
      throw ToolError.invalidArgument(
        r'$.candidates',
        'expected 2 to 6 ids, got ${candidates.length}',
      );
    }
    if (candidates.toSet().length != candidates.length) {
      throw ToolError.invalidArgument(r'$.candidates', 'repeated id');
    }
    final question = args.string('question').trim();
    if (question.isEmpty || question.length > maxQuestionLength) {
      throw ToolError.invalidArgument(
        r'$.question',
        'expected 1 to $maxQuestionLength characters',
      );
    }
    final variant = args.object('variant');
    return OpenSelection(
      candidates: candidates,
      question: question,
      variant: variant == null
          ? const GoldenVariant()
          : GoldenVariant(
              platform:
                  variant.enumValue('platform', VariantPlatform.values) ??
                  VariantPlatform.ios,
              brightness:
                  variant.enumValue('brightness', VariantBrightness.values) ??
                  VariantBrightness.light,
              scale: switch (variant.json['scale']) {
                null || 1 => VariantScale.normal,
                2 => VariantScale.large,
                _ => throw ToolError.invalidArgument(
                  r'$.variant.scale',
                  'expected 1 or 2',
                ),
              },
              dir:
                  variant.enumValue('dir', VariantDirection.values) ??
                  VariantDirection.ltr,
            ),
    );
  }

  /// Ce que la page affiche en titre : une question, pas un document.
  static const maxQuestionLength = 500;

  static const inputSchema = <String, Object?>{
    r'$schema': _draft7,
    'type': 'object',
    'properties': {
      'candidates': {
        'type': 'array',
        'items': {'type': 'string', 'pattern': _idPattern},
        'minItems': 2,
        'maxItems': 6,
        'uniqueItems': true,
        'description': 'The ids returned by search_items, 2 to 6.',
      },
      'question': {
        'type': 'string',
        'minLength': 1,
        'maxLength': maxQuestionLength,
        'description': 'The question for the human, shown on the page.',
      },
      'variant': {
        'type': 'object',
        'properties': {
          'platform': {
            'type': 'string',
            'enum': ['ios', 'android'],
          },
          'brightness': {
            'type': 'string',
            'enum': ['light', 'dark'],
          },
          'scale': {
            'type': 'number',
            'enum': [1, 2],
          },
          'dir': {
            'type': 'string',
            'enum': ['ltr', 'rtl'],
          },
        },
        'additionalProperties': false,
        'description':
            'The variant of the images shown. Default: ios, light, 1, ltr.',
      },
      'selectionHandle': {
        'type': 'string',
        'minLength': 1,
        'description':
            'Alone, reads again the state of a selection opened by an earlier '
            'call.',
      },
    },
    'additionalProperties': false,
  };

  static const outputSchema = <String, Object?>{
    r'$schema': _draft7,
    'type': 'object',
    'properties': {
      'selectionHandle': {'type': 'string'},
      'status': {
        'type': 'string',
        'enum': ['pending', 'chosen', 'declined'],
      },
      'chosen': {
        'type': ['string', 'null'],
        'description': 'The chosen id, to pass to fliin add.',
      },
      'pickUrl': {
        'type': 'string',
        'description': 'The choice page, for the human to open.',
      },
    },
    'required': ['selectionHandle', 'status', 'chosen', 'pickUrl'],
    'additionalProperties': false,
  };
}

final class OpenSelection extends RequestSelectionInput {
  const OpenSelection({
    required this.candidates,
    required this.question,
    this.variant = const GoldenVariant(),
  });

  /// Sans version : chacun est montré à sa plus haute version publiée.
  final List<ItemRef> candidates;
  final String question;
  final GoldenVariant variant;
}

final class ReadSelection extends RequestSelectionInput {
  const ReadSelection(this.handle);

  final SelectionHandle handle;
}

/// L'état d'une sélection, tel que l'agent le relit.
final class SelectionOutput {
  const SelectionOutput(this.selection, this.pickUrl);

  final Selection selection;
  final Uri pickUrl;

  Map<String, Object?> toJson() => {
    'selectionHandle': selection.handle.value,
    'status': switch (selection.status) {
      Pending() => 'pending',
      Chosen() => 'chosen',
      Declined() => 'declined',
    },
    'chosen': switch (selection.status) {
      Chosen(:final item) => '$item',
      _ => null,
    },
    'pickUrl': '$pickUrl',
  };
}

const _draft7 = 'http://json-schema.org/draft-07/schema#';

const _idPattern = r'^(@[a-z0-9][a-z0-9-]*/)?[a-z][a-z0-9]*(-[a-z0-9]+)*$';

const _rawFileSchema = <String, Object?>{
  'type': 'object',
  'properties': {
    'path': {'type': 'string'},
    'sha256': {'type': 'string'},
    'content': {'type': 'string'},
  },
  'required': ['path', 'sha256', 'content'],
  'additionalProperties': false,
};

const _projectFileSchema = <String, Object?>{
  'type': 'object',
  'properties': {
    'path': {'type': 'string'},
    'content': {'type': 'string'},
  },
  'required': ['path', 'content'],
  'additionalProperties': false,
};

/// Les arguments d'un outil. Le SDK les a validés contre `inputSchema` ; ce
/// lecteur garantit qu'une forme inattendue reste une [ToolError] située.
final class _Args {
  const _Args(this.json, [this._at = r'$']);

  final Map<String, Object?> json;
  final String _at;

  String string(String key) =>
      optionalString(key) ??
      (throw ToolError.invalidArgument(_path(key), 'missing field'));

  String? optionalString(String key) => switch (json[key]) {
    null => null,
    final String value => value,
    _ => throw ToolError.invalidArgument(_path(key), 'expected a string'),
  };

  int? integer(String key) => switch (json[key]) {
    null => null,
    final int value => value,
    _ => throw ToolError.invalidArgument(_path(key), 'expected an integer'),
  };

  List<String> strings(String key) => switch (json[key]) {
    null => const [],
    final List<Object?> values => [
      for (final (i, value) in values.indexed)
        value is String
            ? value
            : throw ToolError.invalidArgument(
                '${_path(key)}[$i]',
                'expected a string',
              ),
    ],
    _ => throw ToolError.invalidArgument(_path(key), 'expected an array'),
  };

  _Args? object(String key) => switch (json[key]) {
    null => null,
    final Map<String, Object?> value => _Args(value, _path(key)),
    _ => throw ToolError.invalidArgument(_path(key), 'expected an object'),
  };

  List<T> parsedList<T>(String key, T Function(String text) parser) => [
    for (final (i, text) in strings(key).indexed)
      _parse('${_path(key)}[$i]', text, parser),
  ];

  T? parsed<T>(String key, T Function(String text) parser) {
    final text = optionalString(key);
    return text == null ? null : _parse(_path(key), text, parser);
  }

  static T _parse<T>(String path, String text, T Function(String) parser) {
    try {
      return parser(text);
    } on FormatException catch (e) {
      throw ToolError.invalidArgument(path, '${e.message}: $text');
    }
  }

  T? enumValue<T extends Enum>(String key, List<T> values) {
    final text = optionalString(key);
    return text == null ? null : _enum(_path(key), text, values);
  }

  List<T> enumValues<T extends Enum>(String key, List<T> values) => [
    for (final (i, text) in strings(key).indexed)
      _enum('${_path(key)}[$i]', text, values),
  ];

  static T _enum<T extends Enum>(String path, String text, List<T> values) =>
      values.where((value) => value.name == text).firstOrNull ??
      (throw ToolError.invalidArgument(
        path,
        'unknown value $text. Allowed values: '
        '${[for (final value in values) value.name].join(', ')}',
      ));

  String _path(String key) => '$_at.$key';
}
