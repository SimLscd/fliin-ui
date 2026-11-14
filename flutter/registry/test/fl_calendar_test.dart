import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:fliin_ui/components/calendar/fl_calendar.dart';
import 'package:fliin_ui/components/calendar/fl_calendar_strings.dart';
import 'package:fliin_ui/components/calendar/fl_calendar_view.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

final _fr = FlCalendarStrings.language('fr');
final _ar = FlCalendarStrings.language('ar');
final _today = DateTime(2026, 10, 24);

/// Un calendrier qui garde le jour choisi et note chaque choix.
class _Host extends StatefulWidget {
  const _Host({
    this.width = 320,
    this.initial,
    this.strings,
    this.minDate,
    this.maxDate,
    this.isUnavailable,
    this.firstDayOfWeek,
    this.weeksInMonth,
    this.enabled = true,
    this.reduceMotion = false,
    this.announce = true,
  });

  final double width;
  final DateTime? initial;
  final FlCalendarStrings? strings;
  final DateTime? minDate;
  final DateTime? maxDate;
  final bool Function(DateTime)? isUnavailable;
  final int? firstDayOfWeek;
  final int? weeksInMonth;
  final bool enabled;
  final bool reduceMotion;
  final bool announce;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late DateTime? value = widget.initial;
  final List<DateTime> changes = [];
  final List<DateTime> months = [];

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: widget.reduceMotion, supportsAnnounce: widget.announce),
    child: SizedBox(
      width: widget.width,
      child: FlCalendar(
        value: value,
        onChanged: (day) => setState(() {
          changes.add(day);
          value = day;
        }),
        today: _today,
        strings: widget.strings ?? _fr,
        minDate: widget.minDate,
        maxDate: widget.maxDate,
        isUnavailable: widget.isUnavailable,
        firstDayOfWeek: widget.firstDayOfWeek,
        weeksInMonth: widget.weeksInMonth,
        enabled: widget.enabled,
        semanticLabel: 'Rendez-vous',
        onMonthChanged: months.add,
      ),
    ),
  );
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

Future<void> _pump(WidgetTester tester, _Host host, {TextDirection direction = TextDirection.ltr}) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(toggleApp(host, direction: direction));
  await tester.pumpAndSettle();
}

/// Le nœud du jour dont la lecture commence par [date].
Finder _day(String date) => find.bySemanticsLabel(RegExp('^${RegExp.escape(date)}'));

String _label(WidgetTester tester, String date) => tester.getSemantics(_day(date)).label;

/// Le jour [date] porte l'état choisi, que le lecteur d'écran dit lui-même.
bool _selected(WidgetTester tester, String date) =>
    tester.getSemantics(_day(date)).getSemanticsData().flagsCollection.isSelected == Tristate.isTrue;

/// Les annonces envoyées au lecteur d'écran.
List<String> _announcements(WidgetTester tester) {
  final announced = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
    message,
  ) async {
    final data = (message! as Map<Object?, Object?>)['data']! as Map<Object?, Object?>;
    if (data['message'] case final String text) announced.add(text);
    return null;
  });
  addTearDown(
    () =>
        tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, null),
  );
  return announced;
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key, {bool shift = false}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pumpAndSettle();
}

/// L'échelle à laquelle le texte [text] est peint : sa hauteur à l'écran sur
/// celle de sa mise en page.
double _renderedScale(WidgetTester tester, String text) =>
    tester.getRect(find.text(text).first).height / tester.getSize(find.text(text).first).height;

/// La couleur du disque sous le texte [text], nulle sans fond.
Color? _disc(WidgetTester tester, String text) =>
    (tester
                .widget<DecoratedBox>(find.ancestor(of: find.text(text), matching: find.byType(DecoratedBox)).first)
                .decoration
            as BoxDecoration)
        .color;

