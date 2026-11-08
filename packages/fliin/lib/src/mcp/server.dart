import 'dart:convert';
import 'dart:typed_data';

import 'package:fliin_schema/fliin_schema.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:pub_semver/pub_semver.dart';

import '../cli_version.dart';
import '../install/registry_port.dart';
import '../install/targets.dart';
import '../registry/public_api.dart';
import '../search/search_index.dart';
import '../verify/harness_source.g.dart';
import '../verify/test_source.dart';
import '../verify/verify.dart';
import 'contracts.dart';
import 'local/gates.dart';
import 'local/pick_page.dart';
import 'local/selection_store.dart';
import 'ports.dart';

/// Les trois outils de DESIGN.md §5.3 au-dessus de `mcp_dart`, montés par
/// `fliin mcp` et, en V2, par le serveur distant. [searchItems], [getItem] et
/// les méthodes de sélection ne lèvent que des [ToolError] ; [build] les rend
/// en `isError`.
final class FliinMcpServer {
  FliinMcpServer({
    required this._index,
    required this._registry,
    SelectionStore? selections,
    this.entitlement = const AllEntitled(),
    this.quota = const Unlimited(),
    this.sourceBudget = defaultSourceBudget,
  }) : selections = selections ?? MemorySelectionStore();

  /// Caractères de `source` par page, soit 8 000 jetons environ (DESIGN.md
  /// §5.2, E4).
  static const defaultSourceBudget = 32000;

  final IndexSource _index;
  final Registry _registry;
  final SelectionStore selections;
  final EntitlementResolver entitlement;
  final QuotaGate quota;
  final int sourceBudget;

  late final _page = LocalPickPage(
    store: selections,
    describe: _candidateView,
    preview: _preview,
  );

  /// Le manifeste et l'API publique d'une version publiée, qui ne changent
  /// plus (règle 2) : lus une fois par processus.
  final _releases = <ItemRef, _Release>{};

  /// Les versions déjà montrées dans cette session, par un résultat de
  /// recherche ou une sélection : les seules dont `/preview/` sert l'image.
  /// Une version retirée n'y entre jamais, et une URL forgée ne fait lire au
  /// registre aucun manifeste. L'ensemble grandit sans borne, comme
  /// [_releases] : une session vit le temps d'un agent, et il ne compte que
  /// des versions du catalogue.
  final _shown = <ItemRef>{};

  /// Arrête la page de choix, si elle a démarré.
  Future<void> close() => _page.close();

  Future<SearchItemsOutput> searchItems(SearchItemsInput input) async {
    await _admit(QuotaScope.search);
    final snapshot = await _snapshot();
    final SearchPage page;
    try {
      page = snapshot.index.search(input.query);
    } on InvalidInput catch (e) {
      throw ToolError(
        ToolErrorCode.invalidInput,
        e.message,
        details: {'suggestions': e.suggestions},
      );
    }
    return SearchItemsOutput(
      await Future.wait([
        for (final result in page.results)
          _searchItem(snapshot.entry(result.id)!, result),
      ]),
      page.nextCursor,
    );
  }

  Future<SearchItem> _searchItem(IndexEntry entry, SearchResult result) async {
    final ref = result.id.at(result.version);
    final entitled = entitlement
        .resolve(entry)
        .then((entitlement) => entitlement == Entitlement.granted);
    final _Release release;
    try {
      release = await _release(ref);
    } on ToolError catch (e) {
      return SearchItem(
        result: result,
        entitled: await entitled,
        apiSummary: null,
        previewUrl: null,
        unavailable: e.message,
      );
    }
    _shown.add(ref);
    return SearchItem(
      result: result,
      entitled: await entitled,
      apiSummary: switch (release.api) {
        null => null,
        final api => summarizeApi(
          api,
          rest: 'see get_item(id, include: ["api"])',
        ),
      },
      previewUrl: release.manifest.verify?.goldens == null
          ? null
          : await _page.previewUrl(ref, const GoldenVariant()),
    );
  }

