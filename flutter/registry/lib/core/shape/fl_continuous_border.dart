import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Continuous corners, as Core Animation draws them (ADR 0014 §17). The
/// radius is capped at half the short side, like React Native's `ensureNoOverlap`.
/// Three paths, depending on the room each edge has, measured on the bench:
///
/// - each edge has room for two full corners (1.53 radii each): UIKit's
///   continuous corner, sampled point by point;
/// - the radius reaches half the length of the short side (a capsule): a
///   semicircle on that side and, on the other, Figma's squircle
///   construction with a smoothing of 0.75, which matches buttons and chips;
/// - in between: the path of Core Graphics'
///   `CGPathCreateWithContinuousRoundedRect`, sampled under macOS, each
///   control point of which varies linearly with the room its edge has
///   (error under 0.001 point over 300 random rectangles).
class FlContinuousBorder extends OutlinedBorder {
  /// Continuous corners of radius [radius], and a [side] stroke drawn inside.
  const FlContinuousBorder({super.side, this.radius = 0});

  /// The requested radius, in logical pixels, before capping.
  final double radius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  /// The extent of a UIKit continuous corner along each edge, in radii.
  static const double _reach = 1.52866483;

  /// A UIKit continuous corner, in the top-right corner's frame (x to the left,
  /// y downwards, in radii): the entry cubic, a short segment, the apex cubic
  /// and the exit cubic, mirroring the entry.
  static const List<List<Offset>> _uiKitCorner = [
    [Offset(1.08849323, 0), Offset(0.86840689, 0), Offset(0.66993427, 0.06549600)],
    [Offset(0.63149399, 0.07491100)],
    [Offset(0.37282392, 0.16905899), Offset(0.16906013, 0.37282401), Offset(0.07491176, 0.63149399)],
    [Offset(0, 0.86840701), Offset(0, 1.08849299), Offset(0, _reach)],
  ];

  /// The points of a half-corner, in radii from the angle (`n` inwards, `s`
  /// along the edge), when the edge only has two radii ([_tight]) and when it
  /// has room for a full corner ([_roomy]).
  static const _tight = _Half(
    a: 0.8732602355268561,
    b: 0.024092519875899456,
    c: 0.7476756885741366,
    d: 0.07099462715854132,
    e: 0.62993376642592466,
    f: 0.1726399214289621,
    g: 0.3747658642120895,
  );
  static const _roomy = _Half(a: 1.08849, b: 0, c: 0.868407, d: 0.0749114, e: 0.631494, f: 0.16906, g: 0.372824);

  /// The outline of [rect] with continuous corners of radius [radius].
  static Path pathFor(Rect rect, double radius) {
    final r = math.max(0.0, math.min(radius, rect.shortestSide / 2));
    if (r == 0) return Path()..addRect(rect);
    double room(double side) => ((side / 2 / r - 1) / (_reach - 1)).clamp(0.0, 1.0);
    final horizontal = room(rect.width);
    final vertical = room(rect.height);
    if (math.min(horizontal, vertical) == 1) return _uiKitPath(rect, r);
    if (math.min(horizontal, vertical) == 0) return _capsule(rect, r);
    return _coreGraphicsPath(rect, r, _Half.lerp(horizontal), _Half.lerp(vertical));
  }

