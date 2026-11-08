import 'package:pub_semver/pub_semver.dart';

import 'breaking.dart';
import 'item_ref.dart';
import 'json_node.dart';
import 'manifest_error.dart';
import 'sha256.dart';

enum ItemType {
  core,
  primitive,
  component,
  block,
  screen,
  theme,
  icon,
  lib,
  file;

  String get wire => 'registry:$name';
}

enum Tier { free, pro }

enum Platform { ios, android, web, macos, windows, linux }

/// L'alias d'une cible, résolu sous `root` de `fliin.yaml` ; [root] est
/// `root` lui-même (le `LICENSE` que `core` installe).
enum TargetAlias {
  core,
  components,
  screens,
  icons,
  lib,
  root;

  String get wire => '@$name/';
}

/// Où un fichier s'installe : `@components/button/fl_button.dart`.
final class ItemTarget {
  ItemTarget(this.alias, String path) : path = checkRelativePath(path);

  factory ItemTarget.parse(String text) {
    for (final alias in TargetAlias.values) {
      if (text.startsWith(alias.wire)) {
        return ItemTarget(alias, text.substring(alias.wire.length));
      }
    }
    throw FormatException('expected an @alias/path target', text);
  }

  final TargetAlias alias;
  final String path;

  @override
  String toString() => '${alias.wire}$path';
}

final class ItemFile {
  const ItemFile({
    required this.path,
    required this.type,
    required this.target,
    required this.sha256,
    this.variants = const {},
  });

  factory ItemFile.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    return ItemFile(
      path: node['path'].relativePath,
      type: node['type'].oneOf(ItemType.values, (type) => type.wire),
      target: node['target'].parse(ItemTarget.parse),
      sha256: node['sha256'].parse(Sha256.parse, InvalidSha256.new),
      variants: {
        for (final MapEntry(:key, :value)
            in node['variants'].orElse(const {}).fields.entries)
          key: value.read(FileVariant.fromJson),
      },
    );
  }

  /// Relatif à la source du registre.
  final String path;
  final ItemType type;
  final ItemTarget target;

  /// L'empreinte du fichier brut publié (règle 1).
  final Sha256 sha256;

  /// Les autres contenus de ce fichier, par clé (le jeu d'icônes du
  /// préréglage, `lucide`) : le projet en installe un seul, à la même
  /// cible. Une clé qu'un fliin ne connaît pas est ignorée.
  final Map<String, FileVariant> variants;

  /// Ce fichier tel que le projet qui a choisi [variant] l'installe : le
  /// contenu de la variante, sans les autres. Nul quand [variant] n'est pas
  /// servi.
  ItemFile? select(String? variant) {
    final chosen = variant == null ? null : variants[variant];
    if (variant != null && chosen == null && variants.isNotEmpty) return null;
    return ItemFile(
      path: chosen?.path ?? path,
      type: type,
      target: target,
      sha256: chosen?.sha256 ?? sha256,
    );
  }

  Map<String, Object?> toJson() => {
    'path': path,
    'type': type.wire,
    'target': '$target',
    'sha256': sha256.value,
    if (variants.isNotEmpty)
      'variants': {
        for (final MapEntry(:key, :value) in variants.entries)
          key: value.toJson(),
      },
  };
}

/// Un autre contenu publié d'un [ItemFile], à la même cible.
final class FileVariant {
  const FileVariant({required this.path, required this.sha256});

  factory FileVariant.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    return FileVariant(
      path: node['path'].relativePath,
      sha256: node['sha256'].parse(Sha256.parse, InvalidSha256.new),
    );
  }

  /// Relatif à la source du registre.
  final String path;

  /// L'empreinte du brut publié (règle 1).
  final Sha256 sha256;

  Map<String, Object?> toJson() => {'path': path, 'sha256': sha256.value};
}

/// Le manifeste ne sert pas la variante que le projet a choisie : une
/// version de `icons` publiée avant ce jeu.
final class MissingVariant implements Exception {
  const MissingVariant(this.item, this.version, this.variant);

  final String item;
  final Version version;
  final String variant;

  @override
  String toString() =>
      '$item $version does not serve the preset’s $variant icon set. Run '
      'fliin update $item, or go back to the default set with fliin theme '
      '--preset.';
}

/// Une version publiée reste publiée ; un retrait n'est jamais choisi par la
/// résolution mais reste téléchargeable (règle 12).
sealed class ItemStatus {
  const ItemStatus();

