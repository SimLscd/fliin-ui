import 'package:fliin_ui/components/app_bar/fl_app_bar.dart';
import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/spinner/fl_spinner.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  Widget child, {
  TargetPlatform platform = TargetPlatform.iOS,
  TextDirection direction = TextDirection.ltr,
  double top = 0,
  double scale = 1,
}) => MediaQuery(
  data: MediaQueryData(
    padding: EdgeInsets.only(top: top),
    textScaler: TextScaler.linear(scale),
  ),
  child: Directionality(
    textDirection: direction,
    child: FlScope(
      brightness: Brightness.light,
      platform: platform,
      child: Align(alignment: Alignment.topCenter, child: child),
    ),
  ),
);

final _icon = SizedBox.square(dimension: 20, child: ColoredBox(color: FlTokens.defaults.light.onSurface));

FlAppBar _bar({FlAppBarTitleSize titleSize = FlAppBarTitleSize.medium, VoidCallback? onBack, VoidCallback? onSearch}) =>
    FlAppBar(
      title: 'Réglages',
      titleSize: titleSize,
      back: FlAppBarBack(label: 'Retour', onPressed: onBack ?? () {}),
      actions: [FlAppBarAction(icon: _icon, label: 'Rechercher', onPressed: onSearch ?? () {})],
    );

/// Une barre épinglée en tête d'une liste qu'on peut faire défiler.
Widget _scrolling(FlAppBar bar, ScrollController controller) => SizedBox(
  height: 600,
  child: CustomScrollView(
    controller: controller,
    slivers: [
      FlSliverAppBar(appBar: bar),
      SliverList.list(children: [for (var i = 0; i < 40; i++) SizedBox(height: 48, child: Text('Ligne $i'))]),
    ],
  ),
);

/// Le voile de la barre levée, ou null au repos.
Color? _glass(WidgetTester tester) {
  final blur = find.descendant(of: find.byType(FlAppBar), matching: find.byType(BackdropFilter));
  if (blur.evaluate().isEmpty) return null;
  return tester.widget<ColoredBox>(find.descendant(of: blur, matching: find.byType(ColoredBox)).first).color;
}

