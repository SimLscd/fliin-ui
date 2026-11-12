import 'package:fliin_ui/components/input_otp/fl_input_otp.dart';
import 'package:fliin_ui/components/text_field/fl_text_field.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_host.dart';

Widget _app(Widget child, {TextDirection direction = TextDirection.ltr}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => Directionality(
    textDirection: direction,
    child: FlScope(
      brightness: Brightness.light,
      platform: TargetPlatform.iOS,
      child: OverlayHost(child: Center(child: child)),
    ),
  ),
);

/// Tape la suite de [text] après ce que le champ contient, caractère par
/// caractère : un ajout de plusieurs caractères d'un coup est un collage,
/// que le champ filtre.
Future<void> _type(WidgetTester tester, String text) async {
  final typed = tester.widget<EditableText>(find.byType(EditableText)).controller.text.length;
  for (var i = typed + 1; i <= text.length; i++) {
    await tester.enterText(find.byType(EditableText), text.substring(0, i));
  }
  // The first frame starts the digit's flip, the second ends it.
  await tester.pump();
  await tester.pump(FlTokens.defaults.motion.medium1);
}

List<bool> _invalid(WidgetTester tester) => [
  for (final frame in tester.widgetList<FlInputFrame>(find.byType(FlInputFrame))) frame.invalid,
];

List<bool> _focused(WidgetTester tester) => [
  for (final frame in tester.widgetList<FlInputFrame>(find.byType(FlInputFrame))) frame.focused,
];

List<double> _outlineWidths(WidgetTester tester) => [
  for (final frame in tester.widgetList<FlInputFrame>(find.byType(FlInputFrame))) frame.outlineWidth,
];

EditableText _editable(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText));

Finder _slotText(String char) => find.descendant(of: find.byType(FlInputFrame), matching: find.text(char));