  Future<GetItemOutput> getItem(GetItemInput input) async {
    await _admit(QuotaScope.item);
    final snapshot = await _snapshot();
    final entry = snapshot.entry(input.id);
    if (entry == null) {
      throw ToolError(
        ToolErrorCode.notFound,
        '${input.id} is not in the registry.',
      );
    }
    final version = input.version ?? _latest(entry);
    if (version == null || !entry.versions.any((v) => v.version == version)) {
      throw ToolError(
        ToolErrorCode.notFound,
        '${input.id}@${version ?? '*'} is not published.',
        details: {
          'available': [
            for (final release in entry.versions)
              if (release.status is Published) '${release.version}',
          ],
        },
      );
    }
    // Le manifeste d'un élément Pro est public ; son code, son API et son
    // bloc d'installation demandent la licence.
    if (input.include.any(_needsCode.contains) &&
        await entitlement.resolve(entry) == Entitlement.missing) {
      throw ToolError(
        ToolErrorCode.entitlementRequired,
        entry.meta.tier == Tier.pro
            ? '${ProLicenseRequired(entry.ref.name).message} Without a '
                  'license, get_item without include gives its manifest.'
            : '${entry.ref} requires a ${entry.meta.tier.name} entitlement.',
        details: {'tier': entry.meta.tier.name},
        fix: entry.meta.tier == Tier.pro
            ? const CommandFix('fliin login')
            : null,
      );
    }
    final release = await _release(entry.ref.at(version));
    final manifest = release.manifest;
    final page = input.include.contains(IncludeSection.source)
        ? await _sourcePage(manifest, input.cursor)
        : null;
    final harness = input.include.contains(IncludeSection.verifyHarness);
    return GetItemOutput(
      manifest: manifest,
      include: input.include,
      source: page?.files,
      api: input.include.contains(IncludeSection.api)
          ? release.api?.join('\n')
          : null,
      install: input.include.contains(IncludeSection.install)
          ? _install(snapshot, entry.ref, manifest)
          : null,
      harness: harness
          ? (path: '$harnessDir/fliin_harness.dart', content: harnessSource)
          : null,
      test: harness ? _test(manifest) : null,
      nextCursor: page?.nextCursor,
    );
  }

  /// Ouvre une sélection sur la plus haute version publiée de chaque
  /// candidat, celle que la page montre.
  Future<SelectionOutput> openSelection(OpenSelection input) async {
    await _admit(QuotaScope.selection);
    final snapshot = await _snapshot();
    final candidates = <ItemRef>[];
    final missing = <String>[];
    for (final id in input.candidates) {
      switch (snapshot.entry(id)) {
        case final entry? when _latest(entry) != null:
          candidates.add(id.at(_latest(entry)!));
        case _:
          missing.add('$id');
      }
    }
    if (missing.isNotEmpty) {
      throw ToolError(
        ToolErrorCode.notFound,
        'Candidates not in the registry: ${missing.join(', ')}.',
        details: {'missing': missing},
      );
    }
    _shown.addAll(candidates);
    final selection = await selections.open(
      candidates: candidates,
      question: input.question,
      variant: input.variant,
    );
    return SelectionOutput(selection, await _page.pickUrl(selection.handle));
  }

  /// L'état d'une sélection ; `NOT_FOUND` quand elle a expiré.
  Future<SelectionOutput> readSelection(SelectionHandle handle) async =>
      _output(handle, await selections.find(handle));

  /// L'humain a refusé d'ouvrir la page : la sélection est refusée, sauf si
  /// elle était déjà tranchée.
  Future<SelectionOutput> declineSelection(SelectionHandle handle) async =>
      _output(handle, await selections.settle(handle, const Declined()));

  Future<SelectionOutput> _output(
    SelectionHandle handle,
    Selection? selection,
  ) async {
    if (selection == null) {
      throw ToolError(
        ToolErrorCode.notFound,
        'Selection ${handle.value} is unknown or expired. A selection lasts '
        '30 minutes. Open a new one.',
      );
    }
    return SelectionOutput(selection, await _page.pickUrl(handle));
  }

