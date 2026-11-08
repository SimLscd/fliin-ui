import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fliin/src/mcp/contracts.dart';
import 'package:fliin/src/mcp/local/gates.dart';
import 'package:fliin/fliin.dart';
import 'package:fliin/src/mcp/local/index_source.dart';
import 'package:fliin/src/mcp/local/selection_store.dart';
import 'package:fliin/src/mcp/ports.dart';
import 'package:fliin/src/mcp/server.dart';
import 'package:fliin/src/verify/harness_source.g.dart';
import 'package:fliin_schema/fliin_schema.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../support/fake_registry.dart';
import '../support/source_versions.dart';

final _button = ItemRef('button');
final _core = ItemRef('core');
ItemRef _inSource(String item) => ItemRef(item, version: Version.parse(sourceVersion(item)));
final _buttonInSource = _inSource('button');
final _coreInSource = _inSource('core');
final _spinnerInSource = _inSource('spinner');
const _buttonFile = 'components/button/fl_button.dart';

FliinMcpServer _server({
  Registry? registry,
  EntitlementResolver? entitlement,
  QuotaGate? quota,
  int? sourceBudget,
  SelectionStore? selections,
}) {
  final fake = registry ?? FakeRegistry();
  final server = FliinMcpServer(
    index: LocalIndexSource(fake),
    registry: fake,
    selections: selections,
    entitlement: entitlement ?? const AllEntitled(),
    quota: quota ?? const Unlimited(),
    sourceBudget: sourceBudget ?? FliinMcpServer.defaultSourceBudget,
  );
  addTearDown(server.close);
  return server;
}

/// Un registre dont le pointeur exige un CLI plus récent.
final class _TooNew implements Registry {
  @override
  bool get servesPro => true;

  final _inner = FakeRegistry();

  @override
  Future<IndexPointer> fetchPointer() async =>
      throw CliTooOldFailure(Version(9, 0, 0), Version(0, 1, 0));

  @override
  Future<IndexFragment> fetchFragment(FragmentRef fragment) =>
      _inner.fetchFragment(fragment);

  @override
  Future<ItemManifest> fetchManifest(ItemRef ref, Version version) =>
      _inner.fetchManifest(ref, version);

  @override
  Future<Uint8List> fetchBlob(Sha256 sha256) => _inner.fetchBlob(sha256);
}

final class _Closed implements QuotaGate {
  @override
  Future<QuotaDecision> admit(QuotaScope scope) async =>
      const Exceeded(Duration(seconds: 42));
}

final class _NoneEntitled implements EntitlementResolver {
  @override
  Future<Entitlement> resolve(IndexEntry entry) async => Entitlement.missing;
}

/// La source servie par [FakeRegistry], chaque manifeste publiant des goldens
/// dont le PNG de chaque variante est distinct ; [missing] désigne une
/// variante dont le blob n'est pas servi.
final class _WithGoldens implements Registry {
  @override
  bool get servesPro => true;

  _WithGoldens({this.missing});

  final _inner = FakeRegistry();
  final String? missing;
  final png = {
    for (final id in variantIds) id: Uint8List.fromList(utf8.encode('png $id')),
  };
  int manifestReads = 0;

  @override
  Future<IndexPointer> fetchPointer() => _inner.fetchPointer();

  @override
  Future<IndexFragment> fetchFragment(FragmentRef fragment) =>
      _inner.fetchFragment(fragment);

  @override
  Future<ItemManifest> fetchManifest(ItemRef ref, Version version) async {
    manifestReads++;
    final json = (await _inner.fetchManifest(ref, version)).toJson();
    if (json['verify'] case final Map<String, Object?> verify) {
      verify['goldens'] = {
        'host': 'macos',
        'rendering': {
          'abi': 'macos-arm64',
          'flutter': '3.47.7',
          'fonts': <String, Object?>{},
        },
        'variants': {
          for (final id in variantIds)
            id:
                (id == missing
                        ? Sha256.ofString('absent')
                        : Sha256.ofBytes(png[id]!))
                    .value,
        },
      };
    }
    return ItemManifest.fromJson(json);
  }

