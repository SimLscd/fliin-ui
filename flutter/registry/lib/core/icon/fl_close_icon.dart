// Modified from close-icon.tsx of HeroUI Native 1.0.10, Copyright 2025 NextUI
// Inc., licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/widgets.dart';

import 'package:fliin_ui/core/icon/fl_icon.dart';

/// A cross, in a square of side [size], in [color].
/// Kept for one version for the apps that call it: the registry's items use
/// `FlIcon(FlIcons.xmark)` from the `icons` item, the same path.
@Deprecated('Use FlIcon(FlIcons.xmark, size: size, color: color) from the icons item; removed in 0.2.0.')
class FlCloseIcon extends StatelessWidget {
  /// A cross of side [size], in [color].
  const FlCloseIcon({super.key, required this.size, required this.color});

  /// The side of the square, in logical pixels.
  final double size;

  /// The stroke color.
  final Color color;

  @override
  Widget build(BuildContext context) => FlIcon(_cross, size: size, color: color);
}

/// The path of `close-icon.tsx`, in its 16 × 16 box: `core` does not depend on
/// the `icons` item.
final FlIconData _cross = FlIconData(
  Path()
    ..moveTo(3.47, 3.47)
    ..arcToPoint(const Offset(4.53, 3.47), radius: const Radius.circular(0.75))
    ..lineTo(8, 6.94)
    ..lineTo(11.47, 3.47)
    ..arcToPoint(const Offset(12.53, 4.53), radius: const Radius.circular(0.75), largeArc: true)
    ..lineTo(9.06, 8)
    ..lineTo(12.53, 11.47)
    ..arcToPoint(const Offset(11.47, 12.53), radius: const Radius.circular(0.75), largeArc: true)
    ..lineTo(8, 9.06)
    ..lineTo(4.53, 12.53)
    ..arcToPoint(const Offset(3.47, 11.47), radius: const Radius.circular(0.75))
    ..lineTo(6.94, 8)
    ..lineTo(3.47, 4.53)
    ..arcToPoint(const Offset(3.47, 3.47), radius: const Radius.circular(0.75))
    ..close(),
);