  /// Un serveur `mcp_dart` neuf : un par processus en stdio, un par session
  /// legacy ou par requête 2026-07-28 en HTTP, ce que `StreamableMcpServer`
  /// décide.
  McpServer build() {
    final server = _Connection();
    server.registerTool(
      'search_items',
      title: 'Search Fliin components and screens',
      description: _searchItemsDescription,
      inputSchema: JsonObject.fromJson(SearchItemsInput.inputSchema),
      outputSchema: JsonObject.fromJson(SearchItemsInput.outputSchema),
      annotations: _readOnly,
      callback: (args, _) => _call(
        () async =>
            (await searchItems(SearchItemsInput.fromJson(args))).toJson(),
      ),
    );
    server.registerTool(
      'get_item',
      title: 'Read a Fliin item',
      description: _getItemDescription,
      inputSchema: JsonObject.fromJson(GetItemInput.inputSchema),
      outputSchema: JsonObject.fromJson(GetItemInput.outputSchema),
      annotations: _readOnly,
      callback: (args, _) => _call(
        () async => (await getItem(GetItemInput.fromJson(args))).toJson(),
      ),
    );
    final awaitingRetry = <String, SelectionHandle>{};
    server.registerStatelessTool(
      'request_selection',
      title: 'Let the human pick a Fliin item',
      description: _requestSelectionDescription,
      inputSchema: JsonObject.fromJson(RequestSelectionInput.inputSchema),
      outputSchema: JsonObject.fromJson(RequestSelectionInput.outputSchema),
      annotations: const ToolAnnotations(
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: false,
      ),
      callback: (args, extra) =>
          _requestSelection(server, args, extra, awaitingRetry),
    );
    return server;
  }

  /// Le chemin de DESIGN.md §5.3 selon l'ère et la capacité déclarée :
  /// MRTR en 2026-07-28, −32042 en 2025-11-25, `pickUrl` et images sinon.
  /// [awaitingRetry] retient, pour la connexion, la sélection qu'un client
  /// 2025-11-25 rejoue après −32042 avec les mêmes arguments.
  Future<BaseResultData> _requestSelection(
    _Connection server,
    Map<String, dynamic> args,
    RequestHandlerExtra extra,
    Map<String, SelectionHandle> awaitingRetry,
  ) async {
    try {
      if (extra.requestState case final state?) {
        final declined =
            extra.inputResponses?.values.any(
              (response) => response.value['action'] == 'decline',
            ) ??
            false;
        final handle = SelectionHandle(state);
        return _complete(
          declined
              ? await declineSelection(handle)
              : await readSelection(handle),
        );
      }
      final OpenSelection open;
      switch (RequestSelectionInput.fromJson(args)) {
        case ReadSelection(:final handle):
          return _complete(await readSelection(handle));
        case final OpenSelection input:
          open = input;
      }
      final route = selectionRoute(
        protocolVersion: extra.protocolVersion ?? server.legacyVersion,
        capabilities:
            extra.clientCapabilities ?? server.server.getClientCapabilities(),
      );
      switch (route) {
        case SelectionRoute.inputRequired:
          final output = await openSelection(open);
          return InputRequiredResult(
            inputRequests: {
              _pickRequest: InputRequest.elicit(
                ElicitRequest.url(
                  message: open.question,
                  url: '${output.pickUrl}',
                ),
              ),
            },
            requestState: output.selection.handle.value,
          );
        case SelectionRoute.urlElicitationError:
          final key = canonicalJson(args);
          for (final MapEntry(key: stale, value: handle)
              in awaitingRetry.entries.toList()) {
            // Un appel concurrent a pu réassigner la clé pendant l'attente.
            if (await selections.find(handle) == null &&
                identical(awaitingRetry[stale], handle)) {
              awaitingRetry.remove(stale);
            }
          }
          if (awaitingRetry[key] case final handle?) {
            final selection = await selections.find(handle);
            if (selection != null) {
              if (selection.status is SelectionOutcome) {
                awaitingRetry.remove(key);
              }
              return _complete(await _output(handle, selection));
            }
          }
          final output = await openSelection(open);
          final handle = output.selection.handle;
          awaitingRetry[key] = handle;
          throw McpError(
            ErrorCode.urlElicitationRequired.value,
            'Let the human choose on ${output.pickUrl}, then retry this call. '
            'Or read request_selection(selectionHandle: '
            '"${handle.value}") again.',
            URLElicitationRequiredErrorData(
              elicitations: [
                ElicitRequest.url(
                  message: open.question,
                  url: '${output.pickUrl}',
                  elicitationId: handle.value,
                ),
              ],
            ).toJson(),
          );
        case SelectionRoute.pickUrl:
          final output = await openSelection(open);
          final json = output.toJson();
          return CallToolResult(
            content: [
              TextContent(text: jsonEncode(json)),
              TextContent(
                text:
                    'Ask the human to open ${output.pickUrl} and choose, then '
                    'read request_selection(selectionHandle: '
                    '"${output.selection.handle.value}") again until it is '
                    'chosen or declined. Previews: ${open.variant.label}.',
              ),
              ...await _previews(output.selection),
            ],
            structuredContent: json,
          );
      }
    } on ToolError catch (e) {
      return _error(e);
    }
  }