  /// Un statut absent vaut [Published].
  static ItemStatus fromJson(Object? json, [String at = r'$']) => json == null
      ? const Published()
      : Yanked(JsonNode(json, at)['yanked'].string);

  Map<String, Object?>? toJson();
}

final class Published extends ItemStatus {
  const Published();

  @override
  Map<String, Object?>? toJson() => null;
}

final class Yanked extends ItemStatus {
  const Yanked(this.reason);

  final String reason;

  @override
  Map<String, Object?> toJson() => {'yanked': reason};
}

/// Ce que la recherche et les aperçus lisent d'un élément.
final class ItemMeta {
  const ItemMeta({
    required this.tier,
    required this.platforms,
    required this.states,
    required this.semanticsRoles,
    required this.intents,
    required this.notFor,
    this.fr,
  });

  factory ItemMeta.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    return ItemMeta(
      tier: node['tier'].oneOf(Tier.values),
      platforms: [
        for (final platform in node['platforms'].items)
          platform.oneOf(Platform.values),
      ],
      states: node['states'].orElse(const []).strings,
      semanticsRoles: node['semanticsRoles'].orElse(const []).strings,
      intents: (
        fr: node['intents']['fr'].strings,
        en: node['intents']['en'].strings,
      ),
      notFor: node['notFor'].orElse(const []).strings,
      fr: node['fr'].readOptional(FrenchText.fromJson),
    );
  }

  final Tier tier;
  final List<Platform> platforms;
  final List<String> states;
  final List<String> semanticsRoles;
  final ({List<String> fr, List<String> en}) intents;
  final List<String> notFor;

  /// Le titre, la description et les `notFor` en français, que seule la
  /// recherche lit, pour une requête française : comme les intentions, ce
  /// sont des données de recherche. Ce que lit le développeur est en anglais.
  final FrenchText? fr;

  Map<String, Object?> toJson() => {
    'tier': tier.name,
    'platforms': [for (final platform in platforms) platform.name],
    'states': states,
    'semanticsRoles': semanticsRoles,
    'intents': {'fr': intents.fr, 'en': intents.en},
    'notFor': notFor,
    'fr': ?fr?.toJson(),
  };
}

/// La version française de `title`, `description` et `meta.notFor`, entrée
/// pour entrée, que la recherche indexe à côté de l'anglais.
final class FrenchText {
  const FrenchText({
    required this.title,
    required this.description,
    required this.notFor,
  });

  factory FrenchText.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    return FrenchText(
      title: node['title'].string,
      description: node['description'].string,
      notFor: node['notFor'].orElse(const []).strings,
    );
  }

  final String title;
  final String description;
  final List<String> notFor;

  Map<String, Object?> toJson() => {
    'title': title,
    'description': description,
    'notFor': notFor,
  };
}

/// Les seize variantes de `fliin verify`, dans l'ordre de `fliinMatrix` du
/// harnais : plateforme, luminosité, échelle du texte, direction.
final List<String> variantIds = List.unmodifiable([
  for (final platform in ['ios', 'android'])
    for (final brightness in ['light', 'dark'])
      for (final scale in ['1.0', '2.0'])
        for (final dir in ['ltr', 'rtl']) '$platform.$brightness.$scale.$dir',
]);

/// Le système dont les polices ont rendu des goldens : un rendu n'est
/// comparable qu'à une référence du même système (ADR 0011).
enum GoldenHost { macos, linux, windows }

/// Ce dont les pixels d'un rendu dépendent hors du code de l'élément (ADR
/// 0011) : l'architecture (`macos-arm64`, l'`Abi` de Dart), la version de
/// Flutter, et l'empreinte de chaque police que le harnais a chargée, par nom
/// de fichier. Le harnais la calcule en FNV-1a 64 bits, faute de sha256 sans
/// dépendance : elle détecte une police changée par une mise à jour du
/// système ou du SDK, elle ne prouve rien contre une falsification.
final class Rendering {
  Rendering({
    required this.abi,
    required this.flutter,
    required Map<String, String> fonts,
  }) : fonts = Map.unmodifiable(fonts);

