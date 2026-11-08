import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/tokens/tokens.g.dart';

/// Density changes the visuals, never the touch target: `FlHitTarget` keeps
/// the platform's target whatever the density (DESIGN.md §2.5).
enum FlDensity {
  /// 40-point controls with the default tokens (`sm`); the default on
  /// desktop.
  compact,
  /// 48-point controls with the default tokens (`md`); the default on
  /// mobile.
  comfortable,
  /// 56-point controls with the default tokens (`lg`), for airy reading; never
  /// chosen by default.
  spacious;

  /// Compact on desktop, comfortable on mobile (DESIGN.md §2.5). On the web,
  /// [platform] is the OS the browser reports: the default is stable from the
  /// first frame, without waiting for a pointer. Spacious (a tablet used for
  /// reading) cannot be guessed: it is requested from `FlScope`.
  static FlDensity defaultFor(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS || TargetPlatform.android || TargetPlatform.fuchsia => comfortable,
    TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux => compact,
  };
}

/// The measurements a density sets, in logical points: the minimum height of
/// a control and the vertical padding of a list row.
typedef FlDensityMetrics = ({double controlHeight, double listPadding});

/// Picks the measurements of a [FlDensity] from the size tokens.
extension FlSizeDensity on FlSizeTokens {
  /// The measurements of [density]. `FlTheme.controlHeight` and
  /// `FlTheme.listPadding` read them for the theme's density.
  FlDensityMetrics metricsFor(FlDensity density) => switch (density) {
    FlDensity.compact => (controlHeight: controlCompact, listPadding: listPaddingCompact),
    FlDensity.comfortable => (controlHeight: controlComfortable, listPadding: listPaddingComfortable),
    FlDensity.spacious => (controlHeight: controlSpacious, listPadding: listPaddingSpacious),
  };
}
