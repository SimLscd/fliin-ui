import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fliin_schema/fliin_schema.dart';

import '../registry/build.dart';
import '../registry/public_api.dart';
import '../verify/entry_example.dart';
import 'item_text.dart';
import 'site_writer.dart' show pngSize;

/// One of the sixteen variants, read from its identifier (`ios.dark.1.0.ltr`).
typedef SiteVariant = ({
  String id,
  String platform,
  String brightness,
  String scale,
  String dir,
});

final List<SiteVariant> siteVariants = [
  for (final id in variantIds)
    if (id.split('.') case [
      final platform,
      final brightness,
      final whole,
      final fraction,
      final dir,
    ])
      (
        id: id,
        platform: platform,
        brightness: brightness,
        scale: '$whole.$fraction',
        dir: dir,
      ),
];

/// A registry item as the site shows it: everything comes from its
/// manifest, its sources and its reference goldens.
final class SiteItem {
  SiteItem._({
    required this.manifest,
    required this.api,
    required this.example,
    required this.goldens,
    required this.sources,
    required this.stories,
    required this.examples,
    required this._goldenHashes,
    required this._heights,
  });

  final ItemManifest manifest;

  /// The public signatures, one per line (`publishedApi`).
  final List<String> api;

  /// `verify.entry` as readable Dart: the `Fl` prefix, the left-to-right
  /// text, formatted. Null without `verify`.
  final String? example;

  /// The reference PNGs by variant; empty if the item has none.
  final Map<String, Uint8List> goldens;

  /// The useful height of each golden in CSS pixels: a component's canvas is
  /// sized for its tallest variant, the site crops the empty background
  /// below. Absent if the PNG cannot be read.
  late final Map<String, int> goldenHeights = {
    for (final MapEntry(key: id, value: png) in goldens.entries)
      if (_heights[_goldenHashes[id]!.value] ??= contentHeight(png) ?? -1
          case final height when height >= 0)
        id: height,
  };

  /// The sha256 of each golden, by variant: the key of [_heights].
  final Map<String, Sha256> _goldenHashes;

  /// Measured heights by golden sha256, -1 for an unreadable PNG, shared by
  /// every item and filled as pages ask: decoding a PNG costs, and
  /// `tool/site/dev.dart` keeps them from one build to the next.
  final Map<String, int> _heights;

  /// The files that `fliin add` copies, target path and text.
  final List<({String path, String text})> sources;

  String get name => manifest.name;

  /// The main class (`FlListRow`, `AccountSettingsScreen`), derived from the
  /// name: a screen belongs to the app and does not take the prefix.
  String get className {
    final pascal = [
      for (final part in name.split('-'))
        '${part[0].toUpperCase()}${part.substring(1)}',
    ].join();
    return isScreen ? '${pascal}Screen' : 'Fl$pascal';
  }

  bool get isFoundation => manifest.type == ItemType.core;

  /// A section to place in a screen (`registry:block`).
  bool get isBlock => manifest.type == ItemType.block;

  /// A whole screen (`registry:screen`), which has its own page.
  bool get isScreen => manifest.type == ItemType.screen;

  /// `tier: pro`: the public registry lists it without serving its code,
  /// and the site shows everything but its source (ADR 0020 §2).
  bool get isPro => manifest.meta.tier == Tier.pro;

  /// Its page, relative to the site root.
  String get path =>
      '${switch (manifest.type) {
        ItemType.screen => 'screens',
        ItemType.block => 'blocks',
        _ => 'components',
      }}/$name/';

  /// The English title, description and "not for" list from [itemEnglish].
  ({String title, String description, List<String> notFor}) get english =>
      itemEnglish[name] ??
      (throw StateError('$name: no entry in item_text.dart'));

  /// The catalog stories, in the order the site offers them: the examples,
  /// then one state of `meta.states` each.
  final List<String> stories;

  /// The stories written as an example to copy, in story order: the
  /// catalog renders the very code the site shows.
  final List<SiteExample> examples;

  /// The story the site shows first; null without stories, meaning the
  /// reference.
  String? get firstStory => stories.isEmpty ? null : stories.first;

  /// `meta.states`, in manifest order.
  List<String> get states => manifest.meta.states;

  /// `verify.canvas` for [platform] (`ios` or `android`), or the harness's
  /// default size.
  CanvasSize canvasFor(String platform) => switch (manifest.verify?.canvas) {
    null => (width: 390, height: 300),
    final canvas => platform == 'android' ? canvas.android : canvas.ios,
  };
}

