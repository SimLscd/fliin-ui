import 'dart:ui' show PictureRecorder;

import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rect = Rect.fromLTWH(0, 0, 100, 56);

  test('devrait tracer un demi-cercle sur le petit côté quand le rayon atteint la demi-hauteur', () {
    final path = FlContinuousBorder.pathFor(rect, 32);
    expect(path.contains(const Offset(0.5, 28)), isTrue, reason: 'le flanc touche le bord à mi-hauteur');
    final atQuarter = 28 - 28 * 0.8;
    expect(path.contains(Offset(28 - 28 * 0.6 + 0.3, atQuarter)), isTrue, reason: 'sur le cercle de rayon 28');
    expect(path.contains(Offset(28 - 28 * 0.6 - 0.3, atQuarter)), isFalse);
  });

  test('devrait prolonger la courbe le long du grand côté plus loin qu’un cercle', () {
    final path = FlContinuousBorder.pathFor(rect, 32);
    final stadium = Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(28)));
    const nearTop = Offset(30, 0.2);
    expect(stadium.contains(nearTop), isTrue);
    expect(path.contains(nearTop), isFalse);
    expect(path.contains(const Offset(50, 0.2)), isTrue);
  });

  test('devrait rester un cercle quand le contrôle est carré', () {
    final path = FlContinuousBorder.pathFor(const Rect.fromLTWH(0, 0, 48, 48), 24);
    final circle = Path()..addOval(const Rect.fromLTWH(0, 0, 48, 48));
    for (final point in [const Offset(4, 10), const Offset(10, 4), const Offset(7.2, 7.2), const Offset(6.8, 6.8)]) {
      expect(path.contains(point), circle.contains(point), reason: '$point');
    }
  });

  test('devrait suivre le tracé de Core Graphics quand un bord a moins de place que deux coins entiers', () {
    // Points du coin haut gauche de CGPathCreateWithContinuousRoundedRect
    // (280 × 52, rayon 24), relevés sous macOS.
    const coreGraphics = [
      Offset(0.095, 22.978),
      Offset(0.397, 20.206),
      Offset(0.931, 17.611),
      Offset(3.962, 10.781),
      Offset(7.013, 7.034),
      Offset(10.776, 4.001),
      Offset(19.433, 0.758),
      Offset(24.093, 0.225),
      Offset(29.666, 0.028),
    ];
    final path = FlContinuousBorder.pathFor(const Rect.fromLTWH(0, 0, 280, 52), 24);
    const nudge = Offset(0.02, 0.02);
    for (final point in coreGraphics) {
      expect(path.contains(point + nudge), isTrue, reason: 'à l’intérieur de $point');
      expect(path.contains(point - nudge), isFalse, reason: 'à l’extérieur de $point');
    }
  });

  testWidgets('devrait peindre son trait quand le contour tombe entre deux pixels, comme sous une vue réduite', (
    tester,
  ) async {
    // Le bouton outline réduit par un FittedBox du site : sa capsule posée à
    // (-0,32 ; 0,16). Une différence de chemins y échoue (Skia PathOps, sous
    // CanvasKit comme ici) et la peinture du bouton entier était perdue.
    const rect = Rect.fromLTWH(-0.3200000000000003, 0.15999999999996817, 83, 48);
    const border = FlContinuousBorder(side: BorderSide(color: Color(0xFF000000)), radius: 24);
    final recorder = PictureRecorder();
    border.paint(Canvas(recorder)..translate(1, 0), rect);
    final image = await tester.runAsync(() => recorder.endRecording().toImage(84, 49));
    final bytes = (await tester.runAsync(() => image!.toByteData()))!;
    int alpha(int x, int y) => bytes.getUint8((y * 84 + x) * 4 + 3);
    expect(alpha(42, 0), greaterThan(128), reason: 'le trait du haut');
    expect(alpha(42, 47), greaterThan(128), reason: 'le trait du bas');
    expect(alpha(42, 24), 0, reason: 'le dedans reste vide');
  });
}