  @override
  Future<Uint8List> fetchBlob(Sha256 sha256) async {
    for (final bytes in png.values) {
      if (Sha256.ofBytes(bytes) == sha256) return bytes;
    }
    return _inner.fetchBlob(sha256);
  }
}

Future<McpClient> _connect(
  FliinMcpServer server, {
  String era = '2025-06-18',
  bool url = false,
}) async {
  final toServer = StreamController<List<int>>();
  final toClient = StreamController<List<int>>();
  await server.build().connect(
    IOStreamTransport(stream: toServer.stream, sink: toClient.sink),
  );
  final client = McpClient(
    const Implementation(name: 'test', version: '0'),
    options: McpClientOptions(
      protocol: McpProtocol.legacy,
      protocolVersion: era,
      capabilities: ClientCapabilities(
        elicitation: url ? const ClientElicitation.urlOnly() : null,
      ),
    ),
  );
  await client.connect(
    IOStreamTransport(stream: toClient.stream, sink: toServer.sink),
  );
  addTearDown(client.close);
  return client;
}

/// Un store dont le premier `find` de [held] attend [release] : de quoi
/// faire se croiser deux appels sur la même connexion.
final class _Held implements SelectionStore {
  _Held(this._inner);

  final MemorySelectionStore _inner;
  SelectionHandle? held;
  final reached = Completer<void>();
  final release = Completer<void>();

  @override
  Future<Selection> open({
    required List<ItemRef> candidates,
    required String question,
    required GoldenVariant variant,
  }) =>
      _inner.open(candidates: candidates, question: question, variant: variant);

  @override
  Future<Selection?> find(SelectionHandle handle) async {
    if (handle == held && !reached.isCompleted) {
      reached.complete();
      await release.future;
    }
    return _inner.find(handle);
  }

  @override
  Future<Selection?> settle(SelectionHandle handle, SelectionOutcome outcome) =>
      _inner.settle(handle, outcome);
}

Future<String> _urlOf(Future<CallToolResult> call) => call.then(
  (_) => fail('−32042 attendue'),
  onError: (Object e) => URLElicitationRequiredErrorData.fromJson(
    Map<String, dynamic>.from((e as McpError).data as Map),
  ).elicitations.single.url!,
);

Future<(int, String)> _get(Uri url) async {
  final http = HttpClient();
  try {
    final response = await (await http.getUrl(url)).close();
    return (
      response.statusCode,
      utf8.decode([
        for (final chunk in await response.toList()) ...chunk,
      ], allowMalformed: true),
    );
  } finally {
    http.close();
  }
}

Matcher _toolError(ToolErrorCode code, {Object? details}) => throwsA(
  isA<ToolError>()
      .having((e) => e.code, 'code', code)
      .having((e) => e.details, 'details', details ?? anything),
);

void _validOutput(Map<String, Object?> schema, Map<String, Object?> json) =>
    JsonSchema.fromJson(schema).validate(json);

