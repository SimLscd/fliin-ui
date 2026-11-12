import 'package:fliin_ui/components/app_bar/fl_app_bar.dart';
import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/page/fl_page.dart';
import 'package:fliin_ui/components/scroll_shadow/fl_scroll_shadow.dart';
import 'package:fliin_ui/components/text/fl_text.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'torture/themes.dart';
import 'torture/torture.g.dart';

const _safe = EdgeInsets.only(top: 47, bottom: 34);

Widget _page({required List<Widget> info, FlTokens? tokens, Widget? action}) => MediaQuery(
  data: const MediaQueryData(
    size: Size(390, 844),
    padding: _safe,
    viewPadding: _safe,
    textScaler: TextScaler.linear(2),
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: FlScope(
      tokens: tokens ?? FlTokens.defaults,
      brightness: Brightness.light,
      platform: TargetPlatform.iOS,
      child: FlPage(
        appBar: const FlAppBar(title: 'Panier'),
        tabBar: FlPageBar(
          info: info,
          action: action ?? FlButton(label: 'Payer 137,90 €', onPressed: () {}),
        ),
        slivers: const [SliverToBoxAdapter(child: FlText('Contenu'))],
      ),
    ),
  ),
);

const _long =
    'Le paiement n’a pas pu être confirmé. Votre panier est gardé. Réessayez, ou choisissez un autre moyen '
    'de paiement si le problème continue.';

