/// Every text of the site, in English: a French version is one more
/// `Map<Copy, String>` table, not a rewrite of the pages. A `{name}` is
/// filled by [SiteText.fill]. `site_test.dart` builds the site with dummy
/// texts and checks that no other text appears in the pages.
enum Copy {
  brand('Fliin'),
  pageTitle('{page}, {brand}'),
  listSeparator(', '),
  lang('en'),
  metaDescription(
    'Copy-paste Flutter widgets, checked on 16 variants, kept up to date by '
    'a three-way merge, and wired to your agents through MCP.',
  ),
  skipToContent('Skip to content'),
  navPrimary('Main'),
  navStart('Getting started'),
  navComponents('Components'),
  navBlocks('Blocks'),
  navScreens('Screens'),
  navTheme('Theme'),
  navPro('Pro'),
  previous('Previous'),
  next('Next'),
  navDocs('Docs'),
  navFooter('Site'),
  bannerPro('Blocks and whole screens are in Fliin Pro'),
  bannerProCta('Get Pro'),
  footerLlms('llms.txt'),
  introduction('Introduction'),
  allComponents('All components'),
  allBlocks('All blocks'),
  allScreens('All screens'),
  search('Search'),
  toggleTheme('Color theme'),
  themeSystem('System'),
  openMenu('Open navigation'),
  onThisPage('On this page'),
  copyMarkdown('Copy Markdown'),
  copyCode('Copy code'),
  expandCode('Expand code'),
  collapseCode('Collapse code'),
  homeTitle('Fliin: Flutter widgets you own'),
  heroTitle('Flutter widgets you own.'),
  heroTitleLead('Flutter widgets'),
  heroTitleTail('you {mark} own.'),
  heroLead(
    'Components, blocks and screens you copy into your app and keep. Checked '
    'on 16 variants, updated without losing your edits.',
  ),
  heroBrowse('Browse components'),
  heroPro('Explore Fliin Pro'),
  heroAgents('Your agents already know how to use it'),
  agentClaude('Claude Code'),
  agentCursor('Cursor'),
  agentGemini('Gemini CLI'),
  agentCodex('Codex'),
  agentVscode('VS Code'),
  agentAndroidStudio('Android Studio'),
  getStarted('Get started'),
  quickStart('Quick start'),
  copyCommand('Copy command'),
  copied('Copied'),
  copy('Copy'),
  accentLabel('Accent color'),
  accentShort('Accent'),
  accentBlue('Blue'),
  accentViolet('Violet'),
  accentFuchsia('Fuchsia'),
  accentAmber('Amber'),
  accentGreen('Green'),
  accentTeal('Teal'),
  accentCyan('Cyan'),
  themeEyebrow('Theme'),
  themeDemoTitle('One code,'),
  themeDemoTail('your whole look.'),
  themeDemoBody(
    'A preset code sets colors, fonts, radii, shadows and buttons at once. '
    'Try an accent on the live screen.',
  ),
  themeDemoCta('Build your theme'),
  themeFeatureContrast('Contrast that passes'),
  themeFeatureContrastBody(
    'Each accent is adjusted until every color pair meets WCAG AA.',
  ),
  themeFeatureCode('One short code'),
  themeFeatureCodeBody(
    'The whole look fits in a preset code you can paste and share.',
  ),
  themeFeatureModes('Light and dark'),
  themeFeatureModesBody(
    'Both brightnesses come from the same preset, on iOS and Android.',
  ),
  themeFeatureApply('Applied in one go'),
  themeFeatureApplyBody('{theme} rewrites your tokens, all or nothing.'),
  updateEyebrow('fliin update'),
  updateTitle('Upstream fixes in,'),
  updateTail('your edits stay.'),
  updateLead(
    'Each file merges three ways: the version you installed, your copy and '
    'the new one. Nothing breaks the build.',
  ),
  demoWindow('my_app — zsh'),
  updateMerged('merged'),
  updateConflict('conflict'),
  updateRegenerated('regenerated'),
  updateConflictDetail('(upstream version in {sidecar})'),
  updateRegeneratedDetail('(from fliin.tokens.json)'),
  updateAdvice(
    'For each conflict, copy what you keep from the .fliin-new file into the '
    'file, delete the .fliin-new file, then run fliin update again to finish '
    'the update.',
  ),
  updateFeatureMerge('Three-way merge'),
  updateFeatureMergeBody(
    'Your copy, the version you installed and the new one, line by line.',
  ),
  updateFeatureSide('Conflicts on the side'),
  updateFeatureSideBody(
    'A clash goes to a {sidecar} file next to yours, never into the build.',
  ),
  updateFeatureTokens('Tokens regenerated'),
  updateFeatureTokensBody(
    '{tokens} is rebuilt from your merged theme, your preset reapplied.',
  ),
  updateFeatureBreaking('Breaking changes listed'),
  updateFeatureBreakingBody(
    '{check} shows each new version and what it breaks, before you merge.',
  ),
  agentsEyebrow('Agents'),
  agentsTitle('Ask for a widget,'),
  agentsTail('get the right one.'),
  agentsBody(
    'A local MCP server lets your coding agent search the registry by '
    'intent, then add the item it picked.',
  ),
  agentsCta('Set up your agents'),
  agentsFeatureSearch('Search by intent'),
  agentsFeatureSearchBody(
    'Describe what you need, in English or French, and get the items that '
    'fit.',
  ),
  agentsFeatureLocal('Stays on your machine'),
  agentsFeatureLocalBody(
    'The server runs locally. Your code and your paths never leave.',
  ),
  agentsFeaturePick('Pick from previews'),
  agentsFeaturePickBody(
    'A local page shows the candidates side by side and sends your choice '
    'back to the agent.',
  ),
  agentsFeatureSetup('Wired by init'),
  agentsFeatureSetupBody(
    '{init} adds the server to the agents it finds, such as Claude Code, '
    'Cursor or Codex.',
  ),
  agentsDemoAsk('Add a date range picker to booking'),
  agentsDemoFound('search_items · {count} candidates'),
  agentsDemoPicked('picked'),
  proSectionTitle('Move faster'),
  proSectionTail('with Fliin Pro.'),
  proSectionLead(
    'Blocks and whole screens for sign-in, checkout, chat and dashboards. '
    'Copied like the rest, checked on the same 16 variants.',
  ),
  startTitle('From zero to a checked button'),
  startTail('in a minute.'),
  startBody(
    'Flutter {flutter} or later. Works under MaterialApp, CupertinoApp and '
    'WidgetsApp.',
  ),
  startLabel('Your app'),
  startNew('New app'),
  startExisting('Existing app'),
  startGuide('Read the guide'),
  startNoteFolder('lib/ui/fliin/'),
  startNoteVariants('16/16'),
  startNoteScope('then wrap in FlScope'),
  startNoteMcp('MCP'),
  homeProTitle('Complete flows, not just widgets.'),
  homeProCta('See Fliin Pro'),
  closingTitle('Never start a widget'),
  closingTail('from scratch again.'),
  closingComponents('Browse components'),
  closingPro('Get Fliin Pro'),
  closingTheme('Build a theme'),
  proCardNow('Now available'),
  proCardTitle('Build faster with Fliin Pro'),
  proCardBody('Blocks and screens for Flutter, checked on 16 variants.'),
  proCardCta('Explore Pro'),
  footColumnFliin('Fliin'),
  footColumnPro('Fliin Pro'),
  footColumnAgents('For coding agents'),
  footColumnProject('Project'),
  footQuickStart('Quick start'),
  footPricing('Pricing'),
  footMcp('MCP server'),
  footAgentsFile('AGENTS.md'),
  footCli('CLI'),
  footerTagline('Flutter components you copy, verify and keep.'),
  footerLicense(
    'Free items are under the {mit}; Pro blocks and screens under the {pro}.',
  ),
  mitLicense('MIT License'),
  proLicense('Fliin Pro License'),
  sidebarLabel('Documentation'),
  sidebarFoundation('Foundation'),
  sidebarComponents('Components'),
  sidebarBlocks('Blocks'),
  sidebarScreens('Screens'),
  pro('Pro'),
  proMark('Part of Fliin Pro'),
  proInstall(
    '{item} is part of {pro}. With a license key, sign in once with {login}, '
    'then add it in a Flutter app where {init} has run:',
  ),
  proTitle('Fliin Pro'),
  proLead(
    '{blocks} blocks and {screens} whole screens to copy into your app, built '
    'on the free components, themed by the same tokens and checked on the '
    'same 16 variants.',
  ),
  proGetFrom('Get Fliin Pro from {price}'),
  proBrowseScreens('Browse the screens'),
  proPerkOnce('One-time payment'),
  proPerkLifetime('Lifetime license'),
  proPerkApps('Unlimited apps'),
  proPlansEyebrow('Pricing'),
  proPlansTitle('Pay once.'),
  proPlansTail('Keep it for life.'),
  proPlansLead(
    'Launch prices for the first weeks. Both plans include every Pro block '
    'and screen, with new ones and updates as they ship.',
  ),
  planFree('Free'),
  planFreeFor('The components and the tools.'),
  planFreeTerm('forever, under the {mit}'),
  planFreeCta('Start free'),
  planFreeTools('The CLI and the MCP server'),
  planFreeComponents('{components} components and the icons'),
  planFreeTheme('The theme builder'),
  planFreeVerify('Checked on 16 variants'),
  planFreeUpdate('Updates that keep your edits'),
  planPlus('Everything in {plan}, plus:'),
  planBlocks('{blocks} blocks'),
  planScreens('{screens} whole screens'),
  planControllers('Controllers and sample data'),
  planStrings('Labels in English, French and Arabic'),
  planNew('New items and updates included'),
  planApps('Unlimited apps, for clients too'),
  planTeamSeatsShort('Up to {seats} developers'),
  planTeamOthers('QA and designers need no seat'),
  planTeamMove('A seat moves when someone leaves'),
  proScreensEyebrow('In every screen'),
  proScreensTitle('More than a layout.'),
  proScreensTail('Ready to wire.'),
  proContents(
    '{blocks} blocks to place in a screen of your own, and {screens} whole '
    'screens to wire to your backend. Each screen comes with:',
  ),
  proFeatureController('A controller'),
  proFeatureControllerBody(
    'A ChangeNotifier from widgets.dart, no state package required, and '
    'sample data to swap for your backend.',
  ),
  proFeatureStates('Every state'),
  proFeatureStatesBody(
    'Loading, error, empty or offline, each shown in the reference renders.',
  ),
  proFeatureStrings('Three languages'),
  proFeatureStringsBody(
    'Every label in English, French and Arabic, right to left included.',
  ),
  proFeatureSnippets('Your router, your state'),
  proFeatureSnippetsBody(
    'Snippets for go_router or Navigator, and Provider, Riverpod, Bloc or '
    'plain widgets, which {add} prints for your app.',
  ),
  planSolo('Solo'),
  planSoloSeats('One developer.'),
  planTeam('Team'),
  planTeamSeats(
    'Up to {seats} developers in the same company or organization.',
  ),
  planPrice('\${amount}'),
  planRegular('Regular price'),
  planOff('Launch −{percent}%'),
  planPerSeat('{price} per developer'),
  planOnce('One-time payment, taxes included'),
  planBuy('Buy {plan}'),
  planSoon('Coming soon'),
  proTrustTaxes('Prices in US dollars, taxes included'),
  proTrustPolar('Payment and invoice by Polar, our reseller'),
  proTrustKey('Your license key right after payment'),
  proHowTitle('How it works'),
  proHowBuy('Buy a plan on Polar.'),
  proHowKey('Polar gives you a license key.'),
  proHowLogin(
    'Run {login} and paste the key. The CLI checks it, then stores it in your '
    'user folder, never in the project.',
  ),
  proHowAdd('Add Pro blocks and screens with {add}, like any other item:'),
  proFaqTitle('Questions'),
  faqLifetime('What does lifetime mean?'),
  faqLifetimeAnswer(
    'You pay once. The license is perpetual: the versions you download stay '
    'yours to use, even if Fliin Pro stops. New items and updates come with '
    'the same key, at no extra cost, for as long as Fliin Pro is offered.',
  ),
  faqTeam('How do Team seats work?'),
  faqTeamAnswer(
    'A Team license covers up to {seats} developers of the same company or '
    'organization. Each developer who installs, updates or edits Pro items '
    'needs a seat; people who only build, test or run the app, such as QA '
    'or designers, do not. A seat can move to someone else when a developer '
    'leaves the team.',
  ),
  faqCi('Can I use it in CI?'),
  faqCiAnswer(
    'Yes. Store the key as a secret and expose it as {env}: the CLI reads it '
    'before the stored key. A CI machine does not take a seat.',
  ),
  faqClients('Can I build apps for clients?'),
  faqClientsAnswer(
    'Yes. Use Pro items in any number of apps, free or paid, for yourself or '
    'for clients. A client can keep and maintain the app, Pro items '
    'included, without a license, as long as they do not use the items in '
    'another product.',
  ),
  faqOffline('Does it work offline?'),
  faqOfflineAnswer(
    'Installed files are part of your project: they build and run with no '
    'network and no license check. {add} and {update} download from the '
    'registry, so they need a connection.',
  ),
  faqStop('What happens if Fliin Pro stops?'),
  faqStopAnswer(
    'The files you have downloaded stay in your projects, and your license '
    'to use them is perpetual. Only new items and updates would end.',
  ),
  faqRefund('Can I get a refund?'),
  faqRefundAnswer(
    'Refunds follow the terms of Polar, our reseller, at the time of '
    'purchase. A refunded license ends and its key is revoked.',
  ),
  faqPublic('Can Pro items go in a public repository?'),
  faqPublicAnswer(
    'No. Keep them in private repositories. Publishing their source, in a '
    'public repository or an open-source project, is not allowed; a compiled '
    'app is fine.',
  ),
  proTerms('The full terms are in the {license}.'),
  proClosingTitle('Never start a screen'),
  proClosingTail('from scratch again.'),
  proClosingNote('From {price}. One-time payment, taxes included.'),
  proBarPrice('from {price}, one-time payment'),
  proBarCta('See the plans'),
  routingTitle('Routing'),
  routingBody(
    '{add} prints the route for the router it finds in your pubspec, a file '
    'next to the page that wires its navigation. Each of them:',
  ),
  stateTitle('State'),
  stateBody(
    'The controller is a ChangeNotifier from widgets.dart, with no package. '
    '{add} prints the page that holds it with the state management it finds, '
    'its imports written for your package; below they read your_app. Your '
    'backend implements the Service interface of the screen\'s _data.dart '
    'file:',
  ),
  stringsTitle('Strings'),
  stringsBody(
    'Every label in English, French and Arabic. The screen follows the '
    'closest Localizations; the same table is in the manifest, ready for '
    'your ARB files.',
  ),
  stringsKey('Key'),
  screenGoldensBody(
    'The 16 images published with version {version}, rendered by the shared '
    'harness on macOS with Flutter {flutter}. Each shows every state side by '
    'side, at the size of an iPhone (390 × 844) or of an Android phone '
    '(412 × 915). {verify} compares your copy to them.',
  ),
  pagerLabel('Previous and next'),
  copyPrompt('Copy prompt for your agent'),
  previewLabel('{name}, live preview'),
  playground('Playground'),
  variantsPass('{count} of {total} variants pass'),
  exampleView('View'),
  examplePreview('Preview'),
  exampleCode('Code'),
  controlPlatform('Platform'),
  controlBrightness('Brightness'),
  controlScale('Text scale'),
  controlDirection('Direction'),
  controlState('State'),
  examplesTitle('Examples'),
  stateReference('Reference render'),
  platformIos('iOS'),
  platformAndroid('Android'),
  brightnessLight('Light'),
  brightnessDark('Dark'),
  scaleOne('1.0×'),
  scaleTwo('2.0×'),
  dirLtr('Left to right'),
  dirRtl('Right to left'),
  dirLtrShort('LTR'),
  dirRtlShort('RTL'),
  goldensTitle('Reference renders'),
  goldensBody(
    'The 16 images published with version {version}, rendered by the shared '
    'harness on macOS with Flutter {flutter}. {verify} compares your copy '
    'to them.',
  ),
  goldenAlt('{name}, {platform}, {brightness}, text {scale}, {dir}'),
  storyAlt('{name}, {state} state'),
  variantGroup('{platform} · {brightness}'),
  variantDetail('Text {scale} · {dir}'),
  noGoldens('This item has no reference renders.'),
  importTitle('Import'),
  installBody('In a Flutter app where {init} has run:'),
  alsoInstalls('Also installs: {items}'),
  snippetScreens(
    'The snippets lead to {items}: install these screens too and paste their '
    'snippets.',
  ),
  usageTitle('Usage'),
  usageBody('The code the reference images render:'),
  apiTitle('API'),
  sourceTitle('Source'),
  sourceBody(
    'The files {add} copies into your app, before your prefix and imports '
    'are applied.',
  ),
  intentsTitle('Use it to'),
  notForTitle('Not for'),
  statesTitle('States'),
  prompt(
    'Add the Fliin item "{name}" ({className}) to this Flutter app.\n'
    '1. If the project has no fliin.yaml, run: fliin init\n'
    '2. Run: fliin add {name}\n'
    '3. Use {className} from the installed files. Public API:\n{api}\n'
    '4. Run: fliin verify {name}, then fix any variant that fails.\n'
    'With the Fliin MCP server, call get_item with id "{name}" to read the '
    'files and the API instead.',
  ),
  promptPro(
    'Add the Fliin Pro item "{name}" ({className}) to this Flutter app.\n'
    '1. If the project has no fliin.yaml, run: fliin init\n'
    '2. Run: fliin add {name}. If it asks for a license, have the developer '
    'run fliin login with their Fliin Pro key first.\n'
    '3. Use {className} from the installed files. Public API:\n{api}\n'
    '4. Run: fliin verify {name}, then fix any variant that fails.',
  ),
  componentsTitle('Components'),
  componentsLead('{count} items, each checked on 16 variants.'),
  blocksTitle('Blocks'),
  blocksLead(
    '{count} sections made of components, ready to drop into a screen, '
    'each checked on 16 variants.',
  ),
  screensTitle('Screens'),
  screensLead(
    '{count} whole screens with their states, strings and routes, each '
    'checked on 16 variants.',
  ),
  themeTitle('Theme'),
  themeLead(
    'One preset code shapes every widget, and the CLI applies it to your '
    'app. Every color passes the contrast check in light and dark.',
  ),
  themeControls('Theme settings'),
  groupPresets('Presets'),
  groupStyle('Style'),
  groupColors('Colors'),
  groupTypography('Typography'),
  groupShape('Shape'),
  groupMore('More settings'),
  galleryDefault('Default'),
  galleryOcean('Ocean'),
  galleryForest('Forest'),
  galleryGrape('Grape'),
  galleryMidnight('Midnight'),
  galleryMono('Mono'),
  gallerySand('Sand'),
  galleryCitrus('Citrus'),
  styleDefault('Default'),
  styleDefaultHint('Clean and familiar'),
  styleCrisp('Crisp'),
  styleCrispHint('Flat cards, fine lines'),
  styleSoft('Soft'),
  styleSoftHint('Round and airy'),
  styleCompact('Compact'),
  styleCompactHint('Dense, for busy screens'),
  styleEditorial('Editorial'),
  styleEditorialHint('Serif titles, flat cards'),
  styleTerminal('Terminal'),
  styleTerminalHint('Square and monospaced'),
  presetBase('Base color'),
  presetPrimary('Primary color'),
  presetMenu('Menus and sheets'),
  presetHeading('Heading font'),
  presetBody('Font'),
  presetText('Text size'),
  presetIcons('Icon library'),
  presetRadius('Radius'),
  presetButton('Button'),
  presetBorder('Borders'),
  presetCards('Cards'),
  presetShadow('Shadows'),
  presetSpacing('Spacing'),
  presetMotion('Animations'),
  lockField('Lock {field} when shuffling'),
  valueDefault('Default'),
  baseSand('Sand'),
  baseZinc('Zinc'),
  baseNeutral('Neutral'),
  baseStone('Stone'),
  baseSlate('Slate'),
  baseMauve('Mauve'),
  baseOlive('Olive'),
  primaryIndigo('Indigo'),
  primaryViolet('Violet'),
  primaryPurple('Purple'),
  primaryFuchsia('Fuchsia'),
  primaryPink('Pink'),
  primaryRose('Rose'),
  primaryRed('Red'),
  primaryOrange('Orange'),
  primaryAmber('Amber'),
  primaryYellow('Yellow'),
  primaryLime('Lime'),
  primaryGreen('Green'),
  primaryEmerald('Emerald'),
  primaryTeal('Teal'),
  primaryCyan('Cyan'),
  primarySky('Sky'),
  primaryAzure('Azure'),
  primaryCustom('Custom'),
  brandLabel('Brand color'),
  menuTinted('Tinted'),
  headingInherit('Same as text'),
  fontSample('Aa'),
  bodySystem('System'),
  textSmall('Small'),
  textLarge('Large'),
  radiusNone('None'),
  radiusSmall('Small'),
  radiusLarge('Large'),
  borderMedium('Medium'),
  borderBold('Bold'),
  cardsRaised('Raised'),
  cardsOutlined('Outlined'),
  spacingCompact('Compact'),
  spacingRelaxed('Relaxed'),
  shadowNone('None'),
  motionFast('Fast'),
  motionSlow('Slow'),
  shapeSquare('Square'),
  shapeRounded('Rounded'),
  shapePill('Pill'),
  presetCopy('Copy {code}'),
  presetLoad('Load preset'),
  presetCopyLink('Copy link'),
  presetShuffle('Shuffle'),
  presetUndo('Undo'),
  presetRedo('Redo'),
  presetGetCode('Get code'),
  presetApplied(
    'Preset {code}: all {count} contrast pairs pass in light and dark.',
  ),
  presetExcused(
    'Preset {code}: the default colors, {excused} of {count} contrast pairs '
    'are their declared exceptions.',
  ),
  presetRefused('Refused: {message}'),
  presetRequestError('This request is not a preset.'),
  presetBrandInvalid('Enter the brand color as #RRGGBB, for example #0A6CFF.'),
  presetContrastError(
    'No theme of this color passes the contrast check in light and dark.',
  ),
  presetNearest('The nearest color that passes is {hex}.'),
  presetUseNearest('Use {hex}'),
  presetTokensError('The tokens were refused: {message}'),
  presetReloading('Loading the {icons} icons…'),
  previewRegion('Live preview'),
  previewSections('Preview sections'),
  tabOverview('Overview'),
  tabForms('Forms'),
  tabCommerce('Commerce'),
  tabDashboard('Dashboard'),
  tabMessaging('Messaging'),
  tabScreens('Screens'),
  previewBrightness('Preview brightness'),
  previewDirection('Preview direction'),
  loadTitle('Load a preset'),
  loadLabel('Preset code, command or link'),
  loadSubmit('Load'),
  cancel('Cancel'),
  codeNewApp('In a new app'),
  codeExisting('In an app already set up'),
  codeFonts('Fonts'),
  codeFontsBody(
    'Fliin writes the family name into the tokens; your app ships the font '
    'files. Download them from Google Fonts, then declare them in '
    'pubspec.yaml:',
  ),
  codeTokens('The tokens it writes'),
  codeTokensBody(
    'core/tokens/fliin.tokens.json after the command, in a fresh app on core '
    '{version}, the version fliin init installs today. The command '
    'regenerates tokens.g.dart from it. An app on another version of core '
    'gets the tokens of that version.',
  ),
  copyTokens('Copy tokens'),
  themeSolving('Applying the preset…'),
  themeNeedsScript(
    'The theme builder needs JavaScript. In your project, apply a preset '
    'with the theme command instead:',
  ),
  searchTitle('Search components'),
  searchPlaceholder('Name or intent'),
  searchEmpty('No item matches.'),
  searchHint('Arrows to move, Enter to open, Escape to close.'),
  close('Close'),
  notFoundTitle('Page not found'),
  notFoundBody('Nothing lives at this address.'),
  backHome('Back to the home page'),
  llmsLead(
    'Each item below has a Markdown page for agents. In a Flutter app where '
    '{init} has run, {add} copies an item and its dependencies into the app, '
    'and {verify} renders it on 16 variants (iOS and Android, light and dark, '
    'text at 1× and 2×, left to right and right to left).',
  ),
  llmsAgents(
    'For coding agents: {agents} in the app wires the local MCP server '
    '(search_items, get_item, request_selection) into Claude Code, Cursor, '
    'Gemini CLI, Codex and VS Code, and writes the workflow into AGENTS.md.',
  ),
  llmsGuide('Start here'),
  llmsFull('Every page in one file'),
  guideTitle('Getting started'),
  guideLead(
    'Install the CLI, set up a Flutter app and add a first component. Then '
    'theme it, check it on 16 variants and keep it up to date.',
  ),
  guideRequirementsTitle('Requirements'),
  guideRequirements(
    'Flutter {flutter} or later. The CLI runs on the Dart SDK that comes with '
    'Flutter, and it checks the Flutter version of your app before it writes '
    'anything.',
  ),
  guideRequirementsGit(
    'In a git repository, {init} stops when the tree has uncommitted '
    'changes. Commit first, so that you can review what it writes, or pass '
    '{dirty}.',
  ),
  guideInstallTitle('Install the CLI'),
  guideInstall('Activate the CLI with pub:'),
  guideInstallPath(
    'Pub puts the command in its cache. If your shell does not find it, add '
    '{path} to your PATH ({windows} on Windows), then check that it runs:',
  ),
  guideCreateTitle('Create an app'),
  guideCreate(
    '{create} runs flutter create, sets Fliin up in the new app, and writes '
    'a {main} whose MaterialApp already wraps every screen in {scope}:',
  ),
  guideCreateOptions(
    '{create} takes the options of {init}: {root}, {prefix}, {preset} and '
    '{agent}.',
  ),
  guideInitTitle('Or set up an existing app'),
  guideInit('In the folder of an app you already have:'),
  guideInitRegistry(
    'Items come from the Fliin registry, signed and checked file by file. '
    'To use your own registry instead, pass {registry} and {key}.',
  ),
  guideInitWrites('It writes:'),
  guideFileYaml(
    '{file}: where the items go and the prefix of their classes, {root} and '
    '{prefix} by default, and the registry they come from.',
  ),
  guideFileLock(
    '{file}: the version and the fingerprint of every installed file, which '
    '{update} merges from. Commit it with the rest.',
  ),
  guideFileCore(
    '{file}: the theme, its tokens and the shared code that every component '
    'imports.',
  ),
  guideFileAgents(
    '{file}: how your coding agents should use Fliin, described below.',
  ),
  guideFileIgnore(
    'A few lines in {file}, for the files Fliin keeps to itself.',
  ),
  guideFileLicense(
    '{file}: the MIT license of the files Fliin copies, and the notices of '
    'the work they derive from.',
  ),
  guideScope(
    'Then put the theme above your screens. {init} prints the lines for the '
    '{builder} argument of your MaterialApp or WidgetsApp:',
  ),
  guideScopeBody(
    '{scope} hands the tokens to every component and follows the brightness '
    'of the platform. Components import only {widgets}, so they work under '
    'MaterialApp, CupertinoApp or WidgetsApp alike.',
  ),
  guideAddTitle('Add a component'),
  guideAdd(
    '{add} downloads the button and what it needs ({core} is there already, '
    '{spinner} comes along), checks every file against the signed index, '
    'writes the imports for your package and your prefix, and copies the '
    'files under {folder}.',
  ),
  guideAddOwn(
    'The files are now yours: read them, change them. Use the button like '
    'any widget. Here is the {main} of the app that {create} made, with a '
    'button that shows a spinner while it saves:',
  ),
  guideFind(
    'To find what to add, {search} looks items up by what you want to do, '
    '{list} shows what is installed, and {view} prints the API of an item. '
    'The {components} show each one live, with its examples.',
  ),
  guideComponentPages('component pages'),
  guideThemeTitle('Theme it'),
  guideThemePreset(
    'The {theme} page builds a preset: colors, fonts, radius, spacing, '
    'shadows, icons and motion, in one short code. Its {getCode} button '
    'gives the command for your app:',
  ),
  guideThemePrimary(
    'Or start from your brand color alone. The solver moves lightness in '
    'OKLCH until every text and control pair passes WCAG AA in light and '
    'dark, or names the nearest color that does:',
  ),
  guideThemeFiles(
    'Both rewrite {json} and regenerate {dart} from it, all or nothing: do '
    'not edit the generated file by hand. When a preset names a font, the '
    'command tells you what to declare in {pubspec}. A new app can start '
    'from a preset with {create}.',
  ),
  guideVerifyTitle('Check it on 16 variants'),
  guideVerify(
    '{verify} renders the item inside your app, on iOS and Android, light and '
    'dark, text at 1.0× and 2.0×, left to right and right to left. It writes '
    'the 16 images, a contact sheet and a report to {folder}, and fails when '
    'a variant does not render. When your theme, Flutter version and fonts '
    'are those of the published reference renders, it also measures how far '
    'your copy is from them.',
  ),
  guideVerifyChanged(
    'After an edit, check what it touches, the items that depend on it '
    'included:',
  ),
  guideUpdateTitle('Update without losing your edits'),
  guideUpdate(
    '{check} lists the items that have a new version, and {diff} shows what '
    'changes upstream. {update} then merges each file three ways: the '
    'version you installed, your copy and the new version. Your edits stay, '
    'upstream fixes come in.',
  ),
  guideConflict(
    'When you and upstream changed the same lines, your file stays as it is '
    'and the new version goes next to it, in {sidecar}: the build does not '
    'break, and the item keeps its version. Carry over what you want from '
    'it, delete the {ext} file, then run {update} again to finish.',
  ),
  guideUpdateSafe(
    '{update} never deletes a file of yours and never moves an item back to '
    'an older version. With {markers}, it writes conflict markers in the '
    'file instead, as git does.',
  ),
  guideAgentsTitle('Work with your agents'),
  guideAgents(
    '{init} writes {agents}: the loop your coding agents should follow, and '
    'the rules for the code under {root}. It also connects the Fliin MCP '
    'server to the agents it finds traces of in the project, such as '
    '{claude}, {cursor} or {codex}. To name them, at setup or later:',
  ),
  guideAgentsClients(
    'The clients it knows: {clients}. With {none}, {init} writes no agent '
    'file.',
  ),
  guideMcp(
    'Your agent then starts {mcp}, a local server with three tools: {search} '
    'finds items by intent, {get} returns the files, API and examples of an '
    'item, and {select} opens a page on your machine where you choose '
    'between candidates. Your code and your paths never leave your machine: '
    'the CLI only downloads files from the registry.',
  ),
  guideLlms(
    'An agent without MCP can read {llms}, and every item page has a '
    'Markdown version next to it.',
  ),
  guideProTitle('Fliin Pro'),
  guideProBody(
    'Blocks and screens marked Pro need a license, bought once on the '
    '{pro} page. Add your license key once per machine, then install Pro '
    'items like any other:',
  ),
  guideProKey(
    '{login} asks for the key without showing it, and keeps it outside your '
    'project, in {path} ({windows} on Windows). In CI, set {env} instead. '
    '{status} shows the active license, and {logout} removes it.',
  ),
  guideProWithout(
    'Without a license, {add} of a Pro item stops with exit code 8 and says '
    'where to get one. The Pro items you installed keep working, and '
    '{update} brings their new versions for as long as Fliin Pro exists.',
  ),
  guideNextTitle('Where next'),
  guideNextComponents(
    '{components}: every component with its live preview, examples, API and '
    'reference renders.',
  ),
  guideNextScreens(
    '{blocks} and {screens}: sections and whole screens with their states, '
    'strings and routes. Some blocks and screens are part of {pro}.',
  ),
  guideNextTheme('{theme}: build a preset and see it on every component.'),
  llmsSnippets(
    '{add} also prints the routing and state snippets for the router and '
    'state library it detects in the app.',
  );

  const Copy(this.english);

  final String english;
}

/// The texts of one language.
final class SiteText {
  const SiteText(this._lookup);

  /// The English texts of [Copy].
  static final english = SiteText((copy) => copy.english);

  final String Function(Copy copy) _lookup;

  String call(Copy copy) => _lookup(copy);

  /// Returns [copy] with each `{name}` replaced by its value in [values].
  String fill(Copy copy, Map<String, String> values) =>
      _lookup(copy)
          .replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => values[m[1]] ?? m[0]!);
}
