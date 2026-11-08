import 'package:fliin_schema/fliin_schema.dart' show applyRewrites;

import 'guide.dart';
import 'site_model.dart';
import 'site_text.dart';

/// `llms.txt` (llmstxt.org), the getting started guide and one Markdown
/// page per item next to its HTML page (`components/button/index.md`), and
/// `llms-full.txt` that gathers them: what an agent without the MCP reads
/// from the site, by path relative to its root. Their links are absolute,
/// under [base]: an agent reads a file without knowing where it came from.
Map<String, String> llmsFiles(SiteModel model, SiteText t, String base) {
  String code(String text) => '`$text`';
  final pages = {
    for (final item in model.items) item: _itemMarkdown(item, t, base),
  };
  String section(Copy title, Iterable<SiteItem> items) => [
    '## ${t(title)}',
    '',
    for (final item in items)
      '- [${item.english.title}]($base${item.path}index.md): '
          '${item.english.description}',
  ].join('\n');
  final foundation = model.items.where((item) => item.isFoundation);
  final index = [
    '# ${t(Copy.brand)}',
    '',
    '> ${t(Copy.metaDescription)}',
    '',
    t.fill(Copy.llmsLead, {
      'init': code('fliin init'),
      'add': code('fliin add <name>'),
      'verify': code('fliin verify <name>'),
    }),
    '',
    t.fill(Copy.llmsAgents, {'agents': code('fliin agents')}),
    '',
    '## ${t(Copy.llmsGuide)}',
    '',
    '- [${t(Copy.guideTitle)}]($base${guidePath}index.md): '
        '${t(Copy.guideLead)}',
    '',
    section(Copy.sidebarFoundation, foundation),
    '',
    section(Copy.sidebarComponents, model.components),
    '',
    section(Copy.sidebarBlocks, model.blocks),
    '',
    section(Copy.sidebarScreens, model.screens),
    '',
    '## ${t(Copy.llmsFull)}',
    '',
    '- [llms-full.txt](${base}llms-full.txt)',
    '',
  ].join('\n');
  return {
    'llms.txt': index,
    '${guidePath}index.md': '${_guideMarkdown(t, base)}\n',
    'llms-full.txt':
        '${[_guideMarkdown(t, base), ...pages.values].join('\n\n---\n\n')}\n',
    for (final MapEntry(key: item, value: page) in pages.entries)
      '${item.path}index.md': '$page\n',
  };
}

String _itemMarkdown(SiteItem item, SiteText t, String base) {
  String code(String text) => '`$text`';
  String fence(String text, [String lang = '']) => '```$lang\n$text\n```';
  final m = item.manifest;
  final command = 'fliin add ${item.name}';
  final deps = [for (final dep in m.registryDependencies) dep.ref.name];
  return [
    '# ${item.english.title}',
    '',
    '> ${item.english.description}',
    '',
    '## ${t(Copy.importTitle)}',
    '',
    if (item.isPro)
      t.fill(Copy.proInstall, {
        'item': item.english.title,
        'pro': '[${t(Copy.proTitle)}](${base}pro/)',
        'login': code('fliin login'),
        'init': code('fliin init'),
      })
    else
      t.fill(Copy.installBody, {'init': code('fliin init')}),
    '',
    fence(item.isPro ? 'fliin login\n$command' : command, 'bash'),
    if (deps.isNotEmpty) ...[
      '',
      t.fill(Copy.alsoInstalls, {
        'items': deps.map(code).join(t(Copy.listSeparator)),
      }),
    ],
    if (item.isScreen) ...[
      '',
      t.fill(Copy.llmsSnippets, {'add': code('fliin add')}),
    ],
    if (item.examples.isNotEmpty) ...[
      '',
      '## ${t(Copy.examplesTitle)}',
      for (final example in item.examples) ...[
        '',
        '### ${storyLabel(example.story)}',
        '',
        example.description,
        '',
        fence(applyRewrites(example.code, snippetRender), 'dart'),
      ],
    ],
    if (item.example case final example? when !item.isScreen) ...[
      '',
      '## ${t(Copy.usageTitle)}',
      '',
      t(Copy.usageBody),
      '',
      fence(example, 'dart'),
    ],
    if (item.api.isNotEmpty) ...[
      '',
      '## ${t(Copy.apiTitle)}',
      '',
      fence(item.api.join('\n')),
    ],
    if (m.meta.intents.en.isNotEmpty) ...[
      '',
      '## ${t(Copy.intentsTitle)}',
      '',
      for (final intent in m.meta.intents.en) '- $intent',
    ],
    if (m.meta.notFor.isNotEmpty) ...[
      '',
      '## ${t(Copy.notForTitle)}',
      '',
      for (final not in m.meta.notFor) '- $not',
    ],
    if (item.states.isNotEmpty) ...[
      '',
      '## ${t(Copy.statesTitle)}',
      '',
      item.states.map(code).join(' '),
    ],
  ].join('\n');
}

/// The guide in Markdown, its links under [root], the site's address.
String _guideMarkdown(SiteText t, String root) {
  String text(GuideText block) => t
      .fill(block.copy, {
        ...block.plain,
        for (final MapEntry(:key, :value) in block.labels.entries)
          key: t(value),
      })
      .replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
        if (block.code[m[1]] case final code?) return '`$code`';
        if (block.links[m[1]] case final link?) {
          final label = link.label == null ? '`${link.code}`' : t(link.label!);
          return '[$label]($root${link.path})';
        }
        return m[0]!;
      });
  String markdown(GuideBlock block) => switch (block) {
    GuideText() => text(block),
    GuideCode(:final code, :final lang) =>
      '```${lang == 'sh' ? 'bash' : lang}\n$code\n```',
    GuideList(:final items) => [
      for (final item in items) '- ${text(item)}',
    ].join('\n'),
  };
  return [
    '# ${t(Copy.guideTitle)}',
    '',
    '> ${t(Copy.guideLead)}',
    for (final section in guideSections()) ...[
      '',
      '## ${t(section.title)}',
      for (final block in section.blocks) ...['', markdown(block)],
    ],
  ].join('\n');
}
