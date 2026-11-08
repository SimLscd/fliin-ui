import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// La clé du [RepaintBoundary] que [paintedColor] lit : le test la pose
/// autour de ce qu'il rend, overlays compris.
const Key pixelsBoundary = ValueKey('pixels');

/// La couleur peinte au centre de [finder], lue dans le rendu sous
/// [pixelsBoundary] : ce que l'œil voit, fond et ombres composés.
Future<Color> paintedColor(WidgetTester tester, Finder finder) => _paintedAt(tester, tester.getCenter(finder));

/// La couleur peinte au bord gauche de [finder], à mi-hauteur, un
/// demi-pixel à l'intérieur : là où passe le contour d'un contrôle. Un
/// contrôle se détache de son fond par son remplissage ou par son contour
/// (`fieldBorder`) ; le centre ne voit que le premier.
Future<Color> paintedEdgeColor(WidgetTester tester, Finder finder) =>
    _paintedAt(tester, tester.getRect(finder).centerLeft + const Offset(0.5, 0));

Future<Color> _paintedAt(WidgetTester tester, Offset global) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(pixelsBoundary));
  final at = boundary.globalToLocal(global);
  final pixel = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData();
    final offset = (at.dy.floor() * image.width + at.dx.floor()) * 4;
    image.dispose();
    return data!.buffer.asUint8List(offset, 4);
  });
  return Color.fromARGB(pixel![3], pixel[0], pixel[1], pixel[2]);
}

/// Le rond peint d'un radio sous [control], qui porte son fond.
Finder radioDisc(Finder control) => find
    .descendant(
      of: control,
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is ShapeDecoration &&
            (w.decoration as ShapeDecoration).shape is CircleBorder,
      ),
    )
    .first;