  factory Rendering.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    return Rendering(
      abi: node['abi'].string,
      flutter: node['flutter'].string,
      fonts: node['fonts'].stringMap,
    );
  }

  final String abi;
  final String flutter;
  final Map<String, String> fonts;

  /// Ce qui diffère de [other], une ligne par valeur : vide si les deux
  /// rendus sont comparables.
  List<String> differences(Rendering other) => [
    if (abi != other.abi) 'architecture $abi ≠ ${other.abi}',
    if (flutter != other.flutter) 'Flutter $flutter ≠ ${other.flutter}',
    for (final name in {...fonts.keys, ...other.fonts.keys}.toList()..sort())
      if (fonts[name] != other.fonts[name])
        'font $name ${fonts[name] ?? 'missing'} ≠ '
            '${other.fonts[name] ?? 'missing'}',
  ];

  Map<String, Object?> toJson() => {
    'abi': abi,
    'flutter': flutter,
    'fonts': fonts,
  };
}

/// Les goldens de référence d'une version (ADR 0011) : le rendu de
/// `verify.entry` par le harnais, jetons par défaut, un PNG par variante,
/// publié comme blob et désigné par son empreinte. Les seize variantes ou
/// aucune.
final class ItemGoldens {
  ItemGoldens({
    required this.host,
    required this.rendering,
    required Map<String, Sha256> variants,
  }) : variants = Map.unmodifiable({
         for (final id in variantIds)
           id: variants[id] ?? (throw ArgumentError.value(id, 'variants')),
       }) {
    if (variants.length != variantIds.length) {
      throw ArgumentError.value(variants.keys, 'variants');
    }
  }

  factory ItemGoldens.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    final variants = node['variants'].fields;
    final missing = [
      for (final id in variantIds)
        if (!variants.containsKey(id)) id,
    ];
    final unknown = [
      for (final id in variants.keys)
        if (!variantIds.contains(id)) id,
    ];
    if (missing.isNotEmpty || unknown.isNotEmpty) {
      throw InvalidValue(
        '${node.path}.variants',
        'expected all 16 variants'
            '${missing.isEmpty ? '' : '. Missing: ${missing.join(', ')}'}'
            '${unknown.isEmpty ? '' : '. Unknown: ${unknown.join(', ')}'}',
      );
    }
    return ItemGoldens(
      host: node['host'].oneOf(GoldenHost.values),
      rendering: node['rendering'].read(Rendering.fromJson),
      variants: {
        for (final MapEntry(:key, :value) in variants.entries)
          key: value.parse(Sha256.parse, InvalidSha256.new),
      },
    );
  }

  final GoldenHost host;

  /// Ce qui a produit ces pixels, au-delà du système.
  final Rendering rendering;

  /// Par identifiant de variante, dans l'ordre de [variantIds].
  final Map<String, Sha256> variants;

  Map<String, Object?> toJson() => {
    'host': host.name,
    'rendering': rendering.toJson(),
    'variants': {
      for (final MapEntry(:key, :value) in variants.entries) key: value.value,
    },
  };
}

/// Une taille logique de rendu, en points.
typedef CanvasSize = ({int width, int height});

/// La taille du rendu de `verify.entry` : la même pour toutes les variantes,
/// ou une par plateforme (un écran entier au format d'un iPhone, 390 × 844,
/// et d'un Android, 412 × 915 : ADR 0015 §1).
sealed class VerifyCanvas {
  const VerifyCanvas();

  /// `{width, height}`, ou `{ios: {…}, android: {…}}`.
  factory VerifyCanvas.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    CanvasSize size(JsonNode node) => (
      width: ItemVerify._bounded(node['width'], ItemVerify.maxCanvas),
      height: ItemVerify._bounded(node['height'], ItemVerify.maxCanvas),
    );
    return node['ios'].isAbsent && node['android'].isAbsent
        ? UniformCanvas(size(node))
        : PlatformCanvas(
            ios: size(node['ios']),
            android: size(node['android']),
          );
  }

  /// La taille des variantes iOS.
  CanvasSize get ios;

  /// La taille des variantes Android.
  CanvasSize get android;

  Map<String, Object?> toJson();
}

final class UniformCanvas extends VerifyCanvas {
  const UniformCanvas(this.size);

  final CanvasSize size;

  @override
  CanvasSize get ios => size;

  @override
  CanvasSize get android => size;

  @override
  Map<String, Object?> toJson() => _sizeJson(size);
}

final class PlatformCanvas extends VerifyCanvas {
  const PlatformCanvas({required this.ios, required this.android});

  @override
  final CanvasSize ios;

  @override
  final CanvasSize android;

  @override
  Map<String, Object?> toJson() => {
    'ios': _sizeJson(ios),
    'android': _sizeJson(android),
  };
}

