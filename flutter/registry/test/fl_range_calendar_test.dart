import 'dart:ui' show Tristate;

import 'package:fliin_ui/components/calendar/fl_calendar_strings.dart';
import 'package:fliin_ui/components/range_calendar/fl_range_calendar.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

final _fr = FlCalendarStrings.language('fr');

/// Un calendrier de période qui garde la période choisie et note chaque
/// choix.
class _Host extends StatefulWidget {
  const _Host({
    this.isUnavailable,
    this.focusedDate,
    this.unit = FlRangeUnit.days,
    this.minDate,
    this.maxDate,
    this.initialStart,
  });

  final bool Function(DateTime)? isUnavailable;
  final DateTime? focusedDate;
  final FlRangeUnit unit;
  final DateTime? minDate;
  final DateTime? maxDate;
  final DateTime? initialStart;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  FlDateRange? value;
  final List<FlDateRange> changes = [];

  /// La période posée par l'app, hors d'un toucher.
  void replace(FlDateRange range) => setState(() => value = range);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: FlRangeCalendar(
      value: value,
      onChanged: (range) => setState(() {
        changes.add(range);
        value = range;
      }),
      today: DateTime(2026, 10, 24),
      focusedDate: widget.focusedDate,
      strings: _fr,
      isUnavailable: widget.isUnavailable,
      unit: widget.unit,
      minDate: widget.minDate,
      maxDate: widget.maxDate,
      initialStart: widget.initialStart,
      semanticLabel: 'Séjour',
    ),
  );
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

Future<void> _pump(WidgetTester tester, _Host host) async {
  await tester.pumpWidget(toggleApp(host));
  await tester.pumpAndSettle();
}

Finder _day(String date) => find.bySemanticsLabel(RegExp('^${RegExp.escape(date)}'));

String _label(WidgetTester tester, String date) => tester.getSemantics(_day(date)).label;

bool _selected(WidgetTester tester, String date) =>
    tester.getSemantics(_day(date)).getSemanticsData().flagsCollection.isSelected == Tristate.isTrue;

bool _enabled(WidgetTester tester, String date) =>
    tester.getSemantics(_day(date)).getSemanticsData().flagsCollection.isEnabled == Tristate.isTrue;

/// La nuit du 27 octobre est prise : quelqu'un arrive ce jour-là.
bool _night27(DateTime day) => day == DateTime(2026, 10, 27);

/// Un séjour, en nuits, où la nuit du 27 octobre est prise.
_Host _stay({DateTime? focusedDate, DateTime? initialStart}) =>
    _Host(isUnavailable: _night27, unit: FlRangeUnit.nights, focusedDate: focusedDate, initialStart: initialStart);

double _opacity(WidgetTester tester, String number) =>
    tester.widget<Opacity>(find.ancestor(of: find.text(number), matching: find.byType(Opacity)).first).opacity;

