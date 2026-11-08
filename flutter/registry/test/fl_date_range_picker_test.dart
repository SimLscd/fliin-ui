import 'package:fliin_ui/components/calendar/fl_calendar_strings.dart';
import 'package:fliin_ui/components/calendar/fl_calendar_view.dart';
import 'package:fliin_ui/components/date_picker/fl_date_picker.dart';
import 'package:fliin_ui/components/date_range_picker/fl_date_range_picker.dart';
import 'package:fliin_ui/components/range_calendar/fl_range_calendar.dart';
import 'package:fliin_ui/components/sheet/fl_sheet.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_app.dart';

final _fr = FlCalendarStrings.language('fr');

Widget _picker({
  FlDateRange? value,
  List<FlDateRange?>? log,
  FlDatePickerPresentation? presentation,
  List<DateTime>? months,
  bool Function(DateTime)? isUnavailable,
  FlRangeUnit unit = FlRangeUnit.days,
}) {
  var current = value;
  return StatefulBuilder(
    builder: (context, setState) => Align(
      alignment: AlignmentDirectional.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: SizedBox(
          width: 320,
          child: FlDateRangePicker(
            label: 'Dates du séjour',
            placeholder: 'Arrivée – départ',
            value: current,
            presentation: presentation,
            barrierLabel: 'Fermer le calendrier',
            clearLabel: 'Effacer les dates',
            today: DateTime(2026, 10, 24),
            strings: _fr,
            onMonthChanged: months?.add,
            isUnavailable: isUnavailable,
            unit: unit,
            onChanged: (range) {
              log?.add(range);
              setState(() => current = range);
            },
          ),
        ),
      ),
    ),
  );
}

final _trigger = find.descendant(of: find.byType(FlDateRangePicker), matching: find.byType(FlPressable)).first;

Finder _cell(String day) => find.descendant(of: find.byType(FlCalendarView), matching: find.text(day)).first;

Future<void> _phone(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('devrait dire à l’app le mois que montre la feuille ouverte, puis chaque mois suivant', (tester) async {
    await _phone(tester);
    final months = <DateTime>[];
    await tester.pumpWidget(overlayApp(_picker(months: months)));
    await tester.pumpAndSettle();
    expect(months, isEmpty, reason: 'fermé, le calendrier ne montre aucun mois');
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(find.byType(FlSheet), findsOneWidget);
    expect(months, [DateTime(2026, 10)]);
    await tester.tap(find.bySemanticsLabel('Mois suivant'));
    await tester.pumpAndSettle();
    expect(months, [DateTime(2026, 10), DateTime(2026, 11)]);
  });

  testWidgets('devrait dire à l’app le mois que montre le popover ouvert', (tester) async {
    final months = <DateTime>[];
    await tester.pumpWidget(overlayApp(_picker(months: months, presentation: FlDatePickerPresentation.popover)));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(months, [DateTime(2026, 10)]);
  });

  testWidgets('devrait écrire le début et la fin de la période de l’app', (tester) async {
    await tester.pumpWidget(overlayApp(_picker(value: FlDateRange(DateTime(2026, 10, 12), DateTime(2026, 10, 16)))));
    expect(find.text('lundi 12 octobre 2026 – vendredi 16 octobre 2026'), findsOneWidget);
  });

  testWidgets('devrait ne rien envoyer au premier toucher, puis rendre la période au second et se fermer', (
    tester,
  ) async {
    await _phone(tester);
    final log = <FlDateRange?>[];
    await tester.pumpWidget(overlayApp(_picker(log: log)));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(find.byType(FlSheet), findsOneWidget);
    await tester.tap(_cell('20'));
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(find.text('Arrivée – départ'), findsOneWidget);
    await tester.tap(_cell('12'));
    await tester.pumpAndSettle();
    expect(log, [FlDateRange(DateTime(2026, 10, 12), DateTime(2026, 10, 20))]);
    expect(find.byType(FlSheet), findsNothing);
    expect(find.text('lundi 12 octobre 2026 – mardi 20 octobre 2026'), findsOneWidget);
  });

  testWidgets('devrait finir une période sur un jour départ seulement quand il compte en nuits', (tester) async {
    await _phone(tester);
    final log = <FlDateRange?>[];
    bool night27(DateTime day) => day == DateTime(2026, 10, 27);
    await tester.pumpWidget(overlayApp(_picker(log: log, isUnavailable: night27, unit: FlRangeUnit.nights)));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    await tester.tap(_cell('24'));
    await tester.pump();
    await tester.tap(_cell('27'));
    await tester.pumpAndSettle();
    expect(log, [FlDateRange(DateTime(2026, 10, 24), DateTime(2026, 10, 27))]);
  });

  testWidgets('devrait abandonner un début posé quand le calendrier se ferme, et repartir de la période de l’app', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final log = <FlDateRange?>[];
    final range = FlDateRange(DateTime(2026, 10, 5), DateTime(2026, 10, 7));
    await tester.pumpWidget(overlayApp(_picker(value: range, log: log)));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    await tester.tap(_cell('20'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('début posé')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // Échap abandonne d'abord le début posé, dans le calendrier ; le second
    // ferme le popover.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FlCalendarView), findsNothing);
    expect(find.text('lundi 5 octobre 2026 – mercredi 7 octobre 2026'), findsOneWidget);
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('début posé')), findsNothing);
    await tester.tapAt(const Offset(5, 590));
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    semantics.dispose();
  });

  testWidgets('devrait abandonner un début posé quand la feuille se ferme par son voile', (tester) async {
    await _phone(tester);
    final semantics = tester.ensureSemantics();
    final log = <FlDateRange?>[];
    await tester.pumpWidget(overlayApp(_picker(log: log)));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    await tester.tap(_cell('20'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();
    expect(find.byType(FlSheet), findsNothing);
    expect(find.text('Arrivée – départ'), findsOneWidget);
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('début posé')), findsNothing);
    expect(log, isEmpty);
    semantics.dispose();
  });

  testWidgets('devrait effacer la période par son bouton', (tester) async {
    final log = <FlDateRange?>[];
    await tester.pumpWidget(
      overlayApp(_picker(value: FlDateRange(DateTime(2026, 10, 12), DateTime(2026, 10, 16)), log: log)),
    );
    await tester.tap(find.bySemanticsLabel('Effacer les dates'));
    await tester.pumpAndSettle();
    expect(log, [null]);
    expect(find.text('Arrivée – départ'), findsOneWidget);
  });
}
