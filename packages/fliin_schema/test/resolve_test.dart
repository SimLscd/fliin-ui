import 'package:fliin_schema/fliin_schema.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

const meta = ItemMeta(
  tier: Tier.free,
  platforms: [Platform.ios],
  states: [],
  semanticsRoles: [],
  intents: (fr: [], en: []),
  notFor: [],
);

IndexVersion release(
  String version, {
  List<String> deps = const [],
  String flutter = '>=3.47.0 <4.0.0',
  bool yanked = false,
}) => IndexVersion(
  version: Version.parse(version),
  manifestSha256: Sha256.ofString(version),
  flutter: VersionConstraint.parse(flutter),
  registryDependencies: [for (final dep in deps) ItemDependency.parse(dep)],
  status: yanked ? const Yanked('régression') : const Published(),
);

IndexEntry entry(String ref, List<IndexVersion> versions) => IndexEntry(
  ref: ItemRef.parse(ref),
  type: ItemType.component,
  title: ref,
  description: ref,
  categories: const [],
  meta: meta,
  versions: versions,
);

Resolution run(
  List<IndexEntry> index,
  List<String> roots, {
  String flutter = '3.47.7',
  Map<String, String> installed = const {},
}) {
  final byRef = {for (final entry in index) entry.ref: entry};
  return resolve(
    roots: [for (final root in roots) ItemDependency.parse(root)],
    lookup: (ref) => byRef[ref],
    flutter: Version.parse(flutter),
    installed: {
      for (final MapEntry(:key, :value) in installed.entries)
        ItemRef.parse(key): Version.parse(value),
    },
  );
}

Matcher plans(List<String> items) => isA<InstallPlan>().having(
  (plan) => [for (final item in plan.items) '${item.ref.at(item.version)}'],
  'items',
  items,
);

final button = entry('button', [
  release('1.0.0'),
  release('1.2.0'),
  release('2.0.0'),
]);

void main() {
  test('devrait choisir la plus haute version quand plusieurs satisfont la contrainte', () {
    expect(run([button], ['button@^1.0.0']), plans(['button@1.2.0']));
  });

  test('ne devrait jamais choisir une version yanked (règle 12)', () {
    final index = [
      entry('button', [release('1.0.0'), release('1.2.0', yanked: true)]),
    ];
    expect(run(index, ['button@^1.0.0']), plans(['button@1.0.0']));
    expect(
      run(index, ['button@1.2.0']),
      isA<NoVersionMatches>().having((e) => e.available, 'available', [
        Version(1, 0, 0),
      ]),
    );
  });

  test(
    'devrait garder la version installée quand elle satisfait la contrainte',
    () {
      expect(
        run([button], ['button@^1.0.0'], installed: {'button': '1.0.0'}),
        plans(['button@1.0.0']),
      );
      expect(
        run([button], ['button@^1.2.0'], installed: {'button': '1.0.0'}),
        plans(['button@1.2.0']),
      );
    },
  );

  test(
    'devrait garder la version installée quand elle a été retirée depuis',
    () {
      final index = [
        entry('button', [release('1.0.0'), release('1.2.0', yanked: true)]),
      ];
      expect(
        run(index, ['button@^1.0.0'], installed: {'button': '1.2.0'}),
        plans(['button@1.2.0']),
      );
    },
  );

  test("devrait ordonner les dépendances d'abord et les épingler quand il rend le plan", () {
    final index = [
      entry('core', [release('0.1.0'), release('0.1.3'), release('0.2.0')]),
      entry('button', [
        release('0.1.0', deps: ['core@^0.1.0']),
      ]),
      entry('@pro/card', [
        release('1.0.0', deps: ['button@^0.1.0', 'core@^0.1.0']),
      ]),
    ];
    final plan = run(index, ['@pro/card']);
    expect(plan, plans(['core@0.1.3', 'button@0.1.0', '@pro/card@1.0.0']));
    expect(
      [for (final ref in (plan as InstallPlan).items.last.dependencies) '$ref'],
      ['button@0.1.0', 'core@0.1.3'],
    );
  });

  test('devrait intersecter les contraintes quand plusieurs dépendants visent le même élément', () {
    final index = [
      entry('core', [release('0.1.0'), release('0.1.3'), release('0.2.0')]),
      entry('button', [
        release('0.1.0', deps: ['core@^0.1.0']),
      ]),
    ];
    expect(
      run(index, ['button', 'core@>=0.1.1']),
      plans(['core@0.1.3', 'button@0.1.0']),
    );
  });

  test(
    'devrait rendre ItemNotFound quand une racine est absente du registre',
    () {
      expect(
        run([button], ['@pro/confirm-sheet']),
        isA<ItemNotFound>().having(
          (e) => '${e.ref}',
          'ref',
          '@pro/confirm-sheet',
        ),
      );
    },
  );

  test('ne devrait rendre aucun plan quand une dépendance transitive manque (règle 4)', () {
    final index = [
      entry('button', [
        release('0.1.0', deps: ['core@^0.1.0']),
      ]),
      entry('card', [
        release('0.1.0', deps: ['button@^0.1.0']),
      ]),
    ];
    final resolution = run(index, ['card']);
    expect(resolution, isNot(isA<InstallPlan>()));
    expect(
      resolution,
      isA<ItemNotFound>().having((e) => '${e.ref}', 'ref', 'core'),
    );
  });

  test('devrait rendre NoVersionMatches quand aucune version ne satisfait la contrainte', () {
    expect(
      run([button], ['button@^3.0.0']),
      isA<NoVersionMatches>()
          .having((e) => '${e.ref}', 'ref', 'button')
          .having((e) => '${e.constraint}', 'constraint', '^3.0.0')
          .having((e) => e.available, 'available', [
            Version(1, 0, 0),
            Version(1, 2, 0),
            Version(2, 0, 0),
          ]),
    );
  });

  test('devrait rendre NoVersionMatches quand deux dépendants posent des contraintes disjointes', () {
    final index = [
      entry('core', [release('0.1.0'), release('0.2.0')]),
      entry('button', [
        release('0.1.0', deps: ['core@^0.1.0']),
      ]),
    ];
    expect(run(index, ['core@^0.2.0', 'button']), isA<NoVersionMatches>());
    expect(run(index, ['button', 'core@^0.2.0']), isA<NoVersionMatches>());
  });

  test('devrait rendre DependencyCycle quand deux éléments dépendent l\'un de l\'autre', () {
    final index = [
      entry('a', [
        release('1.0.0', deps: ['b']),
      ]),
      entry('b', [
        release('1.0.0', deps: ['a']),
      ]),
    ];
    expect(
      run(index, ['a']),
      isA<DependencyCycle>().having(
        (e) => [for (final ref in e.path) '$ref'],
        'path',
        ['a', 'b', 'a'],
      ),
    );
  });

  test('devrait rendre FlutterTooOld quand les versions qui conviennent exigent un Flutter plus récent', () {
    final index = [
      entry('button', [
        release('1.0.0', flutter: '>=3.40.0 <4.0.0'),
        release('2.0.0', flutter: '>=3.50.0 <4.0.0'),
      ]),
    ];
    expect(
      run(index, ['button@^2.0.0']),
      isA<FlutterTooOld>()
          .having((e) => '${e.required}', 'required', '>=3.50.0 <4.0.0')
          .having((e) => e.actual, 'actual', Version(3, 47, 7)),
    );
    expect(run(index, ['button']), plans(['button@1.0.0']));
  });
}
