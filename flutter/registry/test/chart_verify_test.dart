import 'package:fliin_ui/components/chart/fl_chart.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Les barres d'une semaine, la bulle ouverte sur jeudi ; deux séries en
/// barres (pleines et creuses) ; deux séries en ligne (continue et en
/// tirets) ; le tableau. Comme `verify.entry`.
Widget _charts(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  // Isolé en arabe, sinon « € » passe devant le nombre (ADR 0015 §17.3).
  String euros(double value) => tr(rtl, '€${value.round()}', '\u2066${value.round()} €\u2069');
  final days = [
    for (final (en, ar, enLong, arLong) in [
      ('M', 'ن', 'Monday', 'الاثنين'),
      ('T', 'ث', 'Tuesday', 'الثلاثاء'),
      ('W', 'ر', 'Wednesday', 'الأربعاء'),
      ('T', 'خ', 'Thursday', 'الخميس'),
      ('F', 'ج', 'Friday', 'الجمعة'),
      ('S', 'س', 'Saturday', 'السبت'),
      ('S', 'ح', 'Sunday', 'الأحد'),
    ])
      FlChartPoint(tr(rtl, en, ar), semanticLabel: tr(rtl, enLong, arLong)),
  ];
  final spent = FlChartSeries(label: tr(rtl, 'Spending', 'المصاريف'), values: const [32, 18, 45, 84, 27, 61, 12]);
  final before = FlChartSeries(
    label: tr(rtl, 'Previous week', 'الأسبوع السابق'),
    values: const [20, 40, 30, 52, 35, 48, 25],
  );
  final months = [
    for (final (en, ar) in [
      ('Jan', 'يناير'),
      ('Feb', 'فبراير'),
      ('Mar', 'مارس'),
      ('Apr', 'أبريل'),
      ('May', 'مايو'),
      ('Jun', 'يونيو'),
    ])
      FlChartPoint(tr(rtl, en, ar)),
  ];
  return ColoredBox(
    color: theme.colors.surface,
    child: SingleChildScrollView(
      padding: EdgeInsetsDirectional.all(theme.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.xl,
        children: [
          FlChart.bar(
            points: days,
            series: [spent],
            formatValue: euros,
            semanticLabel: tr(rtl, 'This week’s spending', 'مصاريف الأسبوع'),
            plotHeight: 120,
            initialSelection: 3,
          ),
          FlChart.bar(
            points: days,
            series: [spent, before],
            formatValue: euros,
            semanticLabel: tr(rtl, 'Spending per day', 'المصاريف اليومية'),
            plotHeight: 100,
          ),
          FlChart.line(
            points: months,
            series: [
              FlChartSeries(label: tr(rtl, 'Balance', 'الرصيد'), values: const [1200, 1450, 1380, 1720, 1650, 1980]),
              FlChartSeries(label: tr(rtl, 'Goal', 'الهدف'), values: const [1300, 1400, 1500, 1600, 1700, 1800]),
            ],
            formatValue: euros,
            semanticLabel: tr(rtl, 'Balance over time', 'تطور الرصيد'),
            plotHeight: 100,
            initialSelection: 4,
          ),
          FlChartTable(
            points: days.take(3).toList(),
            series: [spent],
            formatValue: euros,
            pointsLabel: tr(rtl, 'Day', 'اليوم'),
          ),
        ],
      ),
    ),
  );
}

void main() => verifyItem(
  item: 'chart',
  testFile: 'test/chart_verify_test.dart',
  settle: overlaySettle,
  size: const Size(390, 1040),
  showcase: _charts,
);
