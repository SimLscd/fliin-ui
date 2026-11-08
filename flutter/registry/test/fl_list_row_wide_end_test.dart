import 'package:fliin_ui/components/list_row/fl_list_row.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dir in TextDirection.values) {
    testWidgets('devrait garder dans la ligne une fin plus large que la colonne, sans déborder, en $dir', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: FlScope(
            platform: TargetPlatform.iOS,
            child: Directionality(
              textDirection: dir,
              child: const Align(
                alignment: AlignmentDirectional.topStart,
                child: SizedBox(
                  width: 240,
                  child: FlListRow(
                    title: 'Atelier Vega',
                    leading: SizedBox.square(dimension: 40),
                    trailing: Text('+€2,450.00 +€2,450.00'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final row = tester.getRect(find.byType(FlListRow));
      final end = tester.getRect(find.text('+€2,450.00 +€2,450.00'));
      expect(end.left, greaterThanOrEqualTo(row.left));
      expect(end.right, lessThanOrEqualTo(row.right));
    });
  }

  const iban = 'FR76 3000 6000 0112 3456 7890 189';

  Future<void> pumpRow(WidgetTester tester, TextDirection dir, double scale, FlListRow row) => tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: FlScope(
        platform: TargetPlatform.iOS,
        child: Directionality(
          textDirection: dir,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(width: 240, child: row),
          ),
        ),
      ),
    ),
  );

  for (final dir in TextDirection.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('devrait poser sous le titre et passer à la ligne une valeur plus large que la colonne, '
          'sans déborder, à $scale en $dir', (tester) async {
        await pumpRow(tester, dir, scale, const FlListRow(title: 'IBAN', value: iban));
        expect(tester.takeException(), isNull);
        final row = tester.getRect(find.byType(FlListRow));
        final title = tester.getRect(find.text('IBAN'));
        final value = tester.getRect(find.text(iban));
        expect(value.left, greaterThanOrEqualTo(row.left));
        expect(value.right, lessThanOrEqualTo(row.right));
        expect(value.top, greaterThanOrEqualTo(title.bottom), reason: 'sous le titre');
        expect(value.height, greaterThan(title.height), reason: 'sur plusieurs lignes, entière');
        expect(row.bottom, greaterThanOrEqualTo(value.bottom));
        final start = dir == TextDirection.ltr ? (value.left - title.left) : (title.right - value.right);
        expect(start, 0, reason: 'au début, aligné sur le titre');
      });
    }

    for (final width in [51.0, 150.0]) {
      testWidgets(
        'devrait poser la valeur sur toute la largeur et le contrôle de $width dessous quand ils ne tiennent pas '
        'côte à côte, en $dir',
        (tester) async {
          final control = SizedBox(key: const ValueKey('control'), width: width, height: 31);
          await pumpRow(tester, dir, 1, FlListRow(title: 'IBAN', value: iban, trailing: control));
          expect(tester.takeException(), isNull);
          final row = tester.getRect(find.byType(FlListRow));
          final title = tester.getRect(find.text('IBAN'));
          final value = tester.getRect(find.text(iban));
          final box = tester.getRect(find.byKey(const ValueKey('control')));
          expect(box.width, width);
          // La colonne : la ligne moins ses marges de 16.
          expect(value.width, row.width - 32, reason: 'toute la largeur, jamais écrasée à côté du contrôle');
          expect(value.top, greaterThanOrEqualTo(title.bottom));
          expect(box.top, greaterThanOrEqualTo(value.bottom), reason: 'le contrôle sous la valeur');
          final start = dir == TextDirection.ltr ? box.left - title.left : title.right - box.right;
          expect(start, 0, reason: 'au début');
          expect(row.bottom, greaterThanOrEqualTo(box.bottom));
        },
      );
    }

    testWidgets('devrait garder côte à côte une valeur et un contrôle qui tiennent, en $dir', (tester) async {
      const control = SizedBox(key: ValueKey('control'), width: 51, height: 31);
      await pumpRow(tester, dir, 1, const FlListRow(title: 'Code', value: 'FR76', trailing: control));
      final value = tester.getRect(find.text('FR76'));
      final box = tester.getRect(find.byKey(const ValueKey('control')));
      expect(value.center.dy, box.center.dy);
      expect(dir == TextDirection.ltr ? box.left > value.right : box.right < value.left, isTrue);
    });
  }
}
