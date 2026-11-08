import 'package:flutter/widgets.dart';

/// The stroke of a line icon (Lucide, Tabler…), in units of its box: it
/// follows the icon's size like the rest of the path.
final class FlIconStroke {
  /// A stroke of [width], with [cap] ends and [join] joins.
  const FlIconStroke({required this.width, this.cap = StrokeCap.round, this.join = StrokeJoin.round});

  /// The thickness, in box units.
  final double width;

  /// The shape of the ends.
  final StrokeCap cap;

  /// The shape of the joins.
  final StrokeJoin join;
}

/// The path of an icon, in its box of side [viewBox]: what `FlIcons` from the
/// `icons` item provides, or a path of your own. Filled, or stroked when
/// [stroke] is given; a path can have several subpaths (circles, lines,
/// polygons).
final class FlIconData {
  /// The [path], drawn in a square of side [viewBox]. It is copied: modifying
  /// it afterwards does not change the icon.
  FlIconData(Path path, {this.viewBox = 16, this.mirrorInRtl = false, this.stroke}) : _path = Path.from(path);

  final Path _path;

  /// A copy of the path: the icon is shared by the whole app.
  Path get path => Path.from(_path);

  /// The side of the path's box, in path units.
  final double viewBox;

  /// True for an icon that shows a reading direction (back, chevron towards the
  /// next element): it flips when text runs right to left. False for those
  /// that have none, including the play icon.
  final bool mirrorInRtl;

  /// The stroke, for a line icon; when null, the path is filled according to
  /// its `fillType`.
  final FlIconStroke? stroke;
}

/// An icon: [icon] in a square of [size], in [color].
///
/// Without [size] or [color], those of the `IconTheme`: that of the component
/// that holds it (a button, a row), otherwise the one `FlScope` places over
/// the app's theme, `size.indicatorIcon` scaled with the text up to
/// `size.iconMaxScale` and `colors.onSurface`. A given size is final.
///
/// Without [semanticLabel], it is decorative and absent from the
/// accessibility tree: the button or row that holds it names itself.
class FlIcon extends StatelessWidget {
  /// The icon [icon].
  const FlIcon(this.icon, {super.key, this.size, this.color, this.semanticLabel});

  /// The path.
  final FlIconData icon;

  /// The side of the square, in logical pixels.
  final double? size;

  /// The fill color.
  final Color? color;

  /// What the screen reader announces for an icon that carries meaning alone.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ambient = IconTheme.of(context);
    final paint = CustomPaint(
      size: Size.square(size ?? ambient.size!),
      painter: _IconPainter(icon, color ?? ambient.color!),
    );
    final glyph = icon.mirrorInRtl
        ? Transform.flip(flipX: Directionality.of(context) == TextDirection.rtl, child: paint)
        : paint;
    // A CustomPaint without a semanticsBuilder creates no node: without a
    // label, the icon has none.
    final label = semanticLabel;
    return label == null ? glyph : Semantics(label: label, image: true, child: glyph);
  }
}

class _IconPainter extends CustomPainter {
  const _IconPainter(this.icon, this.color);

  final FlIconData icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // A box narrower than requested (a row that is too short) keeps the whole
    // path, centered, without distorting it.
    final side = size.shortestSide;
    final paint = Paint()..color = color;
    if (icon.stroke case final stroke?) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.width
        ..strokeCap = stroke.cap
        ..strokeJoin = stroke.join;
    }
    canvas
      ..save()
      ..translate((size.width - side) / 2, (size.height - side) / 2)
      ..scale(side / icon.viewBox)
      ..drawPath(icon._path, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) => icon != oldDelegate.icon || color != oldDelegate.color;
}