  /// The Core Graphics path, when an edge has neither exactly two radii nor
  /// room for two full corners.
  static Path _coreGraphicsPath(Rect rect, double r, _Half horizontal, _Half vertical) {
    final path = Path();
    // Core Graphics' order and direction: from the middle of the start edge,
    // each corner arrives along one edge (`inN`, `inS`) and leaves along the
    // other.
    final corners = [
      (rect.topLeft, const Offset(1, 0), const Offset(0, 1), vertical, horizontal),
      (rect.topRight, const Offset(0, 1), const Offset(-1, 0), horizontal, vertical),
      (rect.bottomRight, const Offset(-1, 0), const Offset(0, -1), vertical, horizontal),
      (rect.bottomLeft, const Offset(0, -1), const Offset(1, 0), horizontal, vertical),
    ];
    for (final (i, (corner, inN, inS, arrive, leave)) in corners.indexed) {
      Offset at(Offset n, Offset s, double dn, double ds) => corner + n * (dn * r) + s * (ds * r);
      Offset inward(double dn, double ds) => at(inN, inS, dn, ds);
      Offset outward(double dn, double ds) => at(inS, inN, dn, ds);
      final start = inward(0, arrive.reach);
      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      void cubic(Offset p1, Offset p2, Offset p3) => path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
      cubic(inward(0, arrive.a), inward(arrive.b, arrive.c), inward(arrive.d, arrive.e));
      // Core Graphics takes the second control point's distance to the exit
      // edge from the arriving half-corner.
      cubic(inward(arrive.f, arrive.g), outward(arrive.f, leave.g), outward(leave.d, leave.e));
      cubic(outward(leave.b, leave.c), outward(0, leave.a), outward(0, leave.reach));
    }
    return path..close();
  }

  /// When each edge has room for two full corners, the path of UIKit's
  /// `cornerCurve = .continuous`, sampled point by point.
  static Path _uiKitPath(Rect rect, double r) {
    final path = Path();
    final corners = [
      (rect.topRight, const Offset(-1, 0), const Offset(0, 1)),
      (rect.bottomRight, const Offset(0, -1), const Offset(-1, 0)),
      (rect.bottomLeft, const Offset(1, 0), const Offset(0, -1)),
      (rect.topLeft, const Offset(0, 1), const Offset(1, 0)),
    ];
    for (final (i, (corner, back, down)) in corners.indexed) {
      Offset at(Offset p) => corner + back * (p.dx * r) + down * (p.dy * r);
      final start = at(const Offset(_reach, 0));
      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      for (final segment in _uiKitCorner) {
        final points = [for (final p in segment) at(p)];
        if (points.length == 1) {
          path.lineTo(points[0].dx, points[0].dy);
        } else {
          path.cubicTo(points[0].dx, points[0].dy, points[1].dx, points[1].dy, points[2].dx, points[2].dy);
        }
      }
    }
    return path..close();
  }

  /// The smoothing of a capsule's long side, in the sense of Figma's squircle
  /// construction: the curve leaves the edge at `(1 + s) × r` from the angle.
  static const double _capsuleSmoothing = 0.75;

  /// A capsule: a semicircle on each short side, and on the long side a
  /// blending cubic up to `1.75 × r` from the angle.
  static Path _capsule(Rect rect, double r) {
    final horizontal = rect.width / 2 > r ? _capsuleSmoothing : 0.0;
    final vertical = rect.height / 2 > r ? _capsuleSmoothing : 0.0;
    final path = Path();
    // Each corner, traversed clockwise: it arrives along one edge (direction
    // `back`, backwards) and leaves along the other (`out`).
    final corners = [
      (rect.topRight, const Offset(-1, 0), const Offset(0, 1), horizontal, vertical),
      (rect.bottomRight, const Offset(0, -1), const Offset(-1, 0), vertical, horizontal),
      (rect.bottomLeft, const Offset(1, 0), const Offset(0, -1), horizontal, vertical),
      (rect.topLeft, const Offset(0, 1), const Offset(1, 0), vertical, horizontal),
    ];
    for (final (i, (corner, back, out, incoming, outgoing)) in corners.indexed) {
      Offset at(Offset local, {required bool flip}) =>
          flip ? corner + out * local.dx + back * local.dy : corner + back * local.dx + out * local.dy;
      final arrive = _figmaHalf(r, incoming);
      final leave = _figmaHalf(r, outgoing);
      final start = at(arrive.tangent, flip: false);
      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      if (arrive.cubic case (final c1, final c2, final end)) {
        final (p1, p2, p3) = (at(c1, flip: false), at(c2, flip: false), at(end, flip: false));
        path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
      }
      final bisector = at(arrive.bisector, flip: false);
      path.arcToPoint(bisector, radius: Radius.circular(r));
      final leaveArcEnd = at(leave.cubic?.$3 ?? leave.tangent, flip: true);
      path.arcToPoint(leaveArcEnd, radius: Radius.circular(r));
      if (leave.cubic case (final c1, final c2, _)) {
        final (p1, p2, p3) = (at(c2, flip: true), at(c1, flip: true), at(leave.tangent, flip: true));
        path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
      }
    }
    return path..close();
  }