void main() {
  testWidgets('devrait se lire comme un seul champ nommé dont la valeur est le code, sans lire les cases', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        FlInputOtp(
          label: 'Code',
          hint: '6 chiffres',
          groups: const [3, 3],
          controller: TextEditingController(text: '12'),
        ),
      ),
    );
    final node = tester.getSemantics(find.byType(EditableText));
    expect(node.label, 'Code');
    expect(node.hint, '6 chiffres');
    expect(node.value, '12');
    expect(node.flagsCollection.isTextField, isTrue);
    expect(find.bySemanticsLabel('1'), findsNothing);
    semantics.dispose();
  });

  testWidgets('devrait remplir les cases dans l’ordre et rendre le code complet quand la dernière est remplie', (
    tester,
  ) async {
    final changes = <String>[];
    final completed = <String>[];
    await tester.pumpWidget(
      _app(FlInputOtp(label: 'Code', groups: const [4], onChanged: changes.add, onCompleted: completed.add)),
    );
    expect(find.byType(FlInputFrame), findsNWidgets(4));
    await _type(tester, '12');
    expect(_slotText('1'), findsOneWidget);
    expect(_slotText('2'), findsOneWidget);
    expect(completed, isEmpty);
    await _type(tester, '12345');
    expect(_editable(tester).controller.text, '1234', reason: 'coupé à la longueur');
    expect(changes, ['1', '12', '123', '1234']);
    expect(completed, ['1234']);
  });

  testWidgets('devrait refuser une saisie qui ne suit pas le motif', (tester) async {
    await tester.pumpWidget(_app(FlInputOtp(label: 'Code', groups: const [6], pattern: FlInputOtp.onlyDigits)));
    await _type(tester, '12a');
    expect(_editable(tester).controller.text, '12');
  });

  testWidgets('devrait garder du texte collé ou proposé par le système les seuls six chiffres du code', (tester) async {
    await tester.pumpWidget(_app(FlInputOtp(label: 'Code', groups: const [3, 3])));
    await tester.showKeyboard(find.byType(EditableText));
    tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'Votre code : 482913. Ne le partagez pas.'));
    await tester.pump();
    expect(_editable(tester).controller.text, '482913');
    tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'Appelez le 0612345678'));
    await tester.pump();
    expect(_editable(tester).controller.text, isEmpty, reason: 'dix chiffres de suite ne sont pas un code de six');
    expect(flOtpFromPaste('code 123456', 6), '123456');
  });

  testWidgets('devrait remplacer un code commencé par le code collé ou proposé par le système', (tester) async {
    await tester.pumpWidget(_app(FlInputOtp(label: 'Code', groups: const [3, 3])));
    await tester.showKeyboard(find.byType(EditableText));
    await _type(tester, '12');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: '12482913', selection: TextSelection.collapsed(offset: 8)),
    );
    await tester.pump();
    expect(_editable(tester).controller.text, '482913');
  });

  testWidgets('devrait montrer la barre « Coller » dès le premier appui long, champ sans focus', (tester) async {
    await tester.pumpWidget(_app(FlInputOtp(label: 'Code', groups: const [3, 3])));
    expect(_editable(tester).focusNode.hasFocus, isFalse);
    await tester.longPress(find.byType(FlInputOtp));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    expect(state.widget.focusNode.hasFocus, isTrue);
    expect(state.selectionOverlay?.toolbarIsVisible ?? false, isTrue);
  });

  testWidgets("devrait rendre au nœud fourni son canRequestFocus quand le code le quitte, sans l'écraser", (
    tester,
  ) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(_app(FlInputOtp(label: 'Code', groups: const [4], focusNode: node, disabled: true)));
    expect(node.canRequestFocus, isFalse);
    await tester.pumpWidget(_app(const SizedBox()));
    expect(node.canRequestFocus, isTrue, reason: 'retiré');

    await tester.pumpWidget(_app(FlInputOtp(label: 'Code', groups: const [4], focusNode: node, disabled: true)));
    final other = FocusNode();
    addTearDown(other.dispose);
    await tester.pumpWidget(_app(FlInputOtp(label: 'Code', groups: const [4], focusNode: other, disabled: true)));
    expect(node.canRequestFocus, isTrue, reason: 'remplacé');

    node.canRequestFocus = false;
    await tester.pumpWidget(_app(FlInputOtp(label: 'Code', groups: const [4], focusNode: node)));
    expect(node.canRequestFocus, isFalse, reason: "le choix de l'appelant reste");
  });

  testWidgets('devrait lire désactivé et invalide du FlFieldScope, sauf quand le code les dit lui-même', (
    tester,
  ) async {
    Widget otp({bool? disabled}) => FlFieldScope(
      disabled: true,
      invalid: true,
      child: FlInputOtp(label: 'Code', groups: const [4], disabled: disabled),
    );
    await tester.pumpWidget(_app(otp()));
    expect(_editable(tester).focusNode.canRequestFocus, isFalse);
    expect(_invalid(tester), everyElement(isTrue));
    await tester.pumpWidget(_app(otp(disabled: false)));
    expect(_editable(tester).focusNode.canRequestFocus, isTrue);
  });

  testWidgets('devrait remplir les cases de gauche à droite en RTL aussi, comme le code se lit', (tester) async {
    final controller = TextEditingController(text: '123');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        FlInputOtp(label: 'Code', groups: const [3, 3], controller: controller),
        direction: TextDirection.rtl,
      ),
    );
    final xs = [
      for (final char in ['1', '2', '3']) tester.getCenter(_slotText(char)).dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()), reason: '1, 2, 3 de gauche à droite');
    final frames = tester.getRect(find.byType(FlInputFrame).first);
    expect(tester.getCenter(_slotText('1')).dx, frames.center.dx, reason: 'le 1 dans la première case, à gauche');
  });

  testWidgets('devrait demander le code à usage unique du système et le clavier des chiffres', (tester) async {
    await tester.pumpWidget(_app(FlInputOtp(label: 'Code', groups: const [6])));
    expect(_editable(tester).autofillHints, [AutofillHints.oneTimeCode]);
    expect(_editable(tester).keyboardType, TextInputType.number);
  });

  testWidgets(
    'devrait poser l’anneau de focus sur la case suivante quand le champ a le focus, et cerner toutes les cases de danger quand il est invalide',
    (tester) async {
      final controller = TextEditingController(text: '12');
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(FlInputOtp(label: 'Code', groups: const [4], controller: controller)));
      expect(_invalid(tester), [false, false, false, false]);
      expect(_focused(tester), [false, false, false, false]);
      await tester.tap(find.byType(FlInputOtp));
      await tester.pump();
      expect(_invalid(tester), [false, false, false, false]);
      expect(_focused(tester), [false, false, true, false], reason: "l'anneau de focus du champ sur la case active");
      controller.text = '1234';
      await tester.pump();
      expect(_focused(tester), [false, false, false, false], reason: 'plus de case suivante quand le code est complet');
      await tester.pumpWidget(
        _app(FlInputOtp(label: 'Code', groups: const [4], controller: controller, invalid: true)),
      );
      expect(_invalid(tester), List.filled(4, true));
      expect(_outlineWidths(tester), List.filled(4, FlTokens.defaults.size.border), reason: 'erreur : contour de 1');
    },
  );

  testWidgets('devrait faire clignoter le curseur de la case active, sauf sous mouvement réduit', (tester) async {
    final caret = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is ShapeDecoration &&
          (w.decoration as ShapeDecoration).shape is StadiumBorder,
    );
    double caretOpacity() =>
        tester.widget<Opacity>(find.ancestor(of: caret, matching: find.byType(Opacity)).first).opacity;
    await tester.pumpWidget(_app(FlInputOtp(label: 'Code', groups: const [4], autofocus: true)));
    await tester.pump();
    final first = caretOpacity();
    await tester.pump(FlTokens.defaults.motion.long2);
    expect(caretOpacity(), isNot(first));

    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(FlInputOtp(label: 'Code', groups: const [4], autofocus: true)));
    await tester.pump();
    expect(caretOpacity(), 1);
    await tester.pump(FlTokens.defaults.motion.long2);
    expect(caretOpacity(), 1);
  });

  testWidgets('devrait refuser le focus et pâlir les cases, pas les traits, quand il est désactivé', (tester) async {
    await tester.pumpWidget(_app(const FlInputOtp(label: 'Code', groups: [3, 3], disabled: true)));
    await tester.tap(find.byType(FlInputOtp));
    await tester.pump();
    expect(_editable(tester).focusNode.hasFocus, isFalse);
    final dimmed = tester
        .widgetList<Opacity>(find.ancestor(of: find.byType(FlInputFrame), matching: find.byType(Opacity)))
        .where((o) => o.opacity == FlTokens.defaults.size.disabledOpacity);
    expect(dimmed, hasLength(6));
    final separator = find.byWidgetPredicate((w) => w is SizedBox && w.width == 8 && w.height == 2);
    expect(separator, findsOneWidget);
    expect(
      tester
          .widgetList<Opacity>(find.ancestor(of: separator, matching: find.byType(Opacity)))
          .where((o) => o.opacity < 1),
      isEmpty,
      reason: 'le trait ne pâlit pas',
    );
  });

  testWidgets('devrait réduire le code plutôt que déborder quand sa place est plus étroite que ses cases', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 200,
          child: FlInputOtp(label: 'Code', groups: [3, 3]),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FlInputOtp)).width, lessThanOrEqualTo(200));
    final slot = tester.getRect(find.byType(FlInputFrame).first).size;
    expect(slot.width, lessThan(44));
    expect(slot.width / slot.height, closeTo(44 / 48, 0.01));
  });

  group('mouvement', () {
    Widget otp({bool invalid = false, bool success = false, bool reduced = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: FlScope(
          platform: TargetPlatform.iOS,
          child: Center(
            child: FlInputOtp(label: 'Code', groups: const [3, 3], invalid: invalid, success: success),
          ),
        ),
      ),
    );
    double shake(WidgetTester tester) => tester
        .widget<Transform>(find.descendant(of: find.byType(FlShake), matching: find.byType(Transform)).first)
        .transform
        .getTranslation()
        .x;
    List<double?> traces(WidgetTester tester) => [
      for (final paint in tester.widgetList<CustomPaint>(
        find.descendant(of: find.byType(FlInputOtp), matching: find.byType(CustomPaint)),
      ))
        if ('${paint.foregroundPainter.runtimeType}' == '_Trace')
          (paint.foregroundPainter! as dynamic).progress as double,
    ];

    testWidgets('devrait secouer le code une fois quand il devient invalide', (tester) async {
      await tester.pumpWidget(otp());
      await tester.pumpWidget(otp(invalid: true));
      await tester.pump(const Duration(milliseconds: 30));
      expect(shake(tester), lessThan(-2));
      await tester.pumpAndSettle();
      expect(shake(tester), 0);
      expect(_invalid(tester), everyElement(isTrue));
    });

    testWidgets('devrait rester immobile quand le code devient invalide sous mouvement réduit', (tester) async {
      await tester.pumpWidget(otp(reduced: true));
      await tester.pumpWidget(otp(invalid: true, reduced: true));
      await tester.pump(const Duration(milliseconds: 30));
      expect(shake(tester), 0);
    });

    testWidgets('devrait tracer le contour de succès case après case, puis le garder entier', (tester) async {
      await tester.pumpWidget(otp());
      expect(traces(tester), isEmpty);
      await tester.pumpWidget(otp(success: true));
      await tester.pump(const Duration(milliseconds: 150));
      final partway = traces(tester);
      expect(partway.first, inExclusiveRange(0, 1), reason: 'the first slot is half traced');
      expect(partway.length, lessThan(6), reason: 'the last slots have not started');
      await tester.pumpAndSettle();
      expect(traces(tester), List.filled(6, 1.0));
      await tester.pumpWidget(otp());
      expect(traces(tester), isEmpty);
    });

    testWidgets('devrait poser le contour de succès entier d’un coup sous mouvement réduit', (tester) async {
      await tester.pumpWidget(otp(reduced: true));
      await tester.pumpWidget(otp(success: true, reduced: true));
      expect(traces(tester), List.filled(6, 1.0));
    });
  });
}
