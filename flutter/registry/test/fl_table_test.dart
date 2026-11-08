import 'dart:ui' show CheckedState;

import 'package:fliin_ui/components/checkbox/fl_checkbox.dart';
import 'package:fliin_ui/components/spinner/fl_spinner.dart';
import 'package:fliin_ui/components/table/fl_table.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

typedef _Person = ({String name, String role, String email});

const _people = <_Person>[
  (name: 'Kate Moore', role: 'PDG', email: 'kate@acme.com'),
  (name: 'John Smith', role: 'CTO', email: 'john@acme.com'),
  (name: 'Sara Johnson', role: 'CMO', email: 'sara@acme.com'),
];

const _labels = FlTableLabels(
  ascending: 'Croissant',
  descending: 'Décroissant',
  selectAll: 'Tout sélectionner',
  loading: 'Chargement',
  empty: 'Aucun résultat',
);

final _columns = [
  FlTableColumn<_Person>(id: 'name', label: 'Nom', text: (p) => p.name, width: 140, sortable: true),
  FlTableColumn<_Person>(id: 'role', label: 'Rôle', text: (p) => p.role, width: 100, sortable: true),
  FlTableColumn<_Person>(id: 'email', label: 'E-mail', text: (p) => p.email, width: 180),
];

/// Un tableau trié et sélectionnable que le parent tient à jour.
class _Host extends StatefulWidget {
  const _Host({this.width = 360, this.layout = FlTableLayout.scroll, this.rows = _people, this.loading = false});

  final double width;
  final FlTableLayout layout;
  final List<_Person> rows;
  final bool loading;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  FlTableSort? sort;
  Set<Object> selected = {};

  @override
  Widget build(BuildContext context) {
    final rows = [...widget.rows];
    if (sort case final sort?) {
      final column = _columns.firstWhere((c) => c.id == sort.column);
      rows.sort((a, b) => column.text(a).compareTo(column.text(b)));
      if (sort.direction == FlSortDirection.descending) rows.setAll(0, rows.reversed.toList());
    }
    return SizedBox(
      width: widget.width,
      child: FlTable<_Person>(
        label: 'Équipe',
        columns: _columns,
        rows: rows,
        rowKey: (p) => p.email,
        labels: _labels,
        layout: widget.layout,
        sort: sort,
        onSortChanged: (next) => setState(() => sort = next),
        selected: selected,
        onSelectionChanged: (next) => setState(() => selected = next),
        loading: widget.loading,
      ),
    );
  }
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

void main() {
  testWidgets('devrait trier par la colonne touchée, puis dans l’autre sens au second toucher', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.tap(find.text('Rôle'));
    await tester.pump();
    expect(_host(tester).sort, (column: 'role', direction: FlSortDirection.ascending));
    expect(tester.getTopLeft(find.text('CMO')).dy, lessThan(tester.getTopLeft(find.text('PDG')).dy));
    await tester.tap(find.text('Rôle'));
    await tester.pumpAndSettle();
    expect(_host(tester).sort, (column: 'role', direction: FlSortDirection.descending));
    expect(tester.getTopLeft(find.text('PDG')).dy, lessThan(tester.getTopLeft(find.text('CMO')).dy));
  });

