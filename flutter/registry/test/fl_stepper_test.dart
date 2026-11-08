import 'package:fliin_ui/components/stepper/fl_stepper.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

/// Un pas à pas que le parent tient à jour.
class _Host extends StatefulWidget {
  const _Host({this.initial = 2, this.step = 1, this.max});

  final int initial;
  final int step;
  final int? max;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int value = widget.initial;

  @override
  Widget build(BuildContext context) => FlStepper(
    value: value,
    label: 'Adultes',
    decrementLabel: 'Moins d’adultes',
    incrementLabel: 'Plus d’adultes',
    step: widget.step,
    max: widget.max,
    onChanged: (next) => setState(() => value = next),
  );
}

void main() {
  testWidgets('devrait faire rouler le nombre vers le haut quand il augmente, puis ne garder que le nouveau', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final rest = tester.getRect(find.text('2'));
    await tester.tap(find.bySemanticsLabel('Plus d’adultes'));
    await tester.pump();
    await tester.pump(FlTokens.defaults.motion.short4 ~/ 2);
    expect(find.text('2'), findsOneWidget, reason: 'l’ancien nombre sort');
    expect(find.text('3'), findsOneWidget);
    expect(tester.getRect(find.text('2')).top, lessThan(rest.top), reason: 'il monte');
    expect(tester.getRect(find.text('3')).top, greaterThan(rest.top), reason: 'le nouveau vient d’en bas');
    await tester.pumpAndSettle();
    expect(find.text('2'), findsNothing);
    expect(tester.getRect(find.text('3')).top, rest.top);
  });

  testWidgets('devrait remplacer le nombre d’un coup quand le mouvement est réduit', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(toggleApp(const _Host(), platform: TargetPlatform.iOS));
    await tester.tap(find.bySemanticsLabel('Plus d’adultes'));
    await tester.pump();
    expect(find.text('2'), findsNothing);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('devrait avancer d’un pas et s’arrêter à la borne quand step dépasse 1', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(initial: 15, step: 15, max: 40)));
    await tester.tap(find.bySemanticsLabel('Plus d’adultes'));
    await tester.pumpAndSettle();
    expect(find.text('30'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Plus d’adultes'));
    await tester.pumpAndSettle();
    expect(find.text('40'), findsOneWidget, reason: 'la borne, pas 45');
    await tester.tap(find.bySemanticsLabel('Moins d’adultes'));
    await tester.pumpAndSettle();
    expect(find.text('25'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.bySemanticsLabel('Moins d’adultes'));
      await tester.pumpAndSettle();
    }
    expect(find.text('0'), findsOneWidget, reason: 'min par défaut');
  });
}
