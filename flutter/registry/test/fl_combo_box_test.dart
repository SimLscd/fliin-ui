import 'dart:async';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/combo_box/fl_combo_box.dart';
import 'package:fliin_ui/components/list_row/fl_list_row.dart';
import 'package:fliin_ui/components/select/fl_select.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/overlay_app.dart';

const _cities = ['Paris', 'Pau', 'Lyon', 'Lille', 'Nantes', 'Nice', 'Marseille'];

List<FlSelectOption<String>> _filter(String query) => [
  for (final city in _cities)
    if (city.toLowerCase().contains(query.toLowerCase())) FlSelectOption(value: city, label: city),
];

/// Un combo-box de villes, une valeur tenue par l'hôte comme dans une app,
/// et un bouton au-dessus de lui où porter le focus : la liste s'ouvre
/// dessous.
class _Host extends StatefulWidget {
  const _Host({
    super.key,
    this.source = _filter,
    this.initial,
    this.allowsCustomValue = false,
    this.announce = true,
    this.enabled = true,
    this.changes,
    this.texts,
    this.trigger = true,
    this.controller,
    this.appliesNull = true,
  });

  final FlComboBoxSource<String> source;
  final FlSelectOption<String>? initial;
  final bool allowsCustomValue;
  final bool announce;
  final bool enabled;
  final List<String?>? changes;
  final List<String>? texts;
  final bool trigger;

  /// Un contrôleur fourni, que l'hôte écoute (un bouton « Effacer »).
  final TextEditingController? controller;

  /// Faux : l'hôte ignore le nul, comme avec un `DropdownButton`.
  final bool appliesNull;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late FlSelectOption<String>? value = widget.initial;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  /// L'app pose une valeur, sans passer par le champ.
  void pose(FlSelectOption<String> option) => setState(() => value = option);

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(supportsAnnounce: widget.announce),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlButton(label: 'Valider', onPressed: () {}),
          const SizedBox(height: 16),
          FlComboBox<String>(
            label: 'Ville',
            placeholder: 'Rechercher une ville',
            triggerLabel: widget.trigger ? 'Toutes les villes' : null,
            controller: widget.controller,
            suggestions: widget.source,
            value: value,
            allowsCustomValue: widget.allowsCustomValue,
            onChanged: widget.enabled
                ? (option) {
                    widget.changes?.add(option?.value);
                    if (option != null || widget.appliesNull) setState(() => value = option);
                  }
                : null,
            onTextChanged: (text) {
              widget.texts?.add(text);
              if (!widget.appliesNull) setState(() {});
            },
            countText: (count) => '$count suggestions',
            emptyText: 'Aucune ville',
            loadingText: 'Recherche…',
            errorText: 'La recherche a échoué',
          ),
        ],
      ),
    ),
  );
}

final _field = find.byType(EditableText);
Finder _row(String title) => find.widgetWithText(FlSelectOptionRow<String>, title);
List<String> _rows(WidgetTester tester) => [
  for (final row in tester.widgetList<FlSelectOptionRow<String>>(find.byType(FlSelectOptionRow<String>)))
    row.option.label,
];
String _text(WidgetTester tester) => tester.widget<EditableText>(_field).controller.text;
bool _fieldFocused(WidgetTester tester) => tester.widget<EditableText>(_field).focusNode.hasPrimaryFocus;

