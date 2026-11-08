import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/input_group/fl_input_group.dart';
import 'package:fliin_ui/components/text_field/fl_text_field.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_host.dart';

Widget _app(Widget child, {TextDirection direction = TextDirection.ltr}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => Directionality(
    textDirection: direction,
    child: FlScope(
      brightness: Brightness.light,
      platform: TargetPlatform.iOS,
      child: OverlayHost(
        child: Center(child: SizedBox(width: 320, child: child)),
      ),
    ),
  ),
);

const _prefix = Key('prefix');
const _suffix = Key('suffix');

/// L'opacité où se peint [finder] : le produit des calques d'opacité
/// au-dessus du premier calque de son sous-arbre (un `RepaintBoundary`, la
/// cible de la barre d'édition d'un `EditableText`).
double _paintOpacity(WidgetTester tester, Finder finder) {
  Layer? layerOf(RenderObject node) {
    Layer? found = node.debugLayer;
    node.visitChildren((child) => found ??= layerOf(child));
    return found;
  }

  var opacity = 1.0;
  for (Layer? layer = layerOf(tester.renderObject(finder)); layer != null; layer = layer.parent) {
    if (layer is OpacityLayer) opacity *= layer.alpha! / 255;
  }
  return opacity;
}

FocusNode _focus(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText)).focusNode;