Map<String, Object?> _sizeJson(CanvasSize size) => {
  'width': size.width,
  'height': size.height,
};

/// Ce que `fliin verify` rend quand le manifeste le fournit : une expression
/// de widget où `{prefix}` est à substituer, et les cibles qu'elle importe.
/// [canvas] est la taille logique du rendu (390 × 300 par défaut, celle du
/// harnais), éventuellement par plateforme ; [settleMs] avance l'horloge avant la capture, pour une entrée
/// qui ouvre un overlay par son contrôleur. [states] dit quels états de
/// `meta.states` ce rendu montre ; [goldens] est calculé à la publication.
final class ItemVerify {
  const ItemVerify({
    required this.entry,
    required this.imports,
    this.canvas,
    this.settleMs,
    this.states = const [],
    this.goldens,
  });

  factory ItemVerify.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    return ItemVerify(
      entry: node['entry'].string,
      imports: [
        for (final target in node['imports'].items)
          target.parse(ItemTarget.parse),
      ],
      canvas: node['canvas'].readOptional(VerifyCanvas.fromJson),
      settleMs: node['settleMs'].readOptional(
        (json, at) => _bounded(JsonNode(json, at), maxSettleMs),
      ),
      states: node['states'].orElse(const []).strings,
      goldens: node['goldens'].readOptional(ItemGoldens.fromJson),
    );
  }

  /// Au-delà, un rendu ne tient plus dans une planche lisible.
  static const maxCanvas = 2048;

  /// Une animation d'entrée tient en moins d'une seconde ; une borne garde
  /// un indicateur sans fin de bloquer `verify`.
  static const maxSettleMs = 1000;

  static int _bounded(JsonNode node, int max) {
    final value = node.integer;
    if (value < 1 || value > max) {
      throw InvalidValue(
        node.path,
        'expected an integer from 1 to $max: $value',
      );
    }
    return value;
  }

  final String entry;
  final List<ItemTarget> imports;
  final VerifyCanvas? canvas;
  final int? settleMs;

  /// Les états de `meta.states` que [entry] rend, donc que [goldens] montre.
  final List<String> states;
  final ItemGoldens? goldens;

  Map<String, Object?> toJson() => {
    'entry': entry,
    'imports': [for (final target in imports) '$target'],
    'canvas': ?canvas?.toJson(),
    'settleMs': ?settleMs,
    if (states.isNotEmpty) 'states': states,
    'goldens': ?goldens?.toJson(),
  };
}

/// Le manifeste d'une version d'élément (DESIGN.md §4.1). Publié, il ne change
/// plus (règle 2) : [toJson] est l'inverse exact de [ItemManifest.fromJson].
final class ItemManifest {
  const ItemManifest({
    required this.name,
    required this.type,
    required this.version,
    required this.title,
    required this.description,
    required this.flutter,
    required this.dependencies,
    required this.registryDependencies,
    required this.files,
    required this.tokens,
    required this.l10n,
    required this.snippets,
    required this.categories,
    required this.docs,
    required this.meta,
    this.verify,
    this.status = const Published(),
    this.changelog,
    this.breaking = const [],
  });

