import 'package:fliin/src/mcp/contracts.dart';
import 'package:fliin/src/registry/public_api.dart';
import 'package:fliin/src/search/analyzer.dart';
import 'package:fliin/src/search/search_index.dart';
import 'package:fliin/src/verify/entry_example.dart';
import 'package:fliin_schema/fliin_schema.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../support/fake_registry.dart';

JsonSchema _schema(Map<String, Object?> json) => JsonSchema.fromJson(json);

Matcher _refusedBy(Map<String, Object?> schema) =>
    throwsA(isA<JsonSchemaValidationException>());

Matcher _invalidInput(String path) => throwsA(
  isA<ToolError>()
      .having((e) => e.code, 'code', ToolErrorCode.invalidInput)
      .having((e) => e.details['path'], 'path', path),
);

void main() {
  group('search_items', () {
    const example = {
      'intent': "bouton d'action principal",
      'kind': 'component',
      'platforms': ['ios', 'android'],
      'states': ['loading'],
      'tier': 'free',
      'lang': 'fr',
      'limit': 3,
      'cursor': '3',
    };

    test('devrait accepter un exemple complet quand on le valide contre inputSchema', () {
      _schema(SearchItemsInput.inputSchema).validate(example);
      _schema(SearchItemsInput.inputSchema)
          .validate({'intent': 'valider un formulaire'});
    });

    test('devrait refuser limit: 50 et une propriété inconnue quand on les valide contre inputSchema', () {
      final schema = _schema(SearchItemsInput.inputSchema);
      expect(
        () => schema.validate({'intent': 'valider un formulaire', 'limit': 50}),
        _refusedBy(SearchItemsInput.inputSchema),
      );
      expect(
        () => schema.validate({
          'intent': 'valider un formulaire',
          'installed': <Object?>[],
        }),
        _refusedBy(SearchItemsInput.inputSchema),
      );
      expect(
        () => schema.validate(<String, Object?>{}),
        _refusedBy(SearchItemsInput.inputSchema),
      );
    });

    test('devrait parser l\'exemple en SearchQuery quand les arguments sont dans le contrat', () {
      final query = SearchItemsInput.fromJson(example).query;
      expect(query.intent, "bouton d'action principal");
      expect(query.kind, ItemType.component);
      expect(query.platforms, [Platform.ios, Platform.android]);
      expect(query.states, ['loading']);
      expect(query.tier, Tier.free);
      expect(query.lang, Lang.fr);
      expect(query.limit, 3);
      expect(query.cursor, '3');
      expect(SearchItemsInput.fromJson({'intent': 'x y z'}).limit, 5);
    });

    test(
      'devrait lever INVALID_INPUT situé quand kind n\'est pas cherchable',
      () {
        expect(
          () => SearchItemsInput.fromJson({'intent': 'x y z', 'kind': 'core'}),
          _invalidInput(r'$.kind'),
        );
        expect(
          () => SearchItemsInput.fromJson({'intent': 'x y z', 'limit': 'cinq'}),
          _invalidInput(r'$.limit'),
        );
      },
    );

    test('devrait accepter une page de résultats quand on la valide contre outputSchema', () {
      final result = SearchResult(
        id: ItemRef('button'),
        version: Version(0, 1, 0),
        tier: Tier.free,
        score: 3.14159,
        why: ['intent: “bouton d\'action principal”'],
        requires: [ItemRef('core', version: Version(0, 1, 0))],
      );
      final page = SearchItemsOutput([
        SearchItem(
          result: result,
          entitled: true,
          apiSummary: 'FlButton: class',
          previewUrl: Uri.parse('http://127.0.0.1:1/preview/x.png'),
        ),
        SearchItem(
          result: result,
          entitled: false,
          apiSummary: null,
          previewUrl: null,
          unavailable: 'blob manquant',
        ),
      ], '1');
      _schema(SearchItemsInput.outputSchema).validate(page.toJson());
      _schema(SearchItemsInput.outputSchema)
          .validate(const SearchItemsOutput([], null).toJson());
    });
  });

  group('get_item', () {
    test('devrait parser id, version, include et cursor quand ils sont dans le contrat', () {
      final input = GetItemInput.fromJson({
        'id': '@acme/button',
        'version': '1.2.3',
        'include': ['source', 'verifyHarness'],
        'cursor': '2',
      });
      expect(input.id, ItemRef('button', namespace: Namespace.parse('@acme')));
      expect(input.version, Version(1, 2, 3));
      expect(input.include, {
        IncludeSection.source,
        IncludeSection.verifyHarness,
      });
      expect(input.cursor, '2');
      expect(GetItemInput.fromJson({'id': 'button'}).include, isEmpty);
    });

    test('devrait lever INVALID_INPUT situé quand id est versionné ou include inconnu', () {
      expect(
        () => GetItemInput.fromJson({'id': 'button@1.0.0'}),
        _invalidInput(r'$.id'),
      );
      expect(
        () => GetItemInput.fromJson({
          'id': 'button',
          'include': ['sources'],
        }),
        _invalidInput(r'$.include[0]'),
      );
      expect(
        () => GetItemInput.fromJson(<String, Object?>{}),
        _invalidInput(r'$.id'),
      );
    });

    test('devrait refuser une version dans id quand on le valide contre inputSchema', () {
      final schema = _schema(GetItemInput.inputSchema);
      schema.validate({
        'id': 'button',
        'include': ['install'],
      });
      expect(
        () => schema.validate({'id': 'button@1.0.0'}),
        _refusedBy(GetItemInput.inputSchema),
      );
      expect(
        () => schema.validate({
          'id': 'button',
          'include': ['sources'],
        }),
        _refusedBy(GetItemInput.inputSchema),
      );
    });

    test('devrait accepter une sortie complète quand on la valide contre outputSchema', () {
      final manifest = FakeRegistry().manifests[ItemRef('button')]!;
      final file = manifest.files.single;
      final output = GetItemOutput(
        manifest: manifest,
        include: IncludeSection.values.toSet(),
        source: [
          RawFile(
            path: file.path,
            sha256: file.sha256,
            content: 'class FlButton {}',
          ),
        ],
        api: 'FlButton: class',
        install: InstallBlock(
          ref: ItemRef('button'),
          files: [
            (
              rawPath: file.path,
              targetTemplate: '{root}/components/button/fl_button.dart',
              sha256: file.sha256,
            ),
          ],
          closure: [ItemRef('core', version: Version(0, 1, 0))],
          manifest: manifest,
          lockEntry: LockedItem(
            version: manifest.version,
            registryDependencies: [ItemRef('core', version: Version(0, 1, 0))],
            files: {
              '{root}/components/button/fl_button.dart': LockedFile.pending(
                file.sha256,
              ),
            },
          ),
        ),
        harness: (
          path: 'test/.fliin/fliin_harness.dart',
          content: '// harnais',
        ),
        test: null,
        nextCursor: null,
      );
      final json = output.toJson();
      _schema(GetItemInput.outputSchema).validate(json);
      expect(json['api'], 'FlButton: class');
      expect(json['examples'], [entryExpression(manifest.verify!.entry)]);
      expect('${json['examples']}', isNot(contains('final example')));
      expect('${json['examples']}', isNot(contains('{prefix}')));
      expect((json['install'] as Map)['rewriteRules'], hasLength(2));
      expect(((json['install'] as Map)['lockEntry'] as Map)['ref'], 'button');
      _schema(
        GetItemInput.outputSchema,
      ).validate(GetItemOutput(manifest: manifest, include: const {}).toJson());
    });
  });

  test(
    'devrait couper apiSummary à quarante lignes en disant où lire la suite',
    () {
      final api = [for (var i = 0; i < 45; i++) 'S$i: get int'];
      expect(
        summarizeApi(api.take(40).toList(), rest: 'ailleurs').split('\n'),
        api.take(40),
      );
      final lines = summarizeApi(api, rest: 'ailleurs').split('\n');
      expect(lines, hasLength(maxApiSummaryLines));
      expect(lines.take(39), api.take(39));
      expect(lines.last, '… 6 more: ailleurs');
    },
  );

  group('request_selection', () {
    test(
      'devrait accepter les deux formes quand on les valide contre inputSchema',
      () {
        final schema = _schema(RequestSelectionInput.inputSchema);
        schema.validate({
          'candidates': ['button', '@acme/card'],
          'question': 'Lequel ?',
          'variant': {
            'platform': 'android',
            'brightness': 'dark',
            'scale': 2,
            'dir': 'rtl',
          },
        });
        schema.validate({'selectionHandle': 'abc'});
        for (final refused in <Map<String, Object?>>[
          {
            'candidates': ['button'],
            'question': '?',
          },
          {
            'candidates': ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
            'question': '?',
          },
          {
            'candidates': ['button', 'button'],
            'question': '?',
          },
          {
            'candidates': ['button', 'switch'],
            'question': '?',
            'variant': {'scale': 1.5},
          },
        ]) {
          expect(
            () => schema.validate(refused),
            _refusedBy(RequestSelectionInput.inputSchema),
            reason: '$refused',
          );
        }
      },
    );

    test(
      'devrait parser la variante et ses défauts quand on ouvre une sélection',
      () {
        final open = RequestSelectionInput.fromJson({
          'candidates': ['button', 'switch'],
          'question': '  Lequel ?  ',
          'variant': {'brightness': 'dark', 'scale': 2.0, 'dir': 'rtl'},
        }) as OpenSelection;
        expect(open.candidates, [ItemRef('button'), ItemRef('switch')]);
        expect(open.question, 'Lequel ?');
        expect(open.variant.id, 'ios.dark.2.0.rtl');
        final plain = RequestSelectionInput.fromJson({
          'candidates': ['button', 'switch'],
          'question': 'Lequel ?',
        }) as OpenSelection;
        expect(plain.variant.id, 'ios.light.1.0.ltr');
        expect(
          (RequestSelectionInput.fromJson({
            'selectionHandle': 'abc',
          }) as ReadSelection).handle.value,
          'abc',
        );
      },
    );

    test(
      'devrait lever INVALID_INPUT situé quand la sélection sort du contrat',
      () {
        expect(
          () => RequestSelectionInput.fromJson({
            'selectionHandle': 'abc',
            'question': '?',
          }),
          _invalidInput(r'$.selectionHandle'),
        );
        expect(
          () => RequestSelectionInput.fromJson({
            'candidates': ['button'],
            'question': '?',
          }),
          _invalidInput(r'$.candidates'),
        );
        expect(
          () => RequestSelectionInput.fromJson({
            'candidates': ['button', 'Bouton'],
            'question': '?',
          }),
          _invalidInput(r'$.candidates[1]'),
        );
        expect(
          () => RequestSelectionInput.fromJson({
            'candidates': ['button', 'switch'],
            'question': '   ',
          }),
          _invalidInput(r'$.question'),
        );
        expect(
          () => RequestSelectionInput.fromJson({
            'candidates': ['button', 'switch'],
            'question': '?',
            'variant': {'platform': 'web'},
          }),
          _invalidInput(r'$.variant.platform'),
        );
        expect(
          () => RequestSelectionInput.fromJson({
            'candidates': ['button', 'switch'],
            'question': '?',
            'variant': {'scale': 3},
          }),
          _invalidInput(r'$.variant.scale'),
        );
      },
    );
  });
}
