import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/interaction/fl_hit_target.dart';
import 'package:fliin_ui/core/theme/fl_density.dart';
import 'package:fliin_ui/core/tokens/tokens.g.dart';

/// The theme resolved under a [FlScope]: tokens, brightness, platform,
/// density and Reduce Motion, plus the shortcuts components read. Obtained
/// with `FlScope.of(context)`.
final class FlTheme {
  /// An already resolved theme; an app sets it through [FlScope] rather than
  /// building it.
  const FlTheme({
    required this.tokens,
    required this.brightness,
    required this.platform,
    required this.density,
    required this.reduceMotion,
  });

  /// The theme's tokens, `FlTokens.defaults` when no [FlScope] sets any. Two
  /// themes are only equal on the same token instance.
  final FlTokens tokens;
  /// Light or dark: picks [colors]. Follows the platform's brightness when no
  /// [FlScope] sets it.
  final Brightness brightness;
  /// The platform whose conventions the theme follows: [typography] scale,
  /// [hitTarget], default density. `defaultTargetPlatform` when no [FlScope]
  /// sets it.
  final TargetPlatform platform;
  /// The visual density, which sets [controlHeight] and [listPadding]; by
  /// default `FlDensity.defaultFor(platform)`.
  final FlDensity density;

  /// iOS's Reduce Motion, read from `PlatformDispatcher`: in 3.47 it does not
  /// go through `MediaQueryData.disableAnimations`, which `FlMotion` reads
  /// separately.
  final bool reduceMotion;

  /// The palette of [brightness]: `tokens.light` or `tokens.dark`.
  FlColorTokens get colors => switch (brightness) {
    Brightness.light => tokens.light,
    Brightness.dark => tokens.dark,
  };

  /// The type scale of [platform]: iOS's on iOS, Android's everywhere else.
  /// Read by role with `resolve` and `strut`.
  FlTypeScale get typography =>
      platform == TargetPlatform.iOS ? tokens.typography.ios : tokens.typography.android;

  /// The shadows of [brightness]: `tokens.shadow.light` or
  /// `tokens.shadow.dark`, to be painted by `FlShadow`.
  FlShadows get shadows => switch (brightness) {
    Brightness.light => tokens.shadow.light,
    Brightness.dark => tokens.shadow.dark,
  };

  /// The corner radii and the button shape, taken from the tokens.
  FlShapeTokens get shape => tokens.shape;
  /// The tokens' spacing scale, from `xs` to `xxl`, in logical points.
  FlSpaceTokens get space => tokens.space;
  /// The tokens' dimensions: control heights, touch targets, strokes,
  /// selection handles, in logical points; except `iconMaxScale`, a unitless
  /// factor, and `scrimOpacity`, an opacity from 0 to 1.
  FlSizeTokens get size => tokens.size;
  /// The tokens' springs and durations. A component reads them through
  /// `FlMotion.of`, which applies reduced motion.
  FlMotionTokens get motion => tokens.motion;

  FlDensityMetrics get _metrics => size.metricsFor(density);
  /// The minimum height of a control (button, field) at the theme's
  /// [density], in logical points: 40, 48 or 56 with the default tokens.
  double get controlHeight => _metrics.controlHeight;
  /// The vertical padding of a list row at the theme's [density], in logical
  /// points: 8, 12 or 16 with the default tokens.
  double get listPadding => _metrics.listPadding;

  /// The minimum touch target: 44 on iOS, 48 on Android and Fuchsia, 24 on
  /// desktop (WCAG 2.2 §2.5.8), where compact density must save space. On the
  /// web, `defaultTargetPlatform` is the OS the browser reports.
  double get hitTarget => switch (platform) {
    TargetPlatform.iOS => size.hitTargetIos,
    TargetPlatform.android || TargetPlatform.fuchsia => size.hitTargetAndroid,
    TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux => size.hitTargetDesktop,
  };

  @override
  bool operator ==(Object other) =>
      other is FlTheme &&
      identical(tokens, other.tokens) &&
      brightness == other.brightness &&
      platform == other.platform &&
      density == other.density &&
      reduceMotion == other.reduceMotion;

  @override
  int get hashCode => Object.hash(identityHashCode(tokens), brightness, platform, density, reduceMotion);
}

typedef _Overrides = ({FlTokens? tokens, Brightness? brightness, TargetPlatform? platform, FlDensity? density});