/// Met le focus clavier sur la grille des jours, par Tab depuis le début.
Future<void> _focusGrid(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('devrait dire chaque mois montré une fois, au bouton, au glisser et par la grille des années', (
    tester,
  ) async {
    await _pump(tester, _Host(initial: DateTime(2026, 10, 14)));
    final months = _host(tester).months;
    expect(months, [DateTime(2026, 10)]);
    await tester.tap(find.bySemanticsLabel('Mois suivant'));
    await tester.pumpAndSettle();
    expect(months, [DateTime(2026, 10), DateTime(2026, 11)]);
    await tester.tap(find.text('18'));
    await tester.pumpAndSettle();
    expect(months, hasLength(2), reason: 'choisir un jour du même mois ne le redit pas');
    await tester.fling(find.text('15'), const Offset(-200, 0), 1000);
    await tester.pumpAndSettle();
    expect(months.last, DateTime(2026, 12));
    await tester.tap(find.text('décembre 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2027'));
    await tester.pumpAndSettle();
    expect(months, [DateTime(2026, 10), DateTime(2026, 11), DateTime(2026, 12), DateTime(2027, 12)]);
  });

  testWidgets('devrait rendre le jour touché quand on peut le choisir', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _Host(initial: DateTime(2026, 10, 14)));
    await tester.tap(_day('lundi 19 octobre 2026'));
    await tester.pump();
    expect(_host(tester).changes, [DateTime(2026, 10, 19)]);
    expect(_label(tester, 'lundi 19 octobre 2026'), 'lundi 19 octobre 2026');
    expect(_selected(tester, 'lundi 19 octobre 2026'), isTrue);
    semantics.dispose();
  });

  testWidgets('devrait refuser un jour indisponible, hors des bornes ou du mois voisin', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      _Host(minDate: DateTime(2026, 10, 8), isUnavailable: (day) => day.weekday == DateTime.saturday),
    );
    await tester.tap(_day('samedi 10 octobre 2026'));
    await tester.tap(_day('lundi 5 octobre 2026'));
    // Le 28 septembre est montré avant le 1er octobre, pâli, sans nœud.
    await tester.tap(find.text('28').first);
    await tester.pump();
    expect(_host(tester).changes, isEmpty);
    expect(_label(tester, 'samedi 10 octobre 2026'), 'samedi 10 octobre 2026, indisponible');
    expect(_label(tester, 'lundi 5 octobre 2026'), 'lundi 5 octobre 2026, indisponible');
    expect(find.bySemanticsLabel(RegExp('septembre')), findsNothing);
    final unavailable = tester.getSemantics(_day('samedi 10 octobre 2026')).getSemanticsData();
    expect(unavailable.flagsCollection.isEnabled, Tristate.isFalse);
    semantics.dispose();
  });

  testWidgets('devrait lire chaque jour avec sa date entière, aujourd\'hui et le choix', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _Host(initial: DateTime(2026, 10, 24)));
    // « Choisi » est l'état du nœud, que VoiceOver et TalkBack lisent : le
    // redire dans le libellé le ferait entendre deux fois.
    expect(_label(tester, 'samedi 24 octobre 2026'), 'samedi 24 octobre 2026, aujourd’hui');
    expect(_selected(tester, 'samedi 24 octobre 2026'), isTrue);
    expect(_selected(tester, 'mardi 13 octobre 2026'), isFalse);
    expect(_label(tester, 'mardi 13 octobre 2026'), 'mardi 13 octobre 2026');
    expect(find.bySemanticsLabel('Rendez-vous, octobre 2026'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('devrait passer au mois suivant au bouton et l\'annoncer', (tester) async {
    final semantics = tester.ensureSemantics();
    final announced = _announcements(tester);
    await _pump(tester, const _Host());
    await tester.tap(find.bySemanticsLabel('Mois suivant'));
    await tester.pumpAndSettle();
    expect(find.text('novembre 2026'), findsOneWidget);
    expect(announced, ['novembre 2026']);
    await tester.tap(find.bySemanticsLabel('Mois précédent'));
    await tester.tap(find.bySemanticsLabel('Mois précédent'));
    await tester.pumpAndSettle();
    expect(find.text('septembre 2026'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('devrait annoncer le mois par une région vivante quand la plateforme n\'annonce pas', (tester) async {
    final semantics = tester.ensureSemantics();
    final announced = _announcements(tester);
    await _pump(tester, const _Host(announce: false));
    await tester.tap(find.bySemanticsLabel('Mois suivant'));
    await tester.pumpAndSettle();
    expect(announced, isEmpty);
    final heading = tester.getSemantics(find.bySemanticsLabel('novembre 2026')).getSemanticsData();
    expect(heading.flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });

  testWidgets('devrait faire glisser le mois et le poser d\'un coup sous mouvement réduit', (tester) async {
    await _pump(tester, const _Host());
    await tester.tap(find.bySemanticsLabel('Mois suivant'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Pendant le glissement, les deux mois sont dans l'arbre.
    expect(find.text('19'), findsNWidgets(2));
    await tester.pumpAndSettle();

    await _pump(tester, const _Host(reduceMotion: true));
    await tester.tap(find.bySemanticsLabel('Mois suivant'));
    await tester.pump();
    expect(find.text('novembre 2026'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('devrait changer de mois au glisser du doigt, retourné en RTL', (tester) async {
    await _pump(tester, const _Host());
    await tester.fling(find.text('15'), const Offset(-200, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('novembre 2026'), findsOneWidget);

    await _pump(tester, const _Host(), direction: TextDirection.rtl);
    await tester.fling(find.text('15'), const Offset(-200, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('septembre 2026'), findsOneWidget);
  });

  testWidgets('devrait refuser un mois hors des bornes', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _Host(minDate: DateTime(2026, 10, 3), maxDate: DateTime(2026, 11, 30)));
    await tester.tap(find.bySemanticsLabel('Mois précédent'));
    await tester.pumpAndSettle();
    expect(find.text('octobre 2026'), findsOneWidget);
    final previous = tester.getSemantics(find.bySemanticsLabel('Mois précédent')).getSemanticsData();
    expect(previous.flagsCollection.isEnabled, Tristate.isFalse);
    semantics.dispose();
  });

  testWidgets('devrait parcourir les jours au clavier et choisir à Entrée', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _Host(initial: DateTime(2026, 10, 14)));
    await _focusGrid(tester);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(_host(tester).changes, [DateTime(2026, 10, 22)]);
    await _key(tester, LogicalKeyboardKey.home);
    await _key(tester, LogicalKeyboardKey.space);
    expect(_host(tester).changes.last, DateTime(2026, 10, 19));
    await _key(tester, LogicalKeyboardKey.end);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(_host(tester).changes.last, DateTime(2026, 10, 25));
    await _key(tester, LogicalKeyboardKey.pageDown);
    expect(find.text('novembre 2026'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(_host(tester).changes.last, DateTime(2026, 11, 25));
    await _key(tester, LogicalKeyboardKey.pageUp, shift: true);
    expect(find.text('novembre 2025'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('devrait retourner les flèches gauche et droite en RTL', (tester) async {
    await _pump(
      tester,
      _Host(initial: DateTime(2026, 10, 14), strings: _ar),
      direction: TextDirection.rtl,
    );
    await _focusGrid(tester);
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(_host(tester).changes, [DateTime(2026, 10, 15)]);
  });

  testWidgets('devrait passer au mois voisin quand le curseur en sort, et s\'arrêter à la borne', (tester) async {
    await _pump(tester, _Host(initial: DateTime(2026, 10, 31), maxDate: DateTime(2026, 11, 1)));
    await _focusGrid(tester);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('novembre 2026'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(_host(tester).changes, [DateTime(2026, 11, 1)]);
  });

  testWidgets('devrait choisir une année dans la grille des années, au doigt et au clavier', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _Host(initial: DateTime(2026, 10, 14)));
    await tester.tap(find.text('octobre 2026'));
    await tester.pumpAndSettle();
    final trigger = tester.getSemantics(find.bySemanticsLabel('octobre 2026')).getSemanticsData();
    expect(trigger.hint, 'Choisir l’année');
    expect(trigger.flagsCollection.isExpanded, Tristate.isTrue);
    expect(
      tester.semantics.simulatedAccessibilityTraversal().map((node) => node.label),
      isNot(contains('Rendez-vous, octobre 2026')),
    );
    await tester.tap(find.text('2027'));
    await tester.pumpAndSettle();
    expect(find.text('octobre 2027'), findsOneWidget);
    expect(find.text('2027'), findsNothing);

    await tester.tap(find.text('octobre 2027'));
    await tester.pumpAndSettle();
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(find.text('octobre 2031'), findsOneWidget);

    await tester.tap(find.text('octobre 2031'));
    await tester.pumpAndSettle();
    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.text('octobre 2031'), findsOneWidget);
    expect(find.text('2030'), findsNothing);
    semantics.dispose();
  });

  testWidgets('devrait commencer la semaine au jour de la langue, ou à celui de l\'app', (tester) async {
    await _pump(tester, _Host(strings: _ar), direction: TextDirection.rtl);
    final saturday = tester.getTopRight(find.text('س'));
    final friday = tester.getTopRight(find.text('ج'));
    expect(saturday.dx, greaterThan(friday.dx), reason: 'le samedi ouvre la semaine, à droite en RTL');

    await _pump(tester, const _Host(width: 420, firstDayOfWeek: DateTime.sunday));
    expect(tester.getTopLeft(find.text('D')).dx, lessThan(tester.getTopLeft(find.text('L')).dx));
  });

  testWidgets('devrait écrire les chiffres de la langue', (tester) async {
    await _pump(tester, _Host(strings: _ar), direction: TextDirection.rtl);
    expect(find.text('أكتوبر ٢٠٢٦'), findsOneWidget);
    expect(find.text('١٤'), findsOneWidget);
  });

  testWidgets('devrait tenir sur 320 de large à 2,0 sans couper un jour, les jours de la semaine en initiales', (
    tester,
  ) async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: toggleApp(const _Host(width: 320, weeksInMonth: 6), platform: platform),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('L'), findsOneWidget);
      expect(find.text('lun.'), findsNothing);
      // La ligne de textBase à 2,0 fait 48, la colonne 45,7 : le chiffre est
      // à peine réduit.
      expect(_renderedScale(tester, '5'), moreOrLessEquals(320 / 7 / 48, epsilon: 0.001));
    }
  });

  testWidgets('devrait réduire le chiffre d\'un jour au côté de sa case quand le texte agrandi ne tient pas', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: toggleApp(const _Host(width: 252)),
      ),
    );
    await tester.pumpAndSettle();
    // La ligne de textBase à 2,0 fait 48, la case 36 : rendu à 0,75, soit 1,5.
    expect(_renderedScale(tester, '5'), moreOrLessEquals(0.75, epsilon: 0.001));
    final cell = tester.getRect(find.text('5'));
    expect(cell.height, lessThanOrEqualTo(36));
  });

  testWidgets('devrait étendre la cible de chaque jour à 44 sur iOS et 48 sur Android', (tester) async {
    for (final (platform, side) in [(TargetPlatform.iOS, 44.0), (TargetPlatform.android, 48.0)]) {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(toggleApp(const _Host(width: 252), platform: platform));
      await tester.pumpAndSettle();
      final rect = tester.getSemantics(_day('mardi 13 octobre 2026')).rect;
      expect(rect.width, greaterThanOrEqualTo(side));
      expect(rect.height, greaterThanOrEqualTo(side));
      semantics.dispose();
    }
  });

  testWidgets('devrait tout pâlir et refuser le toucher quand il est désactivé', (tester) async {
    await _pump(tester, _Host(enabled: false, initial: DateTime(2026, 10, 14)));
    await tester.tap(find.text('19'));
    await tester.tap(find.text('octobre 2026'));
    await tester.pumpAndSettle();
    expect(_host(tester).changes, isEmpty);
    expect(find.text('2027'), findsNothing);
  });

  testWidgets('devrait rendre le focus clavier à la grille des jours après le choix d\'une année', (tester) async {
    await _pump(tester, _Host(initial: DateTime(2026, 10, 14)));
    await tester.tap(find.text('octobre 2026'));
    await tester.pumpAndSettle();
    await _key(tester, LogicalKeyboardKey.arrowRight);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(find.text('octobre 2027'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(_host(tester).changes, [DateTime(2027, 10, 15)]);
  });

  testWidgets('devrait ignorer le glisser d\'un calendrier désactivé, et un glisser court et lent', (tester) async {
    await _pump(tester, const _Host(enabled: false));
    await tester.fling(find.text('15'), const Offset(-200, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('octobre 2026'), findsOneWidget);

    await _pump(tester, const _Host());
    await tester.timedDrag(find.text('15'), const Offset(-20, 0), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('octobre 2026'), findsOneWidget);
  });

  testWidgets('devrait suivre une borne qui change et montrer son mois', (tester) async {
    await tester.pumpWidget(const SizedBox());
    Widget at(DateTime? min) => toggleApp(
      SizedBox(
        width: 320,
        child: FlCalendar(value: null, onChanged: (_) {}, today: _today, strings: _fr, minDate: min),
      ),
    );
    await tester.pumpWidget(at(null));
    await tester.pumpAndSettle();
    await tester.pumpWidget(at(DateTime(2026, 12, 3)));
    await tester.pumpAndSettle();
    expect(find.text('décembre 2026'), findsOneWidget);
  });

  testWidgets('devrait offrir les années d\'une borne au-delà de 2099 sans erreur', (tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      toggleApp(
        SizedBox(
          width: 320,
          child: FlCalendar(
            value: null,
            onChanged: (_) {},
            today: _today,
            strings: _fr,
            minDate: DateTime(2150, 3, 1),
            defaultYearPickerOpen: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // L'en-tête de la grille des années dit l'année seule, comme sa case.
    expect(find.text('2150'), findsNWidgets(2));
  });

  testWidgets('devrait rendre le focus à la grille quand « Mois suivant » se désactive à la borne', (tester) async {
    await _pump(tester, _Host(initial: DateTime(2026, 10, 14), maxDate: DateTime(2026, 11, 20)));
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await _key(tester, LogicalKeyboardKey.enter);
    expect(find.text('novembre 2026'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'FlCalendarView grid');
    await _key(tester, LogicalKeyboardKey.enter);
    expect(_host(tester).changes, [DateTime(2026, 11, 14)]);
  });

  testWidgets('devrait donner le focus à la grille, sur le jour choisi, quand autofocus est vrai', (tester) async {
    await tester.pumpWidget(
      toggleApp(
        SizedBox(
          width: 320,
          child: FlCalendar(
            value: DateTime(2026, 10, 14),
            onChanged: (_) {},
            today: _today,
            strings: _fr,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'FlCalendarView grid');
  });

  testWidgets('devrait marquer focalisé, pour le lecteur d\'écran, le jour sous le curseur du clavier', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _Host(initial: DateTime(2026, 10, 14)));
    bool focused(String date) =>
        tester.getSemantics(_day(date)).getSemanticsData().flagsCollection.isFocused == Tristate.isTrue;
    expect(focused('mercredi 14 octobre 2026'), isFalse);
    await _focusGrid(tester);
    expect(focused('mercredi 14 octobre 2026'), isTrue);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(focused('jeudi 15 octobre 2026'), isTrue);
    expect(focused('mercredi 14 octobre 2026'), isFalse);
    semantics.dispose();
  });

  testWidgets('devrait signaler par une assertion une langue sans textes, au lieu de passer à l\'anglais', (
    tester,
  ) async {
    await tester.pumpWidget(
      toggleApp(
        Localizations(
          locale: const Locale('de'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: SizedBox(
            width: 320,
            child: FlCalendar(value: null, onChanged: (_) {}, today: _today),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isA<AssertionError>());
  });

  testWidgets('devrait fermer la grille des années quand le calendrier se désactive', (tester) async {
    await _pump(tester, _Host(initial: DateTime(2026, 10, 14)));
    await tester.tap(find.text('octobre 2026'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(toggleApp(_Host(initial: DateTime(2026, 10, 14), enabled: false)));
    await tester.pumpAndSettle();
    expect(find.text('2027'), findsNothing);
    expect(find.text('octobre 2026'), findsOneWidget);
  });

  testWidgets('devrait marquer aujourd\'hui d\'un disque selected doux et d\'un chiffre link, et le survoler', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const _Host(), platform: TargetPlatform.macOS));
    await tester.pumpAndSettle();
    final light = FlTokens.defaults.light;
    final style = tester.widget<Text>(find.text('24').first).style!;
    expect(style.color, light.link);
    expect(style.fontWeight, FlTokens.defaults.typography.weight.medium);
    expect(_disc(tester, '24'), light.selected.withValues(alpha: light.selected.a * 0.15));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('24')));
    await tester.pumpAndSettle();
    expect(_disc(tester, '24'), FlTokens.defaults.light.control);
  });

  testWidgets('devrait laisser le jour tel quel sous la souris quand la plateforme est un téléphone', (tester) async {
    await _pump(tester, const _Host());
    final light = FlTokens.defaults.light;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('24')));
    await tester.pumpAndSettle();
    expect(_disc(tester, '24'), light.selected.withValues(alpha: light.selected.a * 0.15));
  });

  testWidgets('devrait reconstruire la grille au minuit suivant quand l\'app ne donne pas aujourd\'hui', (
    tester,
  ) async {
    var builds = 0;
    await tester.pumpWidget(
      toggleApp(
        SizedBox(
          width: 320,
          child: FlCalendarView(
            markOf: (_) {
              builds++;
              return FlDayMark.none;
            },
            onDayPressed: (_) {},
            strings: _fr,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = builds;
    final now = DateTime.now();
    await tester.pump(DateTime(now.year, now.month, now.day + 1).difference(now) + const Duration(seconds: 1));
    expect(builds, greaterThan(before));
  });

  test('devrait lire une table de textes d\'une autre langue, et nommer la clé qui manque', () {
    final german = {for (final entry in flCalendarL10n.entries) entry.key: entry.value['en']!}
      ..['calendarMonths'] = 'Januar,Februar,März,April,Mai,Juni,Juli,August,September,Oktober,November,Dezember'
      ..['calendarFirstDay'] = '1';
    final strings = FlCalendarStrings.fromTable(german);
    expect(strings.monthYear(2026, 10), 'Oktober 2026');
    expect(strings.firstDayOfWeek, DateTime.monday);
    expect(
      () => FlCalendarStrings.fromTable({...german}..remove('calendarMonths')),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('calendarMonths'))),
    );
    expect(
      () => FlCalendarStrings.fromTable({...german, 'calendarFirstDay': '0'}),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('calendarFirstDay'))),
    );
  });

  test('devrait garder la table de textes égale au l10n du manifeste', () {
    final manifest = jsonDecode(File('items/calendar.json').readAsStringSync()) as Map<String, Object?>;
    expect(manifest['l10n'], flCalendarL10n);
  });

  test('devrait écrire la date entière et le mois dans les trois langues', () {
    final day = DateTime(2026, 10, 14);
    expect(FlCalendarStrings.language('en').date(day), 'Wednesday, October 14, 2026');
    expect(_fr.date(day), 'mercredi 14 octobre 2026');
    expect(_ar.date(day), 'الأربعاء، ١٤ أكتوبر ٢٠٢٦');
    expect(FlCalendarStrings.language('de').monthYear(2026, 10), 'October 2026');
    expect(_ar.firstDayOfWeek, DateTime.saturday);
  });

  testWidgets('devrait poser un point sous les jours que nomme indicatorOf et lire son texte après la date', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final chosen = DateTime(2026, 10, 15);
    await tester.pumpWidget(
      toggleApp(
        SizedBox(
          width: 320,
          child: FlCalendar(
            value: chosen,
            onChanged: (_) {},
            today: _today,
            strings: _fr,
            indicatorOf: (day) => switch (day.day) {
              7 => '2 événements',
              15 => '',
              _ => null,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Finder dot(String number) => find.descendant(
      of: find.ancestor(of: find.text(number), matching: find.byType(Stack)).first,
      matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is ShapeDecoration),
    );
    final light = FlTokens.defaults.light;
    expect((tester.widget<DecoratedBox>(dot('7')).decoration as ShapeDecoration).color, light.onSurfaceMuted);
    expect((tester.widget<DecoratedBox>(dot('15')).decoration as ShapeDecoration).color, light.onSelected);
    expect(tester.getSize(dot('7')), const Size.square(4));
    final disc = tester.getRect(find.ancestor(of: find.text('7'), matching: find.byType(Stack)).first);
    expect(tester.getRect(dot('7')).bottom, disc.bottom - 4);
    expect(tester.getRect(dot('7')).center.dx, disc.center.dx);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is ShapeDecoration &&
            (w.decoration as ShapeDecoration).shape is CircleBorder,
      ),
      findsNWidgets(2),
    );
    expect(_label(tester, _fr.date(DateTime(2026, 10, 7))), endsWith('2 événements'));
    expect(_label(tester, _fr.date(DateTime(2026, 10, 8))), isNot(contains('événement')));
    expect(_label(tester, _fr.date(chosen)), isNot(endsWith(_fr.separator)));
    semantics.dispose();
  });
}
