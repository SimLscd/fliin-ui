import 'dart:convert';
import 'dart:math' as math;

import 'package:fliin_schema/fliin_schema.dart';

import '../project/agents.dart' show AgentKind;
import '../project/project.dart' show minimumFlutter;
import 'guide.dart';
import 'pro_offer.dart';
import 'site_model.dart';
import 'site_text.dart';
import 'site_writer.dart' show StorySize, siteBase;
import 'theme_bridge.dart';

/// The header tab a page belongs to.
enum _Tab { start, components, blocks, screens, theme, pro }

/// A section of a page: its title goes into the table of contents.
typedef _Section = ({String id, String title, String html});

/// A documentation page: title, description, actions, then the page header
/// (pills, preview), the sections and what follows them (previous, next).
typedef _Doc = ({
  String title,
  String lead,
  String? prompt,
  String? command,
  String intro,
  List<_Section> sections,
  String outro,
});

/// The site's pages, by path relative to the output folder. All text comes
/// from [t] (the interface) or from [model] (the registry).
final class SitePages {
  SitePages(
    this.model,
    this.t, {
    this.base = siteBase,
    this.plans = proPlans,
    this.catalog = 'catalog/',
    this.storySizes = const {},
    this.iconSamples = const {},
  });

  final SiteModel model;
  final SiteText t;

  /// The address the site is built for: its canonical links.
  final String base;

  /// The Fliin Pro plans of the `/pro/` page.
  final List<ProPlan> plans;

  /// The folder of the Flutter web app, relative to the site root:
  /// `catalog/<digest>/` when `tool/site.sh` has stored it under the digest
  /// of its content.
  final String catalog;

  /// The size of each story image (`switch/settings`), in CSS pixels: the
  /// space reserved for the image before it loads, and the height of an
  /// example's stage. Empty without the images (the generator's tests).
  final Map<String, StorySize> storySizes;

  /// One icon from each set, as SVG, for the icons setting of the theme
  /// page; a missing set has no preview.
  final Map<PresetIcons, String> iconSamples;

  /// The site's goldens are dark by default; `site.js` switches to `light`.
  static const defaultBrightness = 'dark';

  /// The brightness of the theme page preview when it opens, the first in
  /// its bar: its placeholder images use it, so that `site.js` does not
  /// fetch the other one (ADR 0013 §8).
  static const studioBrightness = 'dark';

  /// The theme page preview, by tab: an overview made of complete blocks,
  /// shadcn style, then one family per tab, then whole screens in their
  /// phone, forui style (ADR 0016 §7.2). Each view is a catalog story, at
  /// its size, and receives the preset's tokens without being recreated; a
  /// hidden tab does not create its views.
  static const studioTabs = [
    (
      id: 'overview',
      label: Copy.tabOverview,
      tiles: [
        ('auth-form', 'ready'),
        ('settings-section', 'titled'),
        ('icons', 'directional'),
        ('menu', 'open'),
        ('card', 'product'),
        ('accordion', 'multiple'),
        ('chart', 'bar'),
        ('slider', 'example'),
        ('popover', 'open'),
        ('tabs', 'example'),
        ('alert', 'example'),
        ('empty-state', 'empty'),
        ('tab-bar', 'selected'),
        ('skeleton', 'loading'),
      ],
    ),
    (
      id: 'forms',
      label: Copy.tabForms,
      tiles: [
        ('text-field', 'example'),
        ('select', 'open'),
        ('checkbox-group', 'example'),
        ('input-otp', 'example'),
        ('radio', 'shipping'),
        ('switch', 'settings'),
        ('date-field', 'example'),
        ('number-field', 'example'),
        ('segmented', 'example'),
        ('search-field', 'example'),
        ('slider', 'range'),
        ('button', 'variants'),
      ],
    ),
    (
      id: 'commerce',
      label: Copy.tabCommerce,
      tiles: [
        ('plan-card', 'recommended'),
        ('cart-line', 'editable'),
        ('order-summary', 'amounts'),
        ('tracking-steps', 'in-progress'),
        ('order-row', 'shipped'),
        ('result-card', 'tile'),
        ('chip', 'filters'),
        ('tag-group', 'amenities'),
        ('badge', 'variants'),
      ],
    ),
    (
      id: 'dashboard',
      label: Copy.tabDashboard,
      tiles: [
        ('stat-card', 'positive'),
        ('stat-card', 'negative'),
        ('chart', 'line'),
        ('calendar', 'example'),
        ('transaction-row', 'debit'),
        ('progress', 'colors'),
        ('event-row', 'current'),
        ('task-row', 'overdue'),
        ('avatar-group', 'basic'),
      ],
    ),
    (
      id: 'messaging',
      label: Copy.tabMessaging,
      tiles: [
        ('conversation-row', 'unread'),
        ('message-bubble', 'received'),
        ('message-bubble', 'reply'),
        ('composer', 'reply'),
        ('comment-row', 'reply'),
        ('post-card', 'text'),
        ('toast', 'example'),
        ('dialog', 'open'),
        ('sheet', 'open'),
      ],
    ),
    (
      id: 'screens',
      label: Copy.tabScreens,
      tiles: [
        ('sign-in', 'ready'),
        ('checkout', 'cart'),
        ('finance-dashboard', 'ready'),
        ('chat', 'thread'),
        ('app-settings', 'ready'),
        ('orders', 'current'),
      ],
    ),
  ];

  /// The accents offered by the home page's theme tile; null is the
  /// registry's. The `fliin theme` solver adjusts them, and a color it
  /// rejects, or that is confused with `danger`, is not offered.
  static const accents = [
    (Copy.accentBlue, null),
    (Copy.accentViolet, '#7C3AED'),
    (Copy.accentFuchsia, '#C026D3'),
    (Copy.accentAmber, '#F59E0B'),
    (Copy.accentGreen, '#16A34A'),
    (Copy.accentTeal, '#0D9488'),
    (Copy.accentCyan, '#0891B2'),
  ];

  Map<String, String> render() => {
    'index.html': _home(),
    '${guidePath}index.html': _guide(),
    'components/index.html': _components(),
    'blocks/index.html': _blocks(),
    'screens/index.html': _screens(),
    for (final item in model.items)
      '${item.path}index.html': item.isScreen ? _screen(item) : _item(item),
    'theme/index.html': _theme(),
    'pro/index.html': _pro(),
    'pro/license/index.html': _license(
      'pro/license/',
      model.proLicense,
      tab: _Tab.pro,
    ),
    'license/index.html': _license('license/', model.mitLicense),
    '404.html': _notFound(),
  };

  /// The screens the `/pro/` page shows as thumbnails, each leading to its
  /// page.
  static const proGallery = [
    'sign-in',
    'checkout',
    'finance-dashboard',
    'chat',
    'account-settings',
    'booking',
    'onboarding',
    'player',
  ];

  SiteItem _byName(String name) =>
      model.items.firstWhere((item) => item.name == name);

  // The shared layout.

  String _page({
    required String root,
    required String? path,
    required String title,
    required _Doc doc,
    _Tab? tab,
    String? current,
    String scripts = '',
    Map<String, Object?> extra = const {},
    String crumbs = '',
    bool landing = false,
    bool banner = false,
  }) {
    final data = {
      ...extra,
      'root': root,
      'catalog': '$root${catalog}flutter_bootstrap.js',
      'themeCommand': 'fliin theme',
      'text': {
        for (final copy in [
          Copy.copied,
          Copy.searchEmpty,
          Copy.expandCode,
          Copy.collapseCode,
          Copy.themeSolving,
          Copy.presetApplied,
          Copy.presetExcused,
          Copy.presetRefused,
          Copy.presetReloading,
          Copy.presetCopy,
          Copy.presetRequestError,
          Copy.presetBrandInvalid,
          Copy.presetContrastError,
          Copy.presetNearest,
          Copy.presetUseNearest,
          Copy.presetTokensError,
          Copy.storyAlt,
          Copy.goldenAlt,
          Copy.platformIos,
          Copy.platformAndroid,
          Copy.brightnessLight,
          Copy.brightnessDark,
          Copy.scaleOne,
          Copy.scaleTwo,
          Copy.dirLtr,
          Copy.dirRtl,
        ])
          copy.name: t(copy),
      },
      'items': [
        for (final item in model.items)
          {
            'name': item.name,
            'title': item.english.title,
            'url': '$root${item.path}',
            'terms': [
              item.english.title,
              item.manifest.title,
              ...item.manifest.meta.intents.en,
              ...item.manifest.meta.intents.fr,
              ...item.manifest.categories,
              ...item.states,
            ],
          },
      ],
    };
    final toc = landing ? const <_Section>[] : doc.sections;
    return '''<!DOCTYPE html>
<html lang="${t(Copy.lang)}" data-theme="$defaultBrightness">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_e(title)}</title>
<meta name="description" content="${_e(t(Copy.metaDescription))}">
${path == null ? '' : '<link rel="canonical" href="$base$path">\n'}<link rel="icon" type="image/png" sizes="32x32" href="${root}assets/brand/icon-32.png">
<link rel="icon" type="image/png" sizes="192x192" href="${root}assets/brand/icon-192.png">
<link rel="apple-touch-icon" href="${root}assets/brand/apple-touch-icon.png">
<link rel="preload" href="${root}assets/fonts/geist-400.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="${root}assets/tokens.css">
<link rel="stylesheet" href="${root}assets/site.css">
<script>(()=>{const r=document.documentElement,c=localStorage.getItem("fliin-theme")||"$defaultBrightness";r.classList.add("js");r.dataset.themeChoice=c;r.dataset.theme=c==="system"?(matchMedia("(prefers-color-scheme: dark)").matches?"dark":"light"):c;})();</script>
</head>
<body${current == null ? '' : ' data-page="$current"'}>
<a class="skip" href="#main">${_e(t(Copy.skipToContent))}</a>
${_header(root, tab, banner: banner)}
${toc.isEmpty ? '' : _tocBar(toc)}
<div class="layout${landing ? ' landing' : ''}">
${_sidebar(root, current, tab)}
<main id="main" tabindex="-1">
${landing ? doc.intro : _article(doc, crumbs)}
</main>
${toc.isEmpty ? '' : _toc(toc)}
${_footer(root)}
</div>
${_searchDialog()}
<dialog class="drawer" aria-label="${_e(t(Copy.sidebarLabel))}"><button type="button" class="icon-button drawer-close" data-drawer-close aria-label="${_e(t(Copy.close))}">${_icon('close')}</button></dialog>
<div class="toast" role="status" aria-live="polite"></div>
<script type="application/json" id="fliin-data">${_json(data)}</script>
$scripts<script src="${root}assets/site.js" defer></script>
</body>
</html>
''';
  }

  /// A link from a page at [root] to the page in the folder [path] of the
  /// site: never `index.html`, and `./` for the home page seen from itself.
  static String _to(String root, String path) =>
      '$root$path'.isEmpty ? './' : '$root$path';

  /// The header: the logo, the tabs centered on the page, the site's
  /// brightness and Get started; the drawer below 768 px; on the home
  /// page, the Fliin Pro banner above, which scrolls away. The search
  /// opens with Cmd+K or Ctrl+K.
  String _header(String root, _Tab? tab, {bool banner = false}) {
    String link(String href, Copy label, _Tab key) =>
        '<a href="${_to(root, href)}"${tab == key ? ' aria-current="page"' : ''}>${_e(t(label))}</a>';
    return '''<header class="top${banner ? ' with-banner' : ''}">
${banner ? '<a class="top-banner" href="${_to(root, 'pro/')}">${_e(t(Copy.bannerPro))}<span class="top-banner-cta">${_e(t(Copy.bannerProCta))}</span></a>\n' : ''}<div class="top-row">
<a class="brand" href="${_to(root, '')}">$_mark<span class="wordmark"><span class="visually-hidden">${_e(t(Copy.brand))}</span></span></a>
<nav class="top-tabs capsule edge" aria-label="${_e(t(Copy.navPrimary))}">
${link('components/', Copy.navComponents, _Tab.components)}
${link('blocks/', Copy.navBlocks, _Tab.blocks)}
${link('screens/', Copy.navScreens, _Tab.screens)}
${link('theme/', Copy.navTheme, _Tab.theme)}
${link(guidePath, Copy.navDocs, _Tab.start)}
${link('pro/', Copy.navPro, _Tab.pro)}
</nav>
<div class="top-end">
${_themeSwitch()}
<button type="button" class="icon-button capsule edge menu-open" data-drawer-open aria-haspopup="dialog" aria-label="${_e(t(Copy.openMenu))}">${_icon('sidebar')}</button>
<a class="tact accent get-started" href="${_to(root, guidePath)}">${_e(t(Copy.getStarted))}</a>
</div>
</div>
</header>''';
  }

  /// The sidebar: Getting started, then the section of the open tab; all
  /// sections outside the item tabs (home, theme, 404). `data-section` tells
  /// `site.js` whether it has changed. A landing page hides it above 768 px:
  /// it stays for the drawer.
  String _sidebar(String root, String? current, _Tab? tab) {
    final section = switch (tab) {
      _Tab.components || _Tab.blocks || _Tab.screens => tab!.name,
      _ => 'all',
    };
    bool shows(_Tab of) => section == 'all' || section == of.name;
    String link(String href, String key, String label, {String? badge}) =>
        '<li><a href="${_to(root, href)}"${current == key ? ' aria-current="page"' : ''}>${_e(label)}${badge ?? ''}</a></li>';
    String item(SiteItem item) => link(
      item.path,
      item.name,
      item.english.title,
      badge: item.isPro ? '<span class="side-pro">${_e(t(Copy.pro))}</span>' : null,
    );
    String group(
      Copy title,
      String index,
      Copy all,
      Iterable<SiteItem> items,
    ) => items.isEmpty
        ? ''
        : '<h2>${_e(t(title))}<span class="side-count">${items.length}</span></h2>\n<div class="hook"><ul>${link('$index/', index, t(all))}${items.map(item).join()}</ul></div>\n';
    final foundation = model.items.where((i) => i.isFoundation);
    return '''<nav class="sidebar" id="sidebar" data-section="$section" aria-label="${_e(t(Copy.sidebarLabel))}">
<h2>${_e(t(Copy.navStart))}</h2>
<div class="hook"><ul>${link('', 'home', t(Copy.introduction))}${link(guidePath, 'getting-started', t(Copy.guideTitle))}${link('theme/', 'theme', t(Copy.navTheme))}${link('pro/', 'pro', t(Copy.proTitle))}</ul></div>
${shows(_Tab.components) ? group(Copy.sidebarComponents, 'components', Copy.allComponents, model.components) : ''}${shows(_Tab.blocks) ? group(Copy.sidebarBlocks, 'blocks', Copy.allBlocks, model.blocks) : ''}${shows(_Tab.screens) ? group(Copy.sidebarScreens, 'screens', Copy.allScreens, model.screens) : ''}${shows(_Tab.components) && foundation.isNotEmpty ? '<h2>${_e(t(Copy.sidebarFoundation))}</h2>\n<div class="hook"><ul>${foundation.map(item).join()}</ul></div>\n' : ''}</nav>''';
  }

