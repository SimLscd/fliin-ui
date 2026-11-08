import 'package:fliin_ui/components/spinner/fl_spinner.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: FlScope(
    brightness: Brightness.light,
    child: Center(child: child),
  ),
);

double _turns(WidgetTester tester) => tester.widget<RotationTransition>(find.byType(RotationTransition)).turns.value;

void main() {
  testWidgets('devrait s’annoncer comme un chargement nommé', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const FlSpinner(label: 'Chargement')));
    expect(find.bySemanticsLabel('Chargement'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('devrait prendre la taille de sa variante', (tester) async {
    final size = FlTokens.defaults.size;
    for (final (variant, side) in [
      (FlSpinnerSize.sm, size.spinnerSm),
      (FlSpinnerSize.md, size.spinnerMd),
      (FlSpinnerSize.lg, size.spinnerLg),
    ]) {
      await tester.pumpWidget(_app(FlSpinner(label: 'x', size: variant)));
      expect(tester.getSize(find.byType(FlSpinner)), Size.square(side), reason: variant.name);
    }
  });

  testWidgets('devrait tourner et apparaître en fondu, et rester immobile et visible sous Reduce Motion', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const FlSpinner(label: 'x')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_turns(tester), greaterThan(0));
    expect(tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value, 1);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_app(const FlSpinner(key: Key('still'), label: 'x')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_turns(tester), 0);
    expect(tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value, 1);
  });

  testWidgets('devrait tourner deux fois plus vite quand speed vaut 2, et suivre un changement de speed', (
    tester,
  ) async {
    final turn = FlTokens.defaults.motion.indicatorTurn * (1 / 1.1);
    final quarter = turn ~/ 4;
    await tester.pumpWidget(_app(const FlSpinner(label: 'x')));
    await tester.pump(quarter);
    expect(_turns(tester), closeTo(0.25, 0.01));
    await tester.pumpWidget(_app(const FlSpinner(key: Key('vite'), label: 'x', speed: 2)));
    await tester.pump(quarter);
    expect(_turns(tester), closeTo(0.5, 0.01));
    await tester.pumpWidget(_app(const FlSpinner(key: Key('vite'), label: 'x', speed: 0.5)));
    final before = _turns(tester);
    await tester.pump(quarter);
    expect(_turns(tester) - before, closeTo(0.125, 0.01));
  });
}