void main() {
  group('search_items', () {
    test('devrait classer button en premier avec sa commande quand on cherche « bouton d\'action principal »', () async {
      final page = await _server().searchItems(
        const SearchItemsInput(intent: "bouton d'action principal"),
      );
      final first = page.results.first;
      expect(first.result.id, _button);
      expect(first.result.install, 'fliin add button');
      expect(first.result.requires, [_coreInSource, _spinnerInSource]);
      expect(first.entitled, isTrue);
      expect(
        first.apiSummary!.split('\n'),
        containsAll([
          'FlButton: class extends StatelessWidget',
          'FlButton.new: const new({super.key, required String label, '
              'required VoidCallback? onPressed, FlButtonVariant variant, '
              'FlButtonSize? size, bool loading, Widget? leading, Widget? trailing, '
              'FlButtonFeedback feedback, WidgetStatesController? statesController, bool? selected, bool fullWidth})',
        ]),
      );
      expect(
        first.previewUrl,
        isNull,
        reason: 'les manifestes de la source ne publient pas de golden',
      );
      _validOutput(SearchItemsInput.outputSchema, page.toJson());
    });

    test('devrait garder le résultat sans API ni aperçu, avec la raison, quand le registre ne sert pas un de ses fichiers', () async {
      final page =
          await _server(
            registry: FakeRegistry(missing: {FakeRegistry.shaOf(_buttonFile)}),
          ).searchItems(
            const SearchItemsInput(intent: "bouton d'action principal"),
          );
      final button = page.results.firstWhere(
        (item) => item.result.id == _button,
      );
      expect(button.apiSummary, isNull);
      expect(button.previewUrl, isNull);
      expect(button.unavailable, contains(FakeRegistry.shaOf(_buttonFile).hex));
      final others = page.results.where((item) => item.result.id != _button);
      expect(others, isNotEmpty);
      expect([
        for (final item in others) item.apiSummary,
      ], everyElement(isNotEmpty));
      _validOutput(SearchItemsInput.outputSchema, page.toJson());
    });

    test(
      'devrait rendre entitled faux quand le port de droits le refuse',
      () async {
        final page = await _server(entitlement: _NoneEntitled()).searchItems(
          const SearchItemsInput(intent: "bouton d'action principal"),
        );
        expect(page.results, isNotEmpty);
        expect([
          for (final item in page.results) item.entitled,
        ], everyElement(isFalse));
      },
    );

    test('devrait lever INVALID_INPUT avec des suggestions quand l\'intention fait deux mots', () async {
      expect(
        () => _server().searchItems(
          const SearchItemsInput(intent: 'bouton principal'),
        ),
        _toolError(
          ToolErrorCode.invalidInput,
          details: {
            'suggestions': isA<List<Object?>>()
                .having(
                  (s) => s.first,
                  'première',
                  contains("bouton d'action principal"),
                )
                .having((s) => s.length, 'nombre', inInclusiveRange(1, 3)),
          },
        ),
      );
    });
  });

  group('get_item', () {
    test('devrait rendre le manifeste, les fichiers bruts et le bloc install quand on demande source et install', () async {
      final output = await _server().getItem(
        GetItemInput(
          id: _button,
          include: const {IncludeSection.source, IncludeSection.install},
        ),
      );
      expect(output.manifest.name, 'button');
      final file = output.source!.single;
      expect(file.path, _buttonFile);
      expect(file.sha256, FakeRegistry.shaOf(_buttonFile));
      expect(file.content, contains('class FlButton'));
      expect(output.nextCursor, isNull);

      final install = output.install!;
      expect(install.closure, [_coreInSource, _spinnerInSource]);
      expect(
        install.files.single.targetTemplate,
        '{root}/components/button/fl_button.dart',
      );
      expect(install.files.single.sha256, file.sha256);
      final locked =
          install.lockEntry.files['{root}/components/button/fl_button.dart']!;
      expect(locked.pending, isTrue);
      expect(locked.raw, file.sha256);
      expect(install.lockEntry.registryDependencies, [
        _coreInSource,
        _spinnerInSource,
      ]);

      final json = output.toJson();
      _validOutput(GetItemInput.outputSchema, json);
      final rules =
          (json['install'] as Map<String, Object?>)['rewriteRules']
              as List<Object?>;
      expect(
        [for (final rule in rules) (rule as Map<String, Object?>)['kind']],
        ['import', 'prefix'],
      );
    });

    test(
      'devrait lever NOT_FOUND quand l\'élément ou la version n\'existe pas',
      () async {
        expect(
          () => _server().getItem(GetItemInput(id: ItemRef('absent'))),
          _toolError(ToolErrorCode.notFound),
        );
        expect(
          () => _server().getItem(
            GetItemInput(id: _button, version: Version(9, 0, 0)),
          ),
          _toolError(
            ToolErrorCode.notFound,
            details: {
              'available': [sourceVersion('button')],
            },
          ),
        );
      },
    );

    test(
      'devrait paginer source par nextCursor quand le budget est dépassé',
      () async {
        final server = _server(sourceBudget: 5000);
        final paths = <String>[];
        String? cursor;
        var pages = 0;
        do {
          final output = await server.getItem(
            GetItemInput(
              id: _core,
              include: const {IncludeSection.source},
              cursor: cursor,
            ),
          );
          pages++;
          paths.addAll([for (final file in output.source!) file.path]);
          cursor = output.nextCursor;
        } while (cursor != null);
        final manifest = FakeRegistry().manifests[_core]!;
        expect(paths, [for (final file in manifest.files) file.path]);
        expect(pages, greaterThan(1));
        expect(
          () => server.getItem(
            GetItemInput(
              id: _core,
              include: const {IncludeSection.source},
              cursor: 'x',
            ),
          ),
          _toolError(ToolErrorCode.invalidInput),
        );
      },
    );

    test('devrait fournir le harnais et un test à gabarits quand on demande verifyHarness', () async {
      final output = await _server().getItem(
        GetItemInput(
          id: _button,
          include: const {IncludeSection.verifyHarness},
        ),
      );
      expect(output.harness, (
        path: 'test/.fliin/fliin_harness.dart',
        content: harnessSource,
      ));
      final test = output.test!;
      expect(test.path, 'test/.fliin/button_verify_test.dart');
      expect(test.content, contains('{prefix}Scope('));
      expect(
        test.content,
        contains(
          "import 'package:{package}/{importRoot}/components/button/fl_button.dart';",
        ),
      );
      expect(
        test.content,
        contains("import 'package:{package}/{importRoot}/core/fliin.dart';"),
      );
      _validOutput(GetItemInput.outputSchema, output.toJson());
    });

    test('devrait lever QUOTA_EXCEEDED et ENTITLEMENT_REQUIRED quand les portes refusent', () async {
      expect(
        () =>
            _server(quota: _Closed())
                .searchItems(const SearchItemsInput(intent: 'a b c')),
        throwsA(
          isA<ToolError>().having((e) => e.toJson(), 'json', {
            'code': 'QUOTA_EXCEEDED',
            'message': contains('42 s'),
            'retryable': true,
            'retryAfterSec': 42,
            'fix': null,
            'details': isEmpty,
          }),
        ),
      );
      expect(
        () => _server(quota: _Closed()).openSelection(
          OpenSelection(candidates: [_button, _core], question: '?'),
        ),
        _toolError(ToolErrorCode.quotaExceeded),
      );
      expect(
        () => _server(entitlement: _NoneEntitled()).getItem(
          GetItemInput(id: _button, include: const {IncludeSection.source}),
        ),
        _toolError(
          ToolErrorCode.entitlementRequired,
          details: {'tier': 'free'},
        ),
      );
    });

    group('Pro sans clé de licence (ADR 0020 §5)', skip: withoutPro, () {
      FliinMcpServer server() {
        final registry = FakeRegistry(servesPro: false);
        return _server(
          registry: registry,
          entitlement: RegistryEntitlement(registry),
        );
      }

      final screen = ItemRef('account-settings');

      test('devrait trouver l’élément Pro avec son tier, sans droit ni API', () async {
        final page = await server().searchItems(
          const SearchItemsInput(intent: 'réglages du compte'),
        );
        final item = page.results.firstWhere((i) => i.result.id == screen);
        expect(item.toJson(), allOf(
          containsPair('tier', 'pro'),
          containsPair('entitled', false),
          containsPair('apiSummary', null),
        ));
        expect(item.toJson().containsKey('unavailable'), isFalse);
        _validOutput(SearchItemsInput.outputSchema, page.toJson());
      });

      test('devrait rendre le manifeste, et refuser les fichiers avec le renvoi vers la licence', () async {
        final output = await server().getItem(GetItemInput(id: screen));
        expect(output.manifest.meta.tier, Tier.pro);
        for (final section in [IncludeSection.source, IncludeSection.api, IncludeSection.install]) {
          await expectLater(
            server().getItem(GetItemInput(id: screen, include: {section})),
            throwsA(isA<ToolError>().having((e) => e.toJson(), 'json', {
              'code': 'ENTITLEMENT_REQUIRED',
              'message': startsWith(
                'account-settings is a Fliin Pro item. Get a license at '
                'https://fliin.dev/pro, then run fliin login.',
              ),
              'retryable': false,
              'retryAfterSec': null,
              'fix': {'kind': 'command', 'command': 'fliin login'},
              'details': {'tier': 'pro'},
            })),
            reason: section.name,
          );
        }
        final free = await server().getItem(
          GetItemInput(id: _button, include: const {IncludeSection.source}),
        );
        expect(free.source, isNotEmpty);
      });
    });

    test(
      'devrait rendre toutes les signatures publiques quand on demande api',
      () async {
        final output = await _server().getItem(
          GetItemInput(id: _button, include: const {IncludeSection.api}),
        );
        expect(
          output.api!.split('\n'),
          contains('FlButton.build: Widget(BuildContext context)'),
        );
        _validOutput(GetItemInput.outputSchema, output.toJson());
      },
    );

    test('devrait proposer la commande de mise à jour quand le registre exige un CLI plus récent', () async {
      expect(
        () => _server(registry: _TooNew()).getItem(GetItemInput(id: _button)),
        throwsA(
          isA<ToolError>().having((e) => e.toJson(), 'json', {
            'code': 'REGISTRY_UNAVAILABLE',
            'message': contains('9.0.0'),
            'retryable': true,
            'retryAfterSec': null,
            'fix': {
              'kind': 'command',
              'command': 'dart pub global activate fliin',
            },
            'details': {'minCli': '9.0.0', 'cliVersion': '0.1.0'},
          }),
        ),
      );
    });

    test('devrait lever REGISTRY_UNAVAILABLE quand le registre ne sert pas un blob', () async {
      final registry = FakeRegistry(missing: {FakeRegistry.shaOf(_buttonFile)});
      expect(
        () => _server(registry: registry).getItem(
          GetItemInput(id: _button, include: const {IncludeSection.source}),
        ),
        _toolError(ToolErrorCode.registryUnavailable),
      );
    });
  });

  group('request_selection', () {
    test('devrait ouvrir la sélection à la plus haute version publiée et la relire quand on la demande', () async {
      final server = _server();
      final opened = await server.openSelection(
        OpenSelection(candidates: [_button, _core], question: 'Lequel ?'),
      );
      expect(opened.selection.candidates, [
        _buttonInSource,
        _coreInSource,
      ]);
      expect(opened.toJson(), {
        'selectionHandle': opened.selection.handle.value,
        'status': 'pending',
        'chosen': null,
        'pickUrl': matches(RegExp(r'^http://127\.0\.0\.1:\d+/pick/')),
      });
      _validOutput(RequestSelectionInput.outputSchema, opened.toJson());
      final read = await server.readSelection(opened.selection.handle);
      expect(read.toJson(), opened.toJson());
    });

    test('devrait lever NOT_FOUND quand la sélection a expiré au bout de trente minutes', () async {
      var now = DateTime.utc(2026, 10, 19, 12);
      final server = _server(
        selections: MemorySelectionStore(clock: () => now),
      );
      final opened = await server.openSelection(
        OpenSelection(candidates: [_button, _core], question: 'Lequel ?'),
      );
      now = now.add(const Duration(minutes: 29, seconds: 59));
      expect(
        (await server.readSelection(opened.selection.handle))
            .toJson()['status'],
        'pending',
      );
      now = now.add(const Duration(seconds: 1));
      expect(
        () => server.readSelection(opened.selection.handle),
        _toolError(ToolErrorCode.notFound),
      );
    });

    test('devrait garder le choix de l\'humain quand un refus d\'élicitation arrive après', () async {
      final store = MemorySelectionStore();
      final server = _server(selections: store);
      final opened = await server.openSelection(
        OpenSelection(candidates: [_button, _core], question: 'Lequel ?'),
      );
      await store.settle(opened.selection.handle, Chosen(_button));
      expect(
        (await server.declineSelection(opened.selection.handle))
            .toJson()['chosen'],
        'button',
      );
    });
  });

  group('images de la sélection', () {
    test('devrait joindre le golden de la variante demandée pour chaque candidat quand le client n\'a pas d\'élicitation URL', () async {
      final registry = _WithGoldens();
      final client = await _connect(_server(registry: registry));
      final result = await client.callTool(
        const CallToolRequest(
          name: 'request_selection',
          arguments: {
            'candidates': ['button', 'switch'],
            'question': 'Lequel ?',
            'variant': {
              'platform': 'android',
              'brightness': 'dark',
              'scale': 2,
              'dir': 'rtl',
            },
          },
        ),
      );
      expect(
        [
          for (final image in result.content.whereType<ImageContent>())
            utf8.decode(base64.decode(image.data)),
        ],
        ['png android.dark.2.0.rtl', 'png android.dark.2.0.rtl'],
      );
    });

    test('devrait dire qu\'il n\'y a pas d\'image, en ligne et sur la page, quand le golden de la variante n\'est pas servi', () async {
      final registry = _WithGoldens(missing: 'ios.dark.1.0.ltr');
      final client = await _connect(_server(registry: registry));
      final result = await client.callTool(
        const CallToolRequest(
          name: 'request_selection',
          arguments: {
            'candidates': ['button', 'switch'],
            'question': 'Lequel ?',
            'variant': {'brightness': 'dark'},
          },
        ),
      );
      expect(result.content.whereType<ImageContent>(), isEmpty);
      expect([
        for (final text in result.content.whereType<TextContent>()) text.text,
      ], contains('no reference image is published for this version'));
      final (status, html) = await _get(
        Uri.parse(result.structuredContent!['pickUrl']! as String),
      );
      expect(status, 200);
      expect(html, contains('No reference image is published'));
      expect(html, isNot(contains('<img')));
    });

    test('devrait ne servir /preview/ que pour une version déjà montrée, sans lire le registre pour les autres', () async {
      final registry = _WithGoldens();
      final server = _server(registry: registry);
      final opened = await server.openSelection(
        OpenSelection(candidates: [_button, ItemRef('switch')], question: '?'),
      );
      final origin = opened.pickUrl.replace(path: '');
      final reads = registry.manifestReads;
      final (unseen, _) = await _get(
        origin.replace(path: '/preview/radio/0.1.0/ios.light.1.0.ltr.png'),
      );
      expect(unseen, 404);
      expect(registry.manifestReads, reads);
      final (shown, png) = await _get(
        origin.replace(path: '/preview/button/${sourceVersion('button')}/ios.light.1.0.ltr.png'),
      );
      expect(shown, 200);
      expect(png, 'png ios.light.1.0.ltr');
    });
  });

  test('devrait garder la sélection rouverte d\'un rejeu −32042 quand une purge concurrente regarde l\'ancienne', () async {
    var now = DateTime.utc(2026, 10, 20, 12);
    final store = _Held(MemorySelectionStore(clock: () => now));
    final client = await _connect(
      _server(selections: store),
      era: '2025-11-25',
      url: true,
    );
    CallToolRequest ask(String question) => CallToolRequest(
      name: 'request_selection',
      arguments: {
        'candidates': ['button', 'core'],
        'question': question,
      },
    );
    final first = await _urlOf(client.callTool(ask('X ?')));
    store.held = SelectionHandle(Uri.parse(first).pathSegments.last);
    now = now.add(const Duration(minutes: 31));
    final other = _urlOf(client.callTool(ask('Y ?')));
    await store.reached.future;
    final reopened = await _urlOf(client.callTool(ask('X ?')));
    expect(reopened, isNot(first));
    store.release.complete();
    await other;
    final (status, html) = await _get(Uri.parse(reopened));
    expect(status, 200);
    final token = RegExp(r'name="token" value="([^"]+)"').firstMatch(html)![1]!;
    final post = await HttpClient().postUrl(Uri.parse(reopened))
      ..followRedirects = false
      ..headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
      )
      ..write('token=$token&action=choose&item=button');
    expect((await post.close()).statusCode, 303);
    final retried = await client.callTool(ask('X ?'));
    expect(retried.structuredContent?['chosen'], 'button');
  });

  group('surface MCP en mémoire', () {
    late McpClient client;

    setUp(() async {
      final toServer = StreamController<List<int>>();
      final toClient = StreamController<List<int>>();
      await _server().build().connect(
        IOStreamTransport(stream: toServer.stream, sink: toClient.sink),
      );
      client = McpClient(const Implementation(name: 'test', version: '0'));
      await client.connect(
        IOStreamTransport(stream: toClient.stream, sink: toServer.sink),
      );
    });

    tearDown(() => client.close());

    test('devrait annoncer trois outils en lecture seule avec la boucle de travail quand on liste', () async {
      final tools = (await client.listTools()).tools;
      expect([
        for (final tool in tools) tool.name,
      ], unorderedEquals(['get_item', 'request_selection', 'search_items']));
      for (final tool in tools) {
        expect(tool.annotations!.readOnlyHint, isTrue, reason: tool.name);
        expect(tool.annotations!.openWorldHint, isFalse, reason: tool.name);
        expect(
          tool.annotations!.idempotentHint,
          tool.name != 'request_selection',
          reason: '§5.3 ne déclare pas request_selection idempotent',
        );
        expect(tool.outputSchema, isNotNull, reason: tool.name);
      }
      final search = tools.singleWhere((tool) => tool.name == 'search_items');
      expect(search.description, contains('fliin verify <id> --json'));
      expect(search.description, contains('request_selection(candidates'));
      expect(search.inputSchema.toJson()['properties'], contains('intent'));
      expect(search.inputSchema.toJson()[r'$schema'], contains('draft-07'));
    });

    test('devrait rendre isError avec le JSON de l\'erreur quand l\'intention fait deux mots', () async {
      final result = await client.callTool(
        const CallToolRequest(
          name: 'search_items',
          arguments: {'intent': 'bouton principal'},
        ),
      );
      expect(result.isError, isTrue);
      final json = jsonDecode(
        (result.content.single as TextContent).text,
      ) as Map<String, Object?>;
      expect(json['code'], 'INVALID_INPUT');
      expect(
        (json['details'] as Map<String, Object?>)['suggestions'],
        isA<List<Object?>>()
            .having(
              (s) => s.first,
              'première',
              contains("bouton d'action principal"),
            )
            .having((s) => s.length, 'nombre', inInclusiveRange(1, 3)),
      );
    });

    test('devrait rendre structuredContent conforme au schéma quand on appelle get_item', () async {
      final result = await client.callTool(
        const CallToolRequest(
          name: 'get_item',
          arguments: {
            'id': 'button',
            'include': ['install'],
          },
        ),
      );
      expect(result.isError, isFalse);
      final structured = result.structuredContent!;
      expect((structured['item'] as Map)['name'], 'button');
      expect((structured['install'] as Map)['closure'], [
        '$_coreInSource',
        '$_spinnerInSource',
      ]);
    });
  });
}