/// The site's content: the items of the source registry, sorted for
/// navigation (the core first, then the components by name).
final class SiteModel {
  SiteModel._(this.items, this.tokens, this.mitLicense, this.proLicense);

  /// Throws a [BuildError] like `registry build`. [licenses] is the folder
  /// of `LICENSE` and `LICENSE-PRO.md`, the repository root. [stories] is `flutter/catalog/stories.json`: without it, an item's
  /// stories are its states; an unexpected shape throws a
  /// [FormatException]. [heights] holds the goldens' measured heights by
  /// sha256, read and completed (see [SiteItem.goldenHeights]). [examples]
  /// is `flutter/catalog/lib/examples/`: `<item>/<story>.dart` per example
  /// ([readExample]); without it, no item has examples.
  static SiteModel read(
    String source, {
    required String licenses,
    String? stories,
    String? examples,
    Map<String, int>? heights,
  }) {
    heights ??= {};
    final registry = SourceRegistry.read(source);
    final named = stories == null
        ? null
        : storyNames(File(stories).readAsStringSync());
    final items =
        [
          for (final manifest in registry.manifests)
            SiteItem._(
              manifest: manifest,
              api: _api(registry, manifest),
              example: switch (manifest.verify) {
                null => null,
                final verify => readableEntry(verify.entry),
              },
              goldens: {
                for (final MapEntry(key: id, value: sha256)
                    in manifest.verify?.goldens?.variants.entries ??
                        const <MapEntry<String, Sha256>>[])
                  id: registry.blobs[sha256]!,
              },
              sources: [
                for (final file in manifest.files)
                  (
                    path: file.target.path,
                    text: utf8.decode(
                      registry.blobs[file.sha256]!,
                      allowMalformed: true,
                    ),
                  ),
              ],
              goldenHashes: {...?manifest.verify?.goldens?.variants},
              heights: heights,
              stories: named == null
                  ? manifest.meta.states
                  : named[manifest.name] ?? const [],
              examples: [
                if (examples != null)
                  for (final story
                      in named?[manifest.name] ?? manifest.meta.states)
                    if (File(
                          '$examples/${manifest.name}/${story.replaceAll('-', '_')}.dart',
                        )
                        case final file when file.existsSync())
                      readExample(story, file.readAsStringSync()),
              ],
            ),
        ]..sort(
          (a, b) => switch ((a.isFoundation, b.isFoundation)) {
            (true, false) => -1,
            (false, true) => 1,
            _ => a.name.compareTo(b.name),
          },
        );
    final core = items.firstWhere((item) => item.isFoundation);
    final tokensFile = core.manifest.files.firstWhere(
      (file) => file.path.endsWith('.tokens.json'),
    );
    return SiteModel._(
      items,
      utf8.decode(registry.blobs[tokensFile.sha256]!),
      File('$licenses/LICENSE').readAsStringSync(),
      File('$licenses/LICENSE-PRO.md').readAsStringSync(),
    );
  }

  final List<SiteItem> items;

  /// The registry's `fliin.tokens.json`: the site's palette, and the
  /// starting point of the theme page's solver.
  final String tokens;

  /// `LICENSE`, the MIT License of the free items, as written.
  final String mitLicense;

  /// `LICENSE-PRO.md`, the Fliin Pro License, as written.
  final String proLicense;

  /// The components, without the core, the blocks or the screens.
  Iterable<SiteItem> get components =>
      items.where((i) => !i.isFoundation && !i.isBlock && !i.isScreen);

  Iterable<SiteItem> get blocks => items.where((i) => i.isBlock);

  Iterable<SiteItem> get screens => items.where((i) => i.isScreen);

  SiteItem? previous(SiteItem item) {
    final i = items.indexOf(item);
    return i > 0 ? items[i - 1] : null;
  }

  SiteItem? next(SiteItem item) {
    final i = items.indexOf(item);
    return i < items.length - 1 ? items[i + 1] : null;
  }
}

/// The snippets as `fliin add` writes them in an app named `your_app`, with
/// the default `root` and prefix.
final snippetRender = RenderConfig(
  root: 'lib/ui/fliin',
  prefix: 'Fl',
  package: 'your_app',
);

/// A story's example: what it shows, and the code that renders it.
typedef SiteExample = ({String story, String description, String code});

