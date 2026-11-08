import 'dart:convert';
import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;

import 'llms.dart';
import 'pages.dart';
import 'site_model.dart';
import 'site_text.dart';

/// The address the site is built for (ADR 0020 §7): its canonical links,
/// `sitemap.xml` and the absolute links of `llms.txt` and the Markdown pages.
/// The pages link to each other by relative paths, so the same build also
/// works under 127.0.0.1.
const siteBase = 'https://fliin.dev/';

/// Writes the static site into [out], emptied first: the pages, their
/// Markdown and `llms.txt` for agents, `sitemap.xml` and `robots.txt` for
/// [base], the reference goldens, `site.css`
/// and `site.js` from [assets] with its brand images and fonts, and `tokens.css`, the registry's color roles
/// as CSS variables. The compiled solver (`assets/theme.js`) and the Flutter
/// web app (`catalog/`) are added afterwards by `tool/site.sh`, the app
/// under [catalog]. [stories] is the folder of the stories' placeholder
/// images (`<item>/<story>.<brightness>.png`): copied under `stories/`,
/// their dimensions go into the pages. [iconSamples]: one SVG icon from each
/// set, for the theme page. Without [images], neither the stories nor the
/// goldens are copied (only their sizes are read): `tool/site/dev.dart`
/// serves them from a full build. [screenshots]: the pub.dev screenshots of
/// the package, copied under `readme/`, where its README links them (pub.dev
/// shows only absolute image URLs). Returns the number of pages.
int writeSite({
  required SiteModel model,
  required String out,
  required String assets,
  SiteText? text,
  String base = siteBase,
  String catalog = 'catalog/',
  String? stories,
  Map<PresetIcons, String> iconSamples = const {},
  bool images = true,
  String? screenshots,
}) {
  final dir = Directory(out);
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  void write(String path, List<int> bytes) => File(p.join(out, path))
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(bytes);
  final sizes = <String, StorySize>{};
  if (stories != null) {
    for (final file in Directory(stories).listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.png')) continue;
      final relative = p.relative(file.path, from: stories);
      final bytes = images ? file.readAsBytesSync() : _pngHeader(file);
      if (images) write('stories/$relative', bytes);
      if (pngSize(bytes) case final size?) {
        sizes[relative.substring(0, relative.indexOf('.'))] = size;
      }
    }
  }
  final pages = SitePages(
    model,
    text ?? SiteText.english,
    base: base,
    catalog: catalog,
    storySizes: sizes,
    iconSamples: iconSamples,
  ).render();
  for (final MapEntry(key: path, value: html) in pages.entries) {
    write(path, utf8.encode(html));
  }
  for (final MapEntry(key: path, value: markdown)
      in llmsFiles(model, text ?? SiteText.english, base).entries) {
    write(path, utf8.encode(markdown));
  }
  final urls = [
    for (final path in pages.keys)
      if (path != '404.html') '$base${path.replaceFirst(RegExp(r'index\.html$'), '')}',
  ]..sort();
  write(
    'sitemap.xml',
    utf8.encode(
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
      '${[for (final url in urls) '<url><loc>$url</loc></url>\n'].join()}'
      '</urlset>\n',
    ),
  );
  write('robots.txt', utf8.encode('User-agent: *\nAllow: /\nSitemap: ${base}sitemap.xml\n'));
  for (final item in model.items) {
    if (!images) break;
    for (final MapEntry(key: id, value: png) in item.goldens.entries) {
      write('goldens/${item.name}/$id.png', png);
    }
  }
  for (final name in ['site.css', 'site.js']) {
    write('assets/$name', File(p.join(assets, name)).readAsBytesSync());
  }
  final brand = Directory(p.join(assets, 'brand'));
  for (final file in brand.listSync().whereType<File>()) {
    if (file.path.endsWith('.png')) {
      write('assets/brand/${p.basename(file.path)}', file.readAsBytesSync());
    }
  }
  final fonts = Directory(p.join(assets, 'fonts'));
  for (final file in fonts.listSync().whereType<File>()) {
    write('assets/fonts/${p.basename(file.path)}', file.readAsBytesSync());
  }
  if (screenshots != null) {
    for (final file in Directory(screenshots).listSync().whereType<File>()) {
      write('readme/${p.basename(file.path)}', file.readAsBytesSync());
    }
  }
  write('assets/tokens.css', utf8.encode(tokensCss(model.tokens)));
  return pages.length;
}

