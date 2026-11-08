import 'dart:ui' show SemanticsAction;

import 'package:fliin_ui/components/time_field/fl_time_field.dart';
import 'package:fliin_ui/components/text_field/fl_input.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';
import 'torture/torture.g.dart';

Widget _field({FlTime? value, List<FlTime?>? log, String language = 'en'}) {
  var current = value;
  return StatefulBuilder(
    builder: (context, setState) => SizedBox(
      width: 320,
      child: FlTimeField(
        label: 'Heure du rendez-vous',
        value: current,
        strings: FlDateFieldStrings.language(language),
        onChanged: (time) {
          log?.add(time);
          setState(() => current = time);
        },
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget field, {
  TextDirection direction = TextDirection.ltr,
  TargetPlatform platform = TargetPlatform.macOS,
}) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(toggleApp(field, platform: platform, direction: direction));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String characters) async {
  for (final c in characters.split('')) {
    final key = switch (c) {
      'p' => LogicalKeyboardKey.keyP,
      'a' => LogicalKeyboardKey.keyA,
      _ => LogicalKeyboardKey.digit0,
    };
    await tester.sendKeyEvent(key, character: c);
  }
  await tester.pump();
}

void main() {
  testWidgets('devrait garder au nœud du champ une cible de 44 sur iOS quand le contrôle compact fait 36', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    // Le contrôle compact du registre fait 44 : le thème de torture A garde
    // le sien à 36.
    await tester.pumpWidget(
      toggleApp(_field(), platform: TargetPlatform.iOS, density: FlDensity.compact, tokens: tortureA),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FlInputFrame)).height, lessThan(44));
    final node = tester.getSemantics(find.bySemanticsLabel('Heure du rendez-vous'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.rect.height, greaterThanOrEqualTo(44));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('devrait compter sur 12 heures en anglais, le matin posé par l’heure tapée, p pour l’après-midi', (
    tester,
  ) async {
    final log = <FlTime?>[];
    await _pump(tester, _field(log: log));
    expect(find.text('AM'), findsOneWidget);
    await tester.tap(find.byType(FlSegmentedField));
    await tester.pump();
    await _type(tester, '905');
    expect(log, [const FlTime(9, 5)]);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('05'), findsOneWidget);
    await _type(tester, 'p');
    expect(log.last, const FlTime(21, 5));
    expect(find.text('PM'), findsOneWidget);
  });

  testWidgets('devrait rendre midi et minuit sur 12 heures', (tester) async {
    final log = <FlTime?>[];
    await _pump(tester, _field(value: const FlTime(0, 30), log: log));
    expect(find.text('12'), findsOneWidget);
    expect(find.text('AM'), findsOneWidget);
    await tester.tap(find.text('AM'));
    await tester.pump();
    expect(log, [const FlTime(12, 30)]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(log.last, const FlTime(0, 30));
  });

  testWidgets('devrait compter sur 24 heures en français, sans matin ni après-midi', (tester) async {
    final log = <FlTime?>[];
    await _pump(tester, _field(log: log, language: 'fr'));
    expect(find.text('AM'), findsNothing);
    await tester.tap(find.byType(FlSegmentedField));
    await tester.pump();
    await _type(tester, '1430');
    expect(log, [const FlTime(14, 30)]);
    expect(find.text('14'), findsOneWidget);
  });

  testWidgets('devrait écrire l’heure puis la minute de gauche à droite, même en arabe', (tester) async {
    await _pump(
      tester,
      _field(value: const FlTime(9, 5), language: 'ar'),
      direction: TextDirection.rtl,
    );
    expect(tester.getCenter(find.text('٩')).dx, lessThan(tester.getCenter(find.text('٠٥')).dx));
    expect(tester.getCenter(find.text('ص')).dx, lessThan(tester.getCenter(find.text('٩')).dx));
  });

  testWidgets('devrait lire le matin ou l’après-midi, et le changer par le geste d’augmentation', (tester) async {
    final semantics = tester.ensureSemantics();
    final log = <FlTime?>[];
    await _pump(tester, _field(value: const FlTime(9, 5), log: log));
    final period = find.bySemanticsLabel('AM/PM');
    expect(tester.getSemantics(period), isSemantics(label: 'AM/PM', value: 'AM', increasedValue: 'PM'));
    expect(tester.getSemantics(find.bySemanticsLabel('minute')), isSemantics(value: '5'));
    tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
      tester.getSemantics(period).id,
      SemanticsAction.increase,
    );
    await tester.pump();
    expect(log, [const FlTime(21, 5)]);
    semantics.dispose();
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('devrait passer à l’après-midi au toucher sur un téléphone, le pavé numérique n’ayant pas de lettre '
        '(${platform.name})', (tester) async {
      final semantics = tester.ensureSemantics();
      final log = <FlTime?>[];
      await _pump(tester, _field(log: log), platform: platform);
      await tester.tap(find.byType(FlSegmentedField));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      for (final digit in '230'.split('')) {
        tester.testTextInput.updateEditingValue(TextEditingValue(text: '\u200b\u200b$digit'));
        await tester.pump();
      }
      expect(log, [const FlTime(2, 30)]);
      await tester.tap(find.text('AM'));
      await tester.pump();
      expect(log.last, const FlTime(14, 30));
      expect(find.text('PM'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('AM/PM')), isSemantics(value: 'PM', increasedValue: 'AM'));
      await tester.tap(find.text('PM'));
      await tester.pump();
      expect(log.last, const FlTime(2, 30));
      semantics.dispose();
    });
  }

  testWidgets('devrait lire « 00 » comme 12 sur 12 heures, et poser le matin avec l’heure réglée aux flèches', (
    tester,
  ) async {
    final log = <FlTime?>[];
    await _pump(tester, _field(log: log));
    await tester.tap(find.byType(FlSegmentedField));
    await tester.pump();
    await _type(tester, '00');
    expect(find.text('12'), findsOneWidget);
    await _pump(tester, _field(log: log));
    log.clear();
    await tester.tap(find.byType(FlSegmentedField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(log, [const FlTime(1, 0)]);
  });

  testWidgets('devrait suivre l’écran avec les flèches en arabe : l’heure à gauche de la minute', (tester) async {
    await _pump(
      tester,
      _field(value: const FlTime(9, 5), language: 'ar'),
      direction: TextDirection.rtl,
    );
    await tester.tap(find.text('٩'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'FlSegmentedField minute');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'FlSegmentedField dayPeriod');
  });

  test('devrait poser l’heure telle quelle sur le jour, sans corriger une heure absente ou doublée', () {
    // Ce que fait DateTime : un passage à l'heure d'été qui saute minuit le
    // décale (voir la doc de FlTime.on).
    expect(const FlTime(0, 30).on(DateTime(2026, 9, 6)), DateTime(2026, 9, 6, 0, 30));
  });

  test('devrait comparer deux heures par leur valeur', () {
    expect(const FlTime(9, 5), const FlTime(9, 5));
    expect(const FlTime(9, 5).on(DateTime(2026, 10, 14)), DateTime(2026, 10, 14, 9, 5));
  });

  group('erreur', () {
    Widget field(String? error, {bool reduced = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: FlScope(
          platform: TargetPlatform.iOS,
          child: Center(
            child: SizedBox(
              width: 320,
              child: FlTimeField(
                label: 'Heure',
                value: const FlTime(9, 30),
                error: error,
                strings: FlDateFieldStrings.language('fr'),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    double shake(WidgetTester tester) => tester
        .widget<Transform>(find.descendant(of: find.byType(FlShake), matching: find.byType(Transform)).first)
        .transform
        .getTranslation()
        .x;

    testWidgets('devrait secouer le champ une fois quand une erreur apparaît', (tester) async {
      await tester.pumpWidget(field(null));
      await tester.pumpWidget(field('Choisissez une heure ouvrée'));
      await tester.pump(const Duration(milliseconds: 30));
      expect(shake(tester), lessThan(-2));
      await tester.pumpAndSettle();
      expect(shake(tester), 0);
      await tester.pumpWidget(field('Une autre erreur'));
      await tester.pump(const Duration(milliseconds: 30));
      expect(shake(tester), 0, reason: 'an error that stays does not shake again');
    });

    testWidgets('devrait rester immobile quand une erreur apparaît sous mouvement réduit', (tester) async {
      await tester.pumpWidget(field(null, reduced: true));
      await tester.pumpWidget(field('Choisissez une heure ouvrée', reduced: true));
      await tester.pump(const Duration(milliseconds: 30));
      expect(shake(tester), 0);
    });
  });
}