  testWidgets('devrait sélectionner une ligne au toucher, puis toutes par la case de l’en-tête, mixte entre les deux', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.tap(find.text('CTO'));
    await tester.pump();
    expect(_host(tester).selected, {'john@acme.com'});
    final all = tester.widget<FlCheckbox>(find.byType(FlCheckbox).first);
    expect(all.value, isNull);
    await tester.tap(find.byType(FlCheckbox).first);
    await tester.pump();
    expect(_host(tester).selected, {'kate@acme.com', 'john@acme.com', 'sara@acme.com'});
    await tester.tap(find.byType(FlCheckbox).first);
    await tester.pump();
    expect(_host(tester).selected, isEmpty);
  });

  testWidgets('devrait garder la première colonne et les cases au début quand le reste défile de côté', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final name = tester.getTopLeft(find.text('Kate Moore'));
    final email = tester.getTopLeft(find.text('kate@acme.com'));
    await tester.drag(find.text('PDG'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Kate Moore')), name);
    expect(tester.getTopLeft(find.text('kate@acme.com')).dx, lessThan(email.dx - 60));
  });

  testWidgets('devrait garder la première colonne à droite en arabe', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(), direction: TextDirection.rtl));
    final name = tester.getTopRight(find.text('Kate Moore'));
    expect(name.dx, greaterThan(tester.getTopRight(find.text('PDG')).dx));
    await tester.drag(find.text('PDG'), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopRight(find.text('Kate Moore')), name);
  });

  testWidgets('devrait empiler chaque ligne quand les colonnes ne tiennent pas, en mode adaptatif', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(layout: FlTableLayout.adaptive)));
    expect(find.text('Rôle'), findsNWidgets(3), reason: 'le nom de colonne devant chaque valeur');
    expect(tester.getTopLeft(find.text('PDG')).dy, greaterThan(tester.getTopLeft(find.text('Kate Moore')).dy));
    await tester.pumpWidget(toggleApp(const _Host(layout: FlTableLayout.adaptive, width: 700)));
    expect(find.text('Rôle'), findsOneWidget);
  });

  testWidgets('devrait annoncer un tableau, ses lignes, ses en-têtes de colonne et leur tri', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host(width: 700)));
    await tester.tap(find.text('Nom'));
    await tester.pump();
    final table = tester.getSemantics(find.bySemanticsLabel('Équipe'));
    expect(table.role, SemanticsRole.table);
    final header = tester.getSemantics(find.bySemanticsLabel('Nom'));
    expect(header.role, SemanticsRole.columnHeader);
    expect(header.value, 'Croissant');
    expect(header.flagsCollection.isButton, isTrue);
    final cell = tester.getSemantics(find.bySemanticsLabel('john@acme.com'));
    expect(cell.role, SemanticsRole.cell);
    expect(
      tester.getSemantics(find.bySemanticsLabel('John Smith').last).flagsCollection.isChecked,
      isNot(CheckedState.none),
    );
    expect(tester.takeException(), isNull, reason: 'les rôles de tableau sont valides');
    semantics.dispose();
  });

  testWidgets('devrait montrer le texte vide sans lignes, et un indicateur en chargement', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(rows: [])));
    expect(find.text('Aucun résultat'), findsOneWidget);
    expect(tester.widget<FlCheckbox>(find.byType(FlCheckbox)).onChanged, isNull);
    await tester.pumpWidget(toggleApp(const _Host(loading: true)));
    expect(find.byType(FlSpinner), findsOneWidget);
    expect(find.text('Aucun résultat'), findsNothing);
  });

  testWidgets('devrait ouvrir la ligne touchée par onRowPressed, la case seule changeant la sélection', (tester) async {
    for (final layout in [FlTableLayout.scroll, FlTableLayout.stacked]) {
      final opened = <String>[];
      var selected = <Object>{};
      await tester.pumpWidget(
        toggleApp(
          StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 360,
              child: FlTable<_Person>(
                label: 'Équipe',
                columns: _columns,
                rows: _people,
                rowKey: (p) => p.email,
                labels: _labels,
                layout: layout,
                selected: selected,
                onSelectionChanged: (next) => setState(() => selected = next),
                onRowPressed: (p) => opened.add(p.name),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('CTO'));
      await tester.pump();
      expect(opened, ['John Smith'], reason: layout.name);
      expect(selected, isEmpty, reason: layout.name);
      await tester.tap(find.byWidgetPredicate((w) => w is FlCheckbox && w.label == 'John Smith'));
      await tester.pump();
      expect(selected, {'john@acme.com'}, reason: layout.name);
      expect(opened, ['John Smith'], reason: layout.name);
    }
  });

  testWidgets(
    'devrait faire de chaque ligne une cible tactile que le lecteur d’écran active quand onRowPressed est donné',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final opened = <String>[];
      await tester.pumpWidget(
        toggleApp(
          SizedBox(
            width: 360,
            child: FlTable<_Person>(
              label: 'Équipe',
              columns: _columns,
              rows: _people,
              rowKey: (p) => p.email,
              labels: _labels,
              onRowPressed: (p) => opened.add(p.name),
            ),
          ),
        ),
      );
      final row = find.ancestor(
        of: find.text('CTO'),
        matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.role == SemanticsRole.row),
      );
      expect(tester.getSize(row.first).height, greaterThanOrEqualTo(48));
      final node = tester.getSemantics(row.first);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      expect(opened, ['John Smith']);
      semantics.dispose();
    },
  );

  testWidgets('devrait poser emptyState à la place du texte vide quand il n’y a pas de ligne', (tester) async {
    await tester.pumpWidget(
      toggleApp(
        SizedBox(
          width: 360,
          child: FlTable<_Person>(
            label: 'Équipe',
            columns: _columns,
            rows: const [],
            rowKey: (p) => p.email,
            labels: _labels,
            emptyState: const Text('Invitez votre équipe'),
          ),
        ),
      ),
    );
    expect(find.text('Invitez votre équipe'), findsOneWidget);
    expect(find.text('Aucun résultat'), findsNothing);
  });
}
