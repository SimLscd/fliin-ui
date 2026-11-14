import 'package:fliin_ui/components/chart/fl_category.dart';
import 'package:fliin_ui/components/chart/fl_ring_chart.dart';
import 'package:fliin_ui/components/chart/fl_share_bar.dart';
import 'package:fliin_ui/components/chart/fl_share_blocks.dart';
import 'package:fliin_ui/components/chart/fl_sparkline.dart';
import 'package:fliin_ui/components/chart/fl_stacked_bars.dart';
import 'package:fliin_ui/core/fliin.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'torture/themes.dart';

const _shares = [
  FlShare(label: 'Logement', value: 1850, semanticLabel: 'Logement, 1 850 €, 35 %'),
  FlShare(label: 'Courses', value: 940, semanticLabel: 'Courses, 940 €, 18 %'),
  FlShare(label: 'Rien', value: 0),
  FlShare(label: 'Santé', value: 38, semanticLabel: 'Santé, 38 €, 1 %'),
];

Widget _app(Widget child, {TextDirection dir = TextDirection.ltr, double scale = 1, double width = 320}) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
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

/// The blocks' rectangles, in the order of the shares drawn.
List<Rect> _blocks(WidgetTester tester) => [
  for (final element in find.descendant(of: find.byType(FlShareBlocks), matching: find.byType(CustomPaint)).evaluate())
    if ((element.widget as CustomPaint).painter != null) tester.getRect(find.byWidget(element.widget)),
];

