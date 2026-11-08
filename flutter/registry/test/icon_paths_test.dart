import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'support/icon_set.g.dart';

/// La boîte serrée de chaque sous-tracé, lue sur le `Path` de Flutter par
/// ses points, en dehors de toute peinture.
List<Rect> _contours(Path path) => [
  for (final metric in path.computeMetrics())
    if (metric.length > 0)
      () {
        final points = [for (var i = 0; i <= 4096; i++) metric.getTangentForOffset(metric.length * i / 4096)!.position];
        return Rect.fromLTRB(
          points.map((p) => p.dx).reduce(math.min),
          points.map((p) => p.dy).reduce(math.min),
          points.map((p) => p.dx).reduce(math.max),
          points.map((p) => p.dy).reduce(math.max),
        );
      }(),
];

/// L'écart permis est de 0,05 unité dans une boîte de 16, à l'échelle de la
/// boîte du jeu (256 chez Phosphor).
void main() {
  for (final MapEntry(key: set, value: icons) in iconSets.entries) {
    for (final (:name, :icon, :contours) in icons) {
      test('devrait tracer chaque sous-tracé de $name ($set) dans la boîte que son SVG lui donne', () {
        final actual = _contours(icon.path);
        expect(actual, hasLength(contours.length), reason: '$name : nombre de sous-tracés');
        for (final (index, expected) in contours.indexed) {
          for (final (side, a, e) in [
            ('gauche', actual[index].left, expected.left),
            ('haut', actual[index].top, expected.top),
            ('droite', actual[index].right, expected.right),
            ('bas', actual[index].bottom, expected.bottom),
          ]) {
            expect(a, closeTo(e, 0.05 * icon.viewBox / 16), reason: '$name, sous-tracé $index, $side');
          }
        }
      });
    }
  }
}