/// La suggestion désignée au clavier : celle dont l'anneau est visible.
String? _active(WidgetTester tester) {
  for (final ring in find.byType(FlFocusRing).evaluate()) {
    if (!(ring.widget as FlFocusRing).visible) continue;
    final row = find.descendant(of: find.byWidget(ring.widget), matching: find.byType(FlSelectOptionRow<String>));
    if (row.evaluate().isNotEmpty) return tester.widget<FlSelectOptionRow<String>>(row).option.label;
  }
  return null;
}

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

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_field, text);
  await tester.pumpAndSettle();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('devrait filtrer la liste à mesure qu’on tape', (tester) async {
    await tester.pumpWidget(overlayApp(const _Host()));
    await tester.tap(_field);
    await tester.pumpAndSettle();
    expect(_rows(tester), _cities);
    await _type(tester, 'pa');
    expect(_rows(tester), ['Paris', 'Pau']);
    await _type(tester, 'pari');
    expect(_rows(tester), ['Paris']);
  });

  testWidgets('devrait remplir le champ, rendre la valeur et fermer la liste quand on touche une suggestion', (
    tester,
  ) async {
    final changes = <String?>[];
    await tester.pumpWidget(overlayApp(_Host(changes: changes)));
    await tester.tap(_field);
    await _type(tester, 'ly');
    await tester.tap(_row('Lyon'));
    await tester.pumpAndSettle();
    expect(changes, ['Lyon']);
    expect(_text(tester), 'Lyon');
    expect(find.byType(FlSelectOptionRow<String>), findsNothing);
    expect(_fieldFocused(tester), isTrue);
  });

  testWidgets('devrait ignorer une réponse dépassée par une saisie plus récente, dans les deux ordres', (tester) async {
    final pending = <String, Completer<List<FlSelectOption<String>>>>{};
    await tester.pumpWidget(overlayApp(_Host(source: (query) => (pending[query] = Completer()).future)));
    await tester.tap(_field);
    await tester.pump();
    await tester.enterText(_field, 'n');
    await tester.pump();
    await tester.enterText(_field, 'na');
    await tester.pump();
    expect(find.text('Recherche…'), findsOneWidget);
    pending['na']!.complete(_filter('na'));
    await tester.pumpAndSettle();
    expect(_rows(tester), ['Nantes']);
    pending['n']!.complete(_filter('n'));
    await tester.pumpAndSettle();
    expect(_rows(tester), ['Nantes'], reason: 'la réponse à « n » arrive après celle à « na »');

    await tester.enterText(_field, 'par');
    await tester.pump();
    await tester.enterText(_field, 'pau');
    await tester.pump();
    pending['par']!.complete(_filter('par'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_rows(tester), isEmpty, reason: 'la réponse à « par » arrive pendant que « pau » se cherche');
    expect(find.text('Recherche…'), findsOneWidget);
    pending['pau']!.complete(_filter('pau'));
    await tester.pumpAndSettle();
    expect(_rows(tester), ['Pau']);
  });

  testWidgets('devrait dire l’absence de résultat, puis l’échec d’une recherche', (tester) async {
    await tester.pumpWidget(
      overlayApp(
        _Host(
          source: (query) async {
            if (query == 'zz') throw const FormatException('service indisponible');
            return _filter(query);
          },
        ),
      ),
    );
    await tester.tap(_field);
    await _type(tester, 'xyz');
    expect(find.text('Aucune ville'), findsOneWidget);
    await _type(tester, 'zz');
    expect(find.text('La recherche a échoué'), findsOneWidget);
    await _type(tester, 'ni');
    expect(_rows(tester), ['Nice']);
  });

  testWidgets('devrait garder le focus dans le champ, désigner au clavier et choisir par Entrée', (tester) async {
    final changes = <String?>[];
    await tester.pumpWidget(overlayApp(_Host(changes: changes)));
    await tester.tap(_field);
    await _type(tester, 'l');
    expect(_rows(tester), ['Lyon', 'Lille', 'Marseille']);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_active(tester), 'Lyon');
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_active(tester), 'Lille');
    expect(_fieldFocused(tester), isTrue);
    await _key(tester, LogicalKeyboardKey.arrowUp);
    await _key(tester, LogicalKeyboardKey.arrowUp);
    expect(_active(tester), 'Lyon', reason: 'la première reste désignée');
    await _key(tester, LogicalKeyboardKey.enter);
    expect(changes, ['Lyon']);
    expect(_text(tester), 'Lyon');
    expect(find.byType(FlSelectOptionRow<String>), findsNothing);
    expect(_fieldFocused(tester), isTrue);
  });

  testWidgets('devrait ouvrir la liste à la flèche du bas quand elle est fermée', (tester) async {
    await tester.pumpWidget(overlayApp(const _Host()));
    await tester.tap(_field);
    await _type(tester, 'ni');
    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.byType(FlSelectOptionRow<String>), findsNothing);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_rows(tester), ['Nice']);
  });

  testWidgets('devrait fermer la liste à Échap, puis effacer le champ et la valeur', (tester) async {
    final changes = <String?>[];
    await tester.pumpWidget(
      overlayApp(
        _Host(
          changes: changes,
          initial: const FlSelectOption(value: 'Nice', label: 'Nice'),
        ),
      ),
    );
    await tester.tap(_field);
    await tester.pumpAndSettle();
    expect(find.byType(FlSelectOptionRow<String>), findsWidgets);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.byType(FlSelectOptionRow<String>), findsNothing);
    expect(_text(tester), 'Nice');
    await _key(tester, LogicalKeyboardKey.escape);
    expect(_text(tester), isEmpty);
    expect(changes, [null]);
    expect(_fieldFocused(tester), isTrue);
  });

  testWidgets('devrait rendre nul dès que la saisie s’écarte du choix, sans attendre la perte du focus (e5a H1)', (
    tester,
  ) async {
    final changes = <String?>[];
    await tester.pumpWidget(
      overlayApp(
        _Host(
          changes: changes,
          initial: const FlSelectOption(value: 'Lyon', label: 'Lyon'),
        ),
        platform: TargetPlatform.iOS,
      ),
    );
    await tester.tap(_field);
    await _type(tester, 'Lyo');
    expect(changes, [null]);
    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(_fieldFocused(tester), isTrue, reason: 'sur iOS, un toucher ailleurs garde le focus');
    expect(_text(tester), 'Lyo');
    expect(changes, [null]);
  });

  testWidgets('devrait reprendre le libellé choisi quand le champ perd le focus, ou se vider sans choix', (
    tester,
  ) async {
    final texts = <String>[];
    await tester.pumpWidget(
      overlayApp(
        _Host(
          texts: texts,
          initial: const FlSelectOption(value: 'Nice', label: 'Nice'),
        ),
      ),
    );
    await tester.tap(_field);
    await _type(tester, 'Nic');
    await _type(tester, 'Nica');
    await _key(tester, LogicalKeyboardKey.tab);
    expect(_fieldFocused(tester), isFalse);
    expect(_text(tester), isEmpty, reason: 'la saisie « Nica » n’est pas un choix');
    expect(texts.last, isEmpty);
  });

  testWidgets('devrait garder un texte libre à la perte du focus quand allowsCustomValue est vrai', (tester) async {
    final changes = <String?>[];
    final texts = <String>[];
    await tester.pumpWidget(overlayApp(_Host(changes: changes, texts: texts, allowsCustomValue: true)));
    await tester.tap(_field);
    await _type(tester, 'Brest');
    await _key(tester, LogicalKeyboardKey.tab);
    expect(_text(tester), 'Brest');
    expect(texts.last, 'Brest');
    expect(changes, isEmpty);
  });

  testWidgets('devrait annoncer le nombre de résultats et la suggestion désignée', (tester) async {
    final announced = _announcements(tester);
    await tester.pumpWidget(overlayApp(const _Host()));
    await tester.tap(_field);
    await _type(tester, 'pa');
    expect(announced.last, '2 suggestions');
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(announced.last, 'Paris');
    await _type(tester, 'xyz');
    expect(announced.last, 'Aucune ville');
  });

  testWidgets('devrait nommer la liste par son état, région vivante, quand la plateforme n’annonce pas', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final announced = _announcements(tester);
    await tester.pumpWidget(overlayApp(const _Host(announce: false)));
    await tester.tap(_field);
    await _type(tester, 'pa');
    expect(announced, isEmpty);
    final status = find.bySemanticsLabel('2 suggestions');
    expect(status, findsOneWidget);
    expect(tester.getSemantics(status).getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });

  testWidgets('devrait ouvrir toute la liste par le chevron, nommé et déplié', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      overlayApp(
        const _Host(
          initial: FlSelectOption(value: 'Pau', label: 'Pau'),
        ),
      ),
    );
    final trigger = find.bySemanticsLabel('Toutes les villes');
    expect(tester.getSemantics(trigger).getSemanticsData().flagsCollection.isExpanded, Tristate.isFalse);
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(_rows(tester), _cities, reason: 'le champ dit le choix : la liste n’est pas filtrée par lui');
    expect(tester.getSemantics(trigger).getSemanticsData().flagsCollection.isExpanded, Tristate.isTrue);
    expect(_fieldFocused(tester), isTrue);
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(find.byType(FlSelectOptionRow<String>), findsNothing);
    semantics.dispose();
  });

  testWidgets('devrait se fermer au toucher dehors et se rouvrir à la saisie suivante', (tester) async {
    await tester.pumpWidget(overlayApp(const _Host()));
    await tester.tap(_field);
    await _type(tester, 'n');
    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(find.byType(FlSelectOptionRow<String>), findsNothing);
    await _type(tester, 'na');
    expect(_rows(tester), ['Nantes']);
  });

  testWidgets('devrait montrer le libellé d’une valeur posée par l’app', (tester) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(overlayApp(_Host(key: key)));
    key.currentState!.pose(const FlSelectOption(value: 'Nantes', label: 'Nantes'));
    await tester.pumpAndSettle();
    expect(_text(tester), 'Nantes');
  });

  testWidgets('devrait ne rien ouvrir ni rendre quand il est désactivé', (tester) async {
    await tester.pumpWidget(overlayApp(const _Host(enabled: false)));
    await tester.tap(_field);
    await tester.pumpAndSettle();
    expect(_fieldFocused(tester), isFalse);
    await tester.tap(find.byType(FlListRowChevron), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(FlSelectOptionRow<String>), findsNothing);
  });

  testWidgets('devrait garder la liste utilisable au-dessus du clavier, à 2,0 sur un petit écran', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.reset);
    final changes = <String?>[];
    await tester.pumpWidget(
      overlayApp(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(375, 667),
            viewInsets: EdgeInsets.only(bottom: 260),
            textScaler: TextScaler.linear(2),
          ),
          child: _Host(changes: changes),
        ),
        platform: TargetPlatform.iOS,
      ),
    );
    await tester.tap(_field);
    await tester.pumpAndSettle();
    final rows = find.byType(FlSelectOptionRow<String>);
    final keyboardTop = 667 - 260.0;
    final visible = [
      for (final element in rows.evaluate())
        if (tester.getRect(find.byWidget(element.widget)).bottom <= keyboardTop) element,
    ];
    expect(visible.length, greaterThanOrEqualTo(2), reason: 'deux suggestions entières au moins au-dessus du clavier');
    await tester.scrollUntilVisible(
      _row('Marseille'),
      80,
      scrollable: find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable)),
    );
    expect(tester.getRect(_row('Marseille')).bottom, lessThanOrEqualTo(keyboardTop));
    await tester.tap(_row('Marseille'));
    await tester.pumpAndSettle();
    expect(changes, ['Marseille']);
  });

  testWidgets('ne devrait ni ouvrir ni annoncer ni interroger au focus d’un champ vide sans chevron (relecture M1)', (
    tester,
  ) async {
    final announced = _announcements(tester);
    final asked = <String>[];
    await tester.pumpWidget(
      overlayApp(
        _Host(
          trigger: false,
          source: (query) async {
            asked.add(query);
            await Future<void>.delayed(const Duration(milliseconds: 500));
            return query.length < 2 ? const [] : _filter(query);
          },
        ),
        platform: TargetPlatform.iOS,
      ),
    );
    await tester.tap(_field);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Recherche…'), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    expect(asked, isEmpty);
    expect(announced, isEmpty);
  });

  testWidgets('ne devrait pas montrer l’attente d’une demande vide faite au focus, avec chevron (relecture M1)', (
    tester,
  ) async {
    final announced = _announcements(tester);
    await tester.pumpWidget(
      overlayApp(
        _Host(
          source: (query) async {
            await Future<void>.delayed(const Duration(milliseconds: 500));
            return query.isEmpty ? const [] : _filter(query);
          },
        ),
      ),
    );
    await tester.tap(_field);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Recherche…'), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(FlSelectOptionRow<String>), findsNothing);
    expect(announced, isEmpty);
  });

  testWidgets(
    'ne devrait pas faire échouer le framework quand l’app écoute le contrôleur qu’elle fournit (relecture M2)',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final texts = <String>[];
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(
        overlayApp(
          _Host(
            key: key,
            controller: controller,
            texts: texts,
            initial: const FlSelectOption(value: 'Pau', label: 'Pau'),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(controller.text, 'Pau');
      key.currentState!.pose(const FlSelectOption(value: 'Nice', label: 'Nice'));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(controller.text, 'Nice');
      expect(texts, ['Nice']);
    },
  );

  testWidgets('devrait choisir la suggestion désignée à Tab, puis laisser le focus avancer (relecture B1)', (
    tester,
  ) async {
    final changes = <String?>[];
    await tester.pumpWidget(overlayApp(_Host(changes: changes)));
    await tester.tap(_field);
    await _type(tester, 'ly');
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.tab);
    expect(changes, ['Lyon']);
    expect(_text(tester), 'Lyon');
    expect(_fieldFocused(tester), isFalse);
  });

  testWidgets('devrait garder la saisie quand l’app ignore le nul (relecture B2)', (tester) async {
    final changes = <String?>[];
    await tester.pumpWidget(
      overlayApp(
        _Host(
          changes: changes,
          appliesNull: false,
          initial: const FlSelectOption(value: 'Lyon', label: 'Lyon'),
        ),
      ),
    );
    await tester.tap(_field);
    await _type(tester, 'Lyo');
    expect(changes, [null]);
    expect(_text(tester), 'Lyo');
  });

  testWidgets('ne devrait interroger la source qu’une fois quand le chevron ouvre un champ sans focus (relecture B3)', (
    tester,
  ) async {
    final asked = <String>[];
    await tester.pumpWidget(
      overlayApp(
        _Host(
          source: (query) {
            asked.add(query);
            return _filter(query);
          },
        ),
      ),
    );
    await tester.tap(find.byType(FlListRowChevron));
    await tester.pumpAndSettle();
    expect(_rows(tester), _cities);
    expect(asked, ['']);
  });

  testWidgets('devrait dire l’échec, et non attendre à vie, quand la source lève une Error (relecture B4)', (
    tester,
  ) async {
    await tester.pumpWidget(
      overlayApp(_Host(source: (query) async => query == 'zz' ? throw StateError('défaut') : _filter(query))),
    );
    await tester.tap(_field);
    await tester.enterText(_field, 'zz');
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isA<StateError>());
    await tester.pumpAndSettle();
    expect(find.text('La recherche a échoué'), findsOneWidget);
    expect(find.text('Recherche…'), findsNothing);
  });

  testWidgets('devrait rechoisir quand on retape exactement le libellé choisi (relecture B5)', (tester) async {
    final changes = <String?>[];
    await tester.pumpWidget(
      overlayApp(
        _Host(
          changes: changes,
          initial: const FlSelectOption(value: 'Nice', label: 'Nice'),
        ),
      ),
    );
    await tester.tap(_field);
    await _type(tester, 'Nic');
    await _type(tester, 'Nice');
    expect(changes, [null, 'Nice']);
    await _key(tester, LogicalKeyboardKey.tab);
    expect(_text(tester), 'Nice');
  });

  testWidgets('devrait rouvrir la liste quand on touche le champ qui a déjà le focus (relecture B6)', (tester) async {
    await tester.pumpWidget(overlayApp(const _Host(), platform: TargetPlatform.iOS));
    await tester.tap(_field);
    await _type(tester, 'ly');
    await tester.tap(_row('Lyon'));
    await tester.pumpAndSettle();
    expect(find.byType(FlSelectOptionRow<String>), findsNothing);
    expect(_fieldFocused(tester), isTrue);
    await tester.tap(_field);
    await tester.pumpAndSettle();
    expect(_rows(tester), _cities);
  });

  testWidgets('devrait dire la suggestion choisie sélectionnée au lecteur d’écran (relecture B8)', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      overlayApp(
        const _Host(
          initial: FlSelectOption(value: 'Pau', label: 'Pau'),
        ),
      ),
    );
    await tester.tap(find.byType(FlListRowChevron));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(_row('Pau')).getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
    expect(tester.getSemantics(_row('Lyon')).getSemanticsData().flagsCollection.isSelected, isNot(Tristate.isTrue));
    final pau = tester.getSemantics(_row('Pau')).getSemanticsData();
    expect(pau.label, 'Pau');
    expect(pau.hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets(
    'devrait filtrer les options données sans casse, et toutes les montrer au chevron, quand il est filtering',
    (tester) async {
      final semantics = tester.ensureSemantics();
      FlSelectOption<String>? chosen;
      await tester.pumpWidget(
        overlayApp(
          Padding(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setState) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FlComboBox<String>.filtering(
                    label: 'Ville',
                    triggerLabel: 'Toutes les villes',
                    options: [for (final city in _cities) FlSelectOption(value: city, label: city)],
                    value: chosen,
                    onChanged: (option) => setState(() => chosen = option),
                    countText: (count) => '$count suggestions',
                    emptyText: 'Aucune ville',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(_field);
      await tester.enterText(_field, 'LI');
      await tester.pumpAndSettle();
      expect(_rows(tester), ['Lille']);
      await tester.enterText(_field, 'zz');
      await tester.pumpAndSettle();
      expect(_rows(tester), isEmpty);
      expect(find.text('Aucune ville'), findsOneWidget);
      await tester.enterText(_field, 'p');
      await tester.pumpAndSettle();
      expect(_rows(tester), ['Paris', 'Pau']);
      await tester.tap(_row('Pau'));
      await tester.pumpAndSettle();
      expect(chosen?.value, 'Pau');
      await tester.tap(find.bySemanticsLabel('Toutes les villes'));
      await tester.pumpAndSettle();
      expect(_rows(tester), _cities);
      semantics.dispose();
    },
  );
}
