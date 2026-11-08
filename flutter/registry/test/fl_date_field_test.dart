import 'dart:convert';
import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:fliin_ui/components/date_field/fl_date_field.dart';
import 'package:fliin_ui/components/text_field/fl_input.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

final _fr = FlDateFieldStrings.language('fr');
final _en = FlDateFieldStrings.language('en');
final _ar = FlDateFieldStrings.language('ar');
FlTokens get _tokens => FlTokens.defaults;

/// Un champ de date qui garde la date reçue quand [accept] est vrai et note
/// chaque appel de `onChanged`.
Widget _field({
  DateTime? value,
  List<DateTime?>? log,
  FlDateFieldStrings? strings,
  bool accept = true,
  bool enabled = true,
  String? error,
}) {
  var current = value;
  return StatefulBuilder(
    builder: (context, setState) => SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FlDateField(
            label: 'Date de naissance',
            value: current,
            strings: strings ?? _fr,
            error: error,
            onChanged: enabled
                ? (date) {
                    log?.add(date);
                    if (accept) setState(() => current = date);
                  }
                : null,
          ),
          const SizedBox(height: 200, width: 320, child: Text('Ailleurs')),
        ],
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget field, {TargetPlatform platform = TargetPlatform.macOS}) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(toggleApp(field, platform: platform));
  await tester.pumpAndSettle();
}

Future<void> _keys(WidgetTester tester, String characters) async {
  for (final c in characters.split('')) {
    await tester.sendKeyEvent(_digitKeys[c]!, character: c);
  }
  await tester.pump();
}

const _digitKeys = {
  '0': LogicalKeyboardKey.digit0,
  '1': LogicalKeyboardKey.digit1,
  '2': LogicalKeyboardKey.digit2,
  '3': LogicalKeyboardKey.digit3,
  '4': LogicalKeyboardKey.digit4,
  '5': LogicalKeyboardKey.digit5,
  '6': LogicalKeyboardKey.digit6,
  '7': LogicalKeyboardKey.digit7,
  '8': LogicalKeyboardKey.digit8,
  '9': LogicalKeyboardKey.digit9,
};

Finder get _frame => find.byType(FlSegmentedField);

/// Le segment dont le nom lu est [name].
Finder _segment(String name) => find.bySemanticsLabel(name);

String? _focusedSegment() => FocusManager.instance.primaryFocus?.debugLabel;

