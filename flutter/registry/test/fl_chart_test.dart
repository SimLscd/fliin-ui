import 'package:fliin_ui/components/chart/fl_chart.dart';
import 'package:fliin_ui/core/fliin.dart';

import 'dart:ui' show Paragraph;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/system_fonts.dart';
import 'torture/themes.dart';

const _days = [
  FlChartPoint('L', semanticLabel: 'lundi'),
  FlChartPoint('M', semanticLabel: 'mardi'),
  FlChartPoint('M', semanticLabel: 'mercredi'),
  FlChartPoint('J', semanticLabel: 'jeudi'),
  FlChartPoint('V', semanticLabel: 'vendredi'),
];
const _spent = FlChartSeries(label: 'Dépenses', values: [10, 20, 30, 84, 40]);
const _before = FlChartSeries(label: 'Avant', values: [15, 25, 35, 60, 45]);

String _euros(double v) => '${v.round()} €';

Widget _app(
  Widget child, {
  TextDirection dir = TextDirection.ltr,
  double scale = 1,
  bool reduceMotion = false,
  double width = 300,
}) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(scale), disableAnimations: reduceMotion),
  child: FlScope(
    platform: TargetPlatform.iOS,
    brightness: Brightness.light,
    child: Directionality(
      textDirection: dir,
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

FlChart _bar({
  int? selected,
  List<FlChartSeries> series = const [_spent],
  List<FlChartPoint> points = _days,
  bool axis = false,
}) => FlChart.bar(
  points: points,
  series: series,
  formatValue: _euros,
  semanticLabel: 'Dépenses de la semaine',
  summary: 'plus forte le jeudi, 84 €',
  initialSelection: selected,
  showValueAxis: axis,
);

/// Les rectangles des points dans l'arbre de sémantique, dans l'ordre des
/// points.
List<SemanticsNode> _pointNodes(WidgetTester tester) {
  final nodes = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    if (node.getSemanticsData().value.isNotEmpty) nodes.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(find.bySemanticsLabel('Dépenses de la semaine, plus forte le jeudi, 84 €')));
  return nodes;
}

Rect _global(WidgetTester tester, SemanticsNode node) {
  final box = tester.renderObject<RenderBox>(find.byType(CustomPaint).first);
  return MatrixUtils.transformRect(box.getTransformTo(null), node.rect);
}

void main() {
  testWidgets('devrait lire le résumé puis chaque point, son libellé entier et sa valeur, quand on explore', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_bar()));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Dépenses de la semaine, plus forte le jeudi, 84 €'), findsOneWidget);
    final points = _pointNodes(tester);
    expect([for (final p in points) p.label], ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi']);
    expect(points[3].value, '84 €');
    handle.dispose();
  });

  testWidgets('devrait lire les deux valeurs nommées d\'un point quand le graphique a deux séries', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_bar(series: const [_spent, _before])));
    await tester.pumpAndSettle();
    expect(_pointNodes(tester)[3].value, 'Dépenses 84 €, Avant 60 €');
    expect(find.text('Avant'), findsOneWidget, reason: 'la légende nomme la seconde série');
    handle.dispose();
  });

  testWidgets('devrait poser le premier point à droite quand la page est en RTL', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_bar(), dir: TextDirection.rtl));
    await tester.pumpAndSettle();
    final points = _pointNodes(tester);
    expect(_global(tester, points.first).center.dx, greaterThan(_global(tester, points.last).center.dx));
    handle.dispose();
  });

  testWidgets('devrait ouvrir la bulle du point touché, la déplacer au glisser et la fermer au second toucher', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_bar()));
    await tester.pumpAndSettle();
    expect(find.textContaining('84 €'), findsNothing);
    final chart = tester.getRect(find.byType(CustomPaint).first);
    final slot = chart.width;
    // La case de jeudi, quatrième des cinq, dans la partie du tracé.
    final thursday = Offset(chart.right - slot * 0.05 - (chart.right - chart.left) * 0.2, chart.center.dy);
    await tester.tapAt(thursday);
    await tester.pump();
    expect(find.textContaining('jeudi'), findsOneWidget);
    expect(find.textContaining('84 €'), findsOneWidget);

    final drag = await tester.startGesture(thursday);
    await drag.moveBy(const Offset(40, 0));
    await drag.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(find.textContaining('vendredi'), findsOneWidget);
    await drag.up();
    await tester.pump();

    await tester.tapAt(Offset(chart.right - 4, chart.center.dy));
    await tester.pump();
    expect(find.textContaining('vendredi'), findsNothing);
  });

  testWidgets('devrait passer d\'un point à l\'autre aux flèches dans le sens de lecture, Début, Fin et Échap', (
    tester,
  ) async {
    for (final dir in TextDirection.values) {
      await tester.pumpWidget(_app(_bar(), dir: dir));
      await tester.pumpAndSettle();
      Focus.of(tester.element(find.byType(CustomPaint).first)).requestFocus();
      await tester.pump();
      final forward = dir == TextDirection.ltr ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft;
      final back = dir == TextDirection.ltr ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight;
      await tester.sendKeyEvent(forward);
      await tester.pump();
      expect(find.textContaining('lundi'), findsOneWidget, reason: '$dir');
      await tester.sendKeyEvent(forward);
      await tester.pump();
      expect(find.textContaining('mardi'), findsOneWidget, reason: '$dir');
      await tester.sendKeyEvent(back);
      await tester.pump();
      expect(find.textContaining('lundi'), findsOneWidget, reason: '$dir');
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(find.textContaining('vendredi'), findsOneWidget, reason: '$dir');
      expect(await tester.sendKeyEvent(forward), isFalse, reason: 'au dernier point, la flèche remonte à la page');
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(find.textContaining('lundi'), findsOneWidget, reason: '$dir');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.textContaining('lundi'), findsNothing, reason: '$dir');
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.escape), isFalse, reason: 'sans bulle, Échap remonte');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('devrait monter de la ligne de base à l\'apparition, et se poser d\'un coup en mouvement réduit', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_bar()));
    await tester.pump(const Duration(milliseconds: 16));
    final rising = _bars(tester);
    await tester.pumpAndSettle();
    final settled = _bars(tester);
    expect(rising.first.height, lessThan(settled.first.height));
    final perEuro = settled[3].height / 84;
    expect(settled.map((r) => r.height / perEuro), [for (final v in _spent.values) closeTo(v, 0.01)]);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(_bar(), reduceMotion: true));
    expect(tester.hasRunningAnimations, isFalse, reason: 'aucune animation d\'entrée');
    expect(_bars(tester).map((r) => r.height), settled.map((r) => r.height));
  });

  testWidgets('devrait borner la largeur des barres, centrées sur leur point, et teindre les autres de restColor', (
    tester,
  ) async {
    const ink = Color(0xFF111111);
    const rest = Color(0xFFE9E9E9);
    await tester.pumpWidget(
      _app(
        FlChart.bar(
          points: _days,
          series: const [
            FlChartSeries(label: 'Dépenses', values: [10, 20, 30, 84, 40], color: ink),
          ],
          formatValue: _euros,
          semanticLabel: 'Dépenses de la semaine',
          highlight: 3,
          maxBarWidth: 24,
          restColor: rest,
        ),
        width: 600,
      ),
    );
    await tester.pumpAndSettle();
    final bars = _bars(tester);
    expect(bars.map((r) => r.width), everyElement(24));
    // 600 split into five slots of 120: each bar sits in the middle of its own.
    expect(bars.map((r) => r.center.dx), [for (var i = 0; i < 5; i++) closeTo(60 + i * 120, 0.01)]);
    final colors = [
      for (final call in _painted(tester))
        if (call.memberName == #drawRRect) (call.positionalArguments[1] as Paint).color.toARGB32(),
    ];
    expect(colors, [
      for (final c in [rest, rest, rest, ink, rest]) c.toARGB32(),
    ]);
  });

  testWidgets('devrait sauter des libellés de l\'axe du temps à 2,0 plutôt que de les chevaucher', (tester) async {
    final month = [for (var d = 1; d <= 30; d++) FlChartPoint('$d', semanticLabel: '$d octobre')];
    final values = FlChartSeries(label: 'Dépenses', values: [for (var d = 1; d <= 30; d++) d.toDouble()]);
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        _app(
          _bar(points: month, series: [values]),
          scale: scale,
          width: 340,
        ),
      );
      await tester.pumpAndSettle();
      final recorder = _Labels(tester);
      expect(recorder.overlaps, isEmpty, reason: 'à $scale');
      expect(recorder.count, lessThan(30), reason: 'à $scale, 30 libellés ne tiennent pas dans 340');
      expect(recorder.count, greaterThan(1), reason: 'à $scale');
    }
  });

  testWidgets(
    'devrait donner un tableau au lecteur d\'écran : en-têtes, une rangée par point, une cellule par valeur',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const FlChartTable(points: _days, series: [_spent, _before], formatValue: _euros, pointsLabel: 'Jour')),
      );
      final table = tester.getSemantics(find.byType(FlChartTable));
      expect(table.role, SemanticsRole.table);
      final rows = <SemanticsNode>[];
      table.visitChildren((row) {
        rows.add(row);
        return true;
      });
      expect(rows, hasLength(6));
      expect(rows.every((row) => row.role == SemanticsRole.row), isTrue);
      List<(SemanticsRole, String)> cells(SemanticsNode row) {
        final out = <(SemanticsRole, String)>[];
        row.visitChildren((cell) {
          out.add((cell.role, cell.label));
          return true;
        });
        return out;
      }

      expect(cells(rows.first), [
        (SemanticsRole.columnHeader, 'Jour'),
        (SemanticsRole.columnHeader, 'Dépenses'),
        (SemanticsRole.columnHeader, 'Avant'),
      ]);
      expect(cells(rows[4]), [
        (SemanticsRole.cell, 'jeudi'),
        (SemanticsRole.cell, '84 €'),
        (SemanticsRole.cell, '60 €'),
      ]);
      handle.dispose();
    },
  );

  test('devrait garder les marques à 3:1 au moins sur le fond, sous chaque thème de test, en clair et en sombre', () {
    double ratio(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
    }

    final measured = <String, double>{};
    for (final theme in [
      (id: 'default', tokens: FlTokens.defaults),
      for (final t in flTestThemes) (id: t.id, tokens: t.tokens),
    ]) {
      for (final (mode, colors) in [('light', theme.tokens.light), ('dark', theme.tokens.dark)]) {
        for (final (mark, color) in [('selected', colors.selected), ('onSurfaceMuted', colors.onSurfaceMuted)]) {
          for (final (ground, background) in [('surface', colors.surface), ('surfaceRaised', colors.surfaceRaised)]) {
            measured['${theme.id} $mode $mark/$ground'] = ratio(color, background);
          }
        }
      }
    }
    expect({
      for (final e in measured.entries)
        if (e.value < 3) e.key: e.value,
    }, isEmpty);
  });

  for (final font in SystemFont.values) {
    for (final (name, points, series, selected, text) in [
      (
        'un libellé sur deux lignes',
        const [
          FlChartPoint('M', semanticLabel: 'Monday, September 28'),
          FlChartPoint('T', semanticLabel: 'Tuesday, September 29'),
          FlChartPoint('W', semanticLabel: 'Wednesday, September 30'),
        ],
        const [
          FlChartSeries(label: 'Spending', values: [32, 18, 84]),
        ],
        2,
        'Wednesday, September 30',
      ),
      (
        'deux séries',
        _days,
        const [
          _spent,
          FlChartSeries(label: 'Semaine précédente', values: [15, 25, 35, 52, 45]),
        ],
        3,
        'jeudi',
      ),
    ]) {
      testWidgets(
        'devrait donner à la bulle la hauteur de son texte à 2,0 sur 311 de large, $name, sous ${font.name}',
        (tester) async {
          if (!await font.load()) return markTestSkipped('${font.name} absente de cette machine');
          Widget chart({int? at}) => _app(
            DefaultTextStyle(
              style: TextStyle(fontFamily: font.family),
              child: FlChart.bar(
                key: ValueKey(at),
                points: points,
                series: series,
                formatValue: (v) => '€${v.toStringAsFixed(2)}',
                semanticLabel: 'Spending',
                initialSelection: at,
              ),
            ),
            scale: 2,
            width: 311,
          );
          await tester.pumpWidget(chart());
          await tester.pumpAndSettle();
          final closed = tester.getSize(find.byType(CustomPaint).first);
          await tester.pumpWidget(chart(at: selected));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(tester.getSize(find.byType(CustomPaint).first), closed, reason: 'le tracé ne bouge pas');
          final paragraph = tester.renderObject<RenderParagraph>(find.textContaining(text, findRichText: true));
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01),
            reason: 'la bulle coupe son texte',
          );
        },
      );
    }
  }

  testWidgets('devrait poser les graduations sur des multiples de axisUnit, que le format écrit juste', (tester) async {
    Future<List<double>> ticks({double? unit}) async {
      final seen = <double>[];
      await tester.pumpWidget(
        _app(
          FlChart.bar(
            key: UniqueKey(),
            points: _days,
            series: const [
              FlChartSeries(label: 'Dépenses', values: [8.9, 0, 0, 0, 0]),
            ],
            formatValue: _euros,
            formatAxis: (v) {
              seen.add(v);
              return _euros(v);
            },
            axisUnit: unit,
            semanticLabel: 'Dépenses',
          ),
        ),
      );
      return seen;
    }

    expect(await ticks(), contains(2.5), reason: 'sans unité, un pas de 2,5');
    final whole = await ticks(unit: 1);
    expect(whole, isNotEmpty);
    expect(whole.every((v) => v == v.roundToDouble()), isTrue, reason: '$whole');
    expect(whole.last, greaterThanOrEqualTo(8.9));
  });

  for (final type in FlChartType.values) {
    testWidgets('devrait traiter une valeur NaN, infinie ou absente comme un trou, en ${type.name}', (tester) async {
      final handle = tester.ensureSemantics();
      final series = FlChartSeries(label: 'Dépenses', values: [10, double.nan, 30, double.infinity]);
      FlChart chart() => type == FlChartType.bar
          ? FlChart.bar(
              points: _days,
              series: [series],
              formatValue: _euros,
              semanticLabel: 'Dépenses',
              initialSelection: 1,
            )
          : FlChart.line(
              points: _days,
              series: [series],
              formatValue: _euros,
              semanticLabel: 'Dépenses',
              initialSelection: 1,
            );
      await tester.pumpWidget(_app(chart()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('—', findRichText: true), findsOneWidget, reason: 'la bulle du point NaN');
      final values = <String>[];
      void visit(SemanticsNode node) {
        if (node.getSemanticsData().value.isNotEmpty) values.add(node.getSemanticsData().value);
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(tester.getSemantics(find.bySemanticsLabel('Dépenses')));
      expect(values, ['10 €', '—', '30 €', '—', '—'], reason: 'le cinquième point manque à la série');
      if (type == FlChartType.bar) expect(_bars(tester), hasLength(2));
      handle.dispose();
    });
  }

  testWidgets('devrait ne rien ouvrir pour une sélection de départ hors des points', (tester) async {
    await tester.pumpWidget(_app(_bar(selected: 9)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('€', findRichText: true), findsNothing);
  });

  testWidgets('devrait écrire « — » dans le tableau pour une valeur manquante', (tester) async {
    await tester.pumpWidget(
      _app(
        FlChartTable(
          points: _days,
          series: [
            FlChartSeries(label: 'Dépenses', values: [10, double.nan]),
          ],
          formatValue: _euros,
          pointsLabel: 'Jour',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('—'), findsNWidgets(4));
  });

  testWidgets('devrait taire l’axe des valeurs par défaut, comme le canvas', (tester) async {
    await tester.pumpWidget(_app(_bar()));
    await tester.pumpAndSettle();
    final row = _Labels(tester);
    final ticks = [
      for (final call in _painted(tester))
        if (call.memberName == #drawParagraph && (call.positionalArguments[1] as Offset).dy != row.top) call,
    ];
    expect(ticks, isEmpty);
  });

  testWidgets('devrait aligner les graduations contre le tracé en RTL, comme en LTR', (tester) async {
    for (final dir in TextDirection.values) {
      await tester.pumpWidget(_app(_bar(axis: true), dir: dir));
      await tester.pumpAndSettle();
      final row = _Labels(tester);
      final ticks = [
        for (final call in _painted(tester))
          if (call.memberName == #drawParagraph)
            (call.positionalArguments[1] as Offset) & Size((call.positionalArguments[0] as Paragraph).longestLine, 1),
      ].where((r) => r.top != row.top).toList();
      expect(ticks.length, greaterThan(1));
      final edges = dir == TextDirection.ltr ? ticks.map((r) => r.right) : ticks.map((r) => r.left);
      expect(edges.toSet(), hasLength(1), reason: '$dir : $ticks');
      expect(ticks.map((r) => r.width).toSet().length, greaterThan(1), reason: 'des libellés de largeurs différentes');
    }
  });

  testWidgets('devrait garder sa géométrie quand seul le point choisi change', (tester) async {
    var measured = 0;
    await tester.pumpWidget(
      _app(
        FlChart.bar(
          points: _days,
          series: const [_spent],
          formatValue: _euros,
          formatAxis: (v) {
            measured++;
            return _euros(v);
          },
          semanticLabel: 'Dépenses',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = measured;
    final chart = tester.getRect(find.byType(CustomPaint).first);
    final drag = await tester.startGesture(Offset(chart.right - 8, chart.center.dy));
    for (var i = 0; i < 6; i++) {
      await drag.moveBy(const Offset(-30, 0));
      await tester.pump();
    }
    await drag.up();
    await tester.pump();
    expect(find.textContaining('€', findRichText: true), findsOneWidget, reason: 'une bulle ouverte');
    expect(measured, before);
  });

  testWidgets('devrait écrire la valeur seule dans la bulle avec tooltipLabel faux, centrée', (tester) async {
    await tester.pumpWidget(
      _app(
        FlChart.bar(
          points: _days,
          series: [_spent],
          formatValue: _euros,
          semanticLabel: 'Dépenses de la semaine',
          initialSelection: 3,
          tooltipLabel: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bubble = find.textContaining('84 €', findRichText: true);
    expect(bubble, findsOneWidget);
    final text = tester.widget<RichText>(bubble);
    expect(text.text.toPlainText(), '84 €', reason: 'sans « jeudi » dessous');
    expect(text.textAlign, TextAlign.center);
  });

  FlChart sparkline({bool area = true, bool zeroBased = false}) => FlChart.line(
    points: _days,
    series: const [
      FlChartSeries(label: 'Solde', values: [1500, 1550, 1520, 1610, 1700]),
    ],
    formatValue: _euros,
    semanticLabel: 'Solde',
    plotHeight: 48,
    showTimeAxis: false,
    tooltip: false,
    area: area,
    zeroBased: zeroBased,
  );

  testWidgets('devrait tenir dans la hauteur du tracé quand ni l’axe du temps ni la bulle ne sont montrés', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(sparkline()));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(CustomPaint).first).height, 48);
    expect(find.byType(Text), findsNothing, reason: 'aucun libellé ni bulle');
    final chart = tester.getRect(find.byType(CustomPaint).first);
    await tester.tapAt(chart.center);
    await tester.pump();
    expect(find.textContaining('€', findRichText: true), findsNothing, reason: 'pas de bulle');
    expect(
      find.semantics.byPredicate((node) => node.label == 'jeudi' && node.value == '1610 €'),
      findsOneWidget,
      reason: 'le lecteur d’écran lit toujours chaque point',
    );
    handle.dispose();
  });

  testWidgets('devrait étirer une ligne non ancrée à zéro de sa plus petite à sa plus grande valeur', (tester) async {
    await tester.pumpWidget(_app(sparkline(area: false)));
    await tester.pumpAndSettle();
    final path = _painted(tester).firstWhere((call) => call.memberName == #drawPath).positionalArguments.first as Path;
    final bounds = path.getBounds();
    expect(bounds.top, closeTo(0, 0.01), reason: 'la plus grande valeur en haut du tracé');
    expect(bounds.bottom, closeTo(48, 0.01), reason: 'la plus petite en bas');
  });

  testWidgets('devrait remplir sous la ligne d’un dégradé quand area est vrai, et pas sinon', (tester) async {
    int shaded(WidgetTester tester) => [
      for (final call in _painted(tester))
        if (call.memberName == #drawPath && (call.positionalArguments[1] as Paint).shader != null) call,
    ].length;
    await tester.pumpWidget(_app(sparkline()));
    await tester.pumpAndSettle();
    expect(shaded(tester), 1);
    await tester.pumpWidget(_app(sparkline(area: false)));
    await tester.pumpAndSettle();
    expect(shaded(tester), 0);
  });

  testWidgets('devrait peindre une série dans la couleur que l’app lui donne', (tester) async {
    const color = Color(0xFF118844);
    await tester.pumpWidget(
      _app(
        FlChart.bar(
          points: _days,
          series: const [
            FlChartSeries(label: 'Sommeil', values: [7, 6, 8, 7, 9], color: color),
          ],
          formatValue: _euros,
          semanticLabel: 'Sommeil',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final colors = {
      for (final call in _painted(tester))
        if (call.memberName == #drawRRect) (call.positionalArguments[1] as Paint).color.toARGB32(),
    };
    expect(colors, {color.toARGB32()});
  });
}

/// Ce que peint le tracé du graphique.
List<Invocation> _painted(WidgetTester tester) {
  final canvas = TestRecordingCanvas();
  tester
      .renderObject<RenderCustomPaint>(find.byType(CustomPaint).first)
      .paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return [for (final call in canvas.invocations) call.invocation];
}

/// Les barres peintes, dans l'ordre des points.
List<Rect> _bars(WidgetTester tester) => [
  for (final call in _painted(tester))
    if (call.memberName == #drawRRect) (call.positionalArguments.first as RRect).outerRect,
];

/// Les libellés de l'axe du temps peints : la rangée la plus basse de
/// paragraphes.
final class _Labels {
  _Labels(WidgetTester tester) {
    final paragraphs = [
      for (final call in _painted(tester))
        if (call.memberName == #drawParagraph)
          (call.positionalArguments[1] as Offset) & Size((call.positionalArguments[0] as Paragraph).longestLine, 1),
    ];
    final bottom = paragraphs.map((r) => r.top).reduce((a, b) => a > b ? a : b);
    final row = paragraphs.where((r) => r.top == bottom).toList()..sort((a, b) => a.left.compareTo(b.left));
    count = row.length;
    for (var i = 1; i < row.length; i++) {
      if (row[i].left < row[i - 1].right) overlaps.add(i);
    }
    top = bottom;
  }

  late final int count;
  late final double top;
  final overlaps = <int>[];
}
