import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/theme/fl_scope.dart';
import 'package:fliin_ui/core/tokens/tokens.g.dart';

/// How far a control on the accent (a disc, a pill, a skeleton) moves from
/// the accent towards `onAccent`: `onAccent` icons keep 3:1 on it with the
/// shipped accent in both modes (WCAG 1.4.11), and the step stays visible.
const _tint = 0.15;

/// The same step, pressed or for a stroke.
const _tintStrong = 0.25;

/// The primary action on the accent, pressed: `onAccent` dimmed towards the
/// accent, as a filled button darkens.
const _pressed = 0.12;

/// Places [child] on the accent: the accent fills the area, and every
/// component under it reads a palette derived from the theme's, in both
/// modes. The surfaces become the accent; text, muted text and icons
/// `onAccent`, since the accent only guarantees AA for `onAccent` at full
/// strength; controls, pills, borders and skeletons a tint of `onAccent`
/// over the accent; the primary action and every selected state `onAccent`
/// with accent content; the soft danger disc a tint too, its icon
/// `onAccent`. Separators vanish: on the accent, space separates. Fields,
/// segments, scrims and the other status colors keep their values. The
/// palette follows the theme a preset or `fliin theme` sets, and a scope
/// inside another one changes nothing.
///
/// ```dart
/// FlAccentScope(child: Row(children: [title, FlButton.icon(label: 'Pause', icon: pause, variant: FlButtonVariant.tertiary, onPressed: pause)]))
/// ```
class FlAccentScope extends StatelessWidget {
  /// [child] on the accent.
  const FlAccentScope({super.key, this.fill = true, required this.child});

  /// True: the accent is painted behind [child]. False: only the palette
  /// changes, for a child that paints its own accent.
  final bool fill;

  /// The subtree on the accent.
  final Widget child;

  /// The derived tokens of each theme: `FlScope` compares tokens by
  /// identity, so a new instance per build would rebuild every dependent.
  static final _derived = Expando<FlTokens>();
  static final _isDerived = Expando<bool>();

  /// The tokens of [tokens] on the accent.
  static FlTokens tokensOf(FlTokens tokens) {
    if (_isDerived[tokens] == true) return tokens;
    final cached = _derived[tokens];
    if (cached != null) return cached;
    final derived = FlTokens(
      light: _onAccent(tokens.light),
      dark: _onAccent(tokens.dark),
      shape: tokens.shape,
      shadow: tokens.shadow,
      space: tokens.space,
      size: tokens.size,
      motion: tokens.motion,
      typography: tokens.typography,
      contrastExceptions: tokens.contrastExceptions,
    );
    _isDerived[derived] = true;
    return _derived[tokens] = derived;
  }

