import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Une app minimale pour les tests des contrôles à bascule : raccourcis
/// clavier de `WidgetsApp` (Espace, Entrée), localisations, focus de départ
/// dans la portée pour que Tab atteigne le premier contrôle.
Widget toggleApp(
  Widget child, {
  TargetPlatform platform = TargetPlatform.android,
  TextDirection direction = TextDirection.ltr,
  FlDensity? density,
  FlTokens? tokens,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => Directionality(
    textDirection: direction,
    child: FlScope(
      tokens: tokens,
      brightness: Brightness.light,
      platform: platform,
      density: density,
      child: FocusScope(autofocus: true, child: Center(child: child)),
    ),
  ),
);

/// L'anneau de focus, où qu'il soit dans la liste des dessins.
PaintPattern get focusRingPainted => paints
  ..something(
    (method, arguments) =>
        method == #drawRRect &&
        (arguments[1] as Paint).style == PaintingStyle.stroke &&
        (arguments[1] as Paint).color.toARGB32() == FlTokens.defaults.light.focusRing.toARGB32() &&
        (arguments[0] as RRect).outerRect.top < 0,
  );

/// Les cercles que dessine [finder], dans l'ordre : centre, rayon, opacité.
List<(Offset, double, double)> circlesPainted(Finder finder) {
  final circles = <(Offset, double, double)>[];
  expect(
    finder,
    paints..everything((method, arguments) {
      if (method == #drawCircle) {
        circles.add((arguments[0] as Offset, arguments[1] as double, (arguments[2] as Paint).color.a));
      }
      return true;
    }),
  );
  return circles;
}

/// Un trait dessiné dans [color] : contour de case, de cercle ou de piste.
PaintPattern strokePainted(Color color) => paints
  ..something(
    (method, arguments) =>
        (method == #drawRRect || method == #drawCircle) &&
        (arguments.last as Paint).style == PaintingStyle.stroke &&
        (arguments.last as Paint).color.toARGB32() == color.toARGB32(),
  );

/// La cible d'un contrôle bascule ([toggle] : un `FlSwitch`, une
/// `FlCheckbox`, un `FlRadio`) : la boîte à la taille du visuel, qui porte son
/// nœud sémantique. Le contrôle s'aligne au début de la place qu'on lui
/// donne, sa racine peut donc être plus large que lui.
Finder controlOf(Finder toggle) => find.descendant(of: toggle, matching: find.byType(FlHitTarget)).first;