  /// The "On this page" table of contents; `site.js` marks in it the
  /// sections on screen, and hooks its rail to the first of them.
  String _toc(List<_Section> sections) =>
      '''<aside class="toc" aria-labelledby="toc-title">
<h2 id="toc-title">${_e(t(Copy.onThisPage))}</h2>
<div class="toc-list hook">${_tocLinks(sections)}</div>
</aside>''';

  /// The table of contents under the header, collapsed, when the right
  /// column is missing.
  String _tocBar(List<_Section> sections) =>
      '''<details class="toc-bar">
<summary>${_icon('list')}<span class="toc-bar-label">${_e(t(Copy.onThisPage))}</span>${_icon('chevron')}</summary>
${_tocLinks(sections)}
</details>''';

  String _tocLinks(List<_Section> sections) =>
      '<ul>${[for (final s in sections) '<li><a href="#${s.id}">${_e(s.title)}</a></li>'].join()}</ul>';

  /// A copy button whose label turns into "Copied" for a moment
  /// (`site.js`): Copy Markdown, the prompt, a command.
  String _copyButton(String label, {String? copy, bool markdown = false, String classes = 'tact'}) =>
      '<button type="button" class="$classes"${markdown ? ' data-copy-markdown' : ' data-copy="${_e(copy!)}"'}>${_icon('check', 'copy-check')}<span class="copy-label">${_e(label)}</span></button>';

  String _article(_Doc doc, String crumbs) {
    final actions = [
      _copyButton(t(Copy.copyMarkdown), markdown: true),
      if (doc.prompt case final prompt?) _copyButton(t(Copy.copyPrompt), copy: prompt),
    ];
    return '''<article class="doc">
<div class="doc-head">
<div class="doc-title">
${crumbs.isEmpty ? '' : '<p class="crumbs">$crumbs</p>\n'}<h1>${_e(doc.title)}</h1>
${doc.lead.isEmpty ? '' : '<p class="lead">${doc.lead}</p>'}
</div>
<div class="doc-actions">${actions.join()}</div>
</div>
${doc.intro}
${[for (final s in doc.sections) '<section aria-labelledby="${s.id}">\n<h2 id="${s.id}">${_e(s.title)}</h2>\n${s.html}\n</section>'].join('\n')}
${doc.outro}
</article>''';
  }

  /// The footer: the site's links in four columns, the motto, the two
  /// licenses and the brightness, then the logo word drawn in dashes, very
  /// large.
  String _footer(String root) {
    String column(Copy title, List<(String, String)> links) =>
        '<div><p class="foot-head">${_e(t(title))}</p><ul>${[for (final (href, label) in links) '<li><a href="$href">$label</a></li>'].join()}</ul></div>';
    String label(Copy copy) => _e(t(copy));
    return '''<footer class="foot">
<nav class="foot-columns" aria-label="${_e(t(Copy.navFooter))}">
${column(Copy.footColumnFliin, [(_to(root, guidePath), label(Copy.footQuickStart)), (_to(root, 'components/'), label(Copy.navComponents)), (_to(root, 'theme/'), label(Copy.navTheme))])}
${column(Copy.footColumnPro, [(_to(root, 'blocks/'), label(Copy.navBlocks)), (_to(root, 'screens/'), label(Copy.navScreens)), ('${root}pro/#plans', label(Copy.footPricing))])}
${column(Copy.footColumnAgents, [('$root$guidePath#agents', label(Copy.footMcp)), ('$root$guidePath#init', label(Copy.footAgentsFile)), ('${root}llms.txt', label(Copy.footerLlms)), ('$root$guidePath#install', label(Copy.footCli))])}
${column(Copy.footColumnProject, [('${root}license/', label(Copy.mitLicense)), ('${root}pro/license/', label(Copy.proLicense))])}
</nav>
<div class="foot-bottom">
<p class="foot-tag">$_mark<span>${_e(t(Copy.footerTagline))}</span></p>
<p class="foot-license">${_withHtml(Copy.footerLicense, {'mit': '<a href="${root}license/">${_e(t(Copy.mitLicense))}</a>', 'pro': '<a href="${root}pro/license/">${_e(t(Copy.proLicense))}</a>'})}</p>
${_themeSwitch()}
</div>
<div class="foot-word" aria-hidden="true"><svg viewBox="0 0 520 190"><text x="260" y="160">${_e(t(Copy.brand))}</text></svg></div>
</footer>''';
  }

  /// Light, dark or system, in a capsule: in the header and in the footer,
  /// both kept in step by `site.js`.
  String _themeSwitch() {
    String theme(String value, Copy label, String icon) =>
        '<button type="button" data-theme-choice="$value" aria-pressed="false" aria-label="${_e(t(label))}">${_icon(icon)}</button>';
    return '<div class="theme-switch capsule edge" role="group" aria-label="${_e(t(Copy.toggleTheme))}">${theme('light', Copy.brightnessLight, 'sun')}${theme('dark', Copy.brightnessDark, 'moon')}${theme('system', Copy.themeSystem, 'monitor')}</div>';
  }

  /// The Pro mark, which leads to the `/pro/` page.
  String _proMark(String root, {bool large = false}) =>
      '<a class="pro${large ? ' large' : ''}" href="${root}pro/" aria-label="${_e(t(Copy.proMark))}">${_e(t(Copy.pro))}</a>';

  String _searchDialog() =>
      '''<dialog class="search" aria-labelledby="search-title">
<form method="dialog" class="search-box" role="search">
<h2 id="search-title" class="visually-hidden">${_e(t(Copy.searchTitle))}</h2>
${_icon('search')}
<input type="search" role="combobox" aria-expanded="false" aria-controls="search-results" aria-autocomplete="list" aria-describedby="search-hint" placeholder="${_e(t(Copy.searchPlaceholder))}" aria-label="${_e(t(Copy.searchTitle))}" autocomplete="off" spellcheck="false">
<button type="submit" class="icon-button" aria-label="${_e(t(Copy.close))}">${_icon('close')}</button>
</form>
<ul id="search-results" role="listbox" aria-label="${_e(t(Copy.navComponents))}"></ul>
<p id="search-hint" class="search-hint">${_e(t(Copy.searchHint))}</p>
</dialog>''';

  // Live previews.

  /// A live preview. Until Flutter has rendered the view, and forever
  /// without JavaScript, an image stands in for it: the variant's golden for
  /// the reference ([state] null), or the story image, rendered at 2x by
  /// `story_images_test.dart` (hence `2x`), for a story.
  String _live(
    String root,
    SiteItem item, {
    String? state,
    String brightness = defaultBrightness,
    bool followsSite = true,
    String? id,
    bool lazy = false,
  }) {
    final canvas = item.canvasFor('ios');
    final request = {
      'item': item.name,
      'state': state,
      'platform': 'ios',
      'brightness': brightness,
      'scale': '1.0',
      'dir': 'ltr',
    };
    final variant = 'ios.$brightness.1.0.ltr';
    final image = state == null
        ? (item.goldens.isEmpty
              ? ''
              : '<img class="live-image" src="${root}goldens/${item.name}/$variant.png" alt="${_e(_goldenAlt(item, siteVariants.firstWhere((v) => v.id == variant)))}" decoding="async">')
        : '<img class="live-image" src="${root}stories/${item.name}/$state.$brightness.png" srcset="${root}stories/${item.name}/$state.$brightness.png 2x"${_size(item, state)}${lazy ? ' loading="lazy"' : ''} alt="${_e(t.fill(Copy.storyAlt, {'name': item.english.title, 'state': state}))}" decoding="async">';
    return '''<div class="live"${item.isScreen ? ' data-screen' : ''} data-kind="${state == null ? 'reference' : 'story'}"${id == null ? '' : ' id="$id"'} data-live="${_e(_json(request))}"${followsSite ? ' data-follow' : ''} style="--w:${canvas.width};--h:${canvas.height}">
$image
<div class="live-host" role="group" aria-label="${_e(t.fill(Copy.previewLabel, {'name': item.english.title}))}"></div>
</div>''';
  }

  /// The `width` and `height` of the image of [state], when known.
  String _size(SiteItem item, String state) =>
      switch (storySizes['${item.name}/$state']) {
        (:final width, :final height) => ' width="$width" height="$height"',
        null => '',
      };

  String _goldenAlt(SiteItem item, SiteVariant v) => t.fill(Copy.goldenAlt, {
    'name': item.english.title,
    'platform': t(
      v.platform == 'ios' ? Copy.platformIos : Copy.platformAndroid,
    ),
    'brightness': t(
      v.brightness == 'light' ? Copy.brightnessLight : Copy.brightnessDark,
    ),
    'scale': t(v.scale == '1.0' ? Copy.scaleOne : Copy.scaleTwo),
    'dir': t(v.dir == 'ltr' ? Copy.dirLtr : Copy.dirRtl),
  });

  /// A code block and its copy button. Beyond ten lines, `site.js` collapses
  /// it behind "Expand code"; without JavaScript, it stays open.
  String _code(
    String code, {
    String lang = 'dart',
    Copy copy = Copy.copyCode,
    bool long = false,
  }) {
    long |= '\n'.allMatches(code).length >= 10;
    return '<div class="code"${long ? ' data-collapsible' : ''}><pre data-lang="$lang"><code>${_e(code)}</code></pre><button type="button" class="icon-button code-copy" data-copy-code aria-label="${_e(t(copy))}">${_icon('copy')}</button>${long ? '<button type="button" class="code-expand" aria-expanded="false" hidden>${_e(t(Copy.expandCode))}</button>' : ''}</div>';
  }

  String _command(String command) =>
      _code(command, lang: 'sh', copy: Copy.copyCommand);

  /// Returns [copy] escaped, each `{name}` replaced by the HTML of [code]: a
  /// command within a sentence.
  String _withCode(
    Copy copy,
    Map<String, String> code, [
    Map<String, String> plain = const {},
  ]) => _e(t.fill(copy, plain)).replaceAllMapped(
    RegExp(r'\{(\w+)\}'),
    (m) => code.containsKey(m[1]) ? '<code>${_e(code[m[1]]!)}</code>' : m[0]!,
  );

  /// A grid card: the preview on its stage, then the item's name, which
  /// covers the card as a link, the Pro mark of a Pro item and an arrow.
  String _card(String root, SiteItem item, String preview, {int index = 0}) =>
      '<li class="card tile" style="--i:$index"><div class="card-stage">$preview</div>${_cardFoot(root, item)}</li>';

  /// A card's foot: the name, the Pro mark of a Pro item and an arrow.
  String _cardFoot(String root, SiteItem item) =>
      '<div class="card-foot"><a class="card-name" href="$root${item.path}">${_e(item.english.title)}</a>${item.isPro ? _proMark(root) : ''}<span class="card-go" aria-hidden="true">${_icon('arrow')}</span></div>';

  /// A screen's thumbnail, the top of its first story, which follows the
  /// site's brightness.
  String _screenThumb(String root, SiteItem item) => switch (item.firstStory) {
    final state? =>
      '<img src="${root}stories/${item.name}/$state.$defaultBrightness.png" data-themed="${root}stories/${item.name}/$state.{b}.png" alt="${_e(t.fill(Copy.storyAlt, {'name': item.english.title, 'state': state}))}" loading="lazy" decoding="async">',
    null => '',
  };

  // The home page.

