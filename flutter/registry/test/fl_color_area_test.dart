import 'package:fliin_ui/components/color_area/fl_color_area.dart';
import 'package:fliin_ui/components/color_swatch/fl_color_swatch.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

/// Une zone de saturation et de luminosité que le parent tient à jour.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  HSVColor value = const HSVColor.fromAHSV(1, 291, 0.5, 0.5);
  final ends = <HSVColor>[];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    child: FlColorArea(
      value: value,
      xLabel: 'Saturation',
      yLabel: 'Luminosité',
      onChangeEnd: ends.add,
      onChanged: (next) => setState(() => value = next),
    ),
  );
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

Rect _area(WidgetTester tester) =>
    tester.getRect(find.descendant(of: find.byType(FlColorArea), matching: find.byType(CustomPaint)).first);

void main() {
  testWidgets('devrait faire 224 de côté au plus, et poser saturation et luminosité au point touché', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final area = _area(tester);
    expect(area.size, const Size.square(224));
    await tester.tapAt(area.topLeft + Offset(area.width * 0.75, area.height * 0.25));
    await tester.pump();
    expect(_host(tester).value.saturation, closeTo(0.75, 0.01));
    expect(_host(tester).value.value, closeTo(0.75, 0.01));
    expect(_host(tester).value.hue, 291, reason: 'la teinte ne bouge pas');
    expect(_host(tester).ends, hasLength(1));
  });

  testWidgets('devrait faire croître la saturation vers la gauche en arabe', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(), direction: TextDirection.rtl));
    final area = _area(tester);
    await tester.tapAt(area.topLeft + Offset(area.width * 0.2, area.height * 0.5));
    await tester.pump();
    expect(_host(tester).value.saturation, closeTo(0.8, 0.01));
  });

  testWidgets('devrait grossir le pouce de 16 à 20 pendant le glissé, puis revenir', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    double thumb() => tester.getSize(find.byType(FlColorThumb)).width;
    expect(thumb(), 16);
    final area = _area(tester);
    final gesture = await tester.startGesture(area.center);
    await gesture.moveBy(const Offset(30, -30));
    await tester.pumpAndSettle();
    expect(thumb(), 20);
    expect(_host(tester).value.saturation, closeTo(0.5 + 30 / 224, 0.01));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(thumb(), 16);
  });

  testWidgets("devrait s'annoncer comme deux curseurs, un par canal", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host()));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Saturation')),
      matchesSemantics(
        label: 'Saturation',
        isSlider: true,
        value: '50%',
        increasedValue: '51%',
        decreasedValue: '49%',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    tester.semantics.performAction(find.semantics.byLabel('Luminosité'), SemanticsAction.increase);
    await tester.pump();
    expect(_host(tester).value.value, closeTo(0.51, 1e-9));
    expect(_host(tester).value.saturation, 0.5);
    semantics.dispose();
  });

  testWidgets('devrait déplacer la saturation aux flèches horizontales et la luminosité aux verticales', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_host(tester).value.saturation, closeTo(0.51, 1e-9));
    expect(_host(tester).value.value, closeTo(0.51, 1e-9));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(_host(tester).value.saturation, closeTo(0.41, 1e-9));
  });
}
