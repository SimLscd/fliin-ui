import 'package:fliin_ui/components/list_row/fl_list_row.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('devrait donner le sens du premier caractère fort, et rien sans lettre', () {
    expect(flTextDirectionOf('Lift Your Skinny Fists'), TextDirection.ltr);
    expect(flTextDirectionOf('أنا لحبيبي'), TextDirection.rtl);
    expect(flTextDirectionOf('(1) שלום'), TextDirection.rtl, reason: 'la ponctuation et les chiffres ne comptent pas');
    expect(flTextDirectionOf('🌊 Waves'), TextDirection.ltr);
    expect(flTextDirectionOf('坂本龍一'), TextDirection.ltr);
    expect(flTextDirectionOf('2:43:12 🌊'), isNull);
  });

  test('devrait aligner un nom d’un autre sens sur le début de l’écran', () {
    expect(flTextAlignOf('Fiona Apple', TextDirection.rtl), TextAlign.end);
    expect(flTextAlignOf('Fiona Apple', TextDirection.ltr), TextAlign.start);
    expect(flTextAlignOf('فيروز', TextDirection.rtl), TextAlign.start);
    expect(flTextAlignOf('…', TextDirection.rtl), TextAlign.start);
  });

  testWidgets('devrait couper le titre d’une ligne limitée à sa propre fin, aligné sur le début de l’écran', (
    tester,
  ) async {
    const title = 'Lose Yourself to Dance (feat. Pharrell Williams) [Live at the Hollywood Bowl, 2014]';
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: FlScope(
          platform: TargetPlatform.iOS,
          child: const Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 320,
              child: FlListRow(title: title, subtitle: 'Daft Punk', titleLines: 2, subtitleLines: 1),
            ),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.text(title));
    expect((text.maxLines, text.overflow), (2, TextOverflow.ellipsis));
    expect(text.textDirection, TextDirection.ltr);
    expect(text.textAlign, TextAlign.end);
    expect(tester.takeException(), isNull);
  });
}