  String _home() {
    const root = '';
    final accents = accentChoices(model.tokens, SitePages.accents);
    String section(String id, String head, String body, {String classes = 'section'}) =>
        '<section class="$classes" id="$id" aria-labelledby="$id-title">\n$head\n$body\n</section>';
    return _page(
      root: root,
      path: '',
      landing: true,
      banner: true,
      extra: {
        'accents': [for (final accent in accents) accent.theme],
      },
      title: t(Copy.homeTitle),
      current: 'home',
      doc: (
        title: t(Copy.heroTitle),
        lead: '',
        prompt: null,
        command: null,
        intro:
            '''<section class="hero" aria-labelledby="hero-title">
<h1 id="hero-title">${_e(t(Copy.heroTitleLead))} <span class="hero-tail">${_withHtml(Copy.heroTitleTail, {'mark': _mark})}</span></h1>
<p class="hero-lead">${_e(t(Copy.heroLead))}</p>
<div class="hero-actions">
<a class="tact pill invert" href="components/">${_e(t(Copy.heroBrowse))}</a>
<a class="tact pill" href="pro/">${_e(t(Copy.heroPro))}${_icon('arrow')}</a>
</div>
<div class="hero-agents">
<p>${_e(t(Copy.heroAgents))}</p>
<ul>${[for (final kind in AgentKind.values) '<li><a href="$guidePath#agents">${_e(t(agentLabel(kind)))}</a></li>'].join()}</ul>
</div>
</section>
${section('theming', _sectionHead('theming', _icon('palette'), Copy.themeEyebrow, Copy.themeDemoTitle, Copy.themeDemoTail, _e(t(Copy.themeDemoBody))), _themeDemo(root, accents))}
${section('update', _sectionHead('update', _icon('merge'), Copy.updateEyebrow, Copy.updateTitle, Copy.updateTail, _e(t(Copy.updateLead))), _updateDemo())}
${section('agents', _sectionHead('agents', _icon('search'), Copy.agentsEyebrow, Copy.agentsTitle, Copy.agentsTail, _e(t(Copy.agentsBody))), _agentsDemo())}
${section('screens', _sectionHead('screens', _mark, Copy.proTitle, Copy.proSectionTitle, Copy.proSectionTail, _e(t(Copy.proSectionLead)), action: '<div class="split-actions"><a class="tact invert" href="pro/">${_e(t(Copy.homeProCta))}</a><a class="tact" href="screens/">${_e(t(Copy.allScreens))}</a></div>'), _proScreens(root))}
${section('start', _sectionHead('start', _icon('terminal'), Copy.quickStart, Copy.startTitle, Copy.startTail, _e(t.fill(Copy.startBody, {'flutter': '${minimumFlutter.major}.${minimumFlutter.minor}'})), action: '<div class="switcher" role="group" aria-label="${_e(t(Copy.startLabel))}" style="--n:2"><button type="button" aria-pressed="true" aria-controls="start-new">${_e(t(Copy.startNew))}</button><button type="button" aria-pressed="false" aria-controls="start-existing">${_e(t(Copy.startExisting))}</button></div><a class="start-more" href="$guidePath">${_e(t(Copy.startGuide))}${_icon('arrow')}</a>'), _quickStart())}
<section class="closing" aria-labelledby="closing-title">
<h2 id="closing-title">${_e(t(Copy.closingTitle))} <span>${_e(t(Copy.closingTail))}</span></h2>
<div class="command edge"><code>$_install</code>${_copyButton(t(Copy.copy), copy: _install, classes: 'tact small')}</div>
<div class="closing-actions"><a class="tact invert" href="components/">${_e(t(Copy.closingComponents))}</a><a class="tact" href="pro/">${_e(t(Copy.closingPro))}</a><a class="tact" href="theme/">${_e(t(Copy.closingTheme))}</a></div>
</section>
<aside class="pro-card tile" aria-labelledby="pro-card-title" data-pro-card hidden>
<div class="pro-card-art" aria-hidden="true"><span class="pro-card-logo">$_mark<span>${_e(t(Copy.pro))}</span></span><span class="pro-card-now">${_e(t(Copy.proCardNow))}</span></div>
<button type="button" class="icon-button pro-card-x" data-pro-card-close aria-label="${_e(t(Copy.close))}">${_icon('close')}</button>
<div class="pro-card-body"><h2 id="pro-card-title">${_e(t(Copy.proCardTitle))}</h2><p>${_e(t(Copy.proCardBody))}</p>
<a class="tact pill pro-card-cta" href="pro/">${_e(t(Copy.proCardCta))}</a></div>
</aside>''',
        sections: const [],
        outro: '',
      ),
    );
  }

  /// What the home page calls each client that `fliin init --agent`
  /// configures: a new client cannot be added without its name.
  static Copy agentLabel(AgentKind kind) => switch (kind) {
    AgentKind.claude => Copy.agentClaude,
    AgentKind.cursor => Copy.agentCursor,
    AgentKind.gemini => Copy.agentGemini,
    AgentKind.codex => Copy.agentCodex,
    AgentKind.vscode => Copy.agentVscode,
    AgentKind.androidStudio => Copy.agentAndroidStudio,
  };

  /// The screens of the home page's Pro grid: the top of each, in its
  /// phone.
  static const homeScreens = [
    'finance-dashboard',
    'checkout',
    'chat',
    'onboarding',
    'player',
    'booking',
  ];

  /// The screen of the theme showcase, live in its phone: the accents
  /// recolor it.
  static const homeFeature = 'finance-dashboard';

  /// A home section's head: a small label after its [badge] (an icon or
  /// the mark), the title in two tones, and on the other side the lead and
  /// an optional action.
  String _sectionHead(
    String id,
    String badge,
    Copy eyebrow,
    Copy title,
    Copy tail,
    String lead, {
    String action = '',
  }) =>
      '<div class="section-head split-head"><div><p class="eyebrow">$badge${_e(t(eyebrow))}</p><h2 id="$id-title">${_e(t(title))} <span>${_e(t(tail))}</span></h2></div><div class="split-lead"><p>$lead</p>$action</div></div>';

  /// Four points under a showcase: an icon, a title and a sentence each.
  String _features(List<(String, Copy, String)> features) =>
      '<ul class="features">${[for (final (icon, title, body) in features) '<li><span class="feature-icon">${_icon(icon)}</span><h3>${_e(t(title))}</h3><p>$body</p></li>'].join()}</ul>';

  /// A terminal window: three dots and its title, then [body].
  String _window(String body, {String classes = '', String attributes = ''}) =>
      '<div class="window$classes"$attributes><div class="window-head"><span class="window-dots"><span></span><span></span><span></span></span><span>${_e(t(Copy.demoWindow))}</span></div><div class="window-body">$body</div></div>';

  /// The theme showcase: [homeFeature] live in its phone on a backdrop of
  /// the chosen accent, the accents and the theme page in a capsule at its
  /// foot; then what a preset guarantees.
  String _themeDemo(String root, List<AccentChoice> accents) {
    final feature = _byName(homeFeature);
    String swatch(int i, AccentChoice accent) =>
        '<label class="accent-dot" title="${_e(t(accent.name))}"><input type="radio" name="accent" value="$i"${i == 0 ? ' checked' : ''}><span class="dot" style="--light:${accent.light};--dark:${accent.dark}"></span><span class="visually-hidden">${_e(t(accent.name))}</span></label>';
    return '''<div class="showcase theme-demo tile">
<div class="phone screen">${_live(root, feature, state: feature.firstStory)}</div>
<div class="showcase-bar capsule edge">
<fieldset class="accents"><legend class="visually-hidden">${_e(t(Copy.accentLabel))}</legend><span class="showcase-label" aria-hidden="true">${_e(t(Copy.accentShort))}</span>${[for (final (i, accent) in accents.indexed) swatch(i, accent)].join()}</fieldset>
<a class="tact small" href="${root}theme/">${_e(t(Copy.themeDemoCta))}${_icon('arrow')}</a>
</div>
</div>
${_features([
      ('check', Copy.themeFeatureContrast, _e(t(Copy.themeFeatureContrastBody))),
      ('code', Copy.themeFeatureCode, _e(t(Copy.themeFeatureCodeBody))),
      ('moon', Copy.themeFeatureModes, _e(t(Copy.themeFeatureModesBody))),
      ('terminal', Copy.themeFeatureApply, _withCode(Copy.themeFeatureApplyBody, {'theme': 'fliin theme --preset'})),
    ])}''';
  }

  /// The update showcase: what `fliin update` prints, in its own format,
  /// for a merged item, an item in conflict and the regenerated tokens;
  /// then what the merge guarantees.
  String _updateDemo() {
    String path(String name, bool Function(ItemFile) which) {
      final file = _byName(name).manifest.files.firstWhere(which);
      return 'lib/ui/fliin/${file.target.alias.name}/${file.target.path}';
    }

    String bump(String name) {
      final v = _byName(name).manifest.version;
      return '${_e('$v')} → ${v.major}.${v.minor + 1}.0';
    }

    String file(Copy label, String kind, String path, [String detail = '']) =>
        '<span class="term-file"><span class="term-$kind">${_e(t(label).padRight(16))}</span> ${_e(path)}${detail.isEmpty ? '' : ' <span class="term-dim">${_e(detail)}</span>'}</span>';
    final conflicted = path('spinner', (f) => f.path.endsWith('.dart'));
    final body = [
      '<span class="term-command">fliin update</span>',
      '<span>button ${bump('button')}</span>',
      file(Copy.updateMerged, 'ok', path('button', (f) => f.path.endsWith('.dart'))),
      '<span>spinner ${bump('spinner')}</span>',
      file(Copy.updateConflict, 'warn', conflicted, t.fill(Copy.updateConflictDetail, {'sidecar': '$conflicted.fliin-new'})),
      '<span>core ${bump('core')}</span>',
      file(Copy.updateRegenerated, 'accent', path('core', (f) => f.path.endsWith('tokens.g.dart')), t(Copy.updateRegeneratedDetail)),
      '<span class="term-dim">${_e(t(Copy.updateAdvice))}</span>',
      '<span class="term-command term-caret"></span>',
    ].join();
    return '''<div class="showcase update-demo tile">
${_window(body, attributes: ' aria-hidden="true"')}
</div>
${_features([
      ('merge', Copy.updateFeatureMerge, _e(t(Copy.updateFeatureMergeBody))),
      ('copy', Copy.updateFeatureSide, _withCode(Copy.updateFeatureSideBody, {'sidecar': '.fliin-new'})),
      ('palette', Copy.updateFeatureTokens, _withCode(Copy.updateFeatureTokensBody, {'tokens': 'tokens.g.dart'})),
      ('alert', Copy.updateFeatureBreaking, _withCode(Copy.updateFeatureBreakingBody, {'check': 'fliin update --check'})),
    ])}''';
  }

  /// The agents showcase: an agent's request, what the MCP server finds,
  /// the item it adds; then what the server does and does not do.
  String _agentsDemo() =>
      '''<div class="showcase agents-demo tile">
<div class="chat" aria-hidden="true"><span class="chat-ask">${_e(t(Copy.agentsDemoAsk))}</span><span class="chat-answer"><span class="chat-title">${_e(t.fill(Copy.agentsDemoFound, {'count': '3'}))}</span><span class="chat-picked">date-range-picker<span>${_e(t(Copy.agentsDemoPicked))}</span></span><span>range-calendar<span>·</span></span><span>calendar<span>·</span></span></span><span class="chat-run"><code>fliin add date-range-picker</code></span></div>
<a class="tact small showcase-cta" href="$guidePath#agents">${_e(t(Copy.agentsCta))}${_icon('arrow')}</a>
</div>
${_features([
      ('search', Copy.agentsFeatureSearch, _e(t(Copy.agentsFeatureSearchBody))),
      ('lock', Copy.agentsFeatureLocal, _e(t(Copy.agentsFeatureLocalBody))),
      ('list', Copy.agentsFeaturePick, _e(t(Copy.agentsFeaturePickBody))),
      ('terminal', Copy.agentsFeatureSetup, _withCode(Copy.agentsFeatureSetupBody, {'init': 'fliin init'})),
    ])}''';

