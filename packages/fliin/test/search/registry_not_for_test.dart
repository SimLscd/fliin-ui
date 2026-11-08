import 'package:fliin/src/registry/build.dart';
import 'package:fliin/src/registry/client.dart';
import 'package:fliin/src/registry/signing.dart';
import 'package:fliin/src/search/search_index.dart';
import 'package:test/test.dart';

import '../registry/support.dart';

/// Les `notFor` du vrai registre, vus par un agent qui cherche : l'élément
/// écarté recule et dit vers quoi se tourner.
void main() {
  late SearchIndex index;

  setUpAll(() async {
    final dist = tempDir().path;
    final key = await testKey();
    await DistWriter(dist).write(
      SourceRegistry.read(sourceRoot),
      stamp: BuildStamp(version: 1, publishedAt: DateTime.utc(2026, 10, 18)),
      key: key,
    );
    final client = RegistryClient.forUrl(
      Uri.directory(dist),
      Ed25519PointerVerifier([key.publicKey]),
      cacheRoot: tempDir().path,
      clock: () => DateTime.utc(2026, 10, 19),
    );
    final pointer = await client.fetchPointer();
    index = SearchIndex.build(
      (await client.fetchFragment(pointer, pointer.fragments.single)).entries,
    );
  });

  test('devrait renvoyer de chart vers calendar quand on cherche un jour à choisir dans un calendrier', () {
    final results = index
        .search(
          SearchQuery(
            'choisir le jour de la semaine dans un calendrier',
            limit: 10,
          ),
        )
        .results;
    expect(results.first.id.name, 'calendar');
    final chart = results.singleWhere((r) => r.id.name == 'chart');
    expect(
      chart.why,
      contains(allOf(contains('not for'), contains('(calendar)'))),
    );
    expect(
      results.indexOf(chart),
      greaterThan(results.indexWhere((r) => r.id.name == 'date-picker')),
      reason: 'sans le notFor, chart passe devant les sélecteurs de date',
    );
  });
}
