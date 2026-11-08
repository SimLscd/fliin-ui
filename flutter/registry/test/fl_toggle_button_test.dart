import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/toggle_button/fl_toggle_button.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

/// Un bouton à bascule que le parent tient à jour.
class _Host extends StatefulWidget {
  const _Host({super.key, this.variant = FlToggleButtonVariant.filled});

  final FlToggleButtonVariant variant;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool bold = false;

  @override
  Widget build(BuildContext context) => FlToggleButton(
    label: 'Gras',
    selected: bold,
    variant: widget.variant,
    onChanged: (next) => setState(() => bold = next),
  );
}

FlButton _button(WidgetTester tester) => tester.widget<FlButton>(find.byType(FlButton));

void main() {
  testWidgets('devrait s’allumer puis s’éteindre quand on le touche deux fois', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    expect(_button(tester).selected, isFalse);
    await tester.tap(find.text('Gras'));
    await tester.pump();
    expect(_button(tester).selected, isTrue);
    await tester.tap(find.text('Gras'));
    await tester.pump();
    expect(_button(tester).selected, isFalse);
  });

  testWidgets('devrait basculer à la barre d’espace quand il a le focus clavier', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(_button(tester).selected, isTrue);
  });

  testWidgets('devrait prendre le fond selected une fois allumé, plein comme ghost', (tester) async {
    for (final variant in FlToggleButtonVariant.values) {
      await tester.pumpWidget(toggleApp(_Host(key: ValueKey(variant), variant: variant)));
      expect(
        _button(tester).variant,
        variant == FlToggleButtonVariant.filled ? FlButtonVariant.tertiary : FlButtonVariant.ghost,
      );
      await tester.tap(find.text('Gras'));
      await tester.pumpAndSettle();
      expect(_button(tester).variant, FlButtonVariant.tertiary, reason: '$variant allumé');
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is ShapeDecoration &&
              (widget.decoration as ShapeDecoration).color == FlTokens.defaults.light.selected,
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('devrait annoncer son état sans changer de nom quand le lecteur d’écran le lit', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.tap(find.text('Gras'));
    await tester.pump();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Gras')),
      isSemantics(label: 'Gras', isButton: true, isSelected: true, isEnabled: true),
    );
    semantics.dispose();
  });

  testWidgets('devrait se désactiver quand onChanged est nul', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const FlToggleButton(label: 'Gras', selected: true, onChanged: null)));
    expect(_button(tester).onPressed, isNull);
    expect(tester.getSemantics(find.bySemanticsLabel('Gras')), isSemantics(isEnabled: false, isSelected: true));
    semantics.dispose();
  });

  testWidgets('devrait montrer selectedLeading allumé et leading éteint, sans changer de nom', (tester) async {
    Widget toggle(bool on) => toggleApp(
      FlToggleButton(
        label: 'Favori',
        selected: on,
        leading: const SizedBox(key: Key('off')),
        selectedLeading: const SizedBox(key: Key('on')),
        onChanged: (_) {},
      ),
    );
    await tester.pumpWidget(toggle(false));
    expect(find.byKey(const Key('off')), findsOneWidget);
    expect(find.byKey(const Key('on')), findsNothing);
    await tester.pumpWidget(toggle(true));
    expect(find.byKey(const Key('on')), findsOneWidget);
    expect(find.byKey(const Key('off')), findsNothing);
    expect(find.text('Favori'), findsOneWidget);
  });

  testWidgets('devrait montrer selectedIcon une fois allumé quand le bouton n’a qu’une icône', (tester) async {
    await tester.pumpWidget(
      toggleApp(
        FlToggleButton.icon(
          label: 'Favori',
          selected: true,
          icon: const SizedBox(key: Key('off')),
          selectedIcon: const SizedBox(key: Key('on')),
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.byKey(const Key('on')), findsOneWidget);
    expect(find.byKey(const Key('off')), findsNothing);
  });
}