/// iOS's Reduce Motion, which `MediaQuery` does not carry in 3.47.
bool _readReduceMotion() => WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion;

/// An unset value comes from the parent `FlScope`, otherwise from the
/// platform. Defaults resolve under the nearest scope: an unrequested density
/// follows the platform this scope sets, not the parent's.
FlTheme _resolve(BuildContext context, _Overrides overrides, {required bool reduceMotion}) {
  final platform = overrides.platform ?? defaultTargetPlatform;
  return FlTheme(
    tokens: overrides.tokens ?? FlTokens.defaults,
    brightness: overrides.brightness ?? MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light,
    platform: platform,
    density: overrides.density ?? FlDensity.defaultFor(platform),
    reduceMotion: reduceMotion,
  );
}

/// Sets the Fliin theme of the subtree. Each null parameter is inherited from
/// the parent `FlScope`, otherwise taken from the platform. Each scope follows
/// Reduce Motion and notifies its dependents when it changes, and places
/// Fliin's `IconTheme` (`colors.onSurface`, `size.indicatorIcon` following the
/// text up to `size.iconMaxScale`) over the app's. The root scope also places
/// the app's scroll observer and the `FlHitTargetHost` of touch targets.
class FlScope extends StatefulWidget {
  /// A scope that only sets its non-null parameters.
  const FlScope({super.key, this.tokens, this.brightness, this.platform, this.density, required this.child});

  /// The subtree's tokens; null inherits from the parent, else `FlTokens.defaults`.
  final FlTokens? tokens;
  /// Light or dark for the subtree; null inherits from the parent, otherwise
  /// follows `MediaQuery.platformBrightnessOf`, and light without a
  /// `MediaQuery`.
  final Brightness? brightness;
  /// The platform whose conventions the subtree follows; null inherits from
  /// the parent, otherwise `defaultTargetPlatform`.
  final TargetPlatform? platform;
  /// The subtree's density; null inherits from the parent, otherwise
  /// `FlDensity.defaultFor` of the platform this scope retains.
  final FlDensity? density;
  /// The subtree that receives the theme.
  final Widget child;

  /// The theme of the nearest [FlScope]; [context] rebuilds when it changes.
  /// Without a scope above, a theme taken from the platform and the default
  /// tokens, which does not follow Reduce Motion changes.
  static FlTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FlScopeData>()?.theme ??
      _resolve(
        context,
        (tokens: null, brightness: null, platform: null, density: null),
        reduceMotion: _readReduceMotion(),
      );

  @override
  State<FlScope> createState() => _FlScopeState();
}

class _FlScopeState extends State<FlScope> with WidgetsBindingObserver {
  bool _reduceMotion = _readReduceMotion();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() => setState(() => _reduceMotion = _readReduceMotion());

  @override
  Widget build(BuildContext context) {
    final parent = context.dependOnInheritedWidgetOfExactType<_FlScopeData>()?.overrides;
    final _Overrides overrides = (
      tokens: widget.tokens ?? parent?.tokens,
      brightness: widget.brightness ?? parent?.brightness,
      platform: widget.platform ?? parent?.platform,
      density: widget.density ?? parent?.density,
    );
    final theme = _resolve(context, overrides, reduceMotion: _reduceMotion);
    final scope = _FlScopeData(
      overrides: overrides,
      theme: theme,
      // The app's Material or Cupertino theme places its own IconTheme above
      // the `builder`: a free-standing icon would take its color.
      child: IconTheme.merge(
        data: IconThemeData(
          color: theme.colors.onSurface,
          size: (MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling)
              .clamp(maxScaleFactor: theme.size.iconMaxScale)
              .scale(theme.size.indicatorIcon),
        ),
        child: widget.child,
      ),
    );
    // The root scope listens to the app's scrolling: `EditableText` hides its
    // selection toolbar there while a parent scrolls, as under a `Scaffold`.
    // It also places the area where touch targets overflow their ancestors.
    // A nested scope adds neither.
    return parent == null ? ScrollNotificationObserver(child: FlHitTargetHost(child: scope)) : scope;
  }
}

class _FlScopeData extends InheritedWidget {
  const _FlScopeData({required this.overrides, required this.theme, required super.child});

  final _Overrides overrides;
  final FlTheme theme;

  @override
  bool updateShouldNotify(_FlScopeData oldWidget) => theme != oldWidget.theme || overrides != oldWidget.overrides;
}
