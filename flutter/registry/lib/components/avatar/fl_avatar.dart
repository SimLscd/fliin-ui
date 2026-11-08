// Modified from the Avatar of HeroUI Native 1.0.10, Copyright 2025 NextUI Inc.,
// licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';

/// The side of a [FlAvatar], and the size of its text and icon.
enum FlAvatarSize {
  /// 40, `textXs` text, 14 icon.
  sm,

  /// 48, `textSm` text, 16 icon.
  md,

  /// 64, `textBase` text, 20 icon.
  lg,

  /// 88, `heading2` text, 32 icon: the head of a profile (Izydesk's
  /// `.avatar-xl`).
  xl,
}

/// The background of a [FlAvatar].
enum FlAvatarVariant {
  /// The `control` background, whatever the color.
  primary,

  /// The color's tint at 15 %, `control` for the neutral.
  soft,
}

/// The color of a [FlAvatar]: that of the initials and of the fallback
/// icon, and of the `soft` background.
enum FlAvatarColor {
  /// The accent.
  accent,

  /// The neutral.
  neutral,

  /// Green.
  success,

  /// Orange.
  warning,

  /// Red.
  danger,
}

/// An avatar: a round image that fades in once loaded,
/// and, without an image or when it fails, a fallback (initials, a given
/// icon, or a silhouette) that fades in. While loading, only the background
/// shows.
class FlAvatar extends StatelessWidget {
  /// An `md`, `primary`, `accent` avatar.
  const FlAvatar({
    super.key,
    this.image,
    this.initials,
    this.icon,
    this.semanticLabel,
    this.size = FlAvatarSize.md,
    this.variant = FlAvatarVariant.primary,
    this.color = FlAvatarColor.accent,
    this.fallbackDelay = Duration.zero,
    this.dimension,
    this.radius,
    this.backgroundColor,
    this.foregroundColor,
  }) : assert(dimension == null || dimension > 0, 'dimension must be positive'),
       assert(radius == null || radius >= 0, 'radius must not be negative');

  /// The image; when null, the fallback.
  final ImageProvider? image;

  /// The fallback text, most often two letters, in medium weight. It does
  /// not grow beyond 1.4 times its size.
  final String? initials;

  /// The fallback without [initials], in the icon's color and size; when
  /// null, the `person` icon of the chosen set.
  final Widget? icon;

  /// What the screen reader reads: the person's name. When null: the
  /// [initials].
  final String? semanticLabel;

  /// The side.
  final FlAvatarSize size;

  /// The background.
  final FlAvatarVariant variant;

  /// The color.
  final FlAvatarColor color;

  /// The wait before the fallback enters: an image
  /// that fails quickly does not make the initials flicker.
  final Duration fallbackDelay;

  /// The side, instead of that of [size], which keeps its text and icon: a
  /// 24 byline under a card, a 56 community logo.
  final double? dimension;

  /// The radius of the continuous corners; when null,
  /// `shape.radiusButtonLarge`, a disc up to the `lg` size. `shape.radiusXl`
  /// draws a rounded square.
  final double? radius;

  /// The background, instead of that of [variant] and [color].
  final Color? backgroundColor;

