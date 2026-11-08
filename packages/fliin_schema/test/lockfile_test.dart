import 'dart:convert';

import 'package:fliin_schema/fliin_schema.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

final raw = Sha256.ofString('brut');
final base = Sha256.ofString('rendu');
final edited = Sha256.ofString('édité');
const screen =
    'lib/ui/fliin/screens/account_settings/account_settings_screen.dart';
const button = 'lib/ui/fliin/components/button/fl_button.dart';

/// L'exemple de DESIGN.md §4.3, complété du normaliseur.
Map<String, Object?> lockJson() => {
  'lockfileVersion': 1,
  'registries': {
    '@fliin': 'https://registry.fliin.dev/',
    '@pro': 'https://registry.fliin.dev/pro/',
  },
  'config': {
    'root': 'lib/ui/fliin',
    'prefix': 'Fl',
    'package': 'mon_app',
    'configHash': Sha256.ofString(
      '{"package":"mon_app","prefix":"Fl","root":"lib/ui/fliin"}',
    ).value,
  },
  'normalizer': {'dartStyle': '3.1.14'},
  'items': {
    '@pro/account-settings': {
      'version': '1.3.0',
      'registryDependencies': [
        'core@1.0.0',
        'switch@1.0.2',
        '@pro/confirm-sheet@1.0.0',
      ],
      'files': {
        screen: {
          'raw': raw.value,
          'base': base.value,
          'installed': base.value,
          'conflicted': {
            'targetVersion': '1.4.0',
            'sidecarPath': '$screen.fliin-new',
            'raw': raw.value,
            'base': base.value,
          },
        },
      },
    },
    'button': {
      'version': '0.1.0',
      'registryDependencies': ['core@0.1.0'],
      'files': {
        button: {
          'raw': raw.value,
          'base': null,
          'installed': null,
          'pending': true,
        },
      },
    },
  },
};

Map<String, Object?> fileJson(
  Map<String, Object?> lock,
  String item,
  String path,
) => ((((lock['items']! as Map)[item]! as Map)['files']! as Map)[path]! as Map)
    .cast();

Matcher throwsAt<T extends ManifestError>(String path) =>
    throwsA(isA<T>().having((error) => error.path, 'path', path));

void main() {
  test('devrait réécrire exactement le JSON lu quand il est canonique', () {
    final json = lockJson();
    expect(Lockfile.fromJson(jsonDecode(jsonEncode(json))).toJson(), json);
  });

  test('devrait indexer les éléments par référence sans version', () {
    final lock = Lockfile.fromJson(lockJson());
    final item = lock.items[ItemRef.parse('@pro/account-settings')]!;
    expect(item.version, Version(1, 3, 0));
    expect(item.registryDependencies.first, ItemRef.parse('core@1.0.0'));
    expect(item.files[screen]!.conflicted!.targetVersion, Version(1, 4, 0));
    expect(lock.items[ItemRef.parse('button')]!.files[button]!.pending, isTrue);
  });

  test('devrait refuser le lockfile quand configHash ne correspond pas à sa config (règle 3)', () {
    final json = lockJson();
    (json['config']! as Map)['prefix'] = 'Ac';
    expect(
      () => Lockfile.fromJson(json),
      throwsAt<InvalidValue>(r'$.config.configHash'),
    );
  });

  test("devrait exiger base quand le fichier n'est pas en attente", () {
    final json = lockJson();
    fileJson(json, 'button', button)
      ..remove('pending')
      ..remove('base');
    expect(
      () => Lockfile.fromJson(json),
      throwsAt<MissingField>("\$.items.button.files['$button'].base"),
    );
  });

  test('devrait refuser une empreinte quand le fichier est en attente', () {
    final json = lockJson();
    fileJson(json, 'button', button)['installed'] = base.value;
    expect(
      () => Lockfile.fromJson(json),
      throwsAt<InvalidValue>("\$.items.button.files['$button'].installed"),
    );
  });

  test('devrait refuser un chemin de fichier quand il sort du projet', () {
    final json = lockJson();
    final files = ((json['items']! as Map)['button']! as Map)['files']! as Map;
    files['../.bashrc'] = files.remove(button);
    expect(
      () => Lockfile.fromJson(json),
      throwsAt<InvalidValue>(r"$.items.button.files['../.bashrc']"),
    );
  });

  test('devrait refuser une clé d\'élément quand elle porte une version', () {
    final json = lockJson();
    final items = json['items']! as Map;
    items['button@0.1.0'] = items.remove('button');
    expect(
      () => Lockfile.fromJson(json),
      throwsAt<MalformedReference>(r"$.items['button@0.1.0']"),
    );
  });

  test(
    'devrait refuser le lockfile quand sa version de format est inconnue',
    () {
      expect(
        () => Lockfile.fromJson(lockJson()..['lockfileVersion'] = 2),
        throwsAt<InvalidValue>(r'$.lockfileVersion'),
      );
    },
  );

  group('classify', () {
    final tracked = LockedFile(raw: raw, base: base, installed: base);

    test('devrait dire deleted quand le fichier est absent du disque', () {
      expect(classify(tracked, null), InstalledState.deleted);
      expect(classify(LockedFile.pending(raw), null), InstalledState.deleted);
    });

    test("devrait dire pending quand l'installation s'est faite sans CLI", () {
      expect(classify(LockedFile.pending(raw), raw), InstalledState.pending);
    });

    test('devrait dire conflicted quand un .fliin-new attend', () {
      final conflicted = LockedFile(
        raw: raw,
        base: base,
        installed: base,
        conflicted: ConflictMarker(
          targetVersion: Version(1, 4, 0),
          sidecarPath: '$screen.fliin-new',
          raw: raw,
          base: base,
        ),
      );
      expect(classify(conflicted, base), InstalledState.conflicted);
    });

    test('devrait dire intact quand le disque égale ce qui a été installé', () {
      expect(classify(tracked, base), InstalledState.intact);
    });

    test(
      'devrait dire modified quand le disque diffère de ce qui a été installé',
      () {
        expect(classify(tracked, edited), InstalledState.modified);
        expect(classify(tracked, raw), InstalledState.modified);
      },
    );
  });
}