/// The example of [story] from its file: the doc comment of its first class
/// is the description, joined into one paragraph; the code is the file
/// without that comment, as the developer copies it.
SiteExample readExample(String story, String source) {
  final lines = source.split('\n');
  final start = lines.indexWhere((line) => line.startsWith('class '));
  if (start < 0) throw FormatException('$story: no class', source);
  var docStart = start;
  while (docStart > 0 && lines[docStart - 1].startsWith('///')) {
    docStart--;
  }
  return (
    story: story,
    description: [
      for (final line in lines.sublist(docStart, start)) line.substring(3).trim(),
    ].join(' '),
    code: [...lines.sublist(0, docStart), ...lines.sublist(start)].join('\n').trim(),
  );
}

/// A story's or state's identifier as the site shows it: `out-of-range`
/// reads "Out of range".
String storyLabel(String id) {
  final words = id.replaceAll('-', ' ');
  return words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
}

/// The story names by item, read from the catalog's `stories.json`:
/// `{"button": ["variants", …], …}`.
Map<String, List<String>> storyNames(String json) => switch (jsonDecode(json)) {
  final Map<String, Object?> items => {
    for (final MapEntry(key: item, value: names) in items.entries)
      item: switch (names) {
        final List<Object?> names when names.every((n) => n is String) =>
          names.cast<String>(),
        _ => throw FormatException(
          'stories.json: $item, list of names expected',
          '$names',
        ),
      },
  },
  final other => throw FormatException(
    'stories.json: object expected',
    '$other',
  ),
};

List<String> _api(SourceRegistry registry, ItemManifest manifest) => apiLines([
  for (final file in manifest.files)
    if (file.path.endsWith('.dart'))
      utf8.decode(registry.blobs[file.sha256]!, allowMalformed: true),
]);

/// The height in CSS pixels (rendered at 2x) of [png] down to its last row
/// that is not background, the color of the bottom-left corner, plus a margin
/// equal to the top one. Null if [png] is not a non-interlaced 8-bit RGBA
/// PNG, the goldens' format.
int? contentHeight(Uint8List png) {
  final size = pngSize(png);
  if (size == null || png[24] != 8 || png[25] != 6 || png[28] != 0) {
    return null;
  }
  final data = ByteData.sublistView(png);
  final width = data.getUint32(16);
  final height = data.getUint32(20);
  final idat = BytesBuilder(copy: false);
  for (var offset = 8; offset + 8 <= png.length;) {
    final length = data.getUint32(offset);
    if (String.fromCharCodes(png, offset + 4, offset + 8) == 'IDAT') {
      idat.add(Uint8List.sublistView(png, offset + 8, offset + 8 + length));
    }
    offset += 12 + length;
  }
  final raw = ZLibDecoder().convert(idat.takeBytes());
  final stride = width * 4;
  if (raw.length != (stride + 1) * height) return null;
  final rows = Uint8List(stride * height);
  for (var y = 0; y < height; y++) {
    final src = y * (stride + 1) + 1;
    final dst = y * stride;
    final filter = raw[src - 1];
    for (var x = 0; x < stride; x++) {
      final a = x >= 4 ? rows[dst + x - 4] : 0;
      final b = y > 0 ? rows[dst - stride + x] : 0;
      final c = x >= 4 && y > 0 ? rows[dst - stride + x - 4] : 0;
      final p = a + b - c;
      final (pa, pb, pc) = ((p - a).abs(), (p - b).abs(), (p - c).abs());
      rows[dst + x] =
          (raw[src + x] +
              switch (filter) {
                1 => a,
                2 => b,
                3 => (a + b) >> 1,
                4 => pa <= pb && pa <= pc ? a : (pb <= pc ? b : c),
                _ => 0,
              }) &
          0xFF;
    }
  }
  final pixels = ByteData.sublistView(rows);
  final background = pixels.getUint32((height - 1) * stride);
  bool blank(int y) {
    for (var x = 0; x < width; x++) {
      if (pixels.getUint32(y * stride + x * 4) != background) return false;
    }
    return true;
  }

  var top = 0;
  while (top < height && blank(top)) {
    top++;
  }
  if (top == height) return size.height;
  var bottom = height - 1;
  while (blank(bottom)) {
    bottom--;
  }
  return ((bottom + 1 + top) / 2).ceil().clamp(0, size.height);
}