void main() {
  setUpAll(loadTortureFonts);

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets(
    'devrait garder la barre sous la moitié de l’écran, l’action et la barre du haut visibles, sous torture A à 2,0',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(_page(tokens: tortureA, info: [for (var i = 0; i < 3; i++) FlText(_long)]));
      expect(tester.takeException(), isNull);
      final bar = tester.getRect(find.byType(FlPageBar));
      expect(bar.height, lessThanOrEqualTo(844 / 2), reason: 'la moitié de l’écran, zone sûre comprise');
      expect(bar.bottom, 844);
      final action = tester.getRect(find.byType(FlButton));
      expect(action.bottom, lessThanOrEqualTo(844 - _safe.bottom), reason: 'la zone sûre du bas est gardée');
      expect(action.top, greaterThan(bar.top));
      final top = tester.getRect(find.byType(FlAppBar));
      expect(top.height, greaterThanOrEqualTo(_safe.top + 44), reason: 'la barre du haut n’est pas rognée');
      expect(find.text('Contenu'), findsOneWidget);
    },
  );

  testWidgets('devrait faire défiler un avis plus haut que sa part, sans perdre son focus ni son nœud', (tester) async {
    phone(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _page(
        info: [
          for (var i = 0; i < 4; i++) FlText('$_long $i'),
          Focus(child: Builder(builder: (context) => const FlText('Fin de l’avis'))),
        ],
      ),
    );
    final info = find.descendant(of: find.byType(FlPageBar), matching: find.byType(Scrollable)).first;
    final position = tester.state<ScrollableState>(info).position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.scrollUntilVisible(find.text('Fin de l’avis'), 50, scrollable: info);
    expect(tester.getRect(find.text('Fin de l’avis')).bottom, lessThan(tester.getRect(find.byType(FlButton)).top));
    expect(find.bySemanticsLabel('Fin de l’avis'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('devrait laisser l’action seule, à sa hauteur, sans avis', (tester) async {
    phone(tester);
    await tester.pumpWidget(_page(info: const []));
    expect(find.descendant(of: find.byType(FlPageBar), matching: find.byType(FlScrollShadow)), findsNothing);
    final bar = tester.getRect(find.byType(FlPageBar));
    final action = tester.getRect(find.byType(FlButton));
    expect(bar.bottom - action.bottom, greaterThanOrEqualTo(_safe.bottom));
  });

  testWidgets('devrait poser la barre sur le clavier, l’action visible, sous la moitié de la place restante', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(375, 667),
          padding: EdgeInsets.only(top: 47),
          viewPadding: _safe,
          viewInsets: EdgeInsets.only(bottom: 300),
          textScaler: TextScaler.linear(2),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: FlScope(
            brightness: Brightness.light,
            platform: TargetPlatform.iOS,
            child: FlPage(
              appBar: const FlAppBar(title: 'Panier'),
              tabBar: FlPageBar(
                info: const [FlText(_long)],
                action: FlButton(label: 'Payer 137,90 €', onPressed: () {}),
              ),
              slivers: const [SliverToBoxAdapter(child: FlText('Contenu'))],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    const keyboardTop = 667 - 300.0;
    final action = tester.getRect(find.byType(FlButton));
    expect(action.bottom, lessThanOrEqualTo(keyboardTop), reason: 'l’action reste au-dessus du clavier');
    final visible = keyboardTop - tester.getRect(find.byType(FlPageBar)).top;
    expect(visible, lessThanOrEqualTo(keyboardTop / 2 + 0.5), reason: 'la moitié de la place restante');
    expect(tester.getRect(find.text('Contenu')).bottom, lessThanOrEqualTo(tester.getRect(find.byType(FlButton)).top));
  });

  testWidgets('devrait faire défiler une action plus haute que la barre, son bas à l’écran, sans déborder', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      _page(
        tokens: tortureA,
        info: const [FlText(_long)],
        action: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < 3; i++) const FlText(_long),
            FlButton(label: 'Payer 137,90 €', onPressed: () {}),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final bar = tester.getRect(find.byType(FlPageBar));
    expect(bar.height, lessThanOrEqualTo(844 / 2));
    final button = tester.getRect(find.byType(FlButton));
    expect(button.bottom, lessThanOrEqualTo(844 - _safe.bottom));
    expect(button.top, greaterThanOrEqualTo(bar.top));
  });

  testWidgets('devrait laisser voir, flou, le contenu qui passe sous la barre translucide', (tester) async {
    Widget page({required bool translucent}) => MediaQuery(
      data: const MediaQueryData(size: Size(390, 844), padding: _safe, viewPadding: _safe),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: FlScope(
          platform: TargetPlatform.iOS,
          child: FlPage(
            extendBody: true,
            tabBar: FlPageBar(
              translucent: translucent,
              action: FlButton(label: 'Payer', onPressed: () {}),
            ),
            slivers: const [SliverToBoxAdapter(child: SizedBox(height: 2000))],
          ),
        ),
      ),
    );
    await tester.pumpWidget(page(translucent: false));
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.pumpWidget(page(translucent: true));
    expect(find.byType(BackdropFilter), findsOneWidget);
    final background = tester.widget<ColoredBox>(
      find.descendant(of: find.byType(BackdropFilter), matching: find.byType(ColoredBox)).first,
    );
    expect(background.color.a, lessThan(1));
  });

  testWidgets('devrait faire flotter l’action sans bande ni flou, et poser l’avis sur une carte blanche', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844), padding: _safe, viewPadding: _safe),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: FlScope(
            platform: TargetPlatform.iOS,
            brightness: Brightness.light,
            child: FlPage(
              extendBody: true,
              tabBar: FlPageBar(
                floating: true,
                translucent: true,
                info: const [FlText('Ajoutez une adresse pour continuer.')],
                action: FlButton(label: 'Continuer', onPressed: () {}),
              ),
              slivers: const [SliverToBoxAdapter(child: SizedBox(height: 2000))],
            ),
          ),
        ),
      ),
    );
    final bar = find.byType(FlPageBar);
    expect(find.descendant(of: bar, matching: find.byType(BackdropFilter)), findsNothing);
    expect(
      find
          .descendant(of: bar, matching: find.byType(ColoredBox))
          .evaluate()
          .where((element) => element.findAncestorWidgetOfExactType<FlButton>() == null),
      isEmpty,
      reason: 'aucune bande sous l’action',
    );
    final card = tester.widget<DecoratedBox>(
      find.ancestor(of: find.text('Ajoutez une adresse pour continuer.'), matching: find.byType(DecoratedBox)).last,
    );
    final colors = FlScope.of(tester.element(bar)).colors;
    expect((card.decoration as ShapeDecoration).color, colors.surfaceRaised, reason: 'l’avis reste lisible');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'devrait arrêter le lecteur d’écran à la barre translucide : rogné à moitié dessous, caché tout dessous',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: FlScope(
              platform: TargetPlatform.iOS,
              child: FlPage(
                extendBody: true,
                tabBar: FlPageBar(
                  translucent: true,
                  action: FlButton(label: 'Payer', onPressed: () {}),
                ),
                slivers: [
                  SliverList.list(
                    children: [for (var i = 0; i < 30; i++) SizedBox(height: 40, child: FlText('Ligne $i'))],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final bar = tester.getRect(find.byType(FlPageBar)).top;
      var cut = 0;
      for (var i = 0; i < 29 && find.text('Ligne ${i + 1}').evaluate().isNotEmpty; i++) {
        final line = tester.getRect(find.text('Ligne $i'));
        if (line.top >= bar || line.bottom <= bar) continue;
        final node = tester.getSemantics(find.text('Ligne $i'));
        expect(node.rect.height, closeTo(bar - line.top, 0.5), reason: 'la part visible seulement');
        final under = tester.getSemantics(find.text('Ligne ${i + 1}'));
        expect(under.flagsCollection.isHidden, isTrue);
        cut++;
      }
      expect(cut, 1, reason: 'une ligne à cheval sur le bord de la barre');
      semantics.dispose();
    },
  );
}