void main() {
  testWidgets('devrait ranger les segments dans l’ordre de la langue', (tester) async {
    await _pump(tester, _field());
    expect(tester.getCenter(find.text('jj')).dx, lessThan(tester.getCenter(find.text('mm')).dx));
    expect(tester.getCenter(find.text('mm')).dx, lessThan(tester.getCenter(find.text('aaaa')).dx));
    await _pump(tester, _field(strings: _en));
    expect(tester.getCenter(find.text('mm')).dx, lessThan(tester.getCenter(find.text('dd')).dx));
    expect(tester.getCenter(find.text('dd')).dx, lessThan(tester.getCenter(find.text('yyyy')).dx));
    expect(DefaultTextStyle.of(tester.element(find.text('dd'))).style.color, isNot(_tokens.light.onSurface));
    expect(tester.widget<Text>(find.text('dd')).style?.color, _tokens.light.fieldPlaceholder);
  });

  testWidgets('devrait passer au segment suivant quand il est plein, et rendre la date une fois complète', (
    tester,
  ) async {
    final log = <DateTime?>[];
    await _pump(tester, _field(log: log));
    await tester.tap(_frame);
    await tester.pump();
    expect(_focusedSegment(), 'FlSegmentedField day');
    await _keys(tester, '4');
    expect(_focusedSegment(), 'FlSegmentedField month', reason: '4 ne peut pas commencer un jour à deux chiffres');
    await _keys(tester, '10');
    expect(_focusedSegment(), 'FlSegmentedField year');
    await _keys(tester, '198');
    expect(log, isEmpty);
    await _keys(tester, '7');
    expect(log, [DateTime(1987, 10, 4)]);
    expect(find.text('04'), findsOneWidget);
    expect(find.text('1987'), findsOneWidget);
  });

  testWidgets('devrait ramener le 31 février au dernier jour du mois, et le montrer', (tester) async {
    final log = <DateTime?>[];
    await _pump(tester, _field(log: log));
    await tester.tap(_frame);
    await tester.pump();
    await _keys(tester, '31022026');
    expect(log, [DateTime(2026, 2, 28)]);
    expect(find.text('28'), findsOneWidget);
  });

  testWidgets('devrait changer le segment par les flèches, en faisant le tour', (tester) async {
    final log = <DateTime?>[];
    await _pump(tester, _field(value: DateTime(2026, 12, 14), log: log));
    await tester.tap(find.text('12'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(log, [DateTime(2026, 1, 14)]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(log.last, DateTime(2026, 12, 14));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_focusedSegment(), 'FlSegmentedField year');
  });

  testWidgets('devrait rendre null quand un segment se vide, et revenir au précédent par Retour arrière', (
    tester,
  ) async {
    final log = <DateTime?>[];
    await _pump(tester, _field(value: DateTime(2026, 10, 14), log: log));
    await tester.tap(find.text('2026'));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    }
    await tester.pump();
    expect(log, [null]);
    expect(find.text('aaaa'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(_focusedSegment(), 'FlSegmentedField month');
  });

  testWidgets('devrait revenir à la date de l’app quand elle refuse la saisie', (tester) async {
    final log = <DateTime?>[];
    await _pump(tester, _field(value: DateTime(2026, 10, 14), log: log, accept: false));
    await tester.tap(find.text('14'));
    await tester.pump();
    await _keys(tester, '20');
    await tester.pump();
    expect(log, [DateTime(2026, 10, 20)]);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('20'), findsNothing);
  });

  testWidgets('devrait lire chaque segment sous son nom et sa valeur, et le régler par les gestes', (tester) async {
    final semantics = tester.ensureSemantics();
    final log = <DateTime?>[];
    await _pump(tester, _field(value: DateTime(2026, 10, 14), log: log));
    expect(tester.getSemantics(_segment('mois')), isSemantics(label: 'mois', value: '10 – octobre', isFocusable: true));
    expect(tester.getSemantics(_segment('jour')), isSemantics(label: 'jour', value: '14'));
    final node = tester.getSemantics(_segment('jour'));
    tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(node.id, SemanticsAction.increase);
    await tester.pump();
    expect(log, [DateTime(2026, 10, 15)]);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Date de naissance')),
      isSemantics(label: 'Date de naissance', isEnabled: true, hasEnabledState: true),
    );
    semantics.dispose();
  });

  testWidgets('devrait lire un segment vide comme tel', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _field());
    expect(tester.getSemantics(_segment('année')), isSemantics(label: 'année', value: 'vide'));
    semantics.dispose();
  });

  testWidgets('devrait ouvrir le pavé numérique sur iOS et compter la saisie sans touche Retour', (tester) async {
    final log = <DateTime?>[];
    await _pump(tester, _field(log: log), platform: TargetPlatform.iOS);
    await tester.tap(_frame);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.testTextInput.setClientArgs?['inputType']['name'], 'TextInputType.number');
    for (final digit in '14101987'.split('')) {
      tester.testTextInput.updateEditingValue(TextEditingValue(text: '\u200b\u200b$digit'));
      await tester.pump();
    }
    expect(log, [DateTime(1987, 10, 14)]);
    for (var i = 0; i < 4; i++) {
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: '\u200b'));
      await tester.pump();
    }
    expect(log, [DateTime(1987, 10, 14), null]);
    await tester.tap(find.text('Ailleurs'));
    await tester.pump();
    expect(_focusedSegment(), isNot(startsWith('FlSegmentedField')));
    expect(tester.testTextInput.hasAnyClients, isFalse);
  });

  testWidgets('devrait écrire les chiffres de la langue et accepter les chiffres arabes', (tester) async {
    final log = <DateTime?>[];
    await _pump(
      tester,
      Directionality(
        textDirection: TextDirection.rtl,
        child: _field(log: log, strings: _ar),
      ),
    );
    expect(tester.getCenter(find.text('يوم')).dx, greaterThan(tester.getCenter(find.text('شهر')).dx));
    await tester.tap(find.text('يوم'));
    await tester.pump();
    for (final c in '١٤١٠٢٠٢٦'.split('')) {
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: c);
    }
    await tester.pump();
    expect(log, [DateTime(2026, 10, 14)]);
    expect(find.text('٢٠٢٦'), findsOneWidget);
  });

  testWidgets('devrait donner le focus au premier segment vide quand autofocus est vrai', (tester) async {
    await _pump(
      tester,
      SizedBox(
        width: 320,
        child: FlDateField(label: 'Date', value: null, onChanged: (_) {}, strings: _fr, autofocus: true),
      ),
    );
    expect(_focusedSegment(), 'FlSegmentedField day');
    expect(tester.widget<Text>(find.text('jj')).style?.color, _tokens.light.onAccentSoft);
  });

  testWidgets('devrait ne prendre ni focus ni saisie désactivé', (tester) async {
    await _pump(tester, _field(value: DateTime(2026, 10, 14), enabled: false));
    await tester.tap(_frame);
    await tester.pump();
    expect(_focusedSegment(), isNot(startsWith('FlSegmentedField')));
  });

  testWidgets('devrait garder la couleur des segments quand le champ est invalide, le message disant l’erreur', (
    tester,
  ) async {
    await _pump(tester, _field(value: DateTime(2026, 10, 14), error: 'Date future'));
    expect(find.text('Date future'), findsOneWidget);
    expect(tester.widget<Text>(find.text('14')).style?.color, _tokens.light.onSurface);
  });

  testWidgets('devrait tenir à 2,0 sur 320 sans débordement', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: toggleApp(_field(value: DateTime(2026, 10, 14))),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final frame = tester.getRect(find.byType(FlInputFrame));
    for (final text in ['14', '10', '2026']) {
      final rect = tester.getRect(find.text(text));
      expect(frame.contains(rect.topLeft) && frame.contains(rect.bottomRight), isTrue, reason: text);
    }
  });

  testWidgets('devrait échouer par une assertion pour une langue hors de la table', (tester) async {
    Object? error;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('de'),
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Builder(
          builder: (context) {
            try {
              FlDateFieldStrings.of(context);
            } on AssertionError catch (e) {
              error = e;
            }
            return const SizedBox();
          },
        ),
      ),
    );
    expect(error, isA<AssertionError>());
  });

  testWidgets('devrait borner le jour au dernier du mois connu, et ne jamais montrer un jour qu’il ne rend pas', (
    tester,
  ) async {
    final log = <DateTime?>[];
    await _pump(tester, _field(value: DateTime(2026, 2, 28), log: log));
    await tester.tap(find.text('28'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(find.text('29'), findsNothing);
    expect(log, [DateTime(2026, 2, 1)]);
    await _pump(tester, _field(value: DateTime(2026, 4, 30), log: log));
    log.clear();
    await tester.tap(find.text('30'));
    await tester.pump();
    await _keys(tester, '31');
    expect(find.text('31'), findsNothing);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(log, [DateTime(2026, 4, 1)]);
  });

  testWidgets('devrait répartir une date collée sur iOS entre ses segments', (tester) async {
    final log = <DateTime?>[];
    await _pump(tester, _field(log: log), platform: TargetPlatform.iOS);
    await tester.tap(_frame);
    await tester.pump();
    tester.testTextInput.updateEditingValue(const TextEditingValue(text: '\u200b\u200b14101987'));
    await tester.pumpAndSettle();
    expect(log, [DateTime(1987, 10, 14)]);
  });

  test('devrait garder la table de textes égale au l10n du manifeste', () {
    final manifest = jsonDecode(File('items/date-field.json').readAsStringSync()) as Map<String, Object?>;
    expect(manifest['l10n'], flDateFieldL10n);
  });

  test('devrait lire une table d’une autre langue, et nommer la clé fautive', () {
    final table = {for (final entry in flDateFieldL10n.entries) entry.key: entry.value['fr']!};
    expect(FlDateFieldStrings.fromTable({...table, 'dateFieldOrder': 'ymd'}).order, [
      FlDateSegment.year,
      FlDateSegment.month,
      FlDateSegment.day,
    ]);
    expect(
      () => FlDateFieldStrings.fromTable({...table, 'dateFieldOrder': 'ddy'}),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('dateFieldOrder'))),
    );
    expect(
      () => FlDateFieldStrings.fromTable({...table}..remove('timeFieldHourCycle')),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('timeFieldHourCycle'))),
    );
  });

  testWidgets(
    'devrait poser leading avant les segments, en atténué, retirer l’icône et remplir le champ en secondary',
    (tester) async {
      await tester.pumpWidget(
        toggleApp(
          SizedBox(
            width: 320,
            child: FlDateField(
              label: 'Échéance',
              value: DateTime(2026, 10, 14),
              onChanged: (_) {},
              strings: _fr,
              leading: const Text('Le'),
              showIcon: false,
              variant: FlInputVariant.secondary,
            ),
          ),
        ),
      );
      expect(find.byType(FlIcon), findsNothing);
      expect(tester.widget<FlInputFrame>(find.byType(FlInputFrame)).variant, FlInputVariant.secondary);
      final leading = tester.getRect(find.text('Le'));
      final frame = tester.getRect(find.byType(FlInputFrame));
      expect(leading.left - frame.left, 12);
      expect(leading.right + 8, lessThanOrEqualTo(tester.getRect(find.text('14')).left));
      expect(DefaultTextStyle.of(tester.element(find.text('Le'))).style.color, _tokens.light.onSurfaceMuted);
      await tester.pumpWidget(
        toggleApp(
          SizedBox(
            width: 320,
            child: FlDateField(label: 'Échéance', value: null, onChanged: (_) {}, strings: _fr),
          ),
        ),
      );
      expect(find.byType(FlIcon), findsOneWidget);
      expect(tester.widget<FlInputFrame>(find.byType(FlInputFrame)).variant, FlInputVariant.primary);
    },
  );
}
