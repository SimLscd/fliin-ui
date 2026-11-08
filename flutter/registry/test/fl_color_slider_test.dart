import 'package:fliin_ui/components/color_slider/fl_color_slider.dart';
import 'package:fliin_ui/components/color_swatch/fl_color_swatch.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

/// Un curseur de teinte que le parent tient à jour.
class _Host extends StatefulWidget {
  const _Host({this.channel = FlColorChannel.hue, this.enabled = true});

  final FlColorChannel channel;
  final bool enabled;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  HSVColor value = const HSVColor.fromAHSV(1, 90, 1, 1);
  final ends = <HSVColor>[];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    child: FlColorSlider(
      value: value,
      channel: widget.channel,
      label: 'Teinte',
      onChangeEnd: ends.add,
      onChanged: widget.enabled ? (next) => setState(() => value = next) : null,
    ),
  );
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

/// Le point de la piste à la fraction [t] de la course du pouce : de la
/// moitié d'un embout à l'autre, 10 de chaque bout.
Offset _at(WidgetTester tester, double t, {bool rtl = false}) {
  final track = tester.getRect(
    find.descendant(of: find.byType(FlColorSlider), matching: find.byType(LayoutBuilder)).first,
  );
  final along = 10 + t * (track.width - 20);
  return Offset(rtl ? track.right - along : track.left + along, track.center.dy);
}

void main() {
  testWidgets('devrait régler la teinte au point touché, entre les milieux des deux embouts', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.tapAt(_at(tester, 0.75));
    await tester.pump();
    expect(_host(tester).value.hue, closeTo(270, 0.5));
    expect(_host(tester).ends.single.hue, closeTo(270, 0.5));
    await tester.tapAt(_at(tester, 0) - const Offset(8, 0));
    await tester.pump();
    expect(_host(tester).value.hue, 0, reason: 'l’embout est la borne');
  });

  testWidgets('devrait partir de la droite en arabe', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(), direction: TextDirection.rtl));
    await tester.tapAt(_at(tester, 0.25, rtl: true));
    await tester.pump();
    expect(_host(tester).value.hue, closeTo(90, 0.5));
  });

  testWidgets('devrait suivre le doigt pendant un glissé, et ne rendre la fin qu’au lâcher', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final gesture = await tester.startGesture(_at(tester, 0.25));
    await gesture.moveTo(_at(tester, 0.5));
    await tester.pump();
    expect(_host(tester).value.hue, closeTo(180, 0.5));
    expect(_host(tester).ends, isEmpty);
    await gesture.up();
    await tester.pump();
    expect(_host(tester).ends.single.hue, closeTo(180, 0.5));
  });

  testWidgets("devrait s'annoncer comme un curseur en degrés, d'un degré par geste", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host()));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Teinte')),
      matchesSemantics(
        label: 'Teinte',
        isSlider: true,
        value: '90°',
        increasedValue: '91°',
        decreasedValue: '89°',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    tester.semantics.performAction(find.semantics.byLabel('Teinte'), SemanticsAction.decrease);
    await tester.pump();
    expect(_host(tester).value.hue, 89);
    semantics.dispose();
  });

  testWidgets('devrait avancer d’un pas aux flèches, de dix à Page, et aller aux bornes à Début et Fin', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const _Host(channel: FlColorChannel.alpha)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_host(tester).value.alpha, closeTo(0.99, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(_host(tester).value.alpha, closeTo(0.89, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(_host(tester).value.alpha, 0);
    expect(_host(tester).value.hue, 90, reason: 'les autres canaux ne bougent pas');
  });

  testWidgets('devrait passer à demi opaque et ignorer le toucher quand onChanged est nul', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(enabled: false)));
    await tester.tapAt(_at(tester, 0.9));
    await tester.pump();
    expect(_host(tester).value.hue, 90);
    expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, lessThan(1));
  });

  test('devrait peindre la piste des couleurs que le canal traverse, depuis la valeur', () {
    const blue = HSVColor.fromAHSV(1, 217, 0.76, 0.96);
    final saturation = flColorTrack(blue, FlColorChannel.saturation, FlColorSpace.hsb);
    expect(saturation.first, blue.withSaturation(0).toColor());
    expect(saturation.last, blue.withSaturation(1).toColor());
    final hue = flColorTrack(blue, FlColorChannel.hue, FlColorSpace.hsb);
    expect(hue, hasLength(7));
    expect(hue.first, const Color(0xFFFF0000), reason: 'la roue entière, à saturation et luminosité pleines');
    final lightness = flColorTrack(blue, FlColorChannel.lightness, FlColorSpace.hsl);
    expect([lightness.first, lightness.last], [const Color(0xFF000000), const Color(0xFFFFFFFF)]);
    final alpha = flColorTrack(blue.withAlpha(0.5), FlColorChannel.alpha, FlColorSpace.hsb);
    expect([alpha.first.a, alpha.last.a], [0, 1]);
  });
}
