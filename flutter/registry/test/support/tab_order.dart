import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le rectangle de chaque arrêt de Tab, du premier jusqu'au retour au
/// premier (ou [max] arrêts).
Future<List<Rect>> tabStops(WidgetTester tester, {int max = 40}) async {
  final stops = <Rect>[];
  for (var i = 0; i < max; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final box = FocusManager.instance.primaryFocus?.context?.findRenderObject();
    if (box is! RenderBox) break;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (stops.isNotEmpty && rect == stops.first) break;
    stops.add(rect);
  }
  return stops;
}

/// Vrai quand les arrêts [stops] suivent l'ordre de lecture d'une page de
/// gauche à droite : la barre du haut (au-dessus de [contentTop]), puis le
/// contenu de haut en bas, deux arrêts d'une même rangée de gauche à
/// droite, puis la barre du bas.
bool readsTopToBottom(List<Rect> stops, {required double contentTop}) {
  final content = stops.skipWhile((rect) => rect.top < contentTop).toList();
  if (content.any((rect) => rect.top < contentTop)) return false;
  for (var i = 1; i < content.length; i++) {
    final (previous, next) = (content[i - 1], content[i]);
    final sameRow = next.top < previous.bottom && next.bottom > previous.top;
    if (sameRow ? next.left < previous.left : next.top < previous.top - 0.5) return false;
  }
  return true;
}

/// Les libellés des nœuds annoncés comme titres.
List<String> headings(WidgetTester tester) =>
    find.semantics.byFlag(SemanticsFlag.isHeader).evaluate().map((node) => node.label).toList();