  static FlColorTokens _onAccent(FlColorTokens c) {
    final accent = c.accent;
    final on = c.onAccent;
    final tint = Color.lerp(accent, on, _tint)!;
    final strong = Color.lerp(accent, on, _tintStrong)!;
    Color color(FlColorRole role) => switch (role) {
      FlColorRole.background ||
      FlColorRole.surface ||
      FlColorRole.surfaceRaised ||
      FlColorRole.surfaceOverlay => accent,
      FlColorRole.surfacePressed || FlColorRole.surfaceSecondary => tint,
      FlColorRole.surfaceTertiary => strong,
      FlColorRole.onSurface || FlColorRole.onSurfaceMuted || FlColorRole.link || FlColorRole.focusRing => on,
      FlColorRole.border || FlColorRole.borderSecondary || FlColorRole.borderTertiary => strong,
      FlColorRole.separator || FlColorRole.separatorSecondary || FlColorRole.separatorTertiary => accent,
      FlColorRole.accent || FlColorRole.selected => on,
      FlColorRole.accentPressed => Color.lerp(on, accent, _pressed)!,
      FlColorRole.onAccent || FlColorRole.onSelected => accent,
      FlColorRole.accentSoft ||
      FlColorRole.selectedSoft ||
      FlColorRole.control ||
      FlColorRole.dangerSoft ||
      FlColorRole.disabled ||
      FlColorRole.skeleton => tint,
      FlColorRole.accentSoftPressed ||
      FlColorRole.controlPressed ||
      FlColorRole.dangerSoftPressed ||
      FlColorRole.switchTrack ||
      FlColorRole.skeletonShimmer => strong,
      FlColorRole.onAccentSoft || FlColorRole.onControl || FlColorRole.onDangerSoft || FlColorRole.onDisabled => on,
      _ => c[role],
    };
    return FlColorTokens(
      surface: color(FlColorRole.surface),
      background: color(FlColorRole.background),
      surfaceRaised: color(FlColorRole.surfaceRaised),
      surfaceOverlay: color(FlColorRole.surfaceOverlay),
      surfacePressed: color(FlColorRole.surfacePressed),
      surfaceSecondary: color(FlColorRole.surfaceSecondary),
      surfaceTertiary: color(FlColorRole.surfaceTertiary),
      onSurface: color(FlColorRole.onSurface),
      onSurfaceMuted: color(FlColorRole.onSurfaceMuted),
      border: color(FlColorRole.border),
      borderSecondary: color(FlColorRole.borderSecondary),
      borderTertiary: color(FlColorRole.borderTertiary),
      separator: color(FlColorRole.separator),
      separatorSecondary: color(FlColorRole.separatorSecondary),
      separatorTertiary: color(FlColorRole.separatorTertiary),
      accent: color(FlColorRole.accent),
      accentPressed: color(FlColorRole.accentPressed),
      onAccent: color(FlColorRole.onAccent),
      accentSoft: color(FlColorRole.accentSoft),
      accentSoftPressed: color(FlColorRole.accentSoftPressed),
      onAccentSoft: color(FlColorRole.onAccentSoft),
      control: color(FlColorRole.control),
      controlPressed: color(FlColorRole.controlPressed),
      onControl: color(FlColorRole.onControl),
      disabled: color(FlColorRole.disabled),
      onDisabled: color(FlColorRole.onDisabled),
      focusRing: color(FlColorRole.focusRing),
      switchThumb: color(FlColorRole.switchThumb),
      switchTrack: color(FlColorRole.switchTrack),
      danger: color(FlColorRole.danger),
      dangerFill: color(FlColorRole.dangerFill),
      dangerPressed: color(FlColorRole.dangerPressed),
      onDanger: color(FlColorRole.onDanger),
      dangerSoft: color(FlColorRole.dangerSoft),
      dangerSoftPressed: color(FlColorRole.dangerSoftPressed),
      onDangerSoft: color(FlColorRole.onDangerSoft),
      dangerFaint: color(FlColorRole.dangerFaint),
      success: color(FlColorRole.success),
      onSuccess: color(FlColorRole.onSuccess),
      successPressed: color(FlColorRole.successPressed),
      successSoft: color(FlColorRole.successSoft),
      onSuccessSoft: color(FlColorRole.onSuccessSoft),
      warning: color(FlColorRole.warning),
      onWarning: color(FlColorRole.onWarning),
      onStatusAction: color(FlColorRole.onStatusAction),
      warningPressed: color(FlColorRole.warningPressed),
      warningSoft: color(FlColorRole.warningSoft),
      onWarningSoft: color(FlColorRole.onWarningSoft),
      field: color(FlColorRole.field),
      onField: color(FlColorRole.onField),
      fieldPlaceholder: color(FlColorRole.fieldPlaceholder),
      fieldBorder: color(FlColorRole.fieldBorder),
      segment: color(FlColorRole.segment),
      onSegment: color(FlColorRole.onSegment),
      pressHighlight: color(FlColorRole.pressHighlight),
      skeleton: color(FlColorRole.skeleton),
      skeletonShimmer: color(FlColorRole.skeletonShimmer),
      selection: color(FlColorRole.selection),
      scrim: color(FlColorRole.scrim),
      selected: color(FlColorRole.selected),
      onSelected: color(FlColorRole.onSelected),
      selectedSoft: color(FlColorRole.selectedSoft),
      link: color(FlColorRole.link),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = tokensOf(FlScope.of(context).tokens);
    return FlScope(
      tokens: tokens,
      child: fill
          ? Builder(
              builder: (context) => ColoredBox(color: FlScope.of(context).colors.surface, child: child),
            )
          : child,
    );
  }
}
