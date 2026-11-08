import 'dart:ui' show SemanticsValidationResult, Tristate;

import 'package:fliin_ui/components/control_field/fl_control_field.dart';
import 'package:fliin_ui/components/switch_group/fl_switch_group.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

/// Trois réglages indépendants, que le parent tient à jour.
class _Host extends StatefulWidget {
  const _Host({this.invalid = false, this.disabled = false});

  final bool invalid;
  final bool disabled;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool sounds = true;
  bool badges = false;
  final changes = <String>[];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: FlSwitchGroup(
      label: 'Alertes',
      description: 'Pour chaque message reçu',
      error: 'Gardez au moins une alerte',
      invalid: widget.invalid,
      disabled: widget.disabled,
      options: [
        FlSwitchGroupOption(
          value: sounds,
          label: 'Sons',
          onChanged: (on) => setState(() {
            changes.add('sons $on');
            sounds = on;
          }),
        ),
        FlSwitchGroupOption(
          value: badges,
          label: 'Pastilles',
          onChanged: (on) => setState(() {
            changes.add('pastilles $on');
            badges = on;
          }),
        ),
        const FlSwitchGroupOption(value: false, label: 'Aperçus', onChanged: null),
      ],
    ),
  );
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

Finder _row(String label) => find.widgetWithText(FlControlField, label);

void main() {
  testWidgets('devrait basculer chaque réglage seul quand on touche sa ligne', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.tap(_row('Pastilles'));
    await tester.pump();
    await tester.tap(_row('Sons'));
    await tester.pump();
    await tester.tap(_row('Aperçus'));
    await tester.pump();
    expect(_host(tester).changes, ['pastilles true', 'sons false']);
  });

  testWidgets('devrait désactiver chaque réglage quand le groupe est désactivé', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(disabled: true)));
    await tester.tap(_row('Sons'));
    await tester.pump();
    expect(_host(tester).changes, isEmpty);
    for (final field in tester.widgetList<FlControlField>(find.byType(FlControlField))) {
      expect(field.onChanged, isNull);
    }
  });

  testWidgets(
    "devrait s'annoncer comme un groupe nommé et décrit, chaque interrupteur en dessous quand le lecteur d'écran le lit",
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(toggleApp(const _Host()));
      final group = tester.getSemantics(find.byType(FlSwitchGroup));
      expect(group.label, 'Alertes');
      expect(group.hint, 'Pour chaque message reçu');
      final children = <SemanticsNode>[];
      group.visitChildren((child) {
        children.add(child);
        return true;
      });
      expect(children.map((node) => node.label), ['Sons', 'Pastilles', 'Aperçus']);
      expect(children.map((node) => node.flagsCollection.isToggled), [
        Tristate.isTrue,
        Tristate.isFalse,
        Tristate.isFalse,
      ]);
      semantics.dispose();
    },
  );

  testWidgets("devrait montrer l'erreur commune en région vivante quand le groupe est invalide", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host()));
    expect(find.text('Gardez au moins une alerte'), findsNothing);
    await tester.pumpWidget(toggleApp(const _Host(invalid: true)));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.text('Gardez au moins une alerte')).flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });

  testWidgets("devrait porter l'état invalide sur le nœud du groupe pour le lecteur d'écran (relecture B9)", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host(invalid: true)));
    expect(
      tester.getSemantics(find.byType(FlSwitchGroup)).getSemanticsData().validationResult,
      SemanticsValidationResult.invalid,
    );
    semantics.dispose();
  });
}
