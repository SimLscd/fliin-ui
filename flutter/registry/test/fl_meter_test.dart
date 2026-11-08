import 'package:fliin_ui/components/meter/fl_meter.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

Widget _meter(double value, {double max = 100, String Function(double)? valueLabel, bool showLabel = true}) => SizedBox(
  width: 300,
  child: FlMeter(label: 'Stockage', value: value, max: max, valueLabel: valueLabel, showLabel: showLabel),
);

/// La largeur remplie de la piste : le second rectangle arrondi que peint
/// la jauge, après la piste.
double _filled(WidgetTester tester) {
  final widths = <double>[];
  expect(
    find.byType(FlMeter),
    paints..everything((method, arguments) {
      if (method == #drawRRect) widths.add((arguments[0] as RRect).width);
      return true;
    }),
  );
  return widths.length > 1 ? widths[1] : 0;
}

void main() {
  testWidgets('devrait écrire la part de la plage en pourcentage, et l’annoncer, quand aucun libellé n’est donné', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(_meter(3, max: 4)));
    expect(find.text('75%'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Stockage')), matchesSemantics(label: 'Stockage', value: '75%'));
    semantics.dispose();
  });

  testWidgets('devrait borner la valeur à la plage quand elle la dépasse', (tester) async {
    await tester.pumpWidget(toggleApp(_meter(140)));
    expect(find.text('100%'), findsOneWidget);
    await tester.pumpWidget(toggleApp(_meter(-5)));
    await tester.pumpAndSettle();
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('devrait remplir la piste en medium2 quand la valeur change, et d’un coup sous mouvement réduit', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(_meter(20, showLabel: false)));
    expect(_filled(tester), closeTo(60, 0.01));
    await tester.pumpWidget(toggleApp(_meter(80, showLabel: false)));
    await tester.pump(FlTokens.defaults.motion.medium2 ~/ 2);
    expect(_filled(tester), allOf(greaterThan(60), lessThan(240)));
    await tester.pumpAndSettle();
    expect(_filled(tester), closeTo(240, 0.01));

    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(toggleApp(_meter(80, showLabel: false)));
    await tester.pumpWidget(toggleApp(_meter(50, showLabel: false)));
    await tester.pump();
    expect(_filled(tester), closeTo(150, 0.01));
  });

  testWidgets('devrait remplir de fillColor et arrondir tout à fait la piste quand pill est vrai', (tester) async {
    const fill = Color(0xFF123456);
    await tester.pumpWidget(
      toggleApp(
        const SizedBox(
          width: 300,
          child: FlMeter(label: 'Batterie', value: 50, pill: true, fillColor: fill, size: FlMeterSize.lg),
        ),
      ),
    );
    final rrects = <RRect>[];
    final colors = <Color>[];
    expect(
      find.byType(FlMeter),
      paints..everything((method, arguments) {
        if (method == #drawRRect) {
          rrects.add(arguments[0] as RRect);
          colors.add((arguments[1] as Paint).color);
        }
        return true;
      }),
    );
    expect(rrects.first.tlRadiusX, rrects.first.height / 2, reason: 'piste en pilule');
    expect(colors.last.toARGB32(), fill.toARGB32());
  });
}
