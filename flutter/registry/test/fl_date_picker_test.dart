import 'package:fliin_ui/components/calendar/fl_calendar.dart';
import 'package:fliin_ui/components/calendar/fl_calendar_strings.dart';
import 'package:fliin_ui/components/calendar/fl_calendar_view.dart';
import 'package:fliin_ui/components/date_picker/fl_date_picker.dart';
import 'package:fliin_ui/components/sheet/fl_sheet.dart';
import 'package:fliin_ui/components/text_field/fl_input.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_app.dart';

final _fr = FlCalendarStrings.language('fr');
final _today = DateTime(2026, 10, 24);
FlTokens get _tokens => FlTokens.defaults;

/// Un sélecteur de date sur 320 de large, en haut de la page, qui garde la
/// date reçue quand [accept] est vrai et note chaque appel de `onChanged`.
Widget _picker({
  DateTime? value,
  List<DateTime?>? log,
  bool accept = true,
  bool enabled = true,
  FlDatePickerPresentation? presentation,
  String? error,
  String? description,
  bool required = false,
}) {
  var current = value;
  return StatefulBuilder(
    builder: (context, setState) => Align(
      alignment: AlignmentDirectional.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: SizedBox(
          width: 320,
          child: FlDatePicker(
            label: 'Date du rendez-vous',
            placeholder: 'Choisir une date',
            value: current,
            presentation: presentation,
            barrierLabel: 'Fermer le calendrier',
            clearLabel: 'Effacer la date',
            description: description,
            error: error,
            required: required,
            today: _today,
            strings: _fr,
            onChanged: enabled
                ? (day) {
                    log?.add(day);
                    if (accept) setState(() => current = day);
                  }
                : null,
          ),
        ),
      ),
    ),
  );
}

final _trigger = find.descendant(of: find.byType(FlDatePicker), matching: find.byType(FlPressable)).first;

/// Le chiffre [day] dans la grille du calendrier ouvert.
Finder _cell(String day) => find.descendant(of: find.byType(FlCalendarView), matching: find.text(day)).first;

Future<void> _phone(WidgetTester tester, {Size size = const Size(390, 844)}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// Un sélecteur dont l'app change la valeur et les jours indisponibles de
/// l'extérieur, par [set].
class _Ctl {
  DateTime? value;
  bool Function(DateTime)? unavailable;
  final log = <DateTime?>[];
  StateSetter? set;
}

Widget _controlled(_Ctl ctl, {Widget? before}) => StatefulBuilder(
  builder: (context, setState) {
    ctl.set = setState;
    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?before,
              FlDatePicker(
                label: 'Date du rendez-vous',
                placeholder: 'Choisir une date',
                value: ctl.value,
                barrierLabel: 'Fermer le calendrier',
                today: _today,
                strings: _fr,
                isUnavailable: ctl.unavailable,
                onChanged: (day) {
                  ctl.log.add(day);
                  setState(() => ctl.value = day);
                },
              ),
            ],
          ),
        ),
      ),
    );
  },
);

/// L'écart entre le bas de la grille et celui de la feuille.
double _gapUnderGrid(WidgetTester tester) =>
    tester.getRect(find.byType(FlSheet)).bottom - tester.getRect(find.byType(FlCalendarView)).bottom;

Color? _color(WidgetTester tester, String text) =>
    DefaultTextStyle.of(tester.element(find.text(text).first)).style.color ??
    tester.widget<Text>(find.text(text).first).style?.color;

