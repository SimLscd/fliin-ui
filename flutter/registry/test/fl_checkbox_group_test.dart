import 'dart:ui' show CheckedState, SemanticsValidationResult, Tristate;

import 'package:fliin_ui/components/checkbox_group/fl_checkbox_group.dart';
import 'package:fliin_ui/components/control_field/fl_control_field.dart';
import 'package:fliin_ui/components/field/fl_field.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

/// Un groupe que le parent tient à jour.
class _Host extends StatefulWidget {
  const _Host({this.invalid = false, this.disabled = false, this.required = false, this.selectAll});

  final bool invalid;
  final bool disabled;
  final bool required;
  final String? selectAll;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Set<String> value = {'email'};
  final changes = <Set<String>>[];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: FlCheckboxGroup<String>(
      label: 'Notifications',
      description: 'Choisissez au moins un canal',
      error: 'Choisissez un canal',
      invalid: widget.invalid,
      disabled: widget.disabled,
      required: widget.required,
      selectAllLabel: widget.selectAll,
      value: value,
      onChanged: (next) => setState(() {
        changes.add(next);
        value = next;
      }),
      options: const [
        FlCheckboxGroupOption(value: 'email', label: 'E-mail'),
        FlCheckboxGroupOption(value: 'sms', label: 'SMS', description: 'Frais de votre opérateur'),
        FlCheckboxGroupOption(value: 'push', label: 'Push', disabled: true),
      ],
    ),
  );
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

Finder _row(String label) => find.widgetWithText(FlControlField, label);

void main() {
  testWidgets("devrait ajouter puis retirer la valeur d'une case quand on touche sa ligne", (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.tap(_row('SMS'));
    await tester.pump();
    await tester.tap(_row('E-mail'));
    await tester.pump();
    expect(_host(tester).changes, [
      {'email', 'sms'},
      {'sms'},
    ]);
  });

  testWidgets('devrait ignorer une case désactivée, et toutes quand le groupe est désactivé', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.tap(_row('Push'));
    await tester.pump();
    expect(_host(tester).changes, isEmpty);

    await tester.pumpWidget(toggleApp(const _Host(disabled: true)));
    await tester.tap(_row('SMS'));
    await tester.pump();
    expect(_host(tester).changes, isEmpty);
    for (final field in tester.widgetList<FlControlField>(find.byType(FlControlField))) {
      expect(field.onChanged, isNull);
    }
  });

  testWidgets(
    "devrait s'annoncer comme un groupe nommé et décrit, requis, chaque case en dessous quand le lecteur d'écran le lit",
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(toggleApp(const _Host(required: true)));
      final group = tester.getSemantics(find.byType(FlCheckboxGroup<String>));
      expect(group.label, 'Notifications');
      expect(group.hint, 'Choisissez au moins un canal');
      expect(group.flagsCollection.isRequired, Tristate.isTrue);
      final children = <SemanticsNode>[];
      group.visitChildren((child) {
        children.add(child);
        return true;
      });
      expect(children.map((node) => node.label), ['E-mail', 'SMS', 'Push']);
      expect(children.map((node) => node.flagsCollection.isChecked), [
        CheckedState.isTrue,
        CheckedState.isFalse,
        CheckedState.isFalse,
      ]);
      semantics.dispose();
    },
  );

  testWidgets(
    "devrait montrer l'erreur en région vivante et passer chaque case à l'état invalide quand le groupe est invalide",
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(toggleApp(const _Host()));
      expect(find.text('Choisissez un canal'), findsNothing);

      await tester.pumpWidget(toggleApp(const _Host(invalid: true)));
      await tester.pumpAndSettle();
      expect(find.text('Choisissez un canal'), findsOneWidget);
      expect(tester.getSemantics(find.text('Choisissez un canal')).flagsCollection.isLiveRegion, isTrue);
      for (final field in tester.widgetList<FlControlField>(find.byType(FlControlField))) {
        expect(field.invalid, isTrue);
      }
      expect(
        find.ancestor(of: find.byType(FlFieldError), matching: find.byType(FlCheckboxGroup<String>)),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );

  testWidgets("devrait porter l'état invalide sur le nœud du groupe pour le lecteur d'écran (relecture B9)", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host()));
    expect(
      tester.getSemantics(find.byType(FlCheckboxGroup<String>)).getSemanticsData().validationResult,
      SemanticsValidationResult.none,
    );
    await tester.pumpWidget(toggleApp(const _Host(invalid: true)));
    expect(
      tester.getSemantics(find.byType(FlCheckboxGroup<String>)).getSemanticsData().validationResult,
      SemanticsValidationResult.invalid,
    );
    semantics.dispose();
  });

  testWidgets('devrait additionner deux cases touchées avant que le parent ne rende la première (relecture B10)', (
    tester,
  ) async {
    final sent = <Set<String>>[];
    await tester.pumpWidget(
      toggleApp(
        SizedBox(
          width: 320,
          child: FlCheckboxGroup<String>(
            label: 'Notifications',
            value: const {'email'},
            onChanged: sent.add,
            options: const [
              FlCheckboxGroupOption(value: 'email', label: 'E-mail'),
              FlCheckboxGroupOption(value: 'sms', label: 'SMS'),
              FlCheckboxGroupOption(value: 'push', label: 'Push'),
            ],
          ),
        ),
      ),
    );
    await tester.tap(_row('SMS'));
    await tester.tap(_row('Push'));
    await tester.pump();
    expect(sent, [
      {'email', 'sms'},
      {'email', 'sms', 'push'},
    ]);
  });

  testWidgets('devrait tout cocher puis tout décocher, sauf la case désactivée, quand on touche « Tout choisir »', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host(selectAll: 'Tout choisir')));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Tout choisir')).getSemanticsData().flagsCollection.isChecked,
      CheckedState.mixed,
      reason: 'une case sur trois',
    );
    await tester.tap(find.text('Tout choisir'));
    await tester.pump();
    expect(_host(tester).value, {'email', 'sms'}, reason: 'Push est désactivée');
    expect(
      tester.getSemantics(find.bySemanticsLabel('Tout choisir')).getSemanticsData().flagsCollection.isChecked,
      CheckedState.mixed,
      reason: 'Push reste décochée',
    );
    await tester.tap(_row('Push'));
    await tester.pump();
    expect(_host(tester).value, {'email', 'sms'});
    expect(
      tester.getRect(_row('SMS')).left,
      greaterThan(tester.getRect(find.text('Tout choisir')).left - 1),
      reason: 'les cases en retrait, sous le libellé',
    );
    semantics.dispose();
  });
}