  /// The color of the initials and of the fallback icon, instead of that of
  /// [color].
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    final motion = FlMotion.of(context);
    final soft = variant == FlAvatarVariant.soft;
    final fill =
        backgroundColor ??
        switch (color) {
          FlAvatarColor.accent when soft => colors.accentSoft,
          FlAvatarColor.success when soft => colors.successSoft,
          FlAvatarColor.warning when soft => colors.warningSoft,
          FlAvatarColor.danger when soft => colors.dangerSoft,
          _ => colors.control,
        };
    final ink =
        foregroundColor ??
        switch (color) {
          FlAvatarColor.accent => colors.onAccentSoft,
          FlAvatarColor.neutral => colors.onControl,
          FlAvatarColor.success => colors.onSuccessSoft,
          FlAvatarColor.warning => colors.onWarningSoft,
          // On `control`, `danger` holds 4.5:1; `onDangerSoft` is darker only
          // for the soft tint.
          FlAvatarColor.danger => soft ? colors.onDangerSoft : colors.danger,
        };
    final xs = theme.space.xs;
    // size-10, size-12, size-16; the icons from AVATAR_DEFAULT_ICON_SIZE.
    final (sizeSide, role, iconSize) = switch (size) {
      FlAvatarSize.sm => (xs * 10, FlTextRole.textXs, 14.0),
      FlAvatarSize.md => (xs * 12, FlTextRole.textSm, 16.0),
      FlAvatarSize.lg => (xs * 16, FlTextRole.textBase, 20.0),
      FlAvatarSize.xl => (xs * 22, FlTextRole.heading2, 32.0),
    };
    final side = dimension ?? sizeSide;
    final fade = motion.reduced ? Duration.zero : theme.motion.short4;
    final curve = theme.motion.easeIn;
    Widget fallback() {
      final initials = this.initials;
      final scale = theme.typography;
      final content = initials != null
          ? MediaQuery.withClampedTextScaling(
              maxScaleFactor: _maxTextScale,
              child: Text(
                initials,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: scale.resolve(role).copyWith(color: ink, fontWeight: theme.tokens.typography.weight.medium),
                strutStyle: scale.strut(role, inheritedFamily: DefaultTextStyle.of(context).style.fontFamily),
              ),
            )
          : IconTheme.merge(
              data: IconThemeData(color: ink, size: iconSize),
              child: icon ?? const _PersonIcon(),
            );
      return _FadeIn(
        delay: motion.reduced ? Duration.zero : fallbackDelay,
        duration: fade,
        curve: curve,
        child: Center(child: content),
      );
    }

    final image = this.image;
    final shape = FlContinuousBorder(radius: radius ?? theme.shape.radiusButtonLarge);
    return Semantics(
      image: true,
      label: semanticLabel ?? initials,
      child: ExcludeSemantics(
        child: FlPixelSnap(
          child: SizedBox.square(
            dimension: side,
            // The background is painted to the shape, without clipping:
            // clipped as well, its doubly antialiased edge fades (0.63 px at
            // the outline in sm). Only the image, which overflows, is clipped.
            child: DecoratedBox(
              decoration: ShapeDecoration(color: fill, shape: shape),
              child: image == null
                  ? fallback()
                  : ClipPath(
                      clipper: ShapeBorderClipper(shape: shape, textDirection: Directionality.maybeOf(context)),
                      child: Image(
                        image: image,
                        fit: BoxFit.cover,
                        width: side,
                        height: side,
                        frameBuilder: (context, child, frame, synchronous) => frame == null
                            ? const SizedBox.expand()
                            : _FadeIn(duration: fade, curve: curve, child: child),
                        errorBuilder: (context, error, stack) => fallback(),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The largest text scale the initials follow.
const double _maxTextScale = 1.4;

/// A fade-in of [duration] along [curve], after [delay]: Reanimated's
/// `FadeIn`, replayed on every mount.
class _FadeIn extends StatefulWidget {
  const _FadeIn({this.delay = Duration.zero, required this.duration, required this.curve, required this.child});

  final Duration delay;
  final Duration duration;
  final Curve curve;
  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
    value: widget.delay + widget.duration == Duration.zero ? 1 : 0,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = (widget.delay + widget.duration).inMicroseconds;
    final start = total == 0 ? 0.0 : widget.delay.inMicroseconds / total;
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _controller,
        curve: Interval(start, 1, curve: widget.curve),
      ),
      child: widget.child,
    );
  }
}

/// The `person` icon of the chosen set, in the color and size of the
/// `IconTheme`.
class _PersonIcon extends StatelessWidget {
  const _PersonIcon();

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    return FlIcon(FlIcons.person, size: icon.size ?? 16, color: icon.color ?? FlScope.of(context).colors.onControl);
  }
}