void main() {
  testWidgets('devrait écrire la date entière de l’app, et le placeholder atténué sans date', (tester) async {
    await tester.pumpWidget(overlayApp(_picker()));
    expect(tester.widget<Text>(find.text('Choisir une date')).style?.color, _tokens.light.fieldPlaceholder);
    await tester.pumpWidget(overlayApp(_picker(value: DateTime(2026, 10, 14))));
    expect(find.text('mercredi 14 octobre 2026'), findsOneWidget);
    expect(_color(tester, 'mercredi 14 octobre 2026'), _tokens.light.onSurface);
  });

  testWidgets('devrait ouvrir en feuille sur un téléphone, debout comme couché, et en popover sur une tablette', (
    tester,
  ) async {
    BuildContext? context;
    Widget probe() => Builder(
      builder: (c) {
        context = c;
        return const SizedBox();
      },
    );
    for (final (size, expected) in [
      (const Size(390, 844), FlDatePickerPresentation.sheet),
      (const Size(844, 390), FlDatePickerPresentation.sheet),
      (const Size(599, 900), FlDatePickerPresentation.sheet),
      (const Size(744, 1133), FlDatePickerPresentation.popover),
      (const Size(1280, 800), FlDatePickerPresentation.popover),
    ]) {
      await _phone(tester, size: size);
      await tester.pumpWidget(overlayApp(probe()));
      expect(flDatePickerPresentationOf(context!), expected, reason: '$size');
    }
    await _phone(tester);
    await tester.pumpWidget(overlayApp(_picker(value: DateTime(2026, 10, 14))));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(find.ancestor(of: find.byType(FlCalendarView), matching: find.byType(FlSheet)), findsOneWidget);
  });

  testWidgets('devrait arrêter la feuille à la hauteur du calendrier, sans vide dessous', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(overlayApp(_picker(value: DateTime(2026, 10, 14))));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    final sheet = tester.getRect(find.byType(FlSheet));
    final grid = tester.getRect(find.byType(FlCalendarView));
    expect(grid.width, 390 - 40);
    expect(sheet.bottom - grid.bottom, closeTo(12, 0.5));
    // La poignée et la marge de la feuille au-dessus : le voile occupe le reste.
    expect(grid.top, greaterThan(844 / 3));
    await tester.tapAt(Offset(200, grid.top - 60));
    await tester.pumpAndSettle();
    expect(find.byType(FlSheet), findsNothing);
  });

  testWidgets('devrait garder au calendrier la largeur d’un téléphone dans une feuille couchée', (tester) async {
    await _phone(tester, size: const Size(844, 390));
    await tester.pumpWidget(overlayApp(_picker(value: DateTime(2026, 10, 14))));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(FlCalendarView)).width, 400);
    expect(tester.getRect(find.byType(FlCalendarView)).center.dx, 422);
    expect(tester.takeException(), isNull);
  });

  testWidgets('devrait ouvrir le popover sous le champ, à 288 de large, sur une tablette', (tester) async {
    await _phone(tester, size: const Size(1024, 768));
    await tester.pumpWidget(overlayApp(_picker(value: DateTime(2026, 10, 14))));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(find.byType(FlSheet), findsNothing);
    final grid = tester.getRect(find.byType(FlCalendarView));
    expect(grid.width, 288);
    expect(grid.top, greaterThan(tester.getRect(_trigger).bottom));
  });

  testWidgets('devrait donner le focus à la grille à l’ouverture, rendre le jour choisi, se fermer et rendre le '
      'focus au champ', (tester) async {
    final log = <DateTime?>[];
    await tester.pumpWidget(overlayApp(_picker(value: DateTime(2026, 10, 14), log: log)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final trigger = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'FlCalendarView grid');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, [DateTime(2026, 10, 15)]);
    expect(find.byType(FlCalendarView), findsNothing);
    expect(find.text('jeudi 15 octobre 2026'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, same(trigger));
  });

  testWidgets('devrait rendre le focus au champ quand la feuille se ferme à Échap, sans rien envoyer', (tester) async {
    await _phone(tester);
    final log = <DateTime?>[];
    await tester.pumpWidget(overlayApp(_picker(value: DateTime(2026, 10, 14), log: log)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final trigger = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(FlSheet), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'FlCalendarView grid');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FlSheet), findsNothing);
    expect(log, isEmpty);
    expect(find.text('mercredi 14 octobre 2026'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, same(trigger));
  });

  testWidgets('devrait choisir au toucher dans la feuille, et la refermer', (tester) async {
    await _phone(tester);
    final log = <DateTime?>[];
    await tester.pumpWidget(overlayApp(_picker(log: log)));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    await tester.tap(_cell('20'));
    await tester.pumpAndSettle();
    expect(log, [DateTime(2026, 10, 20)]);
    expect(find.byType(FlSheet), findsNothing);
    expect(find.text('mardi 20 octobre 2026'), findsOneWidget);
  });

  testWidgets('devrait garder la date de l’app quand elle refuse le jour touché', (tester) async {
    final log = <DateTime?>[];
    await tester.pumpWidget(overlayApp(_picker(value: DateTime(2026, 10, 14), log: log, accept: false)));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    await tester.tap(_cell('20'));
    await tester.pumpAndSettle();
    expect(log, [DateTime(2026, 10, 20)]);
    expect(find.text('mercredi 14 octobre 2026'), findsOneWidget);
    expect(find.text('mardi 20 octobre 2026'), findsNothing);
  });

  testWidgets('devrait effacer la date par son bouton, absent sans date', (tester) async {
    final log = <DateTime?>[];
    await tester.pumpWidget(overlayApp(_picker(value: DateTime(2026, 10, 14), log: log)));
    await tester.tap(find.bySemanticsLabel('Effacer la date'));
    await tester.pumpAndSettle();
    expect(log, [null]);
    expect(find.byType(FlCalendarView), findsNothing);
    expect(find.text('Choisir une date'), findsOneWidget);
    expect(find.bySemanticsLabel('Effacer la date'), findsNothing);
  });

  testWidgets('devrait se lire comme un bouton nommé, de valeur la date, déplié ouvert, requis et invalide', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(overlayApp(_picker(value: DateTime(2026, 10, 14), required: true, error: 'Date passée')));
    expect(
      tester.getSemantics(_trigger),
      isSemantics(
        label: 'Date du rendez-vous',
        value: 'mercredi 14 octobre 2026',
        hint: 'Date passée',
        isButton: true,
        hasExpandedState: true,
        isExpanded: false,
        hasRequiredState: true,
        isRequired: true,
        validationResult: SemanticsValidationResult.invalid,
      ),
    );
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(_trigger), isSemantics(isExpanded: true, hasExpandedState: true, isButton: true));
    semantics.dispose();
  });

  testWidgets('devrait lire le placeholder en indice sans date, et l’aide sous le champ', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(overlayApp(_picker(description: 'Du lundi au vendredi')));
    expect(
      tester.getSemantics(_trigger),
      isSemantics(label: 'Date du rendez-vous', hint: 'Choisir une date\nDu lundi au vendredi'),
    );
    expect(find.text('Du lundi au vendredi'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('devrait remplacer l’aide par l’erreur, et passer le contour à danger', (tester) async {
    await tester.pumpWidget(overlayApp(_picker(description: 'Du lundi au vendredi', error: 'Date passée')));
    expect(find.text('Du lundi au vendredi'), findsNothing);
    expect(find.text('Date passée'), findsOneWidget);
    final frame = tester.widget<FlInputFrame>(find.descendant(of: _trigger, matching: find.byType(FlInputFrame)));
    expect(frame.outline, _tokens.light.danger);
  });

  testWidgets('devrait ne pas s’ouvrir désactivé, sans bouton qui efface', (tester) async {
    await tester.pumpWidget(overlayApp(_picker(value: DateTime(2026, 10, 14), enabled: false)));
    await tester.tap(_trigger, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(FlCalendarView), findsNothing);
    expect(find.bySemanticsLabel('Effacer la date'), findsNothing);
  });

  testWidgets('devrait écrire la date entière sur plusieurs lignes, sans débordement, à 2,0 sur 320', (tester) async {
    await _phone(tester, size: const Size(360, 640));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(360, 640), textScaler: TextScaler.linear(2)),
        child: overlayApp(_picker(value: DateTime(2026, 10, 14))),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text('mercredi 14 octobre 2026')).height, greaterThan(40));
  });

  testWidgets('devrait s’ouvrir au premier rendu quand defaultOpen est vrai', (tester) async {
    await tester.pumpWidget(
      overlayApp(
        FlDatePicker(
          label: 'Date',
          placeholder: 'Choisir',
          value: DateTime(2026, 10, 14),
          onChanged: (_) {},
          presentation: FlDatePickerPresentation.popover,
          strings: _fr,
          defaultOpen: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FlCalendarView), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'FlCalendarView grid');
  });

  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets('devrait refuser un jour que l’app rend indisponible pendant l’ouverture, et montrer sa nouvelle date '
        '(${size.width.toInt()} de large)', (tester) async {
      await _phone(tester, size: size);
      final ctl = _Ctl()..value = DateTime(2026, 10, 14);
      await tester.pumpWidget(overlayApp(_controlled(ctl)));
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      ctl.set!(() {
        ctl.unavailable = (day) => day.day == 20;
        ctl.value = DateTime(2026, 10, 2);
      });
      await tester.pumpAndSettle();
      await tester.tap(_cell('20'));
      await tester.pumpAndSettle();
      expect(ctl.log, isEmpty);
      final two = find.descendant(of: find.byType(FlCalendarView), matching: find.text('2')).first;
      expect(tester.widget<Text>(two).style?.color, _tokens.light.onSelected);
    });
  }

  testWidgets('devrait suivre la hauteur du mois dans la feuille : six semaines puis cinq', (tester) async {
    await _phone(tester);
    final ctl = _Ctl()..value = DateTime(2026, 10, 14);
    await tester.pumpWidget(overlayApp(_controlled(ctl)));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(_gapUnderGrid(tester), closeTo(12, 0.5));
    await tester.tap(find.bySemanticsLabel('Mois suivant'));
    await tester.pumpAndSettle();
    expect(_gapUnderGrid(tester), closeTo(12, 0.5));
    expect(tester.getRect(find.byType(FlCalendarView)).bottom, lessThan(844));
    await tester.tap(find.descendant(of: find.byType(FlCalendarView), matching: find.text('30')).last);
    await tester.pumpAndSettle();
    expect(ctl.log, [DateTime(2026, 11, 30)]);
  });

  testWidgets('devrait suivre la place quand le clavier se ferme, et quand l’écran se redresse', (tester) async {
    await _phone(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    final ctl = _Ctl()..value = DateTime(2026, 10, 14);
    await tester.pumpWidget(overlayApp(_controlled(ctl)));
    await tester.tap(_trigger);
    await tester.pump();
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(_gapUnderGrid(tester), closeTo(12, 0.5));
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_gapUnderGrid(tester), closeTo(12, 0.5));
  });

  testWidgets('devrait garder le popover ouvert quand la fenêtre passe sous 600, puis ouvrir la feuille', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _phone(tester, size: const Size(1024, 768));
    final ctl = _Ctl()..value = DateTime(2026, 10, 14);
    await tester.pumpWidget(overlayApp(_controlled(ctl)));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(500, 768);
    await tester.pumpAndSettle();
    expect(find.byType(FlCalendarView), findsOneWidget);
    expect(tester.getSemantics(_trigger), isSemantics(isExpanded: true, hasExpandedState: true, isButton: true));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(find.byType(FlCalendarView), findsNothing);
    expect(tester.getSemantics(_trigger), isSemantics(isExpanded: false, hasExpandedState: true, isButton: true));
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(find.ancestor(of: find.byType(FlCalendarView), matching: find.byType(FlSheet)), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('devrait ne pas rendre le focus à un autre champ quand le calendrier, ouvert au doigt, se ferme', (
    tester,
  ) async {
    await _phone(tester);
    final other = FocusNode(debugLabel: 'autre champ');
    addTearDown(other.dispose);
    final ctl = _Ctl()..value = DateTime(2026, 10, 14);
    await tester.pumpWidget(
      overlayApp(
        _controlled(
          ctl,
          before: Focus(focusNode: other, child: const SizedBox(height: 40, width: 40)),
        ),
      ),
    );
    other.requestFocus();
    await tester.pump();
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    await tester.tap(_cell('20'));
    await tester.pumpAndSettle();
    expect(ctl.log, [DateTime(2026, 10, 20)]);
    expect(other.hasFocus, isFalse);
  });

  testWidgets('devrait écrire la date par format, remplir le champ en secondary et passer indicatorOf au calendrier', (
    tester,
  ) async {
    await _phone(tester);
    await tester.pumpWidget(
      overlayApp(
        Align(
          alignment: AlignmentDirectional.topCenter,
          child: SizedBox(
            width: 320,
            child: FlDatePicker(
              label: 'Échéance',
              placeholder: 'Choisir une date',
              barrierLabel: 'Fermer le calendrier',
              value: DateTime(2026, 10, 14),
              onChanged: (_) {},
              today: _today,
              strings: _fr,
              format: (date) => '${date.day}/${date.month}/${date.year}',
              variant: FlInputVariant.secondary,
              indicatorOf: (day) => day.day == 20 ? 'Réunion' : null,
            ),
          ),
        ),
      ),
    );
    expect(find.text('14/10/2026'), findsOneWidget);
    expect(tester.widget<FlInputFrame>(find.byType(FlInputFrame)).variant, FlInputVariant.secondary);
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
    expect(tester.widget<FlCalendar>(find.byType(FlCalendar)).indicatorOf!(DateTime(2026, 10, 20)), 'Réunion');
  });
}