void main() {
  testWidgets('devrait donner à chaque part une largeur à sa mesure, la plus petite gardant la sienne', (tester) async {
    await tester.pumpWidget(_app(const FlShareBlocks(shares: _shares, semanticLabel: 'Dépenses')));
    final blocks = _blocks(tester);
    // Three blocks: the share worth nothing leaves none.
    expect(blocks, hasLength(3));
    final space = FlTokens.defaults.space;
    expect(blocks[2].width, closeTo(space.lg + space.xs, 0.01));
    expect(blocks[0].width / blocks[1].width, closeTo(1850 / 940, 0.01));
    expect(blocks.last.right, closeTo(320, 0.01));
  });

  testWidgets('devrait mettre la première part à droite en RTL', (tester) async {
    await tester.pumpWidget(
      _app(
        const FlShareBlocks(shares: _shares, semanticLabel: 'Dépenses'),
        dir: TextDirection.rtl,
      ),
    );
    final blocks = _blocks(tester);
    expect(blocks.first.right, closeTo(tester.getRect(find.byType(FlShareBlocks)).right, 0.01));
    expect(blocks.first.width, greaterThan(blocks[1].width));
  });

  testWidgets('devrait lire les blocs en une image, ou en un bouton qui passe à la part suivante', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const FlShareBlocks(shares: _shares, semanticLabel: 'Dépenses, 2 828 €')));
    expect(find.bySemanticsLabel('Dépenses, 2 828 €'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Logement')), findsNothing);

    int? chosen = 0;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => FlShareBlocks(
            shares: _shares,
            semanticLabel: 'Dépenses, 2 828 €',
            selected: chosen,
            onSelected: (i) => setState(() => chosen = i),
          ),
        ),
      ),
    );
    final blocks = find.semantics.byLabel('Dépenses, 2 828 €');
    expect(
      tester.getSemantics(find.bySemanticsLabel('Dépenses, 2 828 €')),
      matchesSemantics(
        label: 'Dépenses, 2 828 €',
        value: 'Logement, 1 850 €, 35 %',
        isButton: true,
        hasTapAction: true,
      ),
    );
    tester.semantics.tap(blocks);
    await tester.pump();
    expect(chosen, 1);
    // The share worth nothing is skipped.
    tester.semantics.tap(blocks);
    await tester.pump();
    expect(chosen, 3);
    // A finger chooses the block it touches.
    await tester.tapAt(_blocks(tester)[1].center);
    await tester.pump();
    expect(chosen, 1);
    handle.dispose();
  });

  testWidgets('devrait ajouter le bloc de ce qui reste, en pointillés, après les parts', (tester) async {
    await tester.pumpWidget(_app(const FlShareBlocks(shares: _shares, remaining: 1000, semanticLabel: 'Budget')));
    final painted = find.descendant(of: find.byType(FlShareBlocks), matching: find.byType(CustomPaint));
    final rects = [
      for (final e in painted.evaluate())
        if ((e.widget as CustomPaint).painter != null) tester.getRect(find.byWidget(e.widget)),
    ];
    expect(rects, hasLength(4));
    expect(rects.last.right, closeTo(320, 0.01));
  });

  /// The pills [FlShareBar] draws for [weights] on 320, as the bar lays
  /// them out: a gap of 3 between two, a share narrower than the bar's 10
  /// widened to it, the others shrunk in proportion.
  List<double> pills(List<double> weights) {
    const height = 10.0, gap = 3.0;
    final available = 320 - gap * (weights.length - 1);
    final total = weights.fold(0.0, (a, b) => a + b);
    final raw = [for (final w in weights) w / total * available];
    final small = raw.where((w) => w < height).length;
    final large = raw.where((w) => w >= height).fold(0.0, (a, b) => a + b);
    final scale = (available - height * small) / large;
    return [for (final w in raw) w < height ? height : w * scale];
  }

  RRect pill(double from, double width) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(from, 0, width, 10), const Radius.circular(5));

  testWidgets('devrait découper la barre en pilules à la mesure des parts, de la fin en RTL, et la lire en une image', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final colors = FlTokens.defaults.light;
    final w = pills([1850, 940, 38]);
    await tester.pumpWidget(_app(const FlShareBar(shares: _shares, semanticLabel: 'Dépenses, 2 828 €')));
    final bar = find.descendant(of: find.byType(FlShareBar), matching: find.byType(CustomPaint));
    expect(
      bar,
      paints
        ..rrect(rrect: pill(0, w[0]), color: FlCategoryFill(0).color(colors))
        ..rrect(rrect: pill(w[0] + 3, w[1]), color: FlCategoryFill(1).color(colors))
        ..rrect(rrect: pill(w[0] + w[1] + 6, w[2]), color: FlCategoryFill(3).color(colors)),
    );
    expect(w[2], 10, reason: 'la plus petite part garde une pastille ronde');
    expect(
      tester.getSemantics(find.bySemanticsLabel('Dépenses, 2 828 €')),
      matchesSemantics(label: 'Dépenses, 2 828 €', isImage: true),
    );

    await tester.pumpWidget(
      _app(
        const FlShareBar(shares: _shares, semanticLabel: 'Dépenses'),
        dir: TextDirection.rtl,
      ),
    );
    expect(bar, paints..rrect(rrect: pill(320 - w[0], w[0]), color: FlCategoryFill(0).color(colors)));
    handle.dispose();
  });

  testWidgets(
    'devrait mettre la part choisie en couleur primaire et les autres en teinte légère, puis finir par ce qui reste',
    (tester) async {
      final colors = FlTokens.defaults.light;
      await tester.pumpWidget(_app(const FlShareBar(shares: _shares, selected: 1, semanticLabel: 'Dépenses')));
      final bar = find.descendant(of: find.byType(FlShareBar), matching: find.byType(CustomPaint));
      final w = pills([1850, 940, 38]);
      expect(
        bar,
        paints
          ..rrect(rrect: pill(0, w[0]), color: colors.selectedSoft)
          ..rrect(rrect: pill(w[0] + 3, w[1]), color: colors.selected)
          ..rrect(rrect: pill(w[0] + w[1] + 6, w[2]), color: colors.selectedSoft),
      );

      await tester.pumpWidget(
        _app(
          const FlShareBar(
            shares: [
              FlShare(label: 'Logement', value: 10000),
              FlShare(label: 'Santé', value: 1),
            ],
            remaining: 5000,
            semanticLabel: 'Budget',
          ),
        ),
      );
      final r = pills([10000, 1, 5000]);
      expect(
        bar,
        paints
          ..rrect(rrect: pill(0, r[0]), color: FlCategoryFill(0).color(colors))
          ..rrect(rrect: pill(r[0] + 3, r[1]), color: FlCategoryFill(1).color(colors))
          ..rrect(rrect: pill(r[0] + r[1] + 6, r[2]), color: colors.selectedSoft),
      );
    },
  );

  testWidgets('devrait choisir la tranche touchée de l\'anneau, et la suivante au lecteur d\'écran', (tester) async {
    final handle = tester.ensureSemantics();
    int? chosen = 0;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => FlRingChart(
            shares: _shares,
            diameter: 200,
            semanticLabel: 'Répartition',
            selected: chosen,
            onSelected: (i) => setState(() => chosen = i),
          ),
        ),
      ),
    );
    final ring = tester.getRect(find.byType(FlRingChart));
    // The top of the ring, a little after twelve o'clock: the first share.
    // Just before twelve: the last one drawn.
    await tester.tapAt(ring.topCenter + const Offset(-6, 8));
    await tester.pump();
    expect(chosen, 3);
    await tester.tapAt(ring.topCenter + const Offset(6, 8));
    await tester.pump();
    expect(chosen, 0);
    // The hole does nothing.
    await tester.tapAt(ring.center);
    await tester.pump();
    expect(chosen, 0);

    final node = find.bySemanticsLabel('Répartition');
    expect(
      tester.getSemantics(node),
      matchesSemantics(label: 'Répartition', value: 'Logement, 1 850 €, 35 %', isButton: true, hasTapAction: true),
    );
    tester.semantics.tap(find.semantics.byLabel('Répartition'));
    await tester.pump();
    expect(chosen, 1);
    // The share worth nothing is skipped.
    tester.semantics.tap(find.semantics.byLabel('Répartition'));
    await tester.pump();
    expect(chosen, 3);
    handle.dispose();
  });

  testWidgets('devrait tourner l\'anneau dans l\'autre sens en RTL', (tester) async {
    int? chosen;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => FlRingChart(
            shares: _shares,
            diameter: 200,
            semanticLabel: 'Répartition',
            selected: chosen,
            onSelected: (i) => setState(() => chosen = i),
          ),
        ),
        dir: TextDirection.rtl,
      ),
    );
    final ring = tester.getRect(find.byType(FlRingChart));
    await tester.tapAt(ring.topCenter + const Offset(-6, 8));
    await tester.pump();
    expect(chosen, 0);
  });

  testWidgets('devrait empiler les catégories de chaque barre et faire ressortir la colonne courante', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const FlStackedBars(
          columns: [
            FlStackedColumn(label: 'S1', values: [10, 20]),
            FlStackedColumn(label: 'S2', values: [5, double.nan, -3]),
          ],
          highlight: 1,
          semanticLabel: 'Dépenses par semaine',
        ),
      ),
    );
    expect(find.bySemanticsLabel('Dépenses par semaine'), findsOneWidget);
    expect(find.bySemanticsLabel('S1'), findsNothing);
    final colors = FlTokens.defaults.light;
    Color color(String label) => tester.widget<Text>(find.text(label)).style!.color!;
    expect(color('S2'), colors.onSurface);
    expect(color('S1'), colors.onSurfaceMuted);
    handle.dispose();
  });

  testWidgets('devrait taire la mini-courbe sans libellé et la lire avec', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const FlSparkline(values: [1, 3, 2])));
    expect(tester.getSemantics(find.byType(FlSparkline)), matchesSemantics());
    await tester.pumpWidget(_app(const FlSparkline(values: [1, 3, 2], semanticLabel: 'En hausse')));
    expect(find.bySemanticsLabel('En hausse'), findsOneWidget);
    handle.dispose();
  });

  test(
    'devrait distinguer les catégories par la seule clarté, la sixième et les suivantes partageant la dernière teinte',
    () {
      for (final colors in [
        for (final theme in flTestThemes) ...[theme.tokens.light, theme.tokens.dark],
      ]) {
        final fills = [for (var i = 0; i < FlCategoryFill.count; i++) FlCategoryFill(i).color(colors)];
        expect(fills.first, colors.selected);
        expect(FlCategoryFill(7).color(colors), fills.last);
        expect(FlCategoryFill(2).color(colors, selected: true), colors.selected);
        // Each shade is lighter (more transparent) than the one before it.
        for (var i = 1; i < FlCategoryFill.count; i++) {
          expect(fills[i].a, lessThan(fills[i - 1].a));
        }
      }
    },
  );

  testWidgets('devrait tenir la légende à 2,0 sans déborder', (tester) async {
    await tester.pumpWidget(_app(const FlCategoryLegend(shares: _shares, selected: 1), scale: 2, width: 200));
    expect(tester.takeException(), isNull);
    final dot = tester.widgetList<FlCategoryDot>(find.byType(FlCategoryDot)).toList();
    expect([for (final d in dot) d.selected], [false, true, false, false]);
  });
}
