import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fait défiler la page jusqu'à ce que [target] soit construit, en tirant
/// dans le haut du contenu : la page passe sous la barre du bas translucide
/// (`FlPage.extendBody`), qui peut prendre la moitié d'un petit écran à 2,0,
/// et le centre de la vue qui défile peut tomber sur la barre.
Future<void> scrollPageTo(WidgetTester tester, Finder target) async {
  final page = tester.getRect(find.byType(Scrollable).first);
  for (var i = 0; i < 50 && target.evaluate().isEmpty; i++) {
    await tester.dragFrom(Offset(page.center.dx, page.top + page.height / 4), const Offset(0, -100));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