  /// The Pro grid: each screen of [homeScreens] by the top of its first
  /// story, in a phone that the card's foot cuts, its name below.
  String _proScreens(String root) =>
      '<ul class="screen-grid">${[
        for (final (i, name) in homeScreens.indexed)
          '<li class="screen-card tile" style="--i:$i"><div class="screen-stage"><div class="screen-phone">${_screenThumb(root, _byName(name))}</div></div><div class="card-foot"><a class="card-name" href="$root${_byName(name).path}">${_e(_byName(name).english.title)}</a><span class="card-go" aria-hidden="true">${_icon('phone')}</span></div></li>',
      ].join('\n')}</ul>';

  /// Quick start: the commands of a new app or of an existing one, which
  /// the switcher of the section's head chooses, in a terminal window.
  String _quickStart() {
    String panel(String id, List<(String, Copy?)> lines) =>
        '<div class="start-panel" id="start-$id"><ol>${[for (final (i, (command, note)) in lines.indexed) '<li style="--i:$i"><code>${_e(command)}</code>${note == null ? '' : '<span>${_e(t(note))}</span>'}</li>'].join()}</ol></div>';
    return '<div class="showcase start-demo tile">${_window('${panel('new', quickStartNew)}\n${panel('existing', quickStartExisting)}', classes: ' start-lines', attributes: ' aria-live="polite"')}</div>';
  }

  /// The getting started guide (`guide.dart`), in the order of a first use.
  String _guide() {
    const root = '../';
    String text(GuideText block) =>
        _e(
          t.fill(block.copy, {
            ...block.plain,
            for (final MapEntry(:key, :value) in block.labels.entries)
              key: t(value),
          }),
        ).replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
          if (block.code[m[1]] case final code?) {
            return '<code>${_e(code)}</code>';
          }
          if (block.links[m[1]] case final link?) {
            final label = link.label == null
                ? '<code>${_e(link.code!)}</code>'
                : _e(t(link.label!));
            return '<a href="$root${link.path}">$label</a>';
          }
          return m[0]!;
        });
    String html(GuideBlock block) => switch (block) {
      GuideText() => '<p>${text(block)}</p>',
      GuideCode(:final code, lang: 'sh') => _command(code),
      GuideCode(:final code, :final lang) => _code(code, lang: lang),
      GuideList(:final items) =>
        '<ul>${[for (final item in items) '<li>${text(item)}</li>'].join()}</ul>',
    };
    return _page(
      root: root,
      path: guidePath,
      title: _title(t(Copy.guideTitle)),
      tab: _Tab.start,
      current: 'getting-started',
      doc: (
        title: t(Copy.guideTitle),
        lead: _e(t(Copy.guideLead)),
        prompt: null,
        command: null,
        intro: '',
        sections: [
          for (final section in guideSections())
            (
              id: section.id,
              title: t(section.title),
              html: section.blocks.map(html).join('\n'),
            ),
        ],
        outro: '',
      ),
    );
  }

  /// The registry's accent ramp and neutral, as swatches.
  String _swatches() {
    final json = jsonDecode(model.tokens) as Map<String, Object?>;
    final color = json['color']! as Map<String, Object?>;
    final rows = [
      for (final ramp in ['accent', 'neutral'])
        [
          for (final MapEntry(:key, :value)
              in (color[ramp]! as Map<String, Object?>).entries)
            if (value case {r'$value': {'hex': final String hex}}
                when !key.startsWith(r'$'))
              '<span style="--c:$hex" title="${_e('$ramp.$key $hex')}"></span>',
        ].join(),
    ];
    return rows.map((row) => '<div>$row</div>').join();
  }

  // The component list.

  String _components() => _index(
    items: [
      for (final item in model.items)
        if (!item.isBlock && !item.isScreen) item,
    ],
    key: 'components',
    tab: _Tab.components,
    title: Copy.componentsTitle,
    lead: Copy.componentsLead,
  );

  String _blocks() => _index(
    items: model.blocks.toList(),
    key: 'blocks',
    tab: _Tab.blocks,
    title: Copy.blocksTitle,
    lead: Copy.blocksLead,
  );

  String _screens() => _index(
    items: model.screens.toList(),
    key: 'screens',
    tab: _Tab.screens,
    title: Copy.screensTitle,
    lead: Copy.screensLead,
  );

  /// A list of items as thumbnails, by first category, the core last; the
  /// screens in a single grid of phone-height thumbnails.
  String _index({
    required List<SiteItem> items,
    required String key,
    required _Tab tab,
    required Copy title,
    required Copy lead,
  }) {
    const root = '../';
    final groups = <String, List<SiteItem>>{};
    for (final item in items) {
      (groups[item.manifest.categories.first] ??= []).add(item);
    }
    final order = groups.keys.toList()
      ..sort(
        (a, b) => switch ((a == 'foundation', b == 'foundation')) {
          (true, false) => 1,
          (false, true) => -1,
          _ => a.compareTo(b),
        },
      );
    String grid(List<SiteItem> items, {String kind = 'tiles'}) =>
        '<ul class="$kind">${[for (final (i, item) in items.indexed) _card(root, item, item.isScreen ? _screenThumb(root, item) : _thumbnail(root, item), index: i)].join('\n')}</ul>';
    // Some twenty screens in as many categories: grouped by category, each
    // would sit alone on its row.
    final phones = tab == _Tab.screens;
    return _page(
      root: root,
      path: '$key/',
      title: _title(t(title)),
      tab: tab,
      current: key,
      doc: (
        title: t(title),
        lead: _e(t.fill(lead, {'count': '${items.length}'})),
        prompt: null,
        command: null,
        intro: phones ? grid(items, kind: 'tiles phones') : '',
        sections: [
          if (!phones)
            for (final category in order)
              (id: category, title: category, html: grid(groups[category]!)),
        ],
        outro: '',
      ),
    );
  }

  /// An item's thumbnail: the image of its first story, which follows the
  /// site's brightness (`data-themed`), or the palette for the core.
  String _thumbnail(String root, SiteItem item) => switch (item.firstStory) {
    final state? =>
      '<img src="${root}stories/${item.name}/$state.$defaultBrightness.png" srcset="${root}stories/${item.name}/$state.$defaultBrightness.png 2x" data-themed="${root}stories/${item.name}/$state.{b}.png" alt="${_e(t.fill(Copy.storyAlt, {'name': item.english.title, 'state': state}))}" loading="lazy" decoding="async">',
    null => '<div class="swatches">${_swatches()}</div>',
  };

  /// The Import section: the command, and for a Pro item where to get a
  /// license and how to sign in first; then the items it brings along.
  String _import(String root, SiteItem item) {
    final command = 'fliin add ${item.name}';
    final deps = [
      for (final dep in item.manifest.registryDependencies) dep.ref.name,
    ];
    final items = [for (final dep in deps) '<a href="$root${_byName(dep).path}">${_e(dep)}</a>'].join(_e(t(Copy.listSeparator)));
    final also = deps.isEmpty
        ? ''
        : '\n<p>${_withHtml(Copy.alsoInstalls, {'items': items})}</p>';
    if (!item.isPro) {
      final note = deps.isEmpty ? '' : '<span class="command-note">${_withHtml(Copy.alsoInstalls, {'items': items})}</span>';
      return '<p>${_withCode(Copy.installBody, {'init': 'fliin init'})}</p>\n<div class="command-bar tile"><code>${_e(command)}</code>$note${_copyButton(t(Copy.copy), copy: command, classes: 'tact small')}</div>';
    }
    final lead = _e(
      t.fill(Copy.proInstall, {'item': item.english.title}),
    ).replaceAllMapped(
      RegExp(r'\{(\w+)\}'),
      (m) => switch (m[1]) {
        'pro' => '<a href="${root}pro/">${_e(t(Copy.proTitle))}</a>',
        'login' => '<code>fliin login</code>',
        'init' => '<code>fliin init</code>',
        _ => m[0]!,
      },
    );
    return '<p>$lead</p>\n${_command('fliin login\n$command')}$also';
  }

  /// What an agent is asked to do with [item]: a Pro item needs a license.
  String _prompt(SiteItem item) =>
      t.fill(item.isPro ? Copy.promptPro : Copy.prompt, {
        'name': item.name,
        'className': item.className,
        'api': item.api.join('\n'),
      });

  /// The Source section; none for a Pro item, whose code only the Pro
  /// registry serves (ADR 0020 §7).
  _Section? _source(SiteItem item) => item.isPro
      ? null
      : (
          id: 'source',
          title: t(Copy.sourceTitle),
          html:
              '''<p>${_withCode(Copy.sourceBody, {'add': 'fliin add ${item.name}'})}</p>
${[for (final file in item.sources) '<p class="file-name"><code>${_e(file.path)}</code></p>\n${_code(file.text, lang: file.path.endsWith('.json') ? 'json' : 'dart')}'].join('\n')}''',
        );

  /// The pills above a page's preview: the Pro mark, or a link to the
  /// source.
  String _pills(String root, SiteItem item) => item.isPro
      ? _proMark(root, large: true)
      : '<a class="chip edge" href="#source">${_icon('code')}${_e(t(Copy.sourceTitle))}</a>';

  /// "Components / forms": the list the item belongs to, its first
  /// category.
  String _crumbs(String root, SiteItem item) {
    final (list, label) = item.isScreen
        ? ('screens/', Copy.navScreens)
        : item.isBlock
        ? ('blocks/', Copy.navBlocks)
        : ('components/', Copy.navComponents);
    return '<a href="$root$list">${_e(t(label))}</a> / <span class="chip-category">${_e(item.manifest.categories.first)}</span>';
  }

  /// The playground: the stage tile, the sixteen variants that pass, the
  /// one shown, the live story (a screen's in its phone) and the variant
  /// capsule floating at its foot; below, the stories as cards when the
  /// Examples section does not show them. The stage is as tall as the
  /// item's tallest story: changing the story does not move the page.
  String _playground(String root, SiteItem item) {
    String radios(String name, Copy legend, List<(String, Copy)> options, String checked) =>
        '<fieldset class="segmented" style="--n:${options.length}"><legend class="visually-hidden">${_e(t(legend))}</legend>${[for (final (value, label) in options) '<label><input type="radio" name="$name" value="$value"${value == checked ? ' checked' : ''}><span>${_e(t(label))}</span></label>'].join()}</fieldset>';
    final tallest = [
      for (final story in item.stories)
        if (storySizes['${item.name}/$story'] case (:final height, width: _)) height + 32,
    ].fold(item.canvasFor('ios').height, math.max);
    final live = _live(root, item, state: item.firstStory, followsSite: false, id: 'sandbox');
    final stage = item.isScreen
        ? '<div class="phone screen">$live</div>'
        : '<div class="stage-live" style="--stage:${tallest.clamp(240, 560)}px">$live</div>';
    final variant = [t(Copy.platformIos), t(Copy.brightnessDark), t(Copy.scaleOne), t(Copy.dirLtrShort)].join(' · ');
    return '''<section class="preview tile${item.isScreen ? ' screen-preview' : ''}" aria-label="${_e(t(Copy.playground))}" data-playground>
<form class="preview-controls" aria-label="${_e(t(Copy.playground))}">
<div class="preview-stage">
${item.goldens.length == siteVariants.length ? '<span class="stage-pass">${_e(t.fill(Copy.variantsPass, {'count': '${item.goldens.length}', 'total': '${siteVariants.length}'}))}</span>' : ''}<span class="stage-variant" data-variant aria-hidden="true">${_e(variant)}</span>
$stage
<div class="preview-bar capsule edge">
${radios('platform', Copy.controlPlatform, [('ios', Copy.platformIos), ('android', Copy.platformAndroid)], 'ios')}
${radios('brightness', Copy.controlBrightness, [('dark', Copy.brightnessDark), ('light', Copy.brightnessLight)], defaultBrightness)}
${radios('scale', Copy.controlScale, [('1.0', Copy.scaleOne), ('2.0', Copy.scaleTwo)], '1.0')}
${radios('dir', Copy.controlDirection, [('ltr', Copy.dirLtrShort), ('rtl', Copy.dirRtlShort)], 'ltr')}
</div>
</div>
${item.examples.isEmpty ? _statePicker(root, item) : '<input type="hidden" name="state" value="${_e(item.firstStory ?? '')}">'}
</form>
</section>''';
  }

  // An item's page.

  String _item(SiteItem item) {
    const root = '../../';
    final previous = model.previous(item);
    final next = model.next(item);
    final m = item.manifest;
    final api = item.api.join('\n');
    final command = 'fliin add ${item.name}';
    String pager(SiteItem? other, String rel) => other == null
        ? '<span></span>'
        : '<a class="pager-$rel" rel="$rel" href="$root${other.path}"><span class="pager-rel">${_e(t(rel == 'prev' ? Copy.previous : Copy.next))}</span><span class="pager-name">${_e(other.english.title)}</span></a>';
    return _page(
      root: root,
      path: item.path,
      title: _title(item.english.title),
      tab: item.isBlock ? _Tab.blocks : _Tab.components,
      current: item.name,
      crumbs: _crumbs(root, item),
      doc: (
        title: item.english.title,
        lead: _e(item.english.description),
        prompt: _prompt(item),
        command: command,
        intro:
            '<div class="pills">${_pills(root, item)}</div>\n${_playground(root, item)}',
        sections: [
          (id: 'import', title: t(Copy.importTitle), html: _import(root, item)),
          if (item.examples.isNotEmpty)
            (
              id: 'examples',
              title: t(Copy.examplesTitle),
              html: _examples(root, item),
            ),
          if (item.example case final example?)
            (
              id: 'usage',
              title: t(Copy.usageTitle),
              html: '<p>${_e(t(Copy.usageBody))}</p>\n${_code(example)}',
            ),
          (id: 'api', title: t(Copy.apiTitle), html: _code(api)),
          (
            id: 'reference',
            title: t(Copy.goldensTitle),
            html: item.goldens.isEmpty
                ? '<p>${_e(t(Copy.noGoldens))}</p>'
                : '''<p>${_withCode(Copy.goldensBody, {'verify': 'fliin verify ${item.name}'}, {'version': '${m.version}', 'flutter': m.verify!.goldens!.rendering.flutter})}</p>
${_goldens(root, item)}''',
          ),
          (
            id: 'intents',
            title: t(Copy.intentsTitle),
            html:
                '''<ul>${[for (final intent in m.meta.intents.en) '<li>${_e(intent)}</li>'].join()}</ul>
<dl class="facts">
${item.english.notFor.isEmpty ? '' : '<dt>${_e(t(Copy.notForTitle))}</dt><dd><ul>${[for (final not in item.english.notFor) '<li>${_e(not)}</li>'].join()}</ul></dd>'}
${item.states.isEmpty ? '' : '<dt>${_e(t(Copy.statesTitle))}</dt><dd>${_stateTags(item)}</dd>'}
</dl>''',
          ),
          ?_source(item),
        ],
        outro:
            '<nav class="pager" aria-label="${_e(t(Copy.pagerLabel))}">${pager(previous, 'prev')}${pager(next, 'next')}</nav>',
      ),
    );
  }

  // A screen's page.

  /// The preview's stories as cards, each its rendering and its name: the
  /// examples, then the states of `meta.states`, then the
  /// reference render when the item has goldens. The thumbnails follow the
  /// playground's brightness (`site.js`). Only for a screen, or an item
  /// whose stories are not yet examples: the Examples section shows them.
  String _statePicker(String root, SiteItem item) {
    String card(String value, String label, String themed) =>
        '<label class="state-card"><input type="radio" name="state" value="${_e(value)}"${value == (item.firstStory ?? '') ? ' checked' : ''}>'
        '<span class="state-thumb"><img src="${themed.replaceAll('{b}', defaultBrightness)}" data-themed="$themed" alt="" loading="lazy" decoding="async"></span>'
        '<span class="state-name">${_e(label)}</span></label>';
    String story(String name) => card(name, storyLabel(name), '${root}stories/${item.name}/$name.{b}.png');
    String group(Copy legend, List<String> cards) => cards.isEmpty
        ? ''
        : '<fieldset class="state-group"><legend>${_e(t(legend))}</legend><div class="state-list">${cards.join()}</div></fieldset>';
    final states = item.states.toSet();
    return '''<div class="state-picker" role="group" aria-label="${_e(t(Copy.controlState))}">
${group(Copy.examplesTitle, [for (final name in item.stories) if (!states.contains(name)) story(name)])}
${group(Copy.statesTitle, [
      for (final name in item.stories) if (states.contains(name)) story(name),
      if (item.goldens.isNotEmpty && !item.isScreen) card('', t(Copy.stateReference), '${root}goldens/${item.name}/ios.{b}.1.0.ltr.png'),
    ])}
</div>''';
  }

  /// Each example: its name, what it shows, the live story (a screen's in a
  /// phone), and below it the code that renders it, folded.
  String _examples(String root, SiteItem item) => [
    for (final example in item.examples)
      '''<div class="example tile" data-view="preview">
<div class="example-head"><div><h3 id="example-${example.story}">${_e(storyLabel(example.story))}</h3>
<p>${_e(example.description).replaceAllMapped(RegExp('`([^`]+)`'), (m) => '<code>${m[1]}</code>')}</p></div>
<div class="switcher" role="group" aria-label="${_e(t(Copy.exampleView))}" style="--n:2"><button type="button" data-view="preview" aria-pressed="true">${_e(t(Copy.examplePreview))}</button><button type="button" data-view="code" aria-pressed="false">${_e(t(Copy.exampleCode))}</button></div></div>
${item.isScreen ? '<div class="example-stage screen"><div class="phone screen">${_live(root, item, state: example.story, lazy: true)}</div></div>' : '<div class="example-stage" style="--tile:${(storySizes['${item.name}/${example.story}']?.height ?? 208) + 32}px">${_live(root, item, state: example.story, lazy: true)}</div>'}
${_code(applyRewrites(example.code, snippetRender), long: true)}</div>''',
  ].join('\n');

  /// `meta.states` as tags, by name.
  String _stateTags(SiteItem item) =>
      '<ul class="state-tags">${[for (final state in item.states) '<li>${_e(storyLabel(state))}</li>'].join()}</ul>';

  /// A screen: the large phone, its state and variant as pills, then the
  /// installation (Pro), the route and state snippets, the texts, the
  /// phone-format goldens, its uses and its sources.
  String _screen(SiteItem item) {
    const root = '../../';
    final m = item.manifest;
    final command = 'fliin add ${item.name}';
    String snippets(Map<String, String> byKey) => [
      for (final MapEntry(:key, :value) in byKey.entries)
        '<p class="file-name"><code>${_e(key)}</code></p>\n${_code(applyRewrites(value, snippetRender))}',
    ].join('\n');
    final languages = {for (final texts in m.l10n.values) ...texts.keys}
        .toList();
    return _page(
      root: root,
      path: item.path,
      title: _title(item.english.title),
      tab: _Tab.screens,
      current: item.name,
      crumbs: _crumbs(root, item),
      doc: (
        title: item.english.title,
        lead: _e(item.english.description),
        prompt: _prompt(item),
        command: command,
        intro:
            '<div class="pills">${_pills(root, item)}</div>\n${_playground(root, item)}',
        sections: [
          (id: 'import', title: t(Copy.importTitle), html: _import(root, item)),
          if (item.examples.isNotEmpty)
            (
              id: 'examples',
              title: t(Copy.examplesTitle),
              html: _examples(root, item),
            ),
          (
            id: 'routing',
            title: t(Copy.routingTitle),
            html:
                '<p>${_withCode(Copy.routingBody, {'add': command})}</p>\n${snippets(m.snippets.route)}',
          ),
          (
            id: 'state',
            title: t(Copy.stateTitle),
            html:
                '<p>${_withCode(Copy.stateBody, {'add': command})}</p>\n${snippets(m.snippets.state)}'
                '${m.snippets.screens.isEmpty ? '' : '\n<p>${_withHtml(Copy.snippetScreens, {
                        'items': [for (final screen in m.snippets.screens) '<a href="$root${_byName(screen).path}"><code>${_e(screen)}</code></a>'].join(_e(t(Copy.listSeparator))),
                      })}</p>'}',
          ),
          (id: 'api', title: t(Copy.apiTitle), html: _code(item.api.join('\n'))),
          if (m.l10n.isNotEmpty)
            (
              id: 'strings',
              title: t(Copy.stringsTitle),
              html:
                  '''<p>${_e(t(Copy.stringsBody))}</p>
<div class="table-wrap"><table class="strings">
<thead><tr><th scope="col">${_e(t(Copy.stringsKey))}</th>${[for (final language in languages) '<th scope="col"><code>${_e(language)}</code></th>'].join()}</tr></thead>
<tbody>
${[
                    for (final MapEntry(:key, :value) in m.l10n.entries) '<tr><th scope="row"><code>${_e(key)}</code></th>${[for (final language in languages) '<td lang="$language"${language == 'ar' ? ' dir="rtl"' : ''}>${_e(value[language] ?? '')}</td>'].join()}</tr>',
                  ].join('\n')}
</tbody>
</table></div>''',
            ),
          (
            id: 'reference',
            title: t(Copy.goldensTitle),
            html: item.goldens.isEmpty
                ? '<p>${_e(t(Copy.noGoldens))}</p>'
                : '''<p>${_withCode(Copy.screenGoldensBody, {'verify': 'fliin verify ${item.name}'}, {'version': '${m.version}', 'flutter': m.verify!.goldens!.rendering.flutter})}</p>
${_goldens(root, item)}''',
          ),
          (
            id: 'intents',
            title: t(Copy.intentsTitle),
            html:
                '''<ul>${[for (final intent in m.meta.intents.en) '<li>${_e(intent)}</li>'].join()}</ul>
<dl class="facts">
${item.english.notFor.isEmpty ? '' : '<dt>${_e(t(Copy.notForTitle))}</dt><dd><ul>${[for (final not in item.english.notFor) '<li>${_e(not)}</li>'].join()}</ul></dd>'}
<dt>${_e(t(Copy.statesTitle))}</dt><dd>${_stateTags(item)}</dd>
</dl>''',
          ),
          ?_source(item),
        ],
        outro: '',
      ),
    );
  }

  /// The sixteen goldens by platform and brightness, one row of four (text
  /// size and direction) each. The empty background below a component is
  /// cropped; a screen fills its canvas and stays whole.
  String _goldens(String root, SiteItem item) {
    final groups = <String, List<SiteVariant>>{};
    for (final v in siteVariants) {
      (groups['${v.platform}.${v.brightness}'] ??= []).add(v);
    }
    String figure(SiteVariant v) {
      final canvas = item.canvasFor(v.platform);
      final height = item.isScreen ? null : item.goldenHeights[v.id];
      final crop = height == null || height >= canvas.height
          ? ''
          : ' style="aspect-ratio:${canvas.width}/$height"';
      final caption = t.fill(Copy.variantDetail, {
        'scale': t(v.scale == '1.0' ? Copy.scaleOne : Copy.scaleTwo),
        'dir': t(v.dir == 'ltr' ? Copy.dirLtr : Copy.dirRtl),
      });
      return '<figure><div class="golden-frame"$crop><img src="${root}goldens/${item.name}/${v.id}.png" alt="${_e(_goldenAlt(item, v))}" width="${canvas.width}" height="${canvas.height}" loading="lazy"></div><figcaption>${_e(caption)}</figcaption></figure>';
    }

    String group(List<SiteVariant> variants) {
      final v = variants.first;
      final title = t.fill(Copy.variantGroup, {
        'platform': t(
          v.platform == 'ios' ? Copy.platformIos : Copy.platformAndroid,
        ),
        'brightness': t(
          v.brightness == 'light' ? Copy.brightnessLight : Copy.brightnessDark,
        ),
      });
      return '<figure class="golden-group"><figcaption>${_e(title)}</figcaption><div class="golden-row">\n${variants.map(figure).join('\n')}\n</div></figure>';
    }

    return '<div class="goldens${item.isScreen ? ' wide' : ''}">\n${groups.values.map(group).join('\n')}\n</div>';
  }

  String _title(String page) =>
      t.fill(Copy.pageTitle, {'page': page, 'brand': t(Copy.brand)});

  /// Returns [copy] escaped, each `{name}` replaced by the already escaped
  /// HTML of [html].
  String _withHtml(Copy copy, Map<String, String> html) =>
      _e(t(copy))
          .replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => html[m[1]] ?? m[0]!);

  // The theme page: the settings of a preset (ADR 0016), the preview.

  /// The overall styles, shadcn style: each sets at once the shape, the
  /// spacing, the shadows, the cards, the borders, the text size and the
  /// fonts, without touching the colors or the icons; each setting can then
  /// be adjusted. A style is not in the code: it writes fields
  /// (ADR 0016 §3.9).
  static const studioStyles = [
    (label: Copy.styleDefault, hint: Copy.styleDefaultHint, preset: Preset()),
    (
      label: Copy.styleCrisp,
      hint: Copy.styleCrispHint,
      preset: Preset(
        radius: PresetRadius.small,
        shadow: PresetShadow.none,
        cards: PresetCards.outlined,
        body: PresetFamily.inter,
      ),
    ),
    (
      label: Copy.styleSoft,
      hint: Copy.styleSoftHint,
      preset: Preset(
        radius: PresetRadius.large,
        spacing: PresetSpacing.relaxed,
        button: ButtonShape.pill,
        body: PresetFamily.figtree,
      ),
    ),
    (
      label: Copy.styleCompact,
      hint: Copy.styleCompactHint,
      preset: Preset(
        radius: PresetRadius.small,
        spacing: PresetSpacing.compact,
        text: PresetTextSize.small,
        body: PresetFamily.geist,
      ),
    ),
    (
      label: Copy.styleEditorial,
      hint: Copy.styleEditorialHint,
      preset: Preset(
        radius: PresetRadius.small,
        shadow: PresetShadow.none,
        cards: PresetCards.outlined,
        body: PresetFamily.publicSans,
        heading: PresetFamily.playfairDisplay,
      ),
    ),
    (
      label: Copy.styleTerminal,
      hint: Copy.styleTerminalHint,
      preset: Preset(
        radius: PresetRadius.none,
        spacing: PresetSpacing.compact,
        shadow: PresetShadow.none,
        button: ButtonShape.square,
        cards: PresetCards.outlined,
        border: PresetBorder.medium,
        body: PresetFamily.jetBrainsMono,
      ),
    ),
  ];

  /// The fields a style sets.
  static const studioStyleFields = [
    'radius',
    'spacing',
    'shadow',
    'button',
    'cards',
    'border',
    'text',
    'body',
    'heading',
  ];

  /// The ready-made presets, colors included: a style, a base and a primary
  /// from the mix, whose contrast `preset_contrast_test.dart` proves.
  static const studioGallery = [
    (label: Copy.galleryDefault, preset: Preset()),
    (
      label: Copy.galleryOcean,
      preset: Preset(
        base: PresetBase.slate,
        primary: PresetPrimary.sky,
        radius: PresetRadius.small,
        shadow: PresetShadow.none,
        cards: PresetCards.outlined,
        body: PresetFamily.inter,
      ),
    ),
    (
      label: Copy.galleryForest,
      preset: Preset(
        base: PresetBase.stone,
        primary: PresetPrimary.emerald,
        radius: PresetRadius.small,
        shadow: PresetShadow.none,
        cards: PresetCards.outlined,
        body: PresetFamily.publicSans,
        heading: PresetFamily.lora,
      ),
    ),
    (
      label: Copy.galleryGrape,
      preset: Preset(
        base: PresetBase.mauve,
        primary: PresetPrimary.violet,
        radius: PresetRadius.large,
        spacing: PresetSpacing.relaxed,
        button: ButtonShape.pill,
        menu: PresetMenu.tinted,
        body: PresetFamily.figtree,
      ),
    ),
    (
      label: Copy.galleryMidnight,
      preset: Preset(
        base: PresetBase.slate,
        primary: PresetPrimary.indigo,
        radius: PresetRadius.small,
        spacing: PresetSpacing.compact,
        text: PresetTextSize.small,
        menu: PresetMenu.tinted,
        body: PresetFamily.geist,
      ),
    ),
    (
      label: Copy.galleryMono,
      preset: Preset(
        base: PresetBase.neutral,
        primary: PresetPrimary.lime,
        radius: PresetRadius.none,
        spacing: PresetSpacing.compact,
        shadow: PresetShadow.none,
        button: ButtonShape.square,
        cards: PresetCards.outlined,
        border: PresetBorder.medium,
        body: PresetFamily.jetBrainsMono,
      ),
    ),
    (
      label: Copy.gallerySand,
      preset: Preset(
        base: PresetBase.stone,
        primary: PresetPrimary.teal,
        radius: PresetRadius.large,
        text: PresetTextSize.large,
        body: PresetFamily.dmSans,
        heading: PresetFamily.ebGaramond,
      ),
    ),
    (
      label: Copy.galleryCitrus,
      preset: Preset(
        base: PresetBase.olive,
        primary: PresetPrimary.yellow,
        radius: PresetRadius.large,
        button: ButtonShape.pill,
        body: PresetFamily.outfit,
      ),
    ),
  ];

  String _theme() {
    const root = '../';
    const preset = Preset();
    final code = preset.encode();
    final indices = preset.indices;
    final previewFonts = '$root${catalog}assets/fonts/preview/';
    String family(PresetFamily family) =>
        'Fliin Preview ${previewFontFile(family)}';
    // A setting in the manner of shadcn/create: a row that shows its name,
    // its value and a preview, and opens onto its options. Only one open at
    // a time (`name` of the <details>). The lock is outside the <summary>,
    // which does not accept an interactive element.
    String picker(
      String field,
      Copy label,
      String value,
      String art,
      String menu, {
      bool lock = true,
    }) =>
        '<div class="picker" data-field="$field"><details name="studio-picker"><summary><span class="picker-text"><span class="picker-label">${_e(t(label))}</span><span class="picker-value" data-picker-value>${_e(value)}</span></span><span class="picker-art" data-picker-art aria-hidden="true">$art</span>${_icon('chevron')}</summary><div class="picker-menu">$menu</div></details>${lock ? '<button type="button" class="studio-lock" data-lock="$field" aria-pressed="false" aria-label="${_e(t.fill(Copy.lockField, {'field': t(label)}))}" title="${_e(t.fill(Copy.lockField, {'field': t(label)}))}">${_icon('lock')}</button>' : ''}</div>';
    // Its options: radio buttons, each with a preview of its value.
    String options(String name, Copy label, List<(String, String)> options) =>
        '<fieldset class="picker-options"><legend class="visually-hidden">${_e(t(label))}</legend>${[for (final (i, (text, sample)) in options.indexed) '<label class="picker-option"><input type="radio" name="$name" value="$i"${i == indices[name] ? ' checked' : ''}><span class="picker-glyph" aria-hidden="true">$sample</span><span class="picker-name">${_e(text)}</span>${_icon('check')}</label>'].join()}</fieldset>';
    String choices(String name, Copy label, List<(String, String)> list, {String extra = ''}) {
      final (value, art) = list[indices[name]!];
      return picker(name, label, value, art, options(name, label, list) + extra);
    }

    String swatch(String hex) =>
        '<span class="swatch" style="--c:$hex" aria-hidden="true"></span>';
    String fontGlyph(PresetFamily? f) =>
        '<span class="glyph font-glyph"${f == null ? '' : ' style="font-family:&quot;${family(f)}&quot;"'}>${_e(t(Copy.fontSample))}</span>';
    String corner(double scale) {
      final r = (10 * math.min(scale, 1.5) / 1.5).toStringAsFixed(1);
      return '<svg class="glyph" aria-hidden="true" viewBox="0 0 20 20"><path d="M4 17V${(4 + double.parse(r)).toStringAsFixed(1)}a$r $r 0 0 1 $r-$r H16"/></svg>';
    }

    String bar(double radius, {double stroke = 1.5, bool filled = false}) =>
        '<svg class="glyph" aria-hidden="true" viewBox="0 0 24 20"><rect x="2" y="5" width="20" height="10" rx="$radius" stroke-width="$stroke"${filled ? ' class="filled"' : ''}/></svg>';
    String lines(double scale) =>
        '<svg class="glyph" aria-hidden="true" viewBox="0 0 20 20"><path d="M3 ${10 - 5 * scale}h14M3 10h14M3 ${10 + 5 * scale}h14"/></svg>';
    String textSample(double scale) =>
        '<span class="glyph text-glyph" style="font-size:${(13 * scale).toStringAsFixed(1)}px" aria-hidden="true">${_e(t(Copy.fontSample))}</span>';
    String icon(PresetIcons set) => switch (iconSamples[set]) {
      final svg? =>
        '<span class="glyph icon-glyph" aria-hidden="true">$svg</span>',
      null => '',
    };
    String card(String kind) =>
        '<span class="glyph card-glyph $kind" aria-hidden="true"></span>';
    String tile(String name, String state) {
      final item = _byName(name);
      if (item.isScreen) {
        return '<li class="studio-tile phone-tile"><div class="phone">${_live(root, item, state: state, brightness: studioBrightness, followsSite: false, lazy: true)}</div></li>';
      }
      final height = (storySizes['$name/$state']?.height ?? 208) + 32;
      return '<li class="studio-tile" style="--tile:${height}px">${_live(root, item, state: state, brightness: studioBrightness, followsSite: false, lazy: true)}</li>';
    }

    String segment(String name, Copy legend, List<(String, Copy)> options, String checked) =>
        '<fieldset class="segmented" style="--n:${options.length}"><legend class="visually-hidden">${_e(t(legend))}</legend>${[for (final (value, label) in options) '<label><input type="radio" name="$name" value="$value"${value == checked ? ' checked' : ''}><span>${_e(t(label))}</span></label>'].join()}</fieldset>';
    String vignette(Copy label, Preset preset) =>
        '<button type="button" class="studio-vignette" data-gallery="${preset.encode()}" aria-pressed="false" style="${_e(_galleryStyle(preset))}"><span class="vignette-art" aria-hidden="true"><span class="vignette-card"><span></span><span></span></span><span class="vignette-button"></span></span><span class="vignette-name">${_e(t(label))}</span></button>';
    // A short setting: its name, its lock, its values as chips (or orbs).
    String lock(String field, Copy label) =>
        '<button type="button" class="studio-lock" data-lock="$field" aria-pressed="false" aria-label="${_e(t.fill(Copy.lockField, {'field': t(label)}))}" title="${_e(t.fill(Copy.lockField, {'field': t(label)}))}">${_icon('lock')}</button>';
    String chips(String name, Copy label, List<(String, String)> list, {String kind = 'studio-chips', String option = 'opt', bool named = true}) =>
        '<div class="studio-field"><div class="studio-group-head"><h3 class="studio-label" id="field-$name">${_e(t(label))}</h3>${lock(name, label)}</div><fieldset class="$kind" aria-labelledby="field-$name">${[for (final (i, (text, glyph)) in list.indexed) '<label class="$option"${named ? '' : ' title="${_e(text)}"'}><input type="radio" name="$name" value="$i"${i == indices[name] ? ' checked' : ''}>${named ? '<span>$glyph${_e(text)}</span>' : '$glyph<span class="visually-hidden">${_e(text)}</span>'}</label>'].join()}</fieldset></div>';

    final fontFaces = [
      for (final f in PresetFamily.values)
        '@font-face{font-family:"${family(f)}";src:url("$previewFonts${previewFontFile(f)}-400.ttf") format("truetype");font-display:swap}',
    ].join();
    final core = model.items.firstWhere((item) => item.isFoundation);
    final gallery =
        '<div class="studio-gallery">${[for (final entry in studioGallery) vignette(entry.label, entry.preset)].join()}</div>';
    final styles =
        '<div class="studio-chips">${[for (final (i, style) in studioStyles.indexed) '<button type="button" class="studio-style" data-style="$i" aria-pressed="${i == 0}" title="${_e(t(style.hint))}"><span class="style-name">${_e(t(style.label))}</span></button>'].join()}</div>';
    final orbs = [
      for (final primary in PresetPrimary.values)
        (
          t(primary.hex == null ? Copy.primaryCustom : _primaryLabel(primary)),
          switch (primary.hex) {
            final hex? => swatch(hex),
            null =>
              '<span class="swatch" style="--c:conic-gradient(${[
                for (final primary in [PresetPrimary.rose, PresetPrimary.amber, PresetPrimary.lime, PresetPrimary.cyan, PresetPrimary.indigo, PresetPrimary.fuchsia, PresetPrimary.rose]) primary.hex,
              ].join(',')})" aria-hidden="true"></span>',
          },
        ),
    ];
    String glyph(String html) => '<span class="glyph" aria-hidden="true">$html</span>';
    final intro =
        '''<noscript><p>${_e(t(Copy.themeNeedsScript))}</p>${_command('fliin theme --preset $code')}</noscript>
<div class="studio">
<form class="studio-panel tile" data-preset-builder aria-label="${_e(t(Copy.themeControls))}" data-custom="${_e(t(Copy.primaryCustom))}">
<div class="studio-intro"><h1>${_e(t(Copy.themeTitle))}</h1><p>${_e(t(Copy.themeLead))}</p></div>
<div class="studio-scroll">
<section class="studio-group" aria-labelledby="group-presets"><div class="studio-group-head"><h2 id="group-presets">${_e(t(Copy.groupPresets))}</h2><div class="studio-history"><button type="button" class="icon-button" data-preset-undo aria-label="${_e(t(Copy.presetUndo))}" aria-keyshortcuts="Meta+Z Control+Z" disabled>${_icon('undo')}</button><button type="button" class="icon-button" data-preset-redo aria-label="${_e(t(Copy.presetRedo))}" aria-keyshortcuts="Meta+Shift+Z Control+Shift+Z" disabled>${_icon('redo')}</button></div></div>
$gallery
</section>
<section class="studio-group" aria-labelledby="group-style"><h2 id="group-style">${_e(t(Copy.groupStyle))}</h2>
$styles
</section>
<section class="studio-group" aria-labelledby="group-colors"><h2 id="group-colors" class="visually-hidden">${_e(t(Copy.groupColors))}</h2>
${chips('primary', Copy.presetPrimary, orbs, kind: 'orbs', option: 'orb', named: false)}
<div class="studio-brand" data-brand hidden><input type="color" name="brand" value="#0a6cff" aria-label="${_e(t(Copy.brandLabel))}"><input type="text" name="brandHex" value="#0A6CFF" maxlength="7" spellcheck="false" autocomplete="off" aria-label="${_e(t(Copy.brandLabel))}"></div><p class="studio-nearest" data-nearest hidden><span></span><button type="button" class="tact small" data-use-nearest></button></p>
${chips('base', Copy.presetBase, [for (final base in PresetBase.values) (t(_baseLabel(base)), swatch(base.tone.step('448').hex))])}
</section>
<section class="studio-group" aria-labelledby="group-type"><h2 id="group-type">${_e(t(Copy.groupTypography))}</h2>
${choices('heading', Copy.presetHeading, [(t(Copy.headingInherit), fontGlyph(null)), for (final f in PresetFamily.values) (f.family, fontGlyph(f))])}
${choices('body', Copy.presetBody, [(t(Copy.bodySystem), fontGlyph(null)), for (final f in PresetFamily.values) (f.family, fontGlyph(f))])}
${choices('text', Copy.presetText, [for (final text in PresetTextSize.values) (t(_textLabel(text)), textSample(text.scale))])}
</section>
<section class="studio-group" aria-labelledby="group-shape"><h2 id="group-shape" class="visually-hidden">${_e(t(Copy.groupShape))}</h2>
${chips('radius', Copy.presetRadius, [for (final radius in PresetRadius.values) (t(_radiusLabel(radius)), glyph(corner(radius.scale)))])}
${chips('button', Copy.presetButton, [for (final button in presetButtons) (t(_buttonLabel(button)), glyph(bar(switch (button) {
            ButtonShape.square => 0,
            ButtonShape.rounded => 3,
            ButtonShape.pill => 5,
          })))])}
</section>
<section class="studio-group" aria-labelledby="group-more"><h2 id="group-more">${_e(t(Copy.groupMore))}</h2>
<div class="studio-more">
${choices('menu', Copy.presetMenu, [(t(Copy.valueDefault), bar(3)), (t(Copy.menuTinted), bar(3, filled: true))])}
${choices('border', Copy.presetBorder, [for (final border in PresetBorder.values) (t(_borderLabel(border)), bar(2, stroke: 1.2 * border.scale))])}
${choices('cards', Copy.presetCards, [for (final cards in PresetCards.values) (t(_cardsLabel(cards)), card(cards.name))])}
${choices('shadow', Copy.presetShadow, [for (final shadow in PresetShadow.values) (t(_shadowLabel(shadow)), card(shadow == PresetShadow.none ? 'flat' : 'raised'))])}
${choices('spacing', Copy.presetSpacing, [for (final spacing in PresetSpacing.values) (t(_spacingLabel(spacing)), lines(spacing.scale))])}
${choices('icons', Copy.presetIcons, [for (final icons in PresetIcons.values) (icons.label, icon(icons))])}
${choices('motion', Copy.presetMotion, [for (final motion in PresetMotion.values) (t(_motionLabel(motion)), '<span class="glyph motion-glyph ${motion.name}" aria-hidden="true"></span>')])}
</div>
</section>
</div>
<div class="studio-actions">
<div class="studio-row"><button type="button" class="tact small" data-preset-load aria-haspopup="dialog">${_e(t(Copy.presetLoad))}</button><button type="button" class="tact small" data-preset-link data-copy="">${_icon('link')}<span class="copy-label">${_e(t(Copy.presetCopyLink))}</span></button></div>
<p class="theme-status" role="status"></p>
</div>
</form>
<section class="studio-preview tile" aria-label="${_e(t(Copy.previewRegion))}">
<div class="studio-bar"><div class="studio-tabs" role="tablist" aria-label="${_e(t(Copy.previewSections))}">${[for (final (i, tab) in studioTabs.indexed) '<button type="button" role="tab" id="studio-tab-${tab.id}" aria-controls="studio-${tab.id}" aria-selected="${i == 0}"${i == 0 ? '' : ' tabindex="-1"'}>${_e(t(tab.label))}</button>'].join()}</div></div>
<div class="studio-dock"><div class="studio-capsule capsule">
<button type="button" class="studio-code" data-copy="--preset $code" aria-label="${_e(t.fill(Copy.presetCopy, {'code': '--preset $code'}))}"><code data-preset-code>--preset $code</code>${_icon('copy', 'copy-icon')}${_icon('check', 'copy-check')}</button>
<button type="button" class="tact small" data-preset-shuffle>${_icon('shuffle')}${_e(t(Copy.presetShuffle))}</button>
<button type="button" class="tact small accent" data-preset-get aria-haspopup="dialog">${_e(t(Copy.presetGetCode))}</button>
<div class="studio-variants">${segment('brightness', Copy.previewBrightness, [('dark', Copy.brightnessDark), ('light', Copy.brightnessLight)], studioBrightness)}${segment('dir', Copy.previewDirection, [('ltr', Copy.dirLtrShort), ('rtl', Copy.dirRtlShort)], 'ltr')}</div>
</div></div>
${[
          for (final (i, tab) in studioTabs.indexed) '<div class="studio-tab-panel" role="tabpanel" id="studio-${tab.id}" aria-labelledby="studio-tab-${tab.id}"${i == 0 ? '' : ' hidden'}><ul class="studio-grid${tab.id == 'screens' ? ' phones' : ''}">${[for (final (name, state) in tab.tiles) tile(name, state)].join('\n')}</ul></div>',
        ].join('\n')}
</section>
</div>
<dialog class="studio-dialog" data-load-dialog aria-labelledby="load-title">
<form method="dialog" class="studio-dialog-body">
<h2 id="load-title">${_e(t(Copy.loadTitle))}</h2>
<label class="studio-field"><span>${_e(t(Copy.loadLabel))}</span><input type="text" name="code" maxlength="200" spellcheck="false" autocomplete="off" placeholder="$code"></label>
<p class="studio-error" role="alert"></p>
<div class="studio-dialog-actions"><button type="button" class="studio-button" data-dialog-close>${_e(t(Copy.cancel))}</button><button type="submit" class="studio-button strong">${_e(t(Copy.loadSubmit))}</button></div>
</form>
</dialog>
<dialog class="studio-dialog wide" data-code-dialog aria-labelledby="code-title">
<div class="studio-dialog-body">
<div class="studio-dialog-head"><h2 id="code-title">${_e(t(Copy.presetGetCode))}</h2><button type="button" class="icon-button" data-dialog-close aria-label="${_e(t(Copy.close))}">${_icon('close')}</button></div>
<h3>${_e(t(Copy.codeNewApp))}</h3>
<div data-code-init>${_command('fliin init --preset $code')}</div>
<h3>${_e(t(Copy.codeExisting))}</h3>
<div data-code-theme>${_command('fliin theme --preset $code')}</div>
<div data-code-fonts hidden>
<h3>${_e(t(Copy.codeFonts))}</h3>
<p>${_e(t(Copy.codeFontsBody))}</p>
<ul class="studio-fonts" data-code-font-links></ul>
<div data-code-pubspec>${_code('', lang: 'yaml')}</div>
</div>
<h3>${_e(t(Copy.codeTokens))}</h3>
<p>${_e(t.fill(Copy.codeTokensBody, {'version': '${core.manifest.version}'}))}</p>
<div data-code-tokens>${_code('', lang: 'json', copy: Copy.copyTokens, long: true)}</div>
</div>
</dialog>''';
    return _page(
      root: root,
      path: 'theme/',
      title: _title(t(Copy.themeTitle)),
      tab: _Tab.theme,
      current: 'theme',
      landing: true,
      scripts:
          '<style>$fontFaces</style>\n<script type="application/json" id="fliin-tokens">${_scriptSafe(model.tokens)}</script>\n<script src="${root}assets/theme.js" defer></script>\n',
      extra: {
        'preset': code,
        'iconSets': [for (final icons in PresetIcons.values) icons.name],
        'styles': [
          for (final style in studioStyles)
            {
              for (final name in studioStyleFields)
                name: style.preset.indices[name],
            },
        ],
      },
      doc: (
        title: t(Copy.themeTitle),
        lead: _e(t(Copy.themeLead)),
        prompt: null,
        command: null,
        intro: intro,
        sections: const [],
        outro: '',
      ),
    );
  }

  /// The colors and shapes of a thumbnail, resolved as the CLI would write
  /// them, as CSS properties: background, card (the menu background when
  /// menus are tinted), accent and text, in light (`--v-`) and dark
  /// (`--vd-`), then the radius of the card and of the button.
  String _galleryStyle(Preset preset) {
    final tokens = jsonDecode(model.tokens);
    final result = switch (applyPreset(tokens, tokens, preset)) {
      ThemeSolved(:final patch) => applyJsonPatch(tokens, patch),
      Unsatisfiable() => tokens,
    };
    final resolved = FliinTokens.read(
      resolveTokens(TokenDocument.fromJson(result)),
    );
    final card = preset.menu == PresetMenu.tinted
        ? 'surfaceOverlay'
        : 'surfaceRaised';
    String colors(String prefix, Map<String, int> roles) => [
      for (final (name, role) in [
        ('surface', 'surface'),
        ('card', card),
        ('accent', 'accent'),
        ('text', 'onSurface'),
      ])
        '--$prefix-$name:${Rgb8(roles[role]!).hex}',
    ].join(';');
    final button = switch (preset.button) {
      ButtonShape.pill => '999px',
      ButtonShape.rounded => '3px',
      ButtonShape.square => '0',
    };
    return '${colors('v', resolved.light)};${colors('vd', resolved.dark)};--v-radius:${(6 * preset.radius.scale).toStringAsFixed(1)}px;--v-button:$button';
  }

  Copy _baseLabel(PresetBase base) => switch (base) {
    PresetBase.sand => Copy.baseSand,
    PresetBase.zinc => Copy.baseZinc,
    PresetBase.neutral => Copy.baseNeutral,
    PresetBase.stone => Copy.baseStone,
    PresetBase.slate => Copy.baseSlate,
    PresetBase.mauve => Copy.baseMauve,
    PresetBase.olive => Copy.baseOlive,
  };

  Copy _primaryLabel(PresetPrimary primary) => switch (primary) {
    PresetPrimary.blue => Copy.valueDefault,
    PresetPrimary.indigo => Copy.primaryIndigo,
    PresetPrimary.violet => Copy.primaryViolet,
    PresetPrimary.purple => Copy.primaryPurple,
    PresetPrimary.fuchsia => Copy.primaryFuchsia,
    PresetPrimary.pink => Copy.primaryPink,
    PresetPrimary.rose => Copy.primaryRose,
    PresetPrimary.red => Copy.primaryRed,
    PresetPrimary.orange => Copy.primaryOrange,
    PresetPrimary.amber => Copy.primaryAmber,
    PresetPrimary.yellow => Copy.primaryYellow,
    PresetPrimary.lime => Copy.primaryLime,
    PresetPrimary.green => Copy.primaryGreen,
    PresetPrimary.emerald => Copy.primaryEmerald,
    PresetPrimary.teal => Copy.primaryTeal,
    PresetPrimary.cyan => Copy.primaryCyan,
    PresetPrimary.sky => Copy.primarySky,
    PresetPrimary.azure => Copy.primaryAzure,
    PresetPrimary.custom => Copy.primaryCustom,
  };

  Copy _textLabel(PresetTextSize text) => switch (text) {
    PresetTextSize.regular => Copy.valueDefault,
    PresetTextSize.small => Copy.textSmall,
    PresetTextSize.large => Copy.textLarge,
  };

  Copy _borderLabel(PresetBorder border) => switch (border) {
    PresetBorder.regular => Copy.valueDefault,
    PresetBorder.medium => Copy.borderMedium,
    PresetBorder.bold => Copy.borderBold,
  };

  Copy _cardsLabel(PresetCards cards) => switch (cards) {
    PresetCards.raised => Copy.cardsRaised,
    PresetCards.outlined => Copy.cardsOutlined,
  };

  Copy _motionLabel(PresetMotion motion) => switch (motion) {
    PresetMotion.regular => Copy.valueDefault,
    PresetMotion.fast => Copy.motionFast,
    PresetMotion.slow => Copy.motionSlow,
  };

  Copy _radiusLabel(PresetRadius radius) => switch (radius) {
    PresetRadius.standard => Copy.valueDefault,
    PresetRadius.none => Copy.radiusNone,
    PresetRadius.small => Copy.radiusSmall,
    PresetRadius.large => Copy.radiusLarge,
  };

  Copy _spacingLabel(PresetSpacing spacing) => switch (spacing) {
    PresetSpacing.standard => Copy.valueDefault,
    PresetSpacing.compact => Copy.spacingCompact,
    PresetSpacing.relaxed => Copy.spacingRelaxed,
  };

  Copy _shadowLabel(PresetShadow shadow) => switch (shadow) {
    PresetShadow.standard => Copy.valueDefault,
    PresetShadow.none => Copy.shadowNone,
  };

  Copy _buttonLabel(ButtonShape button) => switch (button) {
    ButtonShape.rounded => Copy.shapeRounded,
    ButtonShape.pill => Copy.shapePill,
    ButtonShape.square => Copy.shapeSquare,
  };

  // The Fliin Pro page and the licenses.

  /// `/pro/` (ADR 0020 §7): what Fliin Pro holds, counted from the
  /// manifests, some screens, the plans of [plans], how a purchase reaches
  /// the CLI, and the questions a buyer asks.
  String _pro() {
    const root = '../';
    final blocks = model.blocks.where((item) => item.isPro).length;
    final screens = model.screens.where((item) => item.isPro).length;
    // The icons item is named on its own in the sentence.
    final components = model.components
        .where((item) => !item.isPro && item.name != 'icons')
        .length;
    final counts = {'blocks': '$blocks', 'screens': '$screens'};
    String code(String text) => '<code>${_e(text)}</code>';
    String sentence(Copy copy, [Map<String, String> html = const {}]) =>
        _withHtml(copy, html);
    String price(num amount) => t.fill(Copy.planPrice, {
      'amount': amount is int ? '$amount' : amount.toStringAsFixed(2),
    });
    final mit = '<a href="${root}license/">${_e(t(Copy.mitLicense))}</a>';
    final license =
        '<a href="${root}pro/license/">${_e(t(Copy.proLicense))}</a>';
    final cheapest = plans.map((plan) => plan.price).reduce(math.min);
    // The middle column, the plan for one developer: no "most popular",
    // which nothing measures.
    final featured = plans.where((plan) => plan.seats == 1).firstOrNull;
    String name(ProPlan plan) => switch (plan.kind) {
      ProPlanKind.solo => t(Copy.planSolo),
      ProPlanKind.team => t(Copy.planTeam),
    };
    String features(List<(String, String)> lines) =>
        '<ul class="price-features">${[for (final (icon, html) in lines) '<li>${_icon(icon)}<span>$html</span></li>'].join()}</ul>';
    String plus(String plan) =>
        '<p class="price-plus">${_e(t.fill(Copy.planPlus, {'plan': plan}))}</p>';
    final free = '''<article class="price-col" aria-labelledby="plan-free">
<div class="price-head"><h3 id="plan-free">${_e(t(Copy.planFree))}</h3></div>
<p class="plan-seats">${_e(t(Copy.planFreeFor))}</p>
<p class="plan-price"><span class="plan-amount">${_e(price(0))}</span></p>
<p class="plan-terms"><span>${_withHtml(Copy.planFreeTerm, {'mit': mit})}</span></p>
${features([
      ('terminal', _e(t(Copy.planFreeTools))),
      ('components', _e(t.fill(Copy.planFreeComponents, {'components': '$components'}))),
      ('palette', _e(t(Copy.planFreeTheme))),
      ('check', _e(t(Copy.planFreeVerify))),
      ('merge', _e(t(Copy.planFreeUpdate))),
    ])}
<a class="tact large price-cta" href="$root$guidePath">${_e(t(Copy.planFreeCta))}</a>
</article>''';
    String plan(ProPlan plan) {
      final seats = switch (plan.kind) {
        ProPlanKind.solo => t(Copy.planSoloSeats),
        ProPlanKind.team => t.fill(Copy.planTeamSeats, {'seats': '${plan.seats}'}),
      };
      final lead = identical(plan, featured);
      final buy = plan.checkout.isEmpty
          ? '<button type="button" class="tact large plan-buy" disabled>${_e(t(Copy.planSoon))}</button>'
          : '<a class="tact${lead ? ' invert' : ''} large plan-buy" href="${_e(plan.checkout)}" rel="noopener">${_e(t.fill(Copy.planBuy, {'plan': name(plan)}))}</a>';
      final id = 'plan-${plan.kind.name}';
      final launch = plan.regular > plan.price;
      final off = ((plan.regular - plan.price) * 100 / plan.regular).round();
      final lines = switch (plan.kind) {
        ProPlanKind.solo => [
          ('blocks', _e(t.fill(Copy.planBlocks, counts))),
          ('phone', _e(t.fill(Copy.planScreens, counts))),
          ('code', _e(t(Copy.planControllers))),
          ('book', _e(t(Copy.planStrings))),
          ('sparkle', _e(t(Copy.planNew))),
          ('link', _e(t(Copy.planApps))),
        ],
        ProPlanKind.team => [
          ('users', _e(t.fill(Copy.planTeamSeatsShort, {'seats': '${plan.seats}'}))),
          ('check', _e(t(Copy.planTeamOthers))),
          ('redo', _e(t(Copy.planTeamMove))),
        ],
      };
      final base = switch (plan.kind) {
        ProPlanKind.solo => t(Copy.planFree),
        ProPlanKind.team => t(Copy.planSolo),
      };
      return '''<article class="plan price-col${lead ? ' featured' : ''}" aria-labelledby="$id">
${lead ? '<div class="price-glow" aria-hidden="true"></div>\n' : ''}<div class="price-head"><h3 id="$id">${_e(name(plan))}</h3>${launch ? '<span class="price-badge">${_e(t.fill(Copy.planOff, {'percent': '$off'}))}</span>' : ''}</div>
<p class="plan-seats">${_e(seats)}</p>
<p class="plan-price"><span class="plan-amount">${_e(price(plan.price))}</span>${launch ? ' <del><span class="visually-hidden">${_e(t(Copy.planRegular))} </span>${_e(price(plan.regular))}</del>' : ''}</p>
<p class="plan-terms"><span>${_e(t(Copy.planOnce))}</span>${plan.seats > 1 ? '<span>${_e(t.fill(Copy.planPerSeat, {'price': price(plan.price / plan.seats)}))}</span>' : ''}</p>
${plus(base)}
${features(lines)}
$buy
</article>''';
    }

    // Three columns of phones, each list twice so that a column scrolls
    // without a seam.
    String wall() {
      const columns = 3;
      String phone(String name, {required bool copy}) {
        final item = _byName(name);
        // A lazy image inside the tilted wall is never seen as near the
        // viewport, so it would never load.
        final thumb = _screenThumb(root, item).replaceFirst(' loading="lazy"', '');
        return copy
            ? '<li aria-hidden="true"><span class="wall-phone">${thumb.replaceFirst(RegExp(r'alt="[^"]*"'), 'alt=""')}</span></li>'
            : '<li><a class="wall-phone" href="$root${item.path}" aria-label="${_e(item.english.title)}">$thumb</a></li>';
      }

      return '<div class="screen-wall"><div class="wall-tilt">${[
        for (var c = 0; c < columns; c++)
          '<ul class="wall-col" style="--c:$c">${[
            for (final copy in [false, true])
              for (final (i, name) in proGallery.indexed)
                if (i % columns == c) phone(name, copy: copy),
          ].join()}</ul>',
      ].join()}</div></div>';
    }

    String question(Copy q, Copy a, [Map<String, String> html = const {}]) =>
        '<details><summary><span>${_e(t(q))}</span>${_icon('chevron')}</summary><p>${sentence(a, html)}</p></details>';
    String section(String id, String head, String body) =>
        '<section class="section" id="$id" aria-labelledby="$id-title">\n$head\n$body\n</section>';
    String plainHead(String id, Copy title) =>
        '<div class="section-head split-head"><h2 id="$id-title">${_e(t(title))}</h2></div>';
    final team = plans.where((plan) => plan.kind == ProPlanKind.team);
    final sold = plans.where((plan) => plan.checkout.isNotEmpty).toList();
    return _page(
      root: root,
      path: 'pro/',
      title: _title(t(Copy.proTitle)),
      tab: _Tab.pro,
      current: 'pro',
      landing: true,
      doc: (
        title: t(Copy.proTitle),
        lead: '',
        prompt: null,
        command: null,
        intro:
            '''<header class="pro-hero">
<div class="pro-hero-text">
<p class="pro-lockup">$_mark${_e(t(Copy.proTitle))}</p>
<h1>${_e(t(Copy.homeProTitle))}</h1>
<p class="lead">${_e(t.fill(Copy.proLead, counts))}</p>
<div class="hero-actions" data-buy-hide>
<a class="tact accent pill" href="#plans">${_e(t.fill(Copy.proGetFrom, {'price': price(cheapest)}))}${_icon('arrow')}</a>
<a class="tact pill" href="${root}screens/">${_e(t(Copy.proBrowseScreens))}</a>
</div>
<ul class="pro-perks">${[for (final perk in [Copy.proPerkOnce, Copy.proPerkLifetime, Copy.proPerkApps]) '<li>${_icon('check')}${_e(t(perk))}</li>'].join()}</ul>
</div>
${wall()}
</header>
${section('plans', _sectionHead('plans', _mark, Copy.proPlansEyebrow, Copy.proPlansTitle, Copy.proPlansTail, _e(t(Copy.proPlansLead))), '''<div class="price-grid" data-buy-hide>
$free
${plans.map(plan).join('\n')}
</div>
<ul class="plan-trust">${[for (final (icon, copy) in [('check', Copy.proTrustTaxes), ('lock', Copy.proTrustPolar), ('sparkle', Copy.proTrustKey)]) '<li>${_icon(icon)}${_e(t(copy))}</li>'].join()}</ul>''')}
${section('contents', _sectionHead('contents', _icon('phone'), Copy.proScreensEyebrow, Copy.proScreensTitle, Copy.proScreensTail, _e(t.fill(Copy.proContents, counts))), _features([
              ('code', Copy.proFeatureController, _e(t(Copy.proFeatureControllerBody))),
              ('list', Copy.proFeatureStates, _e(t(Copy.proFeatureStatesBody))),
              ('book', Copy.proFeatureStrings, _e(t(Copy.proFeatureStringsBody))),
              ('merge', Copy.proFeatureSnippets, _withCode(Copy.proFeatureSnippetsBody, {'add': 'fliin add'})),
            ]))}
${section('how', plainHead('how', Copy.proHowTitle), '''<ol class="steps">
<li>${_e(t(Copy.proHowBuy))}</li>
<li>${_e(t(Copy.proHowKey))}</li>
<li>${sentence(Copy.proHowLogin, {'login': code('fliin login')})}</li>
<li>${sentence(Copy.proHowAdd, {'add': code('fliin add')})}</li>
</ol>
${_command('fliin login\nfliin add ${proGallery.first}')}''')}
${section('faq', plainHead('faq', Copy.proFaqTitle), '''<div class="faq">
${[
              question(Copy.faqLifetime, Copy.faqLifetimeAnswer),
              if (team.isNotEmpty) question(Copy.faqTeam, Copy.faqTeamAnswer, {'seats': '${team.first.seats}'}),
              question(Copy.faqCi, Copy.faqCiAnswer, {'env': code('FLIIN_LICENSE_KEY')}),
              question(Copy.faqClients, Copy.faqClientsAnswer),
              question(Copy.faqOffline, Copy.faqOfflineAnswer, {'add': code('fliin add'), 'update': code('fliin update')}),
              question(Copy.faqStop, Copy.faqStopAnswer),
              question(Copy.faqRefund, Copy.faqRefundAnswer),
              question(Copy.faqPublic, Copy.faqPublicAnswer),
            ].join('\n')}
</div>
<p class="faq-terms">${sentence(Copy.proTerms, {'license': license})}</p>''')}
<section class="closing" aria-labelledby="closing-title" data-buy-hide>
<h2 id="closing-title">${_e(t(Copy.proClosingTitle))} <span>${_e(t(Copy.proClosingTail))}</span></h2>
<p class="closing-note">${_e(t.fill(Copy.proClosingNote, {'price': price(cheapest)}))}</p>
<div class="closing-actions">${sold.isEmpty ? '<a class="tact accent pill" href="#plans">${_e(t.fill(Copy.proGetFrom, {'price': price(cheapest)}))}</a>' : [for (final plan in sold) '<a class="tact pill${identical(plan, sold.first) ? ' accent' : ''}" href="${_e(plan.checkout)}" rel="noopener">${_e(t.fill(Copy.planBuy, {'plan': name(plan)}))}</a>'].join()}<a class="tact pill" href="${root}screens/">${_e(t(Copy.proBrowseScreens))}</a></div>
</section>
<aside class="buy-bar capsule" aria-labelledby="buy-bar-title" data-buy-bar hidden>
<p><span class="buy-bar-name" id="buy-bar-title">$_mark${_e(t(Copy.proTitle))}</span><span class="buy-bar-price">${_e(t.fill(Copy.proBarPrice, {'price': price(cheapest)}))}</span></p>
<a class="tact accent small pill" href="#plans">${_e(t(Copy.proBarCta))}</a>
</aside>''',
        sections: const [],
        outro: '',
      ),
    );
  }

  /// A license as a page, its text taken as written from [text]: the first
  /// line is the title; then Markdown headings (`## `) open the sections,
  /// and a paragraph, a list (`- `) or a quote (`> `) takes its lines up
  /// to the next blank one, with `**bold**` and `` `code` `` inside.
  /// `LICENSE`, plain text, is paragraphs alone.
  String _license(String path, String text, {_Tab? tab}) {
    final root = '../' * '/'.allMatches(path).length;
    final lines = text.trim().split('\n');
    final title = lines.first.replaceFirst(RegExp(r'^#\s+'), '').trim();
    String inline(String text) => _e(text)
        .replaceAllMapped(
          RegExp(r'\*\*(.+?)\*\*'),
          (m) => '<strong>${m[1]}</strong>',
        )
        .replaceAllMapped(RegExp('`([^`]+)`'), (m) => '<code>${m[1]}</code>');
    String block(List<String> lines) {
      if (lines.every((line) => line.startsWith('- '))) {
        return '<ul>${[for (final line in lines) '<li>${inline(line.substring(2))}</li>'].join()}</ul>';
      }
      if (lines.every((line) => line.startsWith('>'))) {
        return '<blockquote class="note"><p>${inline(lines.map((line) => line.replaceFirst(RegExp(r'^>\s?'), '')).join(' '))}</p></blockquote>';
      }
      return '<p>${inline(lines.map((line) => line.trim()).join(' '))}</p>';
    }

    final intro = <String>[];
    final sections = <({String title, List<String> blocks})>[];
    var chunk = <String>[];
    void flush() {
      if (chunk.isEmpty) return;
      (sections.isEmpty ? intro : sections.last.blocks).add(block(chunk));
      chunk = [];
    }

    for (final line in lines.skip(1)) {
      if (line.startsWith('## ')) {
        flush();
        sections.add((title: line.substring(3).trim(), blocks: []));
      } else if (line.trim().isEmpty) {
        flush();
      } else {
        chunk.add(line);
      }
    }
    flush();
    String slug(String title) => title
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return _page(
      root: root,
      path: path,
      title: _title(title),
      tab: tab,
      doc: (
        title: title,
        lead: '',
        prompt: null,
        command: null,
        intro: '<div class="license-text">${intro.join('\n')}</div>',
        sections: [
          for (final section in sections)
            (
              id: slug(section.title),
              title: section.title,
              html: '<div class="license-text">${section.blocks.join('\n')}</div>',
            ),
        ],
        outro: '',
      ),
    );
  }

  String _notFound() => _page(
    root: '/',
    path: null,
    title: _title(t(Copy.notFoundTitle)),
    landing: true,
    doc: (
      title: t(Copy.notFoundTitle),
      lead: '',
      prompt: null,
      command: null,
      intro:
          '<section class="lost"><h1>${_e(t(Copy.notFoundTitle))}</h1><p>${_e(t(Copy.notFoundBody))}</p><div class="hero-actions"><a class="tact accent large" href="/">${_e(t(Copy.backHome))}</a><button type="button" class="tact large" data-search-open aria-haspopup="dialog">${_icon('search')}${_e(t(Copy.search))}</button></div></section>',
      sections: const [],
      outro: '',
    ),
  );
}

