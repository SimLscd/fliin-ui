import 'package:fliin_ui/components/text_field/fl_text_field.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_host.dart';

Widget _app(Widget child, {double scale = 1}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: FlScope(
        brightness: Brightness.light,
        platform: TargetPlatform.iOS,
        child: OverlayHost(
          child: FocusScope(
            autofocus: true,
            child: Center(child: SizedBox(width: 320, child: child)),
          ),
        ),
      ),
    ),
  ),
);

double _height(WidgetTester tester, Key key) => tester.getSize(find.byKey(key)).height;

/// Le curseur, en coordonnées de l'écran.
Rect _caret(WidgetTester tester) {
  final editable = tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;
  final local = editable.getLocalRectForCaret(editable.selection!.extent);
  return MatrixUtils.transformRect(editable.getTransformTo(null), local);
}

void main() {
  testWidgets('devrait avoir la hauteur d’une entrée d’une ligne quand le texte tient sur une ligne', (tester) async {
    const single = Key('single');
    const grows = Key('grows');
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlInput(
              key: single,
              label: 'Une',
              controller: TextEditingController(text: 'Bonjour'),
            ),
            FlInput(
              key: grows,
              label: 'Plusieurs',
              maxLines: 5,
              controller: TextEditingController(text: 'Bonjour'),
            ),
          ],
        ),
      ),
    );
    expect(_height(tester, grows), _height(tester, single));
  });

  testWidgets('devrait grandir avec ses lignes, puis plafonner à maxLines', (tester) async {
    const key = Key('grows');
    final controller = TextEditingController(text: 'un');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(FlInput(key: key, label: 'Message', maxLines: 4, controller: controller)));
    final one = _height(tester, key);
    controller.text = 'un\ndeux\ntrois';
    await tester.pump();
    final three = _height(tester, key);
    expect(three, greaterThan(one));
    controller.text = 'un\ndeux\ntrois\nquatre';
    await tester.pump();
    final four = _height(tester, key);
    expect(four, greaterThan(three), reason: 'une ligne de plus');
    controller.text = List.generate(12, (i) => 'ligne $i').join('\n');
    await tester.pump();
    expect(_height(tester, key), four, reason: 'plafonnée à quatre lignes');
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('devrait garder le curseur visible en tapant au-delà de maxLines, texte à $scale', (tester) async {
      const key = Key('grows');
      await tester.pumpWidget(
        _app(
          const FlInput(key: key, label: 'Message', maxLines: 3),
          scale: scale,
        ),
      );
      await tester.tap(find.byKey(key));
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.enterText(
          find.byType(EditableText),
          '${tester.widget<EditableText>(find.byType(EditableText)).controller.text}ligne $i\n',
        );
        await tester.pump();
      }
      await tester.enterText(
        find.byType(EditableText),
        '${tester.widget<EditableText>(find.byType(EditableText)).controller.text}fin',
      );
      await tester.pumpAndSettle();
      final frame = tester.getRect(find.byType(FlInputFrame));
      final caret = _caret(tester);
      expect(frame.top, lessThanOrEqualTo(caret.top + 0.5));
      expect(frame.bottom, greaterThanOrEqualTo(caret.bottom - 0.5));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('devrait ouvrir le clavier multiligne quand l’entrée grandit, et le texte simple sinon', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlInput(label: 'Une'),
            FlInput(label: 'Plusieurs', maxLines: 5),
          ],
        ),
      ),
    );
    Future<Map<String, dynamic>> configuration(String label) async {
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pump();
      return tester.testTextInput.setClientArgs!;
    }

    final single = await configuration('Une');
    expect((single['inputType'] as Map)['name'], isNot('TextInputType.multiline'));
    expect(single['inputAction'], 'TextInputAction.done');
    final grows = await configuration('Plusieurs');
    expect((grows['inputType'] as Map)['name'], 'TextInputType.multiline');
    expect(grows['inputAction'], 'TextInputAction.newline');
  });

  testWidgets('devrait transmettre maxLines du champ à son entrée', (tester) async {
    await tester.pumpWidget(_app(const FlTextField(label: 'Bio', maxLines: 6)));
    expect(tester.widget<FlInput>(find.byType(FlInput)).maxLines, 6);
    expect(tester.widget<EditableText>(find.byType(EditableText)).maxLines, 6);
  });

  test('devrait refuser maxLines sur une zone de texte à hauteur fixe', () {
    expect(() => FlInput(multiline: true, maxLines: 3), throwsAssertionError);
  });

  test('devrait refuser maxLines sur un texte masqué, par une assertion à son nom', () {
    expect(
      () => FlInput(obscureText: true, maxLines: 3),
      throwsA(isA<AssertionError>().having((e) => '${e.message}', 'message', contains('obscureText'))),
    );
  });
}