  /// Les collections absentes valent vides ; tout le reste est vérifié.
  factory ItemManifest.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    final snippets = node['snippets'].orElse(const {});
    return ItemManifest(
      name: node['name'].parse((text) => ItemRef(text).name),
      type: node['type'].oneOf(ItemType.values, (type) => type.wire),
      version: node['version'].parse(Version.parse, InvalidVersion.new),
      title: node['title'].string,
      description: node['description'].string,
      flutter: node['flutter'].parse(
        VersionConstraint.parse,
        InvalidVersion.new,
      ),
      dependencies: {
        for (final MapEntry(:key, :value)
            in node['dependencies'].orElse(const {}).fields.entries)
          key: value.parse(VersionConstraint.parse, InvalidVersion.new),
      },
      registryDependencies: [
        for (final dependency
            in node['registryDependencies'].orElse(const []).items)
          dependency.parse(ItemDependency.parse, MalformedReference.new),
      ],
      files: [
        for (final file in node['files'].items) file.read(ItemFile.fromJson),
      ],
      tokens: node['tokens'].readOptional((json, at) {
        final tokens = JsonNode(json, at);
        return (light: tokens['light'].object, dark: tokens['dark'].object);
      }),
      l10n: {
        for (final MapEntry(:key, :value)
            in node['l10n'].orElse(const {}).fields.entries)
          key: value.stringMap,
      },
      snippets: (
        route: snippets['route'].orElse(const {}).stringMap,
        state: snippets['state'].orElse(const {}).stringMap,
        screens: snippets['screens'].orElse(const []).strings,
      ),
      categories: node['categories'].orElse(const []).strings,
      docs: node['docs'].optionalString,
      meta: node['meta'].read(ItemMeta.fromJson),
      verify: node['verify'].readOptional(ItemVerify.fromJson),
      status: node['status'].read(ItemStatus.fromJson),
      changelog: node['changelog'].optionalString,
      breaking: [
        for (final change in node['breaking'].orElse(const []).items)
          change.read(BreakingChange.fromJson),
      ],
    );
  }

  /// Ce manifeste tel que le projet qui a choisi [variant] l'installe :
  /// chaque fichier à variantes remplacé par la sienne. Un élément d'icônes
  /// doit servir [variant] dans chacun de ses fichiers : un jeu absent
  /// lève [MissingVariant] au lieu d'installer le jeu par défaut.
  ItemManifest select(String? variant) {
    final icon = type == ItemType.icon && variant != null;
    if (!icon && files.every((file) => file.variants.isEmpty)) return this;
    ItemFile pick(ItemFile file) => switch (file.select(variant)) {
      final chosen? when !icon || file.variants.containsKey(variant) => chosen,
      _ => throw MissingVariant(name, version, variant!),
    };
    return ItemManifest.fromJson({
      ...toJson(),
      'files': [for (final file in files) pick(file).toJson()],
    });
  }

  /// En kebab-case, sans espace de noms : celui-ci vient du registre.
  final String name;
  final ItemType type;
  final Version version;
  final String title;
  final String description;

  /// Les versions de Flutter que cette version supporte.
  final VersionConstraint flutter;

  /// Les paquets pub requis, comparés au `pubspec.lock` du projet.
  final Map<String, VersionConstraint> dependencies;
  final List<ItemDependency> registryDependencies;
  final List<ItemFile> files;

  /// Fragments DTCG, opaques tant que le parseur de jetons n'existe pas.
  final ({Map<String, Object?> light, Map<String, Object?> dark})? tokens;

  /// Clé ARB, puis langue, puis texte.
  final Map<String, Map<String, String>> l10n;

  /// Extraits de branchement par routeur et par gestion d'état. [screens] :
  /// les écrans dont les extraits d'état ouvrent la page, à installer et à
  /// brancher avec celui-ci. Ils ne sont pas dans [registryDependencies],
  /// qui les installerait sans qu'on les demande.
  final ({
    Map<String, String> route,
    Map<String, String> state,
    List<String> screens,
  })
  snippets;
  final List<String> categories;
  final String? docs;
  final ItemMeta meta;
  final ItemVerify? verify;
  final ItemStatus status;

  /// Ce que cette version change, écrit par l'auteur ; `fliin update` le
  /// montre pour chaque version franchie.
  final String? changelog;

  /// Les cassures par rapport à la version précédente publiée : calculées
  /// par `fliin registry build` sur l'API Dart publique, plus celles que
  /// l'auteur déclare ([SemanticBreak]). Signées avec le manifeste, que le
  /// fragment désigne par son empreinte.
  final List<BreakingChange> breaking;

  Map<String, Object?> toJson() => {
    'name': name,
    'type': type.wire,
    'version': '$version',
    'title': title,
    'description': description,
    'flutter': '$flutter',
    'dependencies': {
      for (final MapEntry(:key, :value) in dependencies.entries) key: '$value',
    },
    'registryDependencies': [
      for (final dependency in registryDependencies) '$dependency',
    ],
    'files': [for (final file in files) file.toJson()],
    if (tokens case final tokens?)
      'tokens': {'light': tokens.light, 'dark': tokens.dark},
    'l10n': l10n,
    'snippets': {
      'route': snippets.route,
      'state': snippets.state,
      if (snippets.screens.isNotEmpty) 'screens': snippets.screens,
    },
    'categories': categories,
    'docs': ?docs,
    'meta': meta.toJson(),
    'verify': ?verify?.toJson(),
    'status': ?status.toJson(),
    'changelog': ?changelog,
    if (breaking.isNotEmpty)
      'breaking': [for (final change in breaking) change.toJson()],
  };
}
