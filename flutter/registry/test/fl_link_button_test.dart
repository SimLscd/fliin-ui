import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/link_button/fl_link_button.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: FlScope(
    brightness: Brightness.light,
    platform: TargetPlatform.iOS,
    child: Center(child: child),
  ),
);

void main() {
  testWidgets('devrait s’annoncer comme un bouton nommé et appeler onPressed au toucher', (tester) async {
    final semantics = tester.ensureSemantics();
    var pressed = 0;
    await tester.pumpWidget(_app(FlLinkButton(label: 'Conditions', onPressed: () => pressed++)));
    expect(
      tester.getSemantics(find.byType(FlLinkButton)),
      matchesSemantics(
        label: 'Conditions',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(find.byType(FlLinkButton));
    expect(pressed, 1);
    semantics.dispose();
  });

  testWidgets('devrait lire semanticLabel à la place du mot affiché, en bouton comme en lien', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final link in [false, true]) {
      await tester.pumpWidget(
        _app(FlLinkButton(label: 'Retirer', semanticLabel: 'Retirer Sac cabas en lin', link: link, onPressed: () {})),
      );
      expect(find.bySemanticsLabel('Retirer Sac cabas en lin'), findsOneWidget, reason: 'link: $link');
      expect(find.bySemanticsLabel('Retirer'), findsNothing, reason: 'link: $link');
      expect(find.text('Retirer'), findsOneWidget);
    }
    semantics.dispose();
  });

  testWidgets('devrait faire la hauteur de sa ligne, sans marge, quand il est posé dans un texte', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final (size, role) in [
      (FlButtonSize.sm, FlTextRole.textSm),
      (FlButtonSize.md, FlTextRole.textBase),
      (FlButtonSize.lg, FlTextRole.textLg),
    ]) {
      await tester.pumpWidget(_app(FlLinkButton(label: 'Conditions', size: size, onPressed: () {})));
      final line = FlTokens.defaults.typography.ios.style(role).lineHeight;
      expect(tester.getSize(find.byType(FlLinkButton)).height, line, reason: '$size');
      expect(
        tester.getSize(find.byType(FlLinkButton)).width,
        closeTo(tester.getSize(find.text('Conditions')).width, 1),
      );
    }
    expect(tester.getSemantics(find.byType(FlLinkButton)).rect.height, FlTokens.defaults.size.hitTargetIos);
    semantics.dispose();
  });

  testWidgets('devrait écrire en onControl, sans voile à l’appui', (tester) async {
    await tester.pumpWidget(
      _app(
        FlLinkButton(
          label: 'Conditions',
          statesController: WidgetStatesController({WidgetState.pressed}),
          onPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text('Conditions'));
    expect(text.style!.color, FlTokens.defaults.light.onControl);
    expect(find.byType(FlPressHighlight), findsNothing);
  });

  testWidgets('devrait passer à demi opaque et ignorer le toucher quand onPressed est nul', (tester) async {
    await tester.pumpWidget(_app(const FlLinkButton(label: 'Conditions', onPressed: null)));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, FlTokens.defaults.size.disabledOpacity);
    await tester.tap(find.byType(FlLinkButton), warnIfMissed: false);
  });

  testWidgets('devrait s’annoncer comme un lien, à la cible de la plateforme, quand link est vrai', (tester) async {
    final semantics = tester.ensureSemantics();
    var pressed = 0;
    await tester.pumpWidget(_app(FlLinkButton(label: 'Conditions', link: true, onPressed: () => pressed++)));
    final node = tester.getSemantics(find.bySemanticsLabel('Conditions'));
    expect(
      node,
      matchesSemantics(label: 'Conditions', isLink: true, hasEnabledState: true, isEnabled: true, hasTapAction: true),
    );
    expect(node.rect.height, FlTokens.defaults.size.hitTargetIos);
    expect(find.bySemanticsLabel('Conditions'), findsOneWidget);
    tester.semantics.tap(find.semantics.byLabel('Conditions'));
    await tester.tap(find.byType(FlLinkButton));
    expect(pressed, 2);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets(
    'devrait rester en onControl et se souligner d’un trait plus discret que le mot quand accent ou underline est vrai',
    (tester) async {
      final light = FlTokens.defaults.light;
      final color = light.onControl;
      // Au repos, le trait d'un lien normal est onSurfaceMuted.
      final rest = light.onSurfaceMuted;
      for (final (accent, underline) in [(true, false), (false, true), (true, true)]) {
        await tester.pumpWidget(
          _app(FlLinkButton(label: 'Conditions', accent: accent, underline: underline, onPressed: () {})),
        );
        final style = tester.widget<Text>(find.text('Conditions')).style!;
        expect(style.color, color, reason: 'un lien n’est jamais en accent');
        final text = tester.getRect(find.text('Conditions'));
        expect(
          tester.renderObject(find.byType(FlLinkButton)),
          paints..something((method, arguments) {
            if (method != #drawRect) return false;
            final [Rect rect, Paint paint] = arguments;
            return paint.color.toARGB32() == rest.toARGB32() &&
                rect.height == FlTokens.defaults.size.border &&
                rect.top > text.height / 2;
          }),
        );
      }
      await tester.pumpWidget(_app(FlLinkButton(label: 'Conditions', onPressed: () {})));
      expect(tester.renderObject(find.byType(FlLinkButton)), isNot(paints..rect(color: rest)));
    },
  );

  testWidgets('devrait teinter leading et trailing comme le mot, aux trois quarts de sa taille', (tester) async {
    final seen = <IconThemeData>[];
    Widget icon() => Builder(
      builder: (context) {
        seen.add(IconTheme.of(context));
        return const SizedBox.square(dimension: 1);
      },
    );
    for (final tone in FlLinkButtonTone.values) {
      seen.clear();
      await tester.pumpWidget(
        _app(FlLinkButton(label: 'Suite', tone: tone, leading: icon(), trailing: icon(), onPressed: () {})),
      );
      final color = tester.widget<Text>(find.text('Suite')).style!.color;
      expect(seen, hasLength(2));
      for (final theme in seen) {
        expect(theme.color, color, reason: '$tone');
        expect(theme.size, FlTokens.defaults.typography.ios.textBase.size * 0.75, reason: '$tone');
      }
    }
    final row = tester.getRect(find.byType(Row));
    final text = tester.getRect(find.text('Suite'));
    expect(text.left - row.left, 1 + FlTokens.defaults.space.xs, reason: 'space.xs après l’icône de tête');
  });

  testWidgets('devrait se souligner en onSurfaceMuted au survol quand underline est faux', (tester) async {
    final muted = FlTokens.defaults.light.onSurfaceMuted;
    PaintPattern line() => paints
      ..something((method, arguments) {
        if (method != #drawRect) return false;
        final [_, Paint paint] = arguments;
        return paint.color.toARGB32() == muted.toARGB32();
      });
    await tester.pumpWidget(_app(FlLinkButton(label: 'Conditions', onPressed: () {})));
    expect(tester.renderObject(find.byType(FlLinkButton)), isNot(line()));
    await tester.pumpWidget(
      _app(
        FlLinkButton(
          label: 'Conditions',
          statesController: WidgetStatesController({WidgetState.hovered}),
          onPressed: () {},
        ),
      ),
    );
    expect(tester.renderObject(find.byType(FlLinkButton)), line());
  });

  testWidgets('devrait ne jamais se souligner avec plain, ni au survol ni pressé', (tester) async {
    PaintPattern line() => paints..something((method, arguments) => method == #drawRect);
    for (final state in [WidgetState.hovered, WidgetState.pressed]) {
      await tester.pumpWidget(
        _app(
          FlLinkButton(
            label: 'Répondre',
            plain: true,
            statesController: WidgetStatesController({state}),
            onPressed: () {},
          ),
        ),
      );
      expect(tester.renderObject(find.byType(FlLinkButton)), isNot(line()), reason: '$state');
    }
  });
}