void main() {
  final tokens = FlTokens.defaults;

  testWidgets('devrait annoncer le titre comme en-tête et nommer le retour et les actions', (tester) async {
    final semantics = tester.ensureSemantics();
    var back = 0, search = 0;
    await tester.pumpWidget(_app(_bar(onBack: () => back++, onSearch: () => search++)));
    expect(tester.getSemantics(find.text('Réglages')), matchesSemantics(label: 'Réglages', isHeader: true));
    expect(find.bySemanticsLabel('Retour'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Retour'));
    await tester.tap(find.bySemanticsLabel('Rechercher'));
    expect((back, search), (1, 1));
    semantics.dispose();
  });

  testWidgets('devrait centrer le titre et donner la hauteur de barre de la plateforme sous la zone sûre', (
    tester,
  ) async {
    for (final (platform, height) in [(TargetPlatform.iOS, 52.0), (TargetPlatform.android, 56.0)]) {
      await tester.pumpWidget(_app(SizedBox(width: 390, child: _bar()), platform: platform, top: 47));
      final bar = tester.getRect(find.byType(FlAppBar));
      expect(bar.height, 47 + height, reason: '$platform');
      final title = tester.getRect(find.text('Réglages'));
      expect(title.center.dx, closeTo(bar.center.dx, 0.5), reason: '$platform');
      expect(title.center.dy, closeTo(47 + height / 2, 0.5), reason: '$platform');
    }
  });

  testWidgets('devrait refuser plus de trois actions', (tester) async {
    await tester.pumpWidget(
      _app(
        FlAppBar(
          title: 'Réglages',
          actions: [for (var i = 0; i < 4; i++) FlAppBarAction(icon: _icon, label: '$i', onPressed: () {})],
        ),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('devrait tourner le chevron vers le début de la ligne quand le texte va de droite à gauche', (
    tester,
  ) async {
    for (final (direction, flipped) in [(TextDirection.ltr, false), (TextDirection.rtl, true)]) {
      await tester.pumpWidget(_app(SizedBox(width: 390, child: _bar()), direction: direction));
      final flip = tester.widget<Transform>(
        find.descendant(of: find.bySemanticsLabel('Retour'), matching: find.byType(Transform)).last,
      );
      expect(flip.transform.entry(0, 0), flipped ? -1 : 1, reason: '$direction');
      final back = tester.getRect(find.bySemanticsLabel('Retour'));
      final bar = tester.getRect(find.byType(FlAppBar));
      expect(direction == TextDirection.ltr ? back.left < bar.center.dx : back.left > bar.center.dx, isTrue);
    }
  });

  testWidgets('devrait plafonner le titre de la barre à iconMaxScale quand le texte est agrandi', (tester) async {
    await tester.pumpWidget(_app(SizedBox(width: 390, child: _bar()), scale: 2));
    final text = tester.widget<Text>(find.text('Réglages'));
    expect(text.textScaler!.scale(10), 10 * tokens.size.iconMaxScale);
    expect(tester.takeException(), isNull);
  });

  testWidgets('devrait rester transparente au repos et se voiler de surface quand le contenu passe dessous', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(_app(SizedBox(width: 390, child: _scrolling(_bar(), controller))));
    expect(_glass(tester), isNull);
    controller.jumpTo(6);
    await tester.pump();
    expect(_glass(tester)!.a, closeTo(0.85 * 0.5, 0.01));
    controller.jumpTo(100);
    await tester.pump();
    expect(_glass(tester), tokens.light.surface.withValues(alpha: 0.85));
    expect(tester.getRect(find.byType(FlAppBar)).top, 0);
  });

  testWidgets('devrait partir avec le contenu, revenir dès qu’on remonte, et se voiler hors du haut', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final bar = _bar(titleSize: FlAppBarTitleSize.large);
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 390,
          height: 600,
          child: Stack(
            children: [
              Builder(
                builder: (context) => CustomScrollView(
                  controller: controller,
                  slivers: [
                    SliverPadding(padding: EdgeInsets.only(top: FlFloatingAppBar.restExtent(context, bar))),
                    SliverList.list(
                      children: [for (var i = 0; i < 40; i++) SizedBox(height: 48, child: Text('Ligne $i'))],
                    ),
                  ],
                ),
              ),
              FlFloatingAppBar(appBar: bar, controller: controller),
            ],
          ),
        ),
      ),
    );
    final title = find.text('Réglages');
    final top = tester.getRect(title).top;
    final list = find.byType(Scrollable);
    expect(_glass(tester), isNull, reason: 'au repos');
    await tester.drag(list, const Offset(0, -20));
    await tester.pump();
    expect(tester.getRect(title).top, closeTo(top - 20, 0.5), reason: 'avec le contenu');
    expect(_glass(tester), isNull, reason: 'rien ne passe encore dessous');
    await tester.drag(list, const Offset(0, -300));
    await tester.pump();
    expect(title.hitTestable(), findsNothing, reason: 'partie');
    await tester.drag(list, const Offset(0, 30));
    await tester.pump();
    expect(_glass(tester), tokens.light.surface.withValues(alpha: 0.85), reason: 'sur son verre');
    await tester.drag(list, const Offset(0, 100));
    await tester.pump();
    expect(tester.getRect(title).top, top, reason: 'entière, loin du haut');
    final pixels = controller.offset;
    controller.jumpTo(pixels + 200);
    await tester.pump();
    expect(tester.getRect(title).top, top, reason: 'un saut ne la chasse pas');
    controller.jumpTo(0);
    await tester.pump();
    expect(_glass(tester), isNull, reason: 'en haut, au repos');
  });

  testWidgets('devrait bâtir autour du titre, qui garde son rôle d’en-tête', (tester) async {
    final semantics = tester.ensureSemantics();
    var opened = 0;
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 390,
          child: FlAppBar(
            title: 'Pour vous',
            titleSize: FlAppBarTitleSize.large,
            titleBuilder: (context, title) => GestureDetector(
              onTap: () => opened++,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  title,
                  const SizedBox.square(key: Key('chevron'), dimension: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('chevron')), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Pour vous')),
      matchesSemantics(label: 'Pour vous', isHeader: true, hasTapAction: true),
    );
    await tester.tap(find.text('Pour vous'));
    expect(opened, 1);
    semantics.dispose();
  });

  testWidgets('devrait réduire le grand titre à la taille d’un titre moyen au défilement, puis se voiler', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = ScrollController();
    await tester.pumpWidget(
      _app(SizedBox(width: 390, child: _scrolling(_bar(titleSize: FlAppBarTitleSize.large), controller))),
    );
    final title1 = tokens.typography.ios.style(FlTextRole.title1);
    final headline = tokens.typography.ios.style(FlTextRole.headline);
    final title = find.text('Réglages');
    double scale() => tester
        .widget<Transform>(find.ancestor(of: title, matching: find.byType(Transform)).first)
        .transform
        .entry(0, 0);
    expect(tester.getRect(find.byType(FlAppBar)).height, 52);
    expect(tester.widget<Text>(title).style!.fontSize, title1.size);
    expect(scale(), 1);
    expect(tester.getSemantics(title), matchesSemantics(label: 'Réglages', isHeader: true));
    expect(tester.getRect(title).left, greaterThan(tester.getRect(find.bySemanticsLabel('Retour')).right));

    controller.jumpTo(title1.lineHeight / 2);
    await tester.pump();
    expect(scale(), closeTo((1 + headline.size / title1.size) / 2, 0.01));
    expect(_glass(tester), isNull);

    controller.jumpTo(title1.lineHeight);
    await tester.pump();
    expect(scale(), closeTo(headline.size / title1.size, 0.001));
    expect(tester.getRect(find.byType(FlAppBar)).height, 52);
    expect(_glass(tester), isNull);

    controller.jumpTo(title1.lineHeight + 40);
    await tester.pump();
    expect(_glass(tester), tokens.light.surface.withValues(alpha: 0.85));
    semantics.dispose();
  });

  testWidgets('devrait poser le grand titre sans retour à space.lg, à la hauteur des actions', (tester) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 390,
          child: FlAppBar(
            title: 'Messages',
            titleSize: FlAppBarTitleSize.large,
            actions: [FlAppBarAction(icon: _icon, label: 'Rechercher', onPressed: () {})],
          ),
        ),
      ),
    );
    final title = tester.getRect(find.text('Messages'));
    expect(title.left - tester.getRect(find.byType(FlAppBar)).left, tokens.space.lg);
    expect(title.center.dy, closeTo(tester.getRect(find.bySemanticsLabel('Rechercher')).center.dy, 0.5));
  });

  testWidgets('devrait dessiner le retour et les icônes en disques tertiary, nus sans filled', (tester) async {
    for (final filled in [true, false]) {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 390,
            child: FlAppBar(
              title: 'Produit',
              filled: filled,
              back: FlAppBarBack(label: 'Retour', onPressed: () {}),
              actions: [FlAppBarAction(icon: _icon, label: 'Partager', onPressed: () {})],
            ),
          ),
        ),
      );
      for (final label in ['Retour', 'Partager']) {
        final button = tester.widget<FlButton>(
          find.ancestor(of: find.bySemanticsLabel(label), matching: find.byType(FlButton)).first,
        );
        expect(button.variant, filled ? FlButtonVariant.tertiary : FlButtonVariant.ghost, reason: label);
        expect(tester.getSize(find.byWidget(button)), Size.square(tokens.size.controlCompact - tokens.space.xs));
      }
      expect(find.text('Retour'), findsNothing);
    }
  });

  testWidgets('devrait agrandir le grand titre sans le rogner quand la police agrandit la ligne', (tester) async {
    await tester.pumpWidget(
      _app(
        DefaultTextStyle(
          style: const TextStyle(height: 2),
          child: SizedBox(width: 390, child: _bar(titleSize: FlAppBarTitleSize.large)),
        ),
      ),
    );
    final bar = tester.getRect(find.byType(FlAppBar));
    final title = tester.getRect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.style!.fontSize == tokens.typography.ios.style(FlTextRole.title1).size,
      ),
    );
    expect(title.height, greaterThan(tokens.typography.ios.style(FlTextRole.title1).lineHeight));
    expect(title.bottom, lessThanOrEqualTo(bar.bottom - tokens.space.sm));
  });

  testWidgets('devrait garder retour, actions et grand titre hors de l’encoche en paysage', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(left: 47, right: 47)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: FlScope(
            brightness: Brightness.light,
            platform: TargetPlatform.iOS,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 844, child: _bar(titleSize: FlAppBarTitleSize.large)),
            ),
          ),
        ),
      ),
    );
    final bar = tester.getRect(find.byType(FlAppBar));
    expect(bar.width, 844, reason: 'le fond va d’un bord à l’autre');
    expect(tester.getRect(find.bySemanticsLabel('Retour')).left, greaterThanOrEqualTo(47));
    expect(tester.getRect(find.bySemanticsLabel('Rechercher')).right, lessThanOrEqualTo(844 - 47));
    final large = find.byWidgetPredicate(
      (widget) => widget is Text && widget.style!.fontSize == tokens.typography.ios.style(FlTextRole.title1).size,
    );
    expect(tester.getRect(large).left, greaterThan(tester.getRect(find.bySemanticsLabel('Retour')).right));
  });

  testWidgets('devrait écrire l’action texte dans une pilule accent, plafonner son mot et garder une cible de 44', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var saved = 0;
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 390,
          child: FlAppBar(
            title: 'Profil',
            actions: [FlAppBarAction.text(label: 'Enregistrer', onPressed: () => saved++)],
          ),
        ),
        scale: 2,
      ),
    );
    final word = find.text('Enregistrer');
    expect(tester.widget<Text>(word).textScaler!.scale(10), 10 * tokens.size.iconMaxScale);
    expect(tester.takeException(), isNull);
    final pill = find.ancestor(of: word, matching: find.byType(DecoratedBox)).first;
    expect((tester.widget<DecoratedBox>(pill).decoration as BoxDecoration).color, tokens.light.accent);
    final node = find.bySemanticsLabel('Enregistrer');
    final target = MatrixUtils.transformRect(
      tester.renderObject(node).getTransformTo(null),
      tester.getSemantics(node).rect,
    );
    expect(target.height, greaterThanOrEqualTo(44));
    await tester.tapAt(tester.getRect(pill).center);
    expect(saved, 1);
    semantics.dispose();
  });

  testWidgets('devrait remplacer le mot par un spinner et ne plus répondre pendant le chargement', (tester) async {
    var saved = 0;
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 390,
          child: FlAppBar(
            title: 'Profil',
            actions: [FlAppBarAction.text(label: 'Enregistrer', onPressed: () => saved++, loading: true)],
          ),
        ),
      ),
    );
    expect(find.byType(FlSpinner), findsOneWidget);
    await tester.tap(find.byType(FlSpinner), warnIfMissed: false);
    expect(saved, 0);
  });

  testWidgets('devrait dessiner l’icône du retour à la place du chevron, dans le même disque', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 390,
          child: FlAppBar(
            title: 'Nouvel événement',
            back: FlAppBarBack(
              label: 'Fermer',
              icon: const SizedBox(key: Key('xmark'), width: 16, height: 16),
              onPressed: () => closed++,
            ),
          ),
        ),
      ),
    );
    final button = find.ancestor(of: find.byKey(const Key('xmark')), matching: find.byType(FlButton)).first;
    expect(tester.getSize(button), Size.square(tokens.size.controlCompact - tokens.space.xs));
    expect(find.byType(FlIcon), findsNothing);
    await tester.tap(button);
    expect(closed, 1);
  });

  testWidgets('devrait poser leading au début d’une barre sans retour, le grand titre à côté', (tester) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 390,
          child: FlAppBar(
            title: 'Accueil',
            titleSize: FlAppBarTitleSize.large,
            leading: const SizedBox(key: Key('avatar'), width: 40, height: 40),
            actions: [FlAppBarAction(icon: _icon, label: 'Notifications', onPressed: () {})],
          ),
        ),
      ),
    );
    final bar = tester.getRect(find.byType(FlAppBar));
    final avatar = tester.getRect(find.byKey(const Key('avatar')));
    final title = tester.getRect(find.text('Accueil'));
    expect(avatar.left - bar.left, tokens.space.sm);
    expect(title.left - avatar.right, tokens.space.sm);
    expect(avatar.center.dy, closeTo(title.center.dy, 0.5));
  });

  testWidgets('devrait poser des icônes de statut claires sur l’accent, sombres sur la page claire', (tester) async {
    Brightness icons() => tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(find.byType(AnnotatedRegion<SystemUiOverlayStyle>))
        .value
        .statusBarIconBrightness!;
    await tester.pumpWidget(_app(const FlAppBar(title: 'Now playing')));
    expect(icons(), Brightness.dark);
    await tester.pumpWidget(_app(const FlAccentScope(child: FlAppBar(title: 'Now playing'))));
    expect(icons(), Brightness.light);
  });
}