/// The first command of the guide, on the home page.
const _install = 'dart pub global activate fliin';

/// The logo mark: `site.css` paints it from `assets/brand/`.
const _mark = '<span class="mark" aria-hidden="true"></span>';

/// The site's icons, drawn on a 16-unit grid.
const _icons = {
  'search': '<circle cx="7" cy="7" r="4.5"/><path d="M10.5 10.5 14 14"/>',
  'close': '<path d="m4 4 8 8M12 4l-8 8"/>',
  'copy': '<rect x="5" y="5" width="8.5" height="8.5" rx="2"/><path d="M3 10.5V4a1.5 1.5 0 0 1 1.5-1.5H10"/>',
  'chevron': '<path d="m4.5 6.5 3.5 3.5 3.5-3.5"/>',
  'arrow': '<path d="M3.5 8h9M8.5 4l4 4-4 4"/>',
  'back': '<path d="M12.5 8h-9M7.5 4l-4 4 4 4"/>',
  'sun': '<circle cx="8" cy="8" r="2.75"/><path d="M8 1.5v1.5M8 13v1.5M1.5 8H3M13 8h1.5M3.4 3.4l1 1M11.6 11.6l1 1M3.4 12.6l1-1M11.6 4.4l1-1"/>',
  'moon': '<path d="M13.5 9.5A5.5 5.5 0 0 1 6.5 2.5a5.5 5.5 0 1 0 7 7z"/>',
  'monitor': '<rect x="2" y="2.5" width="12" height="8.5" rx="1.5"/><path d="M6 14h4M8 11v3"/>',
  'sidebar': '<rect x="2" y="2.5" width="12" height="11" rx="2"/><path d="M10 2.5v11"/>',
  'book': '<path d="M2 3.5h4A2 2 0 0 1 8 5.5v8a1.5 1.5 0 0 0-1.5-1.5H2zM14 3.5h-4a2 2 0 0 0-2 2v8a1.5 1.5 0 0 1 1.5-1.5H14z"/>',
  'components': '<path d="m8 1.5 2 2-2 2-2-2zM8 10.5l2 2-2 2-2-2zM3.5 6l2 2-2 2-2-2zM12.5 6l2 2-2 2-2-2z"/>',
  'blocks': '<rect x="2" y="2.5" width="12" height="4.5" rx="1.5"/><rect x="2" y="9" width="5" height="4.5" rx="1.5"/><rect x="9" y="9" width="5" height="4.5" rx="1.5"/>',
  'phone':
      '<rect x="4" y="1.5" width="8" height="13" rx="2"/><path d="M7 12.5h2"/>',
  'palette': '<path d="M8 1.5a6.5 6.5 0 0 0 0 13c.8 0 1.2-.6 1.2-1.2 0-.8-.6-1-.6-1.8s.6-1.2 1.4-1.2h1.5a3 3 0 0 0 3-3C14.5 4 11.6 1.5 8 1.5z"/><circle cx="5" cy="7" r=".75" class="fill"/><circle cx="8" cy="4.5" r=".75" class="fill"/><circle cx="11" cy="7" r=".75" class="fill"/>',
  'list': '<path d="M2.5 4h11M2.5 8h11M2.5 12h7"/>',
  'code': '<path d="m5.5 4.5-3.5 3.5 3.5 3.5M10.5 4.5 14 8l-3.5 3.5"/>',
  'external': '<path d="M9 2.5h4.5V7M13.5 2.5 7 9M11.5 9.5v3a1 1 0 0 1-1 1h-7a1 1 0 0 1-1-1v-7a1 1 0 0 1 1-1h3"/>',
  'sparkle':
      '<path d="M8 2.5 9.3 6.7 13.5 8 9.3 9.3 8 13.5 6.7 9.3 2.5 8 6.7 6.7z"/>',
  'terminal': '<rect x="1.5" y="2.5" width="13" height="11" rx="2"/><path d="m4.5 6 2 2-2 2M8.5 10.5h3"/>',
  'shuffle': '<path d="M2 4.5h2.5c3.5 0 3.5 7 7 7H14M2 11.5h2.5c1.4 0 2.2-1.1 2.8-2.4M9.2 6.4c.6-1 1.4-1.9 2.8-1.9H14M12 2.5l2 2-2 2M12 9.5l2 2-2 2"/>',
  'redo': '<path d="M12.5 6.5H6a3.5 3.5 0 0 0 0 7h4M10 3.5l3 3-3 3"/>',
  'check': '<path d="m3.5 8.5 3 3 6-7"/>',
  'merge': '<circle cx="4.5" cy="3.5" r="1.5"/><circle cx="11.5" cy="3.5" r="1.5"/><circle cx="8" cy="12.5" r="1.5"/><path d="M4.5 5v1a2.5 2.5 0 0 0 2.5 2.5h2A2.5 2.5 0 0 0 11.5 6V5M8 8.5V11"/>',
  'alert': '<path d="M8 2.5 14.5 13.5h-13z"/><path d="M8 6.5v3M8 11.5v.01"/>',
  'lock': '<rect x="3.5" y="7" width="9" height="6.5" rx="1.5"/><path d="M5.5 7V5a2.5 2.5 0 0 1 5 0v2"/>',
  'link': '<path d="M6.5 9.5l3-3M7 4.5l1-1a2.8 2.8 0 0 1 4 4l-1 1M9 11.5l-1 1a2.8 2.8 0 0 1-4-4l1-1"/>',
  'undo': '<path d="M3.5 6.5h6.5a3.5 3.5 0 0 1 0 7H6M6 3.5l-3 3 3 3"/>',
  'users': '<circle cx="6" cy="5.5" r="2.5"/><path d="M1.5 13.5a4.5 4.5 0 0 1 9 0M10.5 3.2a2.5 2.5 0 0 1 0 4.6M12 9.3a4.5 4.5 0 0 1 2.5 4.2"/>',
};