  /// A Figma half-corner in the angle's frame: the edge on the x axis, the
  /// circle's center at (r, r). From the point where the curve leaves the edge
  /// to the circle's point at 45°, through a blending cubic when [s] > 0, then
  /// an arc.
  static ({Offset tangent, (Offset, Offset, Offset)? cubic, Offset bisector}) _figmaHalf(double r, double s) {
    final bisector = Offset(r - r * math.sqrt1_2, r - r * math.sqrt1_2);
    if (s == 0) return (tangent: Offset(r, 0), cubic: null, bisector: bisector);
    double rad(double degrees) => degrees * math.pi / 180;
    final p = (1 + s) * r;
    final arcMeasure = 90 * (1 - s);
    final arcSection = math.sin(rad(arcMeasure / 2)) * r * math.sqrt2;
    final alpha = (90 - arcMeasure) / 2;
    final p3ToP4 = r * math.tan(rad(alpha / 2));
    final beta = 45 * s;
    final c = p3ToP4 * math.cos(rad(beta));
    final d = c * math.tan(rad(beta));
    final b = (p - arcSection - c - d) / 3;
    final a = 2 * b;
    return (
      tangent: Offset(p, 0),
      cubic: (Offset(p - a, 0), Offset(p - a - b, 0), Offset(p - a - b - c, d)),
      bisector: bisector,
    );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => pathFor(rect, radius);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      pathFor(rect.deflate(side.strokeInset), math.max(0, radius - side.strokeInset));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    // A ring by the even-odd rule rather than `Path.combine`: under CanvasKit,
    // the operation fails on some paths and the whole painting is lost
    // (ADR 0014 §17).
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addPath(getOuterPath(rect), Offset.zero)
        ..addPath(getInnerPath(rect), Offset.zero),
      Paint()..color = side.color,
    );
  }

  @override
  FlContinuousBorder copyWith({BorderSide? side, double? radius}) =>
      FlContinuousBorder(side: side ?? this.side, radius: radius ?? this.radius);

  @override
  ShapeBorder scale(double t) => FlContinuousBorder(side: side.scale(t), radius: radius * t);

  @override
  bool operator ==(Object other) => other is FlContinuousBorder && other.side == side && other.radius == radius;

  @override
  int get hashCode => Object.hash(side, radius);
}

/// A continuous half-corner, in radii: see [FlContinuousBorder._tight].
class _Half {
  const _Half({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
    required this.g,
    this.reach = 1,
  });

  /// The half-corner of an edge whose room is [room], from 0 (two radii) to 1
  /// (two full corners).
  factory _Half.lerp(double room) {
    double mix(double tight, double roomy) => tight + (roomy - tight) * room;
    const t = FlContinuousBorder._tight;
    const u = FlContinuousBorder._roomy;
    return _Half(
      a: mix(t.a, u.a),
      b: mix(t.b, u.b),
      c: mix(t.c, u.c),
      d: mix(t.d, u.d),
      e: mix(t.e, u.e),
      f: mix(t.f, u.f),
      g: mix(t.g, u.g),
      reach: mix(1, FlContinuousBorder._reach),
    );
  }

  final double a, b, c, d, e, f, g, reach;
}