void main() {
  testWidgets(
    'devrait poser le préfixe au début et le suffixe à la fin, à space.md des bords et space.sm du texte, dans les deux sens',
    (tester) async {
      final md = FlTokens.defaults.space.md;
      final sm = FlTokens.defaults.space.sm;
      for (final direction in TextDirection.values) {
        await tester.pumpWidget(
          _app(
            const FlInputGroup(
              prefix: SizedBox(key: _prefix, width: 16, height: 16),
              suffix: SizedBox(key: _suffix, width: 16, height: 16),
              child: FlInput(label: 'Site'),
            ),
            direction: direction,
          ),
        );
        final frame = tester.getRect(find.byType(FlInputFrame));
        final text = tester.getRect(find.byType(EditableText));
        final before = tester.getRect(find.byKey(_prefix));
        final after = tester.getRect(find.byKey(_suffix));
        final reason = direction.name;
        if (direction == TextDirection.ltr) {
          expect(before.left - frame.left, md, reason: reason);
          expect(text.left - before.right, sm, reason: reason);
          expect(frame.right - after.right, md, reason: reason);
          expect(after.left - text.right, sm, reason: reason);
        } else {
          expect(frame.right - before.right, md, reason: reason);
          expect(before.left - text.right, sm, reason: reason);
          expect(after.left - frame.left, md, reason: reason);
          expect(text.left - after.right, sm, reason: reason);
        }
        expect(before.center.dy, frame.center.dy, reason: reason);
      }
    },
  );

  testWidgets('devrait rapprocher un affixe serré à space.xs du bord, et garder space.sm du texte', (tester) async {
    final xs = FlTokens.defaults.space.xs;
    final sm = FlTokens.defaults.space.sm;
    await tester.pumpWidget(
      _app(
        const FlInputGroup(
          prefix: SizedBox(key: _prefix, width: 16, height: 16),
          suffix: SizedBox(key: _suffix, width: 16, height: 16),
          tightPrefix: true,
          tightSuffix: true,
          child: FlInput(label: 'Site'),
        ),
      ),
    );
    final frame = tester.getRect(find.byType(FlInputFrame));
    final text = tester.getRect(find.byType(EditableText));
    expect(tester.getRect(find.byKey(_prefix)).left - frame.left, xs);
    expect(text.left - tester.getRect(find.byKey(_prefix)).right, sm);
    expect(frame.right - tester.getRect(find.byKey(_suffix)).right, xs);
  });

  testWidgets('devrait garder la hauteur du contrôle avec un bouton de flInputAffixExtent en suffixe', (tester) async {
    late double extent;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            extent = flInputAffixExtent(FlScope.of(context));
            return FlInputGroup(
              tightSuffix: true,
              suffix: FlButton.icon(
                label: 'Afficher',
                icon: const SizedBox.square(dimension: 16),
                variant: FlButtonVariant.ghost,
                size: FlButtonSize.sm,
                extent: extent,
                onPressed: () {},
              ),
              child: const FlInput(label: 'Mot de passe'),
            );
          },
        ),
      ),
    );
    final theme = FlScope.of(tester.element(find.byType(FlInput)));
    expect(tester.getSize(find.byType(FlInputFrame)).height, theme.controlHeight);
    expect(extent, theme.controlHeight - 2 * theme.space.xs);
  });

  testWidgets("devrait taire un affixe décoratif et donner son toucher à l'entrée", (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _app(
        FlInputGroup(
          prefix: GestureDetector(
            onTap: () => taps++,
            child: const SizedBox(key: _prefix, width: 16, height: 16, child: Text('https://')),
          ),
          decorativePrefix: true,
          child: const FlInput(label: 'Site'),
        ),
      ),
    );
    expect(tester.getSemantics(find.byType(EditableText)).label, 'Site');
    expect(find.bySemanticsLabel(RegExp('https')), findsNothing);
    await tester.tap(find.byKey(_prefix));
    await tester.pump();
    expect(_focus(tester).hasFocus, isTrue);
    expect(taps, 0, reason: "l'affixe décoratif ne reçoit pas le toucher");
    semantics.dispose();
  });

  testWidgets("devrait laisser à un affixe interactif son toucher, sans donner le focus à l'entrée", (tester) async {
    var shown = 0;
    await tester.pumpWidget(
      _app(
        FlInputGroup(
          suffix: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => shown++,
            child: const SizedBox(key: _suffix, width: 16, height: 16),
          ),
          child: const FlInput(label: 'Mot de passe', obscureText: true),
        ),
      ),
    );
    await tester.tap(find.byKey(_suffix));
    await tester.pump();
    expect(shown, 1);
    expect(_focus(tester).hasFocus, isFalse);
  });

  testWidgets("devrait laisser la saisie à l'entrée quand la cible d'un petit bouton d'affixe déborde sur le texte", (
    tester,
  ) async {
    final taps = {'prefix': 0, 'suffix': 0};
    Widget button(String id) => FlButton.icon(
      key: Key(id),
      label: id,
      extent: 16,
      variant: FlButtonVariant.tertiary,
      onPressed: () => taps[id] = taps[id]! + 1,
      icon: const SizedBox.square(dimension: 8),
    );
    await tester.pumpWidget(
      _app(
        FlInputGroup(
          prefix: button('prefix'),
          suffix: button('suffix'),
          child: const FlInput(label: 'Site'),
        ),
      ),
    );
    final text = tester.getRect(find.byType(EditableText));
    expect(text.left - tester.getRect(find.byKey(const Key('prefix'))).right, lessThan(14), reason: 'la cible déborde');
    await tester.tapAt(text.centerRight - const Offset(1, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tapAt(text.centerLeft + const Offset(1, 0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(taps, {'prefix': 0, 'suffix': 0});
    expect(_focus(tester).hasFocus, isTrue);
    await tester.tap(find.byKey(const Key('suffix')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(taps['suffix'], 1, reason: 'le bouton garde son toucher');
  });

  testWidgets("devrait désactiver l'entrée et pâlir ses affixes avec elle quand le groupe est désactivé", (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const FlInputGroup(
          disabled: true,
          prefix: RepaintBoundary(key: _prefix, child: SizedBox(width: 16, height: 16)),
          child: FlInput(label: 'Site'),
        ),
      ),
    );
    expect(_focus(tester).canRequestFocus, isFalse);
    final faded = closeTo(FlTokens.defaults.size.disabledOpacity, 1 / 255);
    expect(_paintOpacity(tester, find.byKey(_prefix)), faded, reason: "l'affixe pâlit une fois");
    expect(_paintOpacity(tester, find.byType(EditableText)), faded, reason: 'la saisie pâlit une fois');
  });

  testWidgets(
    "devrait couper un affixe trop long d'une ellipse plutôt que déborder, et garder de la place à la saisie",
    (tester) async {
      await tester.pumpWidget(
        _app(
          const FlInputGroup(
            prefix: Text('https://www.un-domaine-vraiment-tres-long.example'),
            child: FlInput(label: 'Site'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final frame = tester.getRect(find.byType(FlInputFrame));
      expect(tester.getSize(find.byType(EditableText)).width, greaterThan(frame.width / 2));
      final affix = tester.widget<DefaultTextStyle>(
        find.ancestor(of: find.textContaining('https'), matching: find.byType(DefaultTextStyle)).first,
      );
      expect(affix.overflow, TextOverflow.ellipsis);
    },
  );

  testWidgets("devrait couper toucher, focus et sémantique d'un affixe interactif quand l'entrée est désactivée", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _app(
        FlInputGroup(
          disabled: true,
          suffix: Semantics(
            button: true,
            label: 'Montrer',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(key: _suffix, width: 16, height: 16),
            ),
          ),
          child: const FlInput(label: 'Mot de passe', obscureText: true),
        ),
      ),
    );
    await tester.tap(find.byKey(_suffix), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
    expect(find.bySemanticsLabel('Montrer'), findsNothing);
    semantics.dispose();
  });
}