/// The roles of `color.light` and `color.dark` as CSS variables
/// (`--surface`, `--on-surface`…), and the radii: the site wears the
/// components' palette, and therefore their contrast pairs.
String tokensCss(String tokensJson) {
  final tokens = FliinTokens.read(
    resolveTokens(TokenDocument.fromJson(jsonDecode(tokensJson))),
  );
  String block(Map<String, int> roles) => [
    for (final MapEntry(key: role, value: argb) in roles.entries)
      '  --${_kebab(role)}: #${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()};',
  ].join('\n');
  return '''/* Generated from fliin.tokens.json by tool/site/build_site.dart. */
:root {
  --radius-control: ${tokens.radius['control']}px;
  --radius-card: ${tokens.radius['card']}px;
}
:root[data-theme="light"] {
  color-scheme: light;
${block(tokens.light)}
}
:root[data-theme="dark"] {
  color-scheme: dark;
${block(tokens.dark)}
}
''';
}

String _kebab(String camel) =>
    camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '-${m[0]!.toLowerCase()}');

/// The first 24 bytes of [file]: enough for [pngSize].
List<int> _pngHeader(File file) {
  final handle = file.openSync();
  try {
    return handle.readSync(24);
  } finally {
    handle.closeSync();
  }
}

/// The size of a story image in CSS pixels: it is rendered at 2x.
typedef StorySize = ({int width, int height});

/// The width and height of a PNG, read from its IHDR header, divided by
/// two; null if [png] is not a PNG.
StorySize? pngSize(List<int> png) {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (png.length < 24) return null;
  for (var i = 0; i < signature.length; i++) {
    if (png[i] != signature[i]) return null;
  }
  int word(int at) =>
      png[at] << 24 | png[at + 1] << 16 | png[at + 2] << 8 | png[at + 3];
  return (width: (word(16) / 2).ceil(), height: (word(20) / 2).ceil());
}

/// The heart of each icon set, read from `reference/`: the same contract
/// name (`heart`, ADR 0014 §19) in each set, at the file `icon_sets.dart`
/// gives it. The SVG is kept from `<svg` to `</svg>`, without width or
/// height, so that the page sizes it; the fill and stroke of its root
/// become an inline style, which overrides the `svg` rule of `site.css`,
/// made for the site's stroke icons.
Map<PresetIcons, String> readIconSamples(String reference) => {
  for (final (set, path) in [
    (PresetIcons.fliin, 'gravity-icons/svgs/heart.svg'),
    (PresetIcons.lucide, 'lucide-icons/icons/heart.svg'),
    (PresetIcons.tabler, 'tabler-icons/icons/outline/heart.svg'),
    (PresetIcons.phosphor, 'phosphor-icons/assets/regular/heart.svg'),
  ])
    set: () {
      final file = File(p.join(reference, path)).readAsStringSync();
      final svg = file
          .substring(file.indexOf('<svg'), file.lastIndexOf('</svg>') + 6)
          .replaceAll(RegExp(r'\s+'), ' ');
      final root = svg.substring(0, svg.indexOf('>'));
      String attribute(String name, String fallback) =>
          RegExp('\\s$name="([^"]*)"').firstMatch(root)?[1] ?? fallback;
      final style = [
        'fill:${attribute('fill', 'currentColor')}',
        'stroke:${attribute('stroke', 'none')}',
        'stroke-width:${attribute('stroke-width', '1')}',
        'stroke-linecap:${attribute('stroke-linecap', 'butt')}',
        'stroke-linejoin:${attribute('stroke-linejoin', 'miter')}',
      ].join(';');
      final open = svg.substring(0, svg.indexOf('>') + 1);
      final kept = open.replaceAll(RegExp(r'\s(width|height|class)="[^"]*"'), '');
      return kept.replaceFirst('<svg', '<svg style="$style"') +
          svg.substring(open.length);
    }(),
};