  static const _pickRequest = 'pick';

  /// Chaque candidat nommé, suivi de son golden de référence ou de la
  /// raison de son absence.
  Future<List<Content>> _previews(Selection selection) async => [
    for (final ref in selection.candidates) ...[
      TextContent(text: '${ItemRef(ref.name, namespace: ref.namespace)}:'),
      switch (await _preview(ref, selection.variant)) {
        final png? => ImageContent(
          data: base64.encode(png),
          mimeType: 'image/png',
        ),
        null => const TextContent(
          text: 'no reference image is published for this version',
        ),
      },
    ],
  ];

  Future<CandidateView?> _candidateView(
    ItemRef ref,
    GoldenVariant variant,
  ) async {
    try {
      final manifest = (await _release(ref)).manifest;
      return (
        title: manifest.title,
        description: manifest.description,
        hasPreview: await _preview(ref, variant) != null,
      );
    } on ToolError {
      return null;
    }
  }

  Future<Uint8List?> _preview(ItemRef ref, GoldenVariant variant) async {
    if (!_shown.contains(ref)) return null;
    try {
      final sha256 = (await _release(ref))
          .manifest
          .verify
          ?.goldens
          ?.variants[variant.id];
      return sha256 == null
          ? null
          : await _fetch(() => _registry.fetchBlob(sha256));
    } on ToolError {
      return null;
    }
  }

  /// [ref] porte sa version. L'API vient de [publishedApi], la même analyse
  /// que `breaking[]` à la publication, et que `fliin search --json`.
  Future<_Release> _release(ItemRef ref) async {
    if (_releases[ref] case final release?) return release;
    final manifest = await _fetch(
      () => _registry.fetchManifest(
        ItemRef(ref.name, namespace: ref.namespace),
        ref.version!,
      ),
    );
    return _releases[ref] = (
      manifest: manifest,
      api: manifest.meta.tier == Tier.pro && !_registry.servesPro
          ? null
          : await _fetch(() => publishedApi(_registry, manifest)),
    );
  }

  static const _needsCode = {
    IncludeSection.source,
    IncludeSection.api,
    IncludeSection.install,
  };

  /// La plus haute version publiée, non retirée.
  static Version? _latest(IndexEntry entry) => entry.versions
      .where((release) => release.status is Published)
      .map((release) => release.version)
      .fold<Version?>(null, (best, v) => best == null || v > best ? v : best);

  static const _readOnly = ToolAnnotations(
    readOnlyHint: true,
    destructiveHint: false,
    idempotentHint: true,
    openWorldHint: false,
  );

  /// L'état courant. En attente, il redit comment relire : après une
  /// élicitation URL acceptée, l'humain a seulement ouvert la page.
  static CallToolResult _complete(SelectionOutput output) {
    final json = output.toJson();
    return CallToolResult(
      content: [
        TextContent(text: jsonEncode(json)),
        if (output.selection.status is Pending)
          TextContent(
            text:
                'The human has not decided yet on ${output.pickUrl}. '
                'Read request_selection(selectionHandle: '
                '"${output.selection.handle.value}") again until it is '
                'chosen or declined.',
          ),
      ],
      structuredContent: json,
    );
  }

  static CallToolResult _error(ToolError e) => CallToolResult(
    isError: true,
    content: [TextContent(text: jsonEncode(e.toJson()))],
  );

  static Future<CallToolResult> _call(
    Future<Map<String, Object?>> Function() run,
  ) async {
    try {
      final json = await run();
      return CallToolResult(
        content: [TextContent(text: jsonEncode(json))],
        structuredContent: json,
      );
    } on ToolError catch (e) {
      return _error(e);
    }
  }

  Future<void> _admit(QuotaScope scope) async {
    switch (await quota.admit(scope)) {
      case Admitted():
        return;
      case Exceeded(:final retryAfter):
        throw ToolError(
          ToolErrorCode.quotaExceeded,
          '${scope.name} quota exceeded. Retry in ${retryAfter.inSeconds} s.',
          retryAfter: retryAfter,
        );
    }
  }

  Future<IndexSnapshot> _snapshot() => _fetch(_index.snapshot);

