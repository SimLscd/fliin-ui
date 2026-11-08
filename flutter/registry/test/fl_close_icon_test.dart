// L'alias déprécié reste testé tant qu'il est livré.
// ignore_for_file: deprecated_member_use_from_same_package
import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'devrait peindre la croix de FlIcons.xmark, à la taille et à la couleur demandées, quand une app l’appelle encore',
    (tester) async {
      const color = Color(0xFF0A6CFF);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FlScope(
            child: const Center(child: FlCloseIcon(size: 14, color: color)),
          ),
        ),
      );
      expect(tester.getSize(find.byType(FlCloseIcon)), const Size.square(14));
      final paint = tester.renderObject(
        find.descendant(of: find.byType(FlCloseIcon), matching: find.byType(CustomPaint)),
      );
      final xmark = FlIcons.xmark.path;
      expect(paint, paints..path(color: color, includes: [const Offset(8, 8)], excludes: [const Offset(8, 3)]));
      expect(xmark.contains(const Offset(8, 8)) && !xmark.contains(const Offset(8, 3)), isTrue);
    },
  );
}