TextDecoration? _decoration(WidgetTester tester, String number) =>
    tester.widget<Text>(find.text(number)).style?.decoration;

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('devrait poser le début au premier toucher et rendre la période au second', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, const _Host());
    await tester.tap(_day('lundi 12 octobre 2026'));
    await tester.pump();
    expect(_host(tester).changes, isEmpty);
    expect(_label(tester, 'lundi 12 octobre 2026'), 'lundi 12 octobre 2026, début posé, choisissez la fin');
    expect(_selected(tester, 'lundi 12 octobre 2026'), isFalse);
    await tester.tap(_day('vendredi 16 octobre 2026'));
    await tester.pump();
    expect(_host(tester).changes, [FlDateRange(DateTime(2026, 10, 12), DateTime(2026, 10, 16))]);
    expect(_label(tester, 'lundi 12 octobre 2026'), 'lundi 12 octobre 2026, début de la période');
    expect(_label(tester, 'mercredi 14 octobre 2026'), 'mercredi 14 octobre 2026');
    expect(_label(tester, 'vendredi 16 octobre 2026'), 'vendredi 16 octobre 2026, fin de la période');
    for (final day in ['lundi 12', 'mercredi 14', 'vendredi 16']) {
      expect(_selected(tester, '$day octobre 2026'), isTrue, reason: day);
    }
    expect(_label(tester, 'samedi 17 octobre 2026'), 'samedi 17 octobre 2026');
    semantics.dispose();
  });

  testWidgets('devrait inverser une fin touchée avant le début', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, const _Host());
    await tester.tap(_day('vendredi 16 octobre 2026'));
    await tester.tap(_day('lundi 12 octobre 2026'));
    await tester.pump();
    expect(_host(tester).changes, [FlDateRange(DateTime(2026, 10, 12), DateTime(2026, 10, 16))]);
    semantics.dispose();
  });

  testWidgets('devrait refuser une période qui passe sur un jour indisponible', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _Host(isUnavailable: (day) => day.day == 15 && day.month == 10));
    await tester.tap(_day('lundi 12 octobre 2026'));
    await tester.pump();
    expect(_label(tester, 'vendredi 16 octobre 2026'), 'vendredi 16 octobre 2026, indisponible');
    await tester.tap(_day('vendredi 16 octobre 2026'));
    await tester.pump();
    expect(_host(tester).changes, isEmpty);
    await tester.tap(_day('mercredi 14 octobre 2026'));
    await tester.pump();
    expect(_host(tester).changes, [FlDateRange(DateTime(2026, 10, 12), DateTime(2026, 10, 14))]);
    expect(_label(tester, 'vendredi 16 octobre 2026'), 'vendredi 16 octobre 2026');
    semantics.dispose();
  });

  testWidgets('devrait ne montrer au clavier que le début posé, et l\'abandonner à Échap', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _Host(focusedDate: DateTime(2026, 10, 14)));
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await _key(tester, LogicalKeyboardKey.enter);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_selected(tester, 'jeudi 15 octobre 2026'), isFalse);
    expect(_label(tester, 'mercredi 14 octobre 2026'), 'mercredi 14 octobre 2026, début posé, choisissez la fin');
    await _key(tester, LogicalKeyboardKey.escape);
    expect(_label(tester, 'mercredi 14 octobre 2026'), 'mercredi 14 octobre 2026');
    await _key(tester, LogicalKeyboardKey.enter);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(_host(tester).changes, [FlDateRange(DateTime(2026, 10, 16), DateTime(2026, 10, 23))]);
    semantics.dispose();
  });

  testWidgets('devrait rester sur le mois de la fin quand la période se ferme dans un autre mois', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, const _Host());
    await tester.tap(_day('mercredi 28 octobre 2026'));
    await tester.tap(find.bySemanticsLabel('Mois suivant'));
    await tester.pumpAndSettle();
    await tester.tap(_day('mardi 3 novembre 2026'));
    await tester.pumpAndSettle();
    expect(_host(tester).changes, [FlDateRange(DateTime(2026, 10, 28), DateTime(2026, 11, 3))]);
    expect(find.text('novembre 2026'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('devrait oublier le début posé quand l\'app change la période', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, const _Host());
    await tester.tap(_day('lundi 12 octobre 2026'));
    await tester.pump();
    _host(tester).replace(FlDateRange(DateTime(2026, 10, 20), DateTime(2026, 10, 21)));
    await tester.pump();
    await tester.tap(_day('vendredi 16 octobre 2026'));
    await tester.pump();
    expect(_host(tester).changes, isEmpty);
    semantics.dispose();
  });

  testWidgets('devrait garder le début posé seul quand on change de mois, sans période inventée', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, const _Host());
    await tester.tap(_day('mercredi 28 octobre 2026'));
    await tester.tap(find.bySemanticsLabel('Mois suivant'));
    await tester.pumpAndSettle();
    expect(_host(tester).changes, isEmpty);
    for (final day in ['jeudi 12', 'samedi 28']) {
      expect(_selected(tester, '$day novembre 2026'), isFalse, reason: day);
      expect(_label(tester, '$day novembre 2026'), '$day novembre 2026', reason: day);
    }
    semantics.dispose();
  });

  testWidgets('devrait mener la grille à une période que l\'app pose dans un autre mois', (tester) async {
    await _pump(tester, const _Host());
    _host(tester).replace(FlDateRange(DateTime(2026, 12, 20), DateTime(2026, 12, 27)));
    await tester.pumpAndSettle();
    expect(find.text('décembre 2026'), findsOneWidget);
  });

  testWidgets('devrait rouvrir un choix en attente sur son début posé', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      toggleApp(
        SizedBox(
          width: 320,
          child: FlRangeCalendar(
            value: null,
            initialStart: DateTime(2026, 10, 12),
            onChanged: (_) {},
            today: DateTime(2026, 10, 24),
            strings: _fr,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_label(tester, 'lundi 12 octobre 2026'), 'lundi 12 octobre 2026, début posé, choisissez la fin');
    semantics.dispose();
  });

  testWidgets('devrait laisser aujourd\'hui sur le seul fond du ruban, sans second disque', (tester) async {
    await _pump(tester, const _Host());
    _host(tester).replace(FlDateRange(DateTime(2026, 10, 22), DateTime(2026, 10, 26)));
    await tester.pumpAndSettle();
    final disc =
        (tester
                    .widget<DecoratedBox>(find.ancestor(of: find.text('24'), matching: find.byType(DecoratedBox)).first)
                    .decoration
                as BoxDecoration)
            .color;
    expect(disc, isNull);
  });

  group('en nuits, le jour « départ seulement »', () {
    testWidgets('devrait finir une période le jour dont la nuit est prise quand la veille est libre', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _stay());
      await tester.tap(_day('samedi 24 octobre 2026'));
      await tester.pump();
      expect(_label(tester, 'mardi 27 octobre 2026'), 'mardi 27 octobre 2026, départ seulement');
      expect(_enabled(tester, 'mardi 27 octobre 2026'), isTrue);
      await tester.tap(_day('mardi 27 octobre 2026'));
      await tester.pump();
      expect(_host(tester).changes, [FlDateRange(DateTime(2026, 10, 24), DateTime(2026, 10, 27))]);
      expect(_label(tester, 'mardi 27 octobre 2026'), 'mardi 27 octobre 2026, fin de la période, départ seulement');
      expect(
        tester.widget<Opacity>(find.ancestor(of: find.text('27'), matching: find.byType(Opacity)).first).opacity,
        1,
        reason: 'la fin que l’app a reçue n’est pas pâlie',
      );
      expect(_enabled(tester, 'mardi 27 octobre 2026'), isFalse, reason: 'elle ne commence pas le séjour suivant');
      semantics.dispose();
    });

    testWidgets('devrait refuser ce jour comme arrivée, au premier toucher comme au second', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _stay());
      expect(_label(tester, 'mardi 27 octobre 2026'), 'mardi 27 octobre 2026, départ seulement, indisponible');
      expect(_enabled(tester, 'mardi 27 octobre 2026'), isFalse);
      await tester.tap(_day('mardi 27 octobre 2026'), warnIfMissed: false);
      await tester.pump();
      expect(_label(tester, 'mardi 27 octobre 2026'), isNot(contains('début posé')));
      await tester.tap(_day('jeudi 29 octobre 2026'));
      await tester.pump();
      await tester.tap(_day('mardi 27 octobre 2026'), warnIfMissed: false);
      await tester.pump();
      expect(_host(tester).changes, isEmpty, reason: 'le 27 deviendrait l’arrivée d’une période du 27 au 29');
      await tester.tap(_day('mercredi 28 octobre 2026'));
      await tester.pump();
      expect(_host(tester).changes, [FlDateRange(DateTime(2026, 10, 28), DateTime(2026, 10, 29))]);
      semantics.dispose();
    });

    testWidgets('devrait refuser une période qui traverse la nuit prise, dans un sens comme dans l’autre', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _stay());
      await tester.tap(_day('samedi 24 octobre 2026'));
      await tester.pump();
      expect(_label(tester, 'mercredi 28 octobre 2026'), 'mercredi 28 octobre 2026, indisponible');
      await tester.tap(_day('mercredi 28 octobre 2026'), warnIfMissed: false);
      await tester.pump();
      expect(_host(tester).changes, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, _stay());
      await tester.tap(_day('mercredi 28 octobre 2026'));
      await tester.pump();
      await tester.tap(_day('samedi 24 octobre 2026'), warnIfMissed: false);
      await tester.pump();
      expect(_host(tester).changes, isEmpty);
      semantics.dispose();
    });

    testWidgets('devrait tenir la règle au clavier', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _stay(focusedDate: DateTime(2026, 10, 27)));
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      }
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_label(tester, 'mardi 27 octobre 2026'), isNot(contains('début posé')));
      for (var i = 0; i < 3; i++) {
        await _key(tester, LogicalKeyboardKey.arrowLeft);
      }
      await _key(tester, LogicalKeyboardKey.enter);
      for (var i = 0; i < 4; i++) {
        await _key(tester, LogicalKeyboardKey.arrowRight);
      }
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).changes, isEmpty, reason: 'le 28 est au-delà de la nuit prise');
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).changes, [FlDateRange(DateTime(2026, 10, 24), DateTime(2026, 10, 27))]);
      semantics.dispose();
    });

    testWidgets('devrait tenir la règle dans le mois suivant et après le choix de l’année', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _Host(isUnavailable: (day) => day == DateTime(2026, 11, 2), unit: FlRangeUnit.nights));
      await tester.tap(_day('vendredi 30 octobre 2026'));
      await tester.tap(find.bySemanticsLabel('Mois suivant'));
      await tester.pumpAndSettle();
      expect(_label(tester, 'lundi 2 novembre 2026'), 'lundi 2 novembre 2026, départ seulement');
      expect(_label(tester, 'mardi 3 novembre 2026'), 'mardi 3 novembre 2026, indisponible');
      await tester.tap(find.bySemanticsLabel(RegExp('^novembre 2026')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('2027'));
      await tester.pumpAndSettle();
      expect(_label(tester, 'mardi 2 novembre 2027'), 'mardi 2 novembre 2027, indisponible');
      await tester.tap(find.bySemanticsLabel(RegExp('^novembre 2027')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('2026'));
      await tester.pumpAndSettle();
      await tester.tap(_day('lundi 2 novembre 2026'));
      await tester.pump();
      expect(_host(tester).changes, [FlDateRange(DateTime(2026, 10, 30), DateTime(2026, 11, 2))]);
      semantics.dispose();
    });

    testWidgets('devrait dire indisponible, sans départ, un jour dont la veille est prise ou hors des bornes', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        _Host(
          isUnavailable: (day) => day == DateTime(2026, 10, 26) || day == DateTime(2026, 10, 27),
          unit: FlRangeUnit.nights,
        ),
      );
      expect(_label(tester, 'lundi 26 octobre 2026'), 'lundi 26 octobre 2026, départ seulement, indisponible');
      expect(_label(tester, 'mardi 27 octobre 2026'), 'mardi 27 octobre 2026, indisponible');
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, _Host(isUnavailable: _night27, unit: FlRangeUnit.nights, minDate: DateTime(2026, 10, 27)));
      expect(_label(tester, 'mardi 27 octobre 2026'), 'mardi 27 octobre 2026, indisponible');
      semantics.dispose();
    });

    testWidgets('devrait souligner le chiffre du jour départ seulement, et lui seul', (tester) async {
      await _pump(tester, _stay());
      expect(_decoration(tester, '27'), TextDecoration.underline);
      expect(_decoration(tester, '26'), isNull);
      await tester.tap(find.text('24'));
      await tester.pump();
      expect(_decoration(tester, '27'), TextDecoration.underline);
    });

    testWidgets('devrait ignorer un début rouvert sur un jour départ seulement', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _stay(initialStart: DateTime(2026, 10, 27)));
      expect(_label(tester, 'mardi 27 octobre 2026'), isNot(contains('début posé')));
      semantics.dispose();
    });

    testWidgets('devrait exiger le mot « départ seulement » quand on compte en nuits', (tester) async {
      final table = {for (final entry in flCalendarL10n.entries) entry.key: entry.value['fr']!}
        ..remove('calendarDepartureOnly');
      final strings = FlCalendarStrings.fromTable(table);
      expect(strings.departureOnly, isNull);
      await tester.pumpWidget(
        toggleApp(
          SizedBox(
            width: 320,
            child: FlRangeCalendar(value: null, onChanged: (_) {}, strings: strings, unit: FlRangeUnit.nights),
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('devrait pâlir et dire indisponible la nuit prise au milieu d’une période de l’app (M1)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _stay());
      _host(tester).replace(FlDateRange(DateTime(2026, 10, 24), DateTime(2026, 10, 29)));
      await tester.pumpAndSettle();
      expect(_label(tester, 'mardi 27 octobre 2026'), 'mardi 27 octobre 2026, départ seulement, indisponible');
      expect(_opacity(tester, '27'), lessThan(1));
      semantics.dispose();
    });

    testWidgets('devrait pâlir et dire indisponible une période de l’app qui commence sur une nuit prise (M1)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _stay());
      _host(tester).replace(FlDateRange(DateTime(2026, 10, 27), DateTime(2026, 10, 29)));
      await tester.pumpAndSettle();
      expect(
        _label(tester, 'mardi 27 octobre 2026'),
        'mardi 27 octobre 2026, début de la période, départ seulement, indisponible',
      );
      expect(_opacity(tester, '27'), lessThan(1));
      semantics.dispose();
    });

    testWidgets('devrait abandonner le début posé au second toucher sur le même jour, sans séjour sans nuit (B2)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _stay());
      await tester.tap(_day('samedi 24 octobre 2026'));
      await tester.pump();
      await tester.tap(_day('samedi 24 octobre 2026'));
      await tester.pump();
      expect(_host(tester).changes, isEmpty);
      expect(_label(tester, 'samedi 24 octobre 2026'), isNot(contains('début posé')));
      await tester.tap(_day('samedi 24 octobre 2026'));
      await tester.pump();
      await tester.tap(_day('lundi 26 octobre 2026'));
      await tester.pump();
      expect(_host(tester).changes, [FlDateRange(DateTime(2026, 10, 24), DateTime(2026, 10, 26))]);
      semantics.dispose();
    });

    testWidgets('devrait dire indisponible, sans départ, le jour après la borne haute (B3)', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _Host(isUnavailable: _night27, unit: FlRangeUnit.nights, maxDate: DateTime(2026, 10, 26)));
      expect(_label(tester, 'mardi 27 octobre 2026'), 'mardi 27 octobre 2026, indisponible');
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, _Host(isUnavailable: _night27, unit: FlRangeUnit.nights, maxDate: DateTime(2026, 10, 27)));
      await tester.tap(_day('samedi 24 octobre 2026'));
      await tester.pump();
      await tester.tap(_day('mardi 27 octobre 2026'));
      await tester.pump();
      expect(_host(tester).changes, [FlDateRange(DateTime(2026, 10, 24), DateTime(2026, 10, 27))]);
      semantics.dispose();
    });
  });

  for (final unit in FlRangeUnit.values) {
    testWidgets('devrait abandonner le début posé quand sa nuit devient prise, en ${unit.name} (B1)', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _Host(isUnavailable: _night27, unit: unit));
      await tester.tap(_day('samedi 24 octobre 2026'));
      await tester.pump();
      await _pump(tester, _Host(isUnavailable: (day) => day == DateTime(2026, 10, 24) || _night27(day), unit: unit));
      expect(_label(tester, 'samedi 24 octobre 2026'), isNot(contains('début posé')));
      await tester.tap(_day('lundi 26 octobre 2026'));
      await tester.pump();
      expect(_host(tester).changes, isEmpty, reason: 'le 26 pose un nouveau début');
      expect(_label(tester, 'lundi 26 octobre 2026'), contains('début posé'));
      semantics.dispose();
    });
  }

  testWidgets('devrait abandonner le début posé quand une borne le laisse dehors (B1)', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _stay());
    await tester.tap(_day('samedi 24 octobre 2026'));
    await tester.pump();
    await _pump(tester, _Host(isUnavailable: _night27, unit: FlRangeUnit.nights, minDate: DateTime(2026, 10, 25)));
    await tester.tap(_day('lundi 26 octobre 2026'));
    await tester.pump();
    expect(_host(tester).changes, isEmpty);
    expect(_label(tester, 'lundi 26 octobre 2026'), contains('début posé'));
    await _pump(tester, _Host(isUnavailable: _night27, unit: FlRangeUnit.nights, maxDate: DateTime(2026, 10, 25)));
    expect(
      _label(tester, 'lundi 26 octobre 2026'),
      isNot(contains('début posé')),
      reason: 'la borne haute le laisse dehors',
    );
    semantics.dispose();
  });

  testWidgets('devrait ignorer un début rouvert sur un jour indisponible, puis compter en nuits sans lui (B1)', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _Host(isUnavailable: _night27, initialStart: DateTime(2026, 10, 27)));
    await _pump(tester, _Host(isUnavailable: _night27, unit: FlRangeUnit.nights, initialStart: DateTime(2026, 10, 27)));
    await tester.tap(_day('mercredi 28 octobre 2026'));
    await tester.pump();
    expect(_host(tester).changes, isEmpty);
    expect(_label(tester, 'mercredi 28 octobre 2026'), contains('début posé'));
    semantics.dispose();
  });

  testWidgets('devrait garder en jours, par défaut, le jour indisponible fermé à la fin d’une période', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, const _Host(isUnavailable: _night27));
    // Barré comme tout jour refusé (`.cal-d.off` d'Izydesk), jamais souligné : en jours, pas de départ seulement.
    expect(_decoration(tester, '27'), TextDecoration.lineThrough);
    await tester.tap(_day('samedi 24 octobre 2026'));
    await tester.pump();
    expect(_label(tester, 'mardi 27 octobre 2026'), 'mardi 27 octobre 2026, indisponible');
    await tester.tap(_day('mardi 27 octobre 2026'), warnIfMissed: false);
    await tester.pump();
    expect(_host(tester).changes, isEmpty);
    expect(_decoration(tester, '27'), TextDecoration.lineThrough);
    semantics.dispose();
  });

  test('devrait garder une période dans l\'ordre et sans heure', () {
    expect(() => FlDateRange(DateTime(2026, 10, 16), DateTime(2026, 10, 12)), throwsArgumentError);
    final range = FlDateRange.between(DateTime(2026, 10, 16, 18), DateTime(2026, 10, 12, 9));
    expect(range.start, DateTime(2026, 10, 12));
    expect(range.end, DateTime(2026, 10, 16));
    expect(range.contains(DateTime(2026, 10, 16, 23, 59)), isTrue);
    expect(range.contains(DateTime(2026, 10, 17)), isFalse);
  });
}