  Future<T> _fetch<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on RegistryFailure catch (e) {
      throw switch (e) {
        CliTooOldFailure(:final minCli, :final cliVersion) => ToolError(
          ToolErrorCode.registryUnavailable,
          e.message,
          details: {'minCli': '$minCli', 'cliVersion': '$cliVersion'},
          fix: const CommandFix('dart pub global activate fliin'),
        ),
        _ => ToolError(ToolErrorCode.registryUnavailable, e.message),
      };
    }
  }

  /// Les fichiers bruts depuis [cursor], tant que la page tient dans
  /// [sourceBudget] ; le premier fichier d'une page passe toujours.
  Future<({List<RawFile> files, String? nextCursor})> _sourcePage(
    ItemManifest manifest,
    String? cursor,
  ) async {
    final offset = cursor == null ? 0 : int.tryParse(cursor);
    if (offset == null ||
        offset < 0 ||
        (offset > 0 && offset >= manifest.files.length)) {
      throw ToolError(
        ToolErrorCode.invalidInput,
        'Unreadable cursor. Use the nextCursor of a page.',
        details: {'path': r'$.cursor'},
      );
    }
    final files = <RawFile>[];
    var chars = 0;
    var next = offset;
    for (; next < manifest.files.length; next++) {
      final file = manifest.files[next];
      final content = utf8.decode(
        await _fetch(() => _registry.fetchBlob(file.sha256)),
        allowMalformed: true,
      );
      if (files.isNotEmpty && chars + content.length > sourceBudget) break;
      files.add(
        RawFile(path: file.path, sha256: file.sha256, content: content),
      );
      chars += content.length;
    }
    return (
      files: files,
      nextCursor: next < manifest.files.length ? '$next' : null,
    );
  }

  InstallBlock _install(
    IndexSnapshot snapshot,
    ItemRef ref,
    ItemManifest manifest,
  ) {
    final List<PlannedItem> plan;
    switch (snapshot.closure(ref, manifest.version)) {
      case InstallPlan(:final items):
        plan = items;
      case final ResolutionError error:
        throw ToolError(ToolErrorCode.notFound, _describe(error));
    }
    final files = [
      for (final file in manifest.files)
        (
          rawPath: file.path,
          targetTemplate: _template(file.target),
          sha256: file.sha256,
        ),
    ];
    return InstallBlock(
      ref: ref,
      files: files,
      closure: [
        for (final item in plan)
          if (item.ref != ref) item.ref.at(item.version),
      ],
      manifest: manifest,
      lockEntry: LockedItem(
        version: manifest.version,
        registryDependencies: plan
            .lastWhere((item) => item.ref == ref)
            .dependencies,
        files: {
          for (final file in files)
            file.targetTemplate: LockedFile.pending(file.sha256),
        },
      ),
    );
  }

  /// Le test que `fliin verify` générerait, avec les gabarits `{prefix}`,
  /// `{package}` et `{importRoot}` à la place des valeurs de `fliin.yaml`.
  ProjectFile? _test(ItemManifest manifest) {
    final verify = manifest.verify;
    if (verify == null) return null;
    return (
      path: '$harnessDir/${manifest.name}_verify_test.dart',
      content: verifyTestSource(
        item: manifest.name,
        version: '${manifest.version}',
        prefix: '{prefix}',
        entry: verify.entry,
        imports: {
          for (final target in [
            ItemTarget(TargetAlias.core, 'fliin.dart'),
            ...verify.imports,
          ])
            'package:{package}/{importRoot}/${_under(target)}',
        },
        outDir: 'build/fliin/verify/${manifest.name}',
        variants: const [],
        canvas: verify.canvas,
        settleMs: verify.settleMs,
      ),
    );
  }

  static String _template(ItemTarget target) => '{root}/${_under(target)}';

  static String _under(ItemTarget target) => underRoot(target);

  static String _describe(ResolutionError error) => switch (error) {
    ItemNotFound(:final ref) => 'dependency $ref is not in the registry',
    NoVersionMatches(:final ref, :final constraint) =>
      'dependency $ref: no version matches $constraint',
    DependencyCycle(:final path) => 'dependency cycle: ${path.join(' → ')}',
    FlutterTooOld(:final ref) => 'dependency $ref: Flutter is too old',
  };
}

/// [api] est nul pour un élément Pro dont le registre ne sert pas le code.
typedef _Release = ({ItemManifest manifest, List<String>? api});

/// Comment `request_selection` met l'humain dans la boucle (DESIGN.md §5.3).
enum SelectionRoute {
  /// 2026-07-28 : `InputRequiredResult` portant l'élicitation URL, la poignée
  /// dans `requestState`.
  inputRequired,