String _icon(String name, [String? classes]) =>
    '<svg${classes == null ? '' : ' class="$classes"'} aria-hidden="true" viewBox="0 0 16 16">${_icons[name]!}</svg>';

String _e(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

String _json(Object? value) => _scriptSafe(jsonEncode(value));

/// JSON safe inside a `<script>`: without any `<`, neither `</script>` nor
/// `<!--` (which would switch the HTML parser to "double escaped" text) can
/// appear. `\u003c` is the same character for `JSON.parse`.
String _scriptSafe(String json) => json.replaceAll('<', r'\u003c');

/// An accent pill: its name, the theme it sends to the views (null is the
/// registry's), its color in light and in dark.
typedef AccentChoice = ({
  Copy name,
  Map<String, Object?>? theme,
  String light,
  String dark,
});

/// The [candidates] (name, color; null for the registry's accent) that the
/// `fliin theme` solver resolves on [tokens] without `danger` and the accent
/// being confused: a color it rejects is not offered. The theme keeps only
/// the roles that change.
List<AccentChoice> accentChoices(
  String tokens,
  List<(Copy, String?)> candidates,
) {
  final base = jsonDecode(solveThemeJson(tokens, '{}')) as Map<String, Object?>;
  final baseRoles = base['roles']! as Map<String, Object?>;
  Map<String, Object?> mode(Map<String, Object?> roles, String name) =>
      roles[name]! as Map<String, Object?>;
  return [
    for (final (name, hex) in candidates)
      if (hex == null)
        (
          name: name,
          theme: null,
          light: mode(baseRoles, 'light')['accent']! as String,
          dark: mode(baseRoles, 'dark')['accent']! as String,
        )
      else if (jsonDecode(solveThemeJson(tokens, jsonEncode({'primary': hex})))
          case {
            'kind': 'solved',
            'clashes': List<Object?>(isEmpty: true),
            'roles': final Map<String, Object?> roles,
            'radius': final Object? radius,
            'button': final Object? button,
          })
        (
          name: name,
          theme: {
            'roles': {
              for (final name in ['light', 'dark'])
                name: {
                  for (final MapEntry(:key, :value) in mode(
                    roles,
                    name,
                  ).entries)
                    if (mode(baseRoles, name)[key] != value) key: value,
                },
            },
            'radius': radius,
            'button': button,
          },
          light: mode(roles, 'light')['accent']! as String,
          dark: mode(roles, 'dark')['accent']! as String,
        ),
  ];
}
