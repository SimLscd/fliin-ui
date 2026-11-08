import 'dart:ui' show Tristate;

import 'package:fliin_ui/components/color_area/fl_color_area.dart';
import 'package:fliin_ui/components/color_picker/fl_color_picker.dart';
import 'package:fliin_ui/components/color_slider/fl_color_slider.dart';
import 'package:fliin_ui/components/color_swatch/fl_color_swatch.dart';
import 'package:fliin_ui/components/color_swatch_picker/fl_color_swatch_picker.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

const _labels = FlColorPickerLabels(
  saturation: 'Saturation',
  brightness: 'Luminosité',
  hue: 'Teinte',
  alpha: 'Opacité',
  hex: 'Hexadécimal',
  swatches: 'Teintes prêtes',
);

/// Un sélecteur que le parent tient à jour, dans un `Overlay`.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  HSVColor value = const HSVColor.fromAHSV(1, 217, 0.76, 0.96);

  @override
  Widget build(BuildContext context) => Overlay(
    initialEntries: [
      OverlayEntry(
        builder: (context) => Align(
          alignment: AlignmentDirectional.topStart,
          child: FlColorPicker(
            label: 'Choisir une couleur',
            value: value,
            labels: _labels,
            showField: true,
            showAlpha: true,
            swatches: const [
              FlColorSwatchItem(value: Color(0xFFF43F5E), color: Color(0xFFF43F5E), label: 'Rose'),
              FlColorSwatchItem(value: Color(0xFFFAFAFA), color: Color(0xFFFAFAFA), label: 'Blanc'),
            ],
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    ],
  );
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

void main() {
  testWidgets('devrait ouvrir le panneau au toucher du déclencheur, qui annonce la couleur et son ouverture', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host(), platform: TargetPlatform.iOS));
    expect(find.byType(FlColorArea), findsNothing);
    final trigger = find.bySemanticsLabel('Choisir une couleur, #3B82F5FF');
    expect(tester.getSemantics(trigger).flagsCollection.isExpanded, Tristate.isFalse);
    await tester.tap(find.text('Choisir une couleur'));
    await tester.pumpAndSettle();
    expect(find.byType(FlColorArea), findsOneWidget);
    expect(find.byType(FlColorSlider), findsNWidgets(2));
    expect(tester.getSemantics(trigger).flagsCollection.isExpanded, Tristate.isTrue);
    semantics.dispose();
  });

  testWidgets('devrait synchroniser la zone, les curseurs et le champ sur la couleur choisie', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.tap(find.text('Choisir une couleur'));
    await tester.pumpAndSettle();
    tester.semantics.performAction(find.semantics.byLabel('Teinte'), SemanticsAction.increase);
    await tester.pump();
    expect(_host(tester).value.hue, 218);
    expect(tester.widget<FlColorArea>(find.byType(FlColorArea)).value.hue, 218);
    final hex = flColorHex(_host(tester).value.toColor(), alpha: true);
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, hex);

    await tester.enterText(find.byType(EditableText), '#FF0000');
    await tester.pump();
    expect(_host(tester).value.toColor(), const Color(0xFFFF0000));
    expect(tester.widget<FlColorSlider>(find.byType(FlColorSlider).first).value.hue, 0);
    semantics.dispose();
  });

  testWidgets('devrait prendre une teinte prête au toucher, en gardant la teinte d’un gris', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.tap(find.text('Choisir une couleur'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Rose'));
    await tester.pump();
    expect(_host(tester).value.toColor(), const Color(0xFFF43F5E));
    await tester.tap(find.bySemanticsLabel('Blanc'));
    await tester.pump();
    expect(_host(tester).value.toColor(), const Color(0xFFFAFAFA));
    expect(_host(tester).value.hue, closeTo(HSVColor.fromColor(const Color(0xFFF43F5E)).hue, 1e-9));
  });

  testWidgets('devrait remplacer la zone par la saturation et la clarté en HSL quand showArea est faux', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var value = const HSVColor.fromAHSV(1, 217, 0.76, 0.96);
    await tester.pumpWidget(
      toggleApp(
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 248,
            child: FlColorPickerPanel(
              value: value,
              showArea: false,
              labels: const FlColorPickerLabels(
                saturation: 'Saturation',
                brightness: 'Luminosité',
                hue: 'Teinte',
                lightness: 'Clarté',
              ),
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(FlColorArea), findsNothing);
    expect(
      [for (final slider in tester.widgetList<FlColorSlider>(find.byType(FlColorSlider))) slider.channel],
      [FlColorChannel.hue, FlColorChannel.saturation, FlColorChannel.lightness],
    );
    final before = value.toColor();
    tester.semantics.performAction(find.semantics.byLabel('Clarté'), SemanticsAction.increase);
    await tester.pump();
    expect(value.hue, 217, reason: 'la teinte reste');
    expect(value.toColor(), isNot(before));
    semantics.dispose();
  });
}
