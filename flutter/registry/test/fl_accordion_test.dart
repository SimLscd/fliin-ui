import 'dart:math' as math;

import 'package:fliin_ui/components/accordion/fl_accordion.dart';
import 'package:fliin_ui/components/separator/fl_separator.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'torture/torture.g.dart';

Widget _app(Widget child, {bool reduced = false, TextDirection direction = TextDirection.ltr, double textScale = 1}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduced, textScaler: TextScaler.linear(textScale)),
      child: Directionality(
        textDirection: direction,
        child: FlScope(
          platform: TargetPlatform.iOS,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: 360, child: child),
          ),
        ),
      ),
    );

List<FlAccordionItem<String>> _items({bool secondEnabled = true}) => [
  FlAccordionItem(value: 'a', title: 'Commande', content: const Text('Réponse A')),
  FlAccordionItem(value: 'b', title: 'Paiement', content: const Text('Réponse B'), enabled: secondEnabled),
  FlAccordionItem(value: 'c', title: 'Livraison', content: const Text('Réponse C')),
];

Future<void> _tap(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

Set<String> _open(WidgetTester tester) => {
  for (final (text, value) in [('Réponse A', 'a'), ('Réponse B', 'b'), ('Réponse C', 'c')])
    if (find.text(text).evaluate().isNotEmpty) value,
};

double _turnOf(WidgetTester tester, String title) {
  final row = find.ancestor(of: find.text(title), matching: find.byType(Row)).last;
  final transform = tester.widget<Transform>(find.descendant(of: row, matching: find.byType(Transform)).last);
  return math.atan2(transform.transform.entry(1, 0), transform.transform.entry(0, 0));
}

void main() {
  final tokens = FlTokens.defaults;

  testWidgets('devrait n’ouvrir qu’une section à la fois, et refermer celle qu’on rappuie', (tester) async {
    await tester.pumpWidget(_app(FlAccordion<String>(items: _items())));
    expect(_open(tester), isEmpty);
    await _tap(tester, 'Commande');
    expect(_open(tester), {'a'});
    await _tap(tester, 'Paiement');
    expect(_open(tester), {'b'});
    await _tap(tester, 'Paiement');
    expect(_open(tester), isEmpty);
  });

  testWidgets('devrait garder ouverte la section rappuyée quand collapsible est faux', (tester) async {
    await tester.pumpWidget(
      _app(FlAccordion<String>(items: _items(), collapsible: false, initialExpanded: const {'a'})),
    );
    await _tap(tester, 'Commande');
    expect(_open(tester), {'a'});
  });

  testWidgets('devrait ouvrir plusieurs sections en mode multiple', (tester) async {
    await tester.pumpWidget(_app(FlAccordion<String>(items: _items(), selection: FlAccordionSelection.multiple)));
    await _tap(tester, 'Commande');
    await _tap(tester, 'Livraison');
    expect(_open(tester), {'a', 'c'});
    await _tap(tester, 'Commande');
    expect(_open(tester), {'c'});
  });

  testWidgets('devrait laisser l’app tenir les sections ouvertes quand expanded est donné', (tester) async {
    final changes = <Set<String>>[];
    await tester.pumpWidget(
      _app(FlAccordion<String>(items: _items(), expanded: const {'c'}, onExpandedChanged: changes.add)),
    );
    await _tap(tester, 'Commande');
    expect(changes, [
      {'a'},
    ]);
    expect(_open(tester), {'c'});
  });

  testWidgets('devrait ignorer l’appui et pâlir l’en-tête d’une section désactivée', (tester) async {
    await tester.pumpWidget(_app(FlAccordion<String>(items: _items(secondEnabled: false))));
    await _tap(tester, 'Paiement');
    expect(_open(tester), isEmpty);
    final opacity = tester.widget<Opacity>(find.ancestor(of: find.text('Paiement'), matching: find.byType(Opacity)));
    expect(opacity.opacity, tokens.size.disabledOpacity);
    await tester.pumpWidget(_app(FlAccordion<String>(items: _items(), enabled: false)));
    await _tap(tester, 'Commande');
    expect(_open(tester), isEmpty);
  });

  testWidgets(
    'devrait déplier au ressort layout, faire entrer le contenu en fondu et tourner le chevron d’un demi-tour',
    (tester) async {
      await tester.pumpWidget(_app(FlAccordion<String>(items: _items())));
      final closed = tester.getSize(find.byType(FlAccordion<String>)).height;
      await tester.tap(find.text('Commande'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final opening = tester.getSize(find.byType(FlAccordion<String>)).height;
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: find.text('Réponse A'), matching: find.byType(FadeTransition)),
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      expect(_turnOf(tester, 'Commande'), inExclusiveRange(-math.pi, 0));
      await tester.pumpAndSettle();
      final open = tester.getSize(find.byType(FlAccordion<String>)).height;
      expect(opening, inExclusiveRange(closed, open));
      expect(fade.opacity.value, 1);
      expect(_turnOf(tester, 'Commande').abs(), closeTo(math.pi, 1e-9));
    },
  );

  testWidgets('devrait suivre le ressort layout, pas celui d’expand, à mi-course', (tester) async {
    await tester.pumpWidget(_app(FlAccordion<String>(items: _items(), initialExpanded: const {'a'})));
    final open = tester.getSize(find.byType(FlAccordion<String>)).height;
    await tester.pumpWidget(_app(FlAccordion<String>(key: const Key('fermé'), items: _items())));
    final closed = tester.getSize(find.byType(FlAccordion<String>)).height;
    final springs = FlMotion.of(tester.element(find.byType(FlAccordion<String>))).tokens;
    double at(SpringDescription spring) => closed + (open - closed) * SpringSimulation(spring, 0, 1, 0).x(0.1);
    expect((at(springs.layout) - at(springs.expand)).abs(), greaterThan(3));
    await tester.tap(find.text('Commande'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(find.byType(FlAccordion<String>)).height, closeTo(at(springs.layout), 0.5));
  });

  testWidgets('devrait ouvrir avec Entrée et refermer avec Espace la section focalisée au clavier', (tester) async {
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (context, _) => _app(FocusScope(autofocus: true, child: FlAccordion<String>(items: _items()))),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_open(tester), {'a'});
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(_open(tester), isEmpty);
  });

  testWidgets('devrait poser le chevron au bout de la ligne dans le sens de lecture', (tester) async {
    Finder chevron() => find
        .descendant(
          of: find.ancestor(of: find.text('Commande'), matching: find.byType(Row)).last,
          matching: find.byType(Transform),
        )
        .last;
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(_app(FlAccordion<String>(items: _items()), direction: direction));
      final title = tester.getRect(find.text('Commande'));
      final box = tester.getRect(find.byType(FlAccordion<String>));
      final indicator = tester.getRect(chevron());
      final rtl = direction == TextDirection.rtl;
      expect(rtl ? indicator.right < title.left : indicator.left > title.right, isTrue, reason: direction.name);
      expect(rtl ? title.right - box.left : box.right - title.left, greaterThan(box.width / 2), reason: direction.name);
    }
  });

  testWidgets('devrait poser l’icône leading avant le titre, à 12, atténuée et à la taille de l’indicateur', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        _app(
          FlAccordion<String>(
            items: [
              FlAccordionItem(
                value: 'a',
                title: 'Commande',
                leading: FlIcon(FlIcons.shoppingCart),
                content: const Text('Réponse A'),
              ),
            ],
          ),
          direction: direction,
        ),
      );
      final icon = find.byType(FlIcon).first;
      final title = tester.getRect(find.text('Commande'));
      final glyph = tester.getRect(icon);
      final rtl = direction == TextDirection.rtl;
      expect(rtl ? glyph.left - title.right : title.left - glyph.right, tokens.space.xs * 3, reason: direction.name);
      expect(glyph.size, Size.square(tokens.size.indicatorIcon), reason: direction.name);
      final theme = IconTheme.of(tester.element(find.descendant(of: icon, matching: find.byType(CustomPaint))));
      expect(theme.color, tokens.light.onSurfaceMuted, reason: direction.name);
    }
  });

  testWidgets('devrait grandir l’icône leading, le chevron et l’indicateur avec le texte jusqu’à iconMaxScale', (
    tester,
  ) async {
    Widget accordion() => FlAccordion<String>(
      items: [
        FlAccordionItem(
          value: 'a',
          title: 'Commande',
          leading: FlIcon(FlIcons.shoppingCart, key: const ValueKey('leading')),
          content: const Text('Réponse A'),
        ),
        FlAccordionItem(
          value: 'b',
          title: 'Paiement',
          indicator: FlIcon(FlIcons.plus, key: const ValueKey('indicator')),
          content: const Text('Réponse B'),
        ),
      ],
    );
    final chevron = find.byWidgetPredicate((widget) => widget is FlIcon && widget.icon == FlIcons.chevronDown);
    for (final scale in [1.0, 1.2, 2.0]) {
      await tester.pumpWidget(_app(accordion(), textScale: scale));
      final side = tokens.size.indicatorIcon * math.min(scale, tokens.size.iconMaxScale);
      for (final icon in [find.byKey(const ValueKey('leading')), find.byKey(const ValueKey('indicator')), chevron]) {
        expect(tester.getSize(icon), Size.square(side), reason: '$icon à $scale');
        final theme = IconTheme.of(tester.element(find.descendant(of: icon, matching: find.byType(CustomPaint))));
        expect(theme.color, tokens.light.onSurfaceMuted, reason: '$icon à $scale');
      }
    }
  });

  testWidgets('devrait grandir l’en-tête avec le texte à 2,0 et déplier sans débordement', (tester) async {
    double header(WidgetTester tester) =>
        tester.getSize(find.ancestor(of: find.text('Commande'), matching: find.byType(FlPressable)).first).height;
    await tester.pumpWidget(_app(FlAccordion<String>(items: _items())));
    final regular = header(tester);
    await tester.pumpWidget(_app(FlAccordion<String>(items: _items()), textScale: 2));
    final line = tokens.typography.ios.textBase.lineHeight;
    expect(header(tester), closeTo(regular + line, 1));
    await _tap(tester, 'Commande');
    expect(tester.takeException(), isNull);
    expect(_open(tester), {'a'});
    expect(
      tester.getRect(find.text('Réponse A')).top,
      greaterThanOrEqualTo(tester.getRect(find.text('Commande')).bottom),
    );
  });

  testWidgets('devrait sauter à la hauteur ouverte sous mouvement réduit', (tester) async {
    await tester.pumpWidget(_app(FlAccordion<String>(items: _items()), reduced: true));
    await tester.tap(find.text('Commande'));
    await tester.pump();
    final first = tester.getSize(find.byType(FlAccordion<String>)).height;
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FlAccordion<String>)).height, first);
    expect(_turnOf(tester, 'Commande').abs(), closeTo(math.pi, 1e-9));
  });

  testWidgets('devrait annoncer chaque en-tête comme un bouton d’en-tête, ouvert ou fermé', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(FlAccordion<String>(items: _items(), initialExpanded: const {'b'})));
    final closed = tester.getSemantics(find.text('Commande'));
    expect(closed.flagsCollection.isButton, isTrue);
    expect(closed.flagsCollection.isHeader, isTrue);
    expect(closed.flagsCollection.isExpanded.toBoolOrNull(), isFalse);
    expect(tester.getSemantics(find.text('Paiement')).flagsCollection.isExpanded.toBoolOrNull(), isTrue);
    handle.dispose();
  });

  testWidgets('devrait tirer un filet entre les sections, retiré de 12 sur la surface, et aucun sans separators', (
    tester,
  ) async {
    await tester.pumpWidget(_app(FlAccordion<String>(items: _items())));
    expect(find.byType(FlSeparator), findsNWidgets(2));
    expect(tester.getSize(find.byType(FlSeparator).first).width, 360);
    await tester.pumpWidget(_app(FlAccordion<String>(items: _items(), variant: FlAccordionVariant.surface)));
    expect(tester.getRect(find.byType(FlSeparator).first).left, (800 - 360) / 2 + 1 + 12);
    await tester.pumpWidget(_app(FlAccordion<String>(items: _items(), separators: false)));
    expect(find.byType(FlSeparator), findsNothing);
  });

  testWidgets('devrait retirer titre et contenu de 4, de 16 dans la bordure de 1 de la surface (canvas)', (
    tester,
  ) async {
    for (final (variant, inset) in [(FlAccordionVariant.plain, 4.0), (FlAccordionVariant.surface, 17.0)]) {
      await tester.pumpWidget(
        _app(FlAccordion<String>(items: _items(), variant: variant, initialExpanded: const {'a'})),
      );
      final left = tester.getRect(find.byType(FlAccordion<String>)).left;
      expect(tester.getRect(find.text('Commande')).left - left, inset, reason: variant.name);
      expect(tester.getRect(find.text('Réponse A')).left - left, inset, reason: variant.name);
    }
  });

  testWidgets('devrait garder chaque en-tête à la cible de la plateforme quand les marges des jetons rétrécissent', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: FlScope(
          tokens: tortureB,
          platform: TargetPlatform.iOS,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              child: FlAccordion<String>(items: _items(), variant: FlAccordionVariant.surface),
            ),
          ),
        ),
      ),
    );
    final header = find.ancestor(of: find.text('Commande'), matching: find.byType(Container)).first;
    expect(tester.getSize(header).height, greaterThanOrEqualTo(tortureB.size.hitTargetIos));
  });

  testWidgets('devrait montrer les morceaux du titre, surlignés, et lire le titre quand titleSpans est donné', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    const mark = TextStyle(fontWeight: FontWeight.w700);
    await tester.pumpWidget(
      _app(
        FlAccordion<String>(
          items: [
            FlAccordionItem(
              value: 'a',
              title: 'Moyens de paiement',
              titleSpans: const [
                TextSpan(text: 'Moyens de '),
                TextSpan(text: 'paiement', style: mark),
              ],
              content: const Text('Réponse A'),
            ),
          ],
        ),
      ),
    );
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final spans = <TextSpan>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span);
      return true;
    });
    expect(spans.map((s) => s.text), ['Moyens de ', 'paiement']);
    expect(spans.last.style?.fontWeight, FontWeight.w700);
    expect(find.bySemanticsLabel('Moyens de paiement'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('devrait rendre le même titre avec ou sans titleSpans quand les morceaux sont sans style', (
    tester,
  ) async {
    Future<Size> sizeOf(List<InlineSpan>? spans) async {
      await tester.pumpWidget(
        _app(
          FlAccordion<String>(
            key: UniqueKey(),
            items: [
              FlAccordionItem(
                value: 'a',
                title: 'Une question assez longue pour passer à la ligne suivante',
                titleSpans: spans,
                content: const Text('Réponse A'),
              ),
            ],
          ),
        ),
      );
      return tester.getSize(find.byType(RichText).first);
    }

    final plain = await sizeOf(null);
    final split = await sizeOf(const [
      TextSpan(text: 'Une question assez '),
      TextSpan(text: 'longue pour passer à la ligne suivante'),
    ]);
    expect(split, plain);
  });

  testWidgets('devrait refuser en debug des morceaux dont le texte n’est pas le titre', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final report = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = report);
    await tester.pumpWidget(
      _app(
        FlAccordion<String>(
          items: [
            FlAccordionItem(
              value: 'a',
              title: 'Paiement',
              titleSpans: const [TextSpan(text: 'Livraison')],
              content: const Text('Réponse A'),
            ),
          ],
        ),
      ),
    );
    FlutterError.onError = report;
    expect(errors, isNotEmpty);
    expect(errors.first.exception, isAssertionError);
    expect('${errors.first.exception}', contains('titleSpans'));
  });

  testWidgets('devrait faire descendre le contenu dans l’ouverture pendant son fondu, et pas sous mouvement réduit', (
    tester,
  ) async {
    double drop(WidgetTester tester, [String answer = 'Réponse A']) => tester
        .widget<Transform>(find.ancestor(of: find.text(answer), matching: find.byType(Transform)).first)
        .transform
        .getTranslation()
        .y;
    await tester.pumpWidget(_app(FlAccordion<String>(items: _items())));
    await tester.tap(find.text('Commande'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(drop(tester), inExclusiveRange(-tokens.space.sm, 0), reason: 'it settles down from space.sm above');
    await tester.pumpAndSettle();
    expect(drop(tester), 0);
    await tester.pumpWidget(_app(FlAccordion<String>(items: _items()), reduced: true));
    await tester.tap(find.text('Paiement'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(drop(tester, 'Réponse B'), 0);
  });

  testWidgets('devrait écrire le sous-titre sous le titre, en textSm atténué', (tester) async {
    await tester.pumpWidget(
      _app(
        FlAccordion<String>(
          items: [
            FlAccordionItem(value: 'a', title: 'Commande', subtitle: 'Suivi et retours', content: const Text('A')),
          ],
        ),
      ),
    );
    final subtitle = tester.widget<Text>(find.text('Suivi et retours')).style!;
    expect(subtitle.fontSize, tokens.typography.ios.textSm.size);
    expect(subtitle.color, tokens.light.onSurfaceMuted);
    expect(tester.getTopLeft(find.text('Suivi et retours')).dy, tester.getBottomLeft(find.text('Commande')).dy);
  });

  testWidgets('devrait passer de indicator à expandedIndicator quand la section s’ouvre, sans tourner', (tester) async {
    await tester.pumpWidget(
      _app(
        FlAccordion<String>(
          items: [
            FlAccordionItem(
              value: 'a',
              title: 'Commande',
              indicator: const SizedBox(key: Key('plus'), width: 16, height: 16),
              expandedIndicator: const SizedBox(key: Key('minus'), width: 16, height: 16),
              content: const Text('A'),
            ),
          ],
        ),
      ),
    );
    final fade = find.byType(AnimatedCrossFade);
    expect(tester.widget<AnimatedCrossFade>(fade).crossFadeState, CrossFadeState.showFirst);
    await _tap(tester, 'Commande');
    expect(tester.widget<AnimatedCrossFade>(fade).crossFadeState, CrossFadeState.showSecond);
  });
}