  /// 2025-11-25 : l'erreur `URLElicitationRequiredError` (−32042).
  urlElicitationError,

  /// Tout le reste : `pickUrl` et les images dans le résultat.
  pickUrl,
}

/// Le mode URL seulement si le client le déclare (`elicitation.url`) dans
/// une ère qui le connaît : une capacité vide vaut « formulaire seul », et
/// 2025-06-18 n'a pas de mode URL.
SelectionRoute selectionRoute({
  required String? protocolVersion,
  required ClientCapabilities? capabilities,
}) {
  if (capabilities?.elicitation?.url == null) return SelectionRoute.pickUrl;
  return switch (protocolVersion) {
    stableProtocolVersion => SelectionRoute.inputRequired,
    latestInitializationProtocolVersion => SelectionRoute.urlElicitationError,
    _ => SelectionRoute.pickUrl,
  };
}

/// Le serveur d'une connexion. Il retient la version que le premier
/// `initialize` a négociée (un second est refusé par le SDK), que `mcp_dart` garde privée, avec la même règle que lui : la
/// version demandée si elle est legacy et connue, sinon 2025-11-25.
final class _Connection extends McpServer {
  _Connection()
    : super(
        const Implementation(name: 'fliin', version: cliVersion),
        options: const McpServerOptions(protocol: McpProtocol.stable),
      );

  String? legacyVersion;

  @override
  Future<void> connect(Transport transport) {
    final connecting = super.connect(transport);
    final deliver = transport.onmessage;
    transport.onmessage = (message) {
      if (message case JsonRpcRequest(
        method: Method.initialize,
        :final params?,
      )) {
        final requested = params['protocolVersion'];
        legacyVersion ??= legacyProtocolVersions.contains(requested)
            ? requested as String
            : latestInitializationProtocolVersion;
      }
      deliver?.call(message);
    };
    return connecting;
  }
}

/// La boucle de DESIGN.md §5.4 en clair : Android Studio ignore les prompts
/// et les ressources, la description est le seul endroit qu'il lit.
const _searchItemsDescription = '''
Searches for a Fliin Flutter component, block or screen by intent, in English or French, three words or more: "primary action button", "delete account". Returns up to 10 ranked results, each with `why` (what matched), `requires` (registry dependencies to compare with fliin.lock.json) and `install` (the command to run). Nothing from the project is sent.

Working loop:
1. search_items(intent) → candidates, with previewUrl, the reference image.
2. request_selection(candidates, question) → the human's choice on a local page.
3. `fliin add <id> --json` → files written. Exit code 4: run it again with `--accept-deps`.
4. Wire the route and state snippets that `add` prints.
5. `fliin verify <id> --json` → report.json and overview.png.
6. Read overview.png, then the failing PNGs, fix, and go back to 5.

Without a terminal: get_item(id, include: ["source", "install"]) gives the raw files and the rules to write them yourself, then include: ["verifyHarness"] gives the test to run from the IDE.''';

const _getItemDescription = '''
Reads a Fliin item: its manifest and, on request (`include`):
- `source`: its raw files, not adapted, with their sha256, paginated by `cursor`.
- `install`: the install block for working without a terminal (files and target paths with {root}, rewrite rules with {package}, {importRoot} and {prefix} read from fliin.yaml, the closure of dependencies to install first, pub dependencies, l10n, snippets, a pending lockfile entry).
- `verifyHarness`: the harness and the test to write under test/.fliin/, to run from the IDE.
- `api`: all public signatures. `docs`, `examples`.
Prefer `fliin add` and `fliin verify` when a terminal is available.''';

const _requestSelectionDescription = '''
Lets the human pick among 2 to 6 candidates from search_items, on a page that fliin mcp serves on 127.0.0.1: the question, then each candidate with its reference image in the requested variant (`variant`, default iOS, light, text 1.0×, left to right). Returns selectionHandle, status (pending, chosen, declined), chosen (the id to pass to `fliin add`) and pickUrl.

If the client can open a URL (it declares URL elicitation), it offers the URL itself. Otherwise the result holds pickUrl and the images, and you must ask the human to open pickUrl. In every case, while status is pending, call request_selection again with selectionHandle alone until it is chosen or declined: agreeing to open the URL is not choosing. A selection expires 30 minutes after it opens (NOT_FOUND afterwards).''';
