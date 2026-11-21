import 'dart:math' as math;
import 'dart:ui' show ImageFilter, SemanticsRole, lerpDouble;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The emphasis of an [FlFab].
enum FlFabVariant {
  /// `accent` fill, `onAccent` glyph: the screen's lead action.
  primary,

  /// `accentSoft` fill, `onAccentSoft` glyph: a lead action on a screen that
  /// already spends its accent elsewhere.
  secondary,

  /// `surfaceOverlay` fill, `onSurface` glyph: a neutral action floating
  /// over the content (scroll to top, recenter a map).
  surface,

  /// `surfaceOverlay` fill, `danger` glyph and label: a destructive action,
  /// told by its color and never by a red fill.
  danger,
}

/// The size of an [FlFab]: 44, 56 or 64 points across with the default
/// tokens.
enum FlFabSize {
  /// `size.controlCompact` across, label `controlSm`.
  sm,

  /// `size.controlSpacious` across, label `controlMd`.
  md,

  /// `size.controlSpacious` plus `space.sm` across, label `controlLg`.
  lg,
}

/// The corner of its parent where an [FlFab] or an [FlFabGroup] parks.
enum FlFabPlacement {
  /// The bottom, on the side where the text starts.
  bottomStart,

  /// The bottom, centered.
  bottomCenter,

  /// The bottom, on the side where the text ends: where a thumb rests.
  bottomEnd;

  AlignmentDirectional get _alignment => switch (this) {
    bottomStart => AlignmentDirectional.bottomStart,
    bottomCenter => AlignmentDirectional.bottomCenter,
    bottomEnd => AlignmentDirectional.bottomEnd,
  };

  CrossAxisAlignment get _cross => switch (this) {
    bottomStart => CrossAxisAlignment.start,
    bottomCenter => CrossAxisAlignment.center,
    bottomEnd => CrossAxisAlignment.end,
  };
}

/// What an [FlFabGroup] opens.
enum FlFabLayout {
  /// A column of round buttons, each with its label beside it, that unfold
  /// from the trigger one after the other.
  dial,

  /// One panel of rows that grows out of the trigger's corner.
  menu,
}

/// The blur of the screen behind an open group, that of the glass bars.
const double _glassBlur = 20;

/// How far apart the actions of a dial start, as a share of the opening.
const double _stagger = 0.12;

/// The scale an action or a menu grows from.
const double _enterScale = 0.6;

typedef _Metrics = ({double extent, double padding, double gap, double icon, FlTextRole text});

typedef _Paint = ({Color fill, Color foreground, Color highlight, Color? outline});

_Metrics _metricsOf(FlTheme theme, FlFabSize size) {
  final s = theme.size;
  return switch (size) {
    FlFabSize.sm => (
      extent: s.controlCompact,
      padding: s.buttonPaddingSm,
      gap: s.buttonGapSm,
      icon: s.buttonIconMd,
      text: FlTextRole.controlSm,
    ),
    FlFabSize.md => (
      extent: s.controlSpacious,
      padding: s.buttonPaddingMd,
      gap: s.buttonGapMd,
      icon: s.buttonIconLg,
      text: FlTextRole.controlMd,
    ),
    FlFabSize.lg => (
      extent: s.controlSpacious + theme.space.sm,
      padding: s.buttonPaddingLg,
      gap: s.buttonGapLg,
      icon: s.buttonIconLg,
      text: FlTextRole.controlLg,
    ),
  };
}

_Paint _paintOf(FlTheme theme, FlFabVariant variant) {
  final c = theme.colors;
  return switch (variant) {
    FlFabVariant.primary => (fill: c.accent, foreground: c.onAccent, highlight: c.accentPressed, outline: null),
    FlFabVariant.secondary => (
      fill: c.accentSoft,
      foreground: c.onAccentSoft,
      highlight: c.accentSoftPressed,
      outline: null,
    ),
    FlFabVariant.surface => (
      fill: c.surfaceOverlay,
      foreground: c.onSurface,
      highlight: c.surfacePressed,
      outline: flOverlayOutline(theme),
    ),
    FlFabVariant.danger => (
      fill: c.surfaceOverlay,
      foreground: c.danger,
      highlight: Color.alphaBlend(c.dangerSoft, c.surfaceOverlay),
      outline: flOverlayOutline(theme),
    ),
  };
}

/// The theme's button shape: a circle, or a capsule once extended, under
/// `pill`.
OutlinedBorder _shapeOf(FlTheme theme, [BorderSide side = BorderSide.none]) => switch (theme.shape.button) {
  FlButtonShape.square => RoundedRectangleBorder(side: side),
  FlButtonShape.rounded => FlContinuousBorder(side: side, radius: theme.shape.radiusButtonLarge),
  FlButtonShape.pill => StadiumBorder(side: side),
};

BorderRadius _radiusOf(FlTheme theme) => switch (theme.shape.button) {
  FlButtonShape.square => BorderRadius.zero,
  FlButtonShape.rounded => BorderRadius.circular(theme.shape.radiusButtonLarge),
  FlButtonShape.pill => theme.shape.buttonRadius,
};

/// [child] parked at [placement], [offset] from the edges and the safe area.
Widget _parked(BuildContext context, FlFabPlacement placement, double? offset, Widget child) => SafeArea(
  top: false,
  child: Padding(
    padding: EdgeInsetsDirectional.all(offset ?? FlScope.of(context).space.lg),
    child: Align(alignment: placement._alignment, child: child),
  ),
);

/// A floating action button: the one action of a screen, pinned over its
/// content. Round with [icon] alone, or [extended] into a capsule that spells
/// [label] out. It lifts on the `overlay` shadow, shrinks when pressed, and
/// follows the theme's button shape: a circle under `pill`.
///
/// With [placement], it parks in a corner of its parent, [offset] from the
/// edges and clear of the safe area: make it a child of a `Stack` over the
/// content, and leave the list room to scroll its last row clear. Without, it
/// sits in the flow like any button.
///
/// ```dart
/// Stack(children: [
///   list,
///   FlFab(label: 'New message', icon: FlIcon(FlIcons.pencil),
///       placement: FlFabPlacement.bottomEnd, onPressed: compose),
/// ])
/// ```
///
/// One per screen. For a lead action with a few others behind it, use
/// [FlFabGroup].
class FlFab extends StatelessWidget {
  /// A floating action button, round and `primary` by default.
  const FlFab({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.extended = false,
    this.variant = FlFabVariant.primary,
    this.size = FlFabSize.md,
    this.placement,
    this.offset,
    this.statesController,
  });

  /// The action's name: read by the screen reader, and shown beside [icon]
  /// when [extended].
  final String label;

  /// The glyph, in the variant's foreground color and at the size's icon
  /// size.
  final Widget icon;

  /// Called when the button is pressed. When null, the button goes to
  /// `size.disabledOpacity` and announces itself disabled.
  final VoidCallback? onPressed;

  /// True: [label] shows beside [icon]. Changing it animates the label in or
  /// out (collapse it once the list scrolls), at once under reduced motion.
  final bool extended;

  /// The fill and the glyph color; `primary` by default.
  final FlFabVariant variant;

  /// The diameter; `md` by default.
  final FlFabSize size;

  /// The corner of the parent where the button parks; when null, it sits in
  /// the flow.
  final FlFabPlacement? placement;

  /// The distance from the parent's edges under [placement], added to the
  /// safe area; when null, `space.lg`.
  final double? offset;

  /// The button's states, which the app can read or force; see
  /// `FlPressable.statesController`.
  final WidgetStatesController? statesController;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final button = FlPressable(
      onPressed: onPressed,
      statesController: statesController,
      label: label,
      borderRadius: _radiusOf(theme),
      builder: (context, states) => TweenAnimationBuilder<double>(
        tween: Tween(end: extended ? 1 : 0),
        duration: FlMotion.of(context).reduced ? Duration.zero : theme.motion.medium2,
        curve: theme.motion.standard,
        builder: (context, extent, _) =>
            _Face(variant: variant, size: size, icon: icon, label: label, extent: extent, states: states),
      ),
    );
    final placement = this.placement;
    // In the flow, a parent that stretches its children (a column) leaves the
    // button at its own size.
    return placement == null
        ? Align(alignment: AlignmentDirectional.center, widthFactor: 1, heightFactor: 1, child: button)
        : _parked(context, placement, offset, button);
  }
}

/// The look of a floating button: the shadow, the fill, the glyph turned by
/// [turn] eighths of a circle, and [label] unfolded by [extent].
class _Face extends StatelessWidget {
  const _Face({
    required this.variant,
    required this.size,
    required this.icon,
    required this.states,
    this.label,
    this.extent = 0,
    this.turn = 0,
  });

  final FlFabVariant variant;
  final FlFabSize size;
  final Widget icon;
  final Set<WidgetState> states;
  final String? label;
  final double extent;
  final double turn;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final metrics = _metricsOf(theme, size);
    final paint = _paintOf(theme, variant);
    final outline = paint.outline;
    final shape = _shapeOf(
      theme,
      outline == null ? BorderSide.none : BorderSide(color: outline, width: theme.size.border),
    );
    final iconSize = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: theme.size.iconMaxScale)
        .scale(metrics.icon);
    final label = this.label;
    final shown = label == null ? 0.0 : extent.clamp(0.0, 1.0);
    // Round, the glyph sits in the middle; extended, the button's own padding.
    final inline = lerpDouble(math.max(0, (metrics.extent - iconSize) / 2), metrics.padding, shown)!;
    final disabled = states.contains(WidgetState.disabled);
    final hovered = theme.hovers && !disabled && states.contains(WidgetState.hovered);
    return Opacity(
      opacity: disabled ? theme.size.disabledOpacity : 1,
      child: FlShadow(
        layers: theme.shadows.overlay,
        shape: shape,
        child: DecoratedBox(
          decoration: ShapeDecoration(color: hovered ? paint.highlight : paint.fill, shape: shape),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: metrics.extent, minHeight: metrics.extent),
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: [
                Positioned.fill(
                  child: ClipPath(
                    clipper: ShapeBorderClipper(shape: shape),
                    child: FlPressHighlight(color: paint.highlight),
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.symmetric(horizontal: inline),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.rotate(
                        angle: turn * math.pi / 4,
                        child: IconTheme.merge(
                          data: IconThemeData(color: paint.foreground, size: iconSize),
                          child: icon,
                        ),
                      ),
                      if (label != null && shown > 0)
                        Flexible(
                          child: ClipRect(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              widthFactor: shown,
                              heightFactor: 1,
                              child: Opacity(
                                opacity: shown,
                                child: Padding(
                                  padding: EdgeInsetsDirectional.only(start: metrics.gap),
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.fade,
                                    style: theme.typography.resolve(metrics.text).copyWith(color: paint.foreground),
                                    strutStyle: theme.typography.strut(
                                      metrics.text,
                                      inheritedFamily: DefaultTextStyle.of(context).style.fontFamily,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One action of an [FlFabGroup].
final class FlFabAction {
  /// An action named [label], drawn as [icon].
  const FlFabAction({required this.label, required this.icon, required this.onPressed, this.destructive = false});

  /// The action's name, shown beside its glyph and read by the screen reader.
  final String label;

  /// The glyph.
  final Widget icon;

  /// Called once the group has started closing; when null, the action is
  /// disabled.
  final VoidCallback? onPressed;

  /// True: the glyph and the label take the `danger` color.
  final bool destructive;
}

/// A floating action button that opens a few more: one lead action with its
/// secondary ones behind it. The trigger parks at [placement]; pressed, it
/// drops a scrim over its parent and unfolds [actions] above itself, as a
/// [FlFabLayout.dial] of round buttons or a [FlFabLayout.menu] panel. A tap
/// on an action, on the scrim or on the trigger, Escape and the system's back
/// gesture all close it.
///
/// It fills its parent, which the scrim covers and [offset] is measured from:
/// make it the last child of a `Stack` that spans the screen.
///
/// ```dart
/// Stack(children: [
///   page,
///   FlFabGroup(label: 'Create', barrierLabel: 'Close', icon: FlIcon(FlIcons.plus), actions: [
///     FlFabAction(label: 'Event', icon: FlIcon(FlIcons.calendar), onPressed: addEvent),
///     FlFabAction(label: 'Note', icon: FlIcon(FlIcons.pencil), onPressed: addNote),
///   ]),
/// ])
/// ```
///
/// One spring drives the whole opening: each action reads it a little later
/// than the one below, so they unfold in turn and fold back the same way.
/// Under reduced motion they only fade. Closed, the actions are not built: a
/// screen reader never reaches them. Open, focus goes to the first action,
/// and what lies under the scrim is out of the screen reader's reach.
///
/// For three or more actions of equal weight, use a `toolbar`.
class FlFabGroup extends StatefulWidget {
  /// A closed group, a dial at the bottom end by default.
  const FlFabGroup({
    super.key,
    required this.label,
    required this.barrierLabel,
    required this.icon,
    required this.actions,
    this.open,
    this.onOpenChange,
    this.layout = FlFabLayout.dial,
    this.placement = FlFabPlacement.bottomEnd,
    this.offset,
    this.extended = false,
    this.variant = FlFabVariant.primary,
    this.size = FlFabSize.md,
    this.enabled = true,
    this.blur = false,
    this.rotateOnOpen = true,
  });

  /// The trigger's name: read by the screen reader, and shown beside [icon]
  /// while the group is closed when [extended].
  final String label;

  /// The name of the tap on the scrim that closes the group, for screen
  /// readers ("Close").
  final String barrierLabel;

  /// The trigger's glyph.
  final Widget icon;

  /// The actions, from the top down: the last one is the closest to the
  /// trigger.
  final List<FlFabAction> actions;

  /// Open or not, when the app holds the state; when null, the group holds
  /// its own.
  final bool? open;

  /// Called when the group asks to open or close.
  final ValueChanged<bool>? onOpenChange;

  /// A dial of round buttons by default, or a menu panel.
  final FlFabLayout layout;

  /// The corner of the parent where the group parks; the bottom end by
  /// default.
  final FlFabPlacement placement;

  /// The distance from the parent's edges, added to the safe area; when null,
  /// `space.lg`. Raise it to clear a bottom bar.
  final double? offset;

  /// True: the trigger spells [label] out while closed, and folds back to
  /// its glyph as the group opens.
  final bool extended;

  /// The trigger's fill and glyph color; `primary` by default.
  final FlFabVariant variant;

  /// The trigger's diameter; `md` by default. The dial's buttons stay `sm`.
  final FlFabSize size;

  /// False: the trigger is disabled, and the group stays closed.
  final bool enabled;

  /// True: the screen behind the open group is blurred instead of dimmed.
  final bool blur;

  /// True: the trigger's glyph turns an eighth of a circle while open, so a
  /// plus reads as a closing cross. Turn it off for a glyph that is not one.
  final bool rotateOnOpen;

  @override
  State<FlFabGroup> createState() => _FlFabGroupState();
}

class _FlFabGroupState extends State<FlFabGroup> with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController.unbounded(vsync: this, value: _open ? 1 : 0);
  late final Animation<double> _fade = _progress.drive(const _Clamp());
  final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'FlFabGroup');
  bool _own = false;

  bool get _open => widget.enabled && (widget.open ?? _own);

  /// Where the spring was last sent.
  late bool _target;

  @override
  void initState() {
    super.initState();
    _target = _open;
  }

  @override
  void didUpdateWidget(FlFabGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_open != _target) _run();
  }

  @override
  void dispose() {
    _progress.dispose();
    _scope.dispose();
    super.dispose();
  }

  void _set(bool open) {
    if (open == _open) return;
    if (widget.open == null) setState(() => _own = open);
    widget.onOpenChange?.call(open);
    if (_open != _target) _run();
  }

  void _run() {
    final open = _target = _open;
    _progress.driveTo(open ? 1 : 0, FlMotion.of(context).spring(FlSpring.release));
    if (!open) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_open || _scope.hasFocus) return;
      _scope.requestFocus();
      _scope.nextFocus();
    });
  }

  void _choose(FlFabAction action) {
    _set(false);
    action.onPressed?.call();
  }

  /// How far the action [fromTrigger] places away from the trigger has come:
  /// the closest starts first, and only the spring's own overshoot passes 1.
  double _reach(double progress, int fromTrigger) {
    final raw = progress * (1 + _stagger * (widget.actions.length - 1)) - _stagger * fromTrigger;
    return raw <= 1 ? math.max(0, raw) : math.max(1, progress);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final reduced = FlMotion.of(context).reduced;
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final open = _open;
        final progress = _progress.value;
        final visible = open || progress > 0;
        // Reduced motion drives opacities alone: what moves snaps instead.
        final turn = reduced ? (open ? 1.0 : 0.0) : progress;
        final trigger = FlPressable(
          onPressed: widget.enabled ? () => _set(!open) : null,
          label: widget.label,
          expanded: open,
          borderRadius: _radiusOf(theme),
          builder: (context, states) => _Face(
            variant: widget.variant,
            size: widget.size,
            icon: widget.icon,
            label: widget.extended ? widget.label : null,
            extent: 1 - turn,
            turn: widget.rotateOnOpen ? turn : 0,
            states: states,
          ),
        );
        final gap = SizedBox(height: theme.space.md);
        return PopScope(
          canPop: !open,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _set(false);
          },
          child: CallbackShortcuts(
            bindings: {if (open) const SingleActivator(LogicalKeyboardKey.escape): () => _set(false)},
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (visible) BlockSemantics(child: _scrim(progress)),
                _parked(
                  context,
                  widget.placement,
                  widget.offset,
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: widget.placement._cross,
                    children: [
                      if (visible)
                        Flexible(
                          child: FocusScope(
                            node: _scope,
                            child: Semantics(
                              container: true,
                              explicitChildNodes: true,
                              role: SemanticsRole.menu,
                              child: switch (widget.layout) {
                                FlFabLayout.dial => _dial(theme, progress, reduced),
                                FlFabLayout.menu => _menu(theme, progress, reduced),
                              },
                            ),
                          ),
                        ),
                      if (visible) gap,
                      trigger,
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _scrim(double progress) {
    void close() => _set(false);
    if (!widget.blur) {
      return FlPopupOverlay(animation: _fade, onDismiss: close, dismissLabel: widget.barrierLabel);
    }
    final sigma = _glassBlur * progress.clamp(0.0, 1.0);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: FlPopupOverlay(
          animation: _fade,
          backdrop: FlPopupBackdrop.transparent,
          onDismiss: close,
          dismissLabel: widget.barrierLabel,
        ),
      ),
    );
  }

  Widget _dial(FlTheme theme, double progress, bool reduced) {
    final count = widget.actions.length;
    final action = _metricsOf(theme, FlFabSize.sm).extent;
    final step = action + theme.space.md;
    // The small buttons share the trigger's axis.
    final inset = math.max(0.0, (_metricsOf(theme, widget.size).extent - action) / 2);
    return SingleChildScrollView(
      reverse: true,
      clipBehavior: Clip.none,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: widget.placement._cross,
        spacing: theme.space.md,
        children: [
          for (final (index, item) in widget.actions.indexed)
            _Unfold(
              reach: _reach(progress, count - 1 - index),
              reduced: reduced,
              rise: (count - index) * step,
              alignment: widget.placement._alignment,
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: widget.placement == FlFabPlacement.bottomCenter ? 0 : inset,
                ),
                child: _DialAction(
                  action: item,
                  leadingButton: widget.placement == FlFabPlacement.bottomStart,
                  onPressed: item.onPressed == null ? null : () => _choose(item),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _menu(FlTheme theme, double progress, bool reduced) {
    final shape = FlContinuousBorder(radius: theme.shape.radiusCard);
    return _Unfold(
      reach: _reach(progress, 0),
      reduced: reduced,
      rise: 0,
      alignment: widget.placement._alignment,
      child: FlShadow(
        layers: theme.shadows.overlay,
        shape: shape,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: theme.colors.surfaceOverlay,
            shape: FlContinuousBorder(
              radius: theme.shape.radiusCard,
              side: BorderSide(color: flOverlayOutline(theme), width: theme.size.border),
            ),
          ),
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: shape),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: theme.size.menuMinWidth, maxWidth: theme.size.menuMaxWidth),
              child: IntrinsicWidth(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, item) in widget.actions.indexed) ...[
                        if (index > 0)
                          ColoredBox(
                            color: theme.colors.separator,
                            child: SizedBox(height: theme.size.border),
                          ),
                        _MenuAction(action: item, onPressed: item.onPressed == null ? null : () => _choose(item)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An animation's value kept between 0 and 1: a spring overshoots, an opacity
/// does not.
class _Clamp extends Animatable<double> {
  const _Clamp();

  @override
  double transform(double t) => t.clamp(0.0, 1.0);
}

/// [child] coming out of the trigger: it fades in, rises by [rise] and grows
/// towards [alignment] as [reach] goes from 0 to 1. Under reduced motion, it
/// only fades.
class _Unfold extends StatelessWidget {
  const _Unfold({
    required this.reach,
    required this.reduced,
    required this.rise,
    required this.alignment,
    required this.child,
  });

  final double reach;
  final bool reduced;
  final double rise;
  final AlignmentDirectional alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A row that has not faded in yet is still a row of the menu.
    final faded = Opacity(opacity: reach.clamp(0.0, 1.0), alwaysIncludeSemantics: true, child: child);
    if (reduced) return faded;
    return Transform.translate(
      offset: Offset(0, (1 - reach) * rise),
      child: Transform.scale(
        scale: lerpDouble(_enterScale, 1, reach),
        alignment: alignment.resolve(Directionality.of(context)),
        child: faded,
      ),
    );
  }
}

/// A dial's action: a small round button, and its label on a chip beside it.
/// The button is the control a screen reader and the keyboard reach; the
/// chip only extends where a finger can land.
class _DialAction extends StatelessWidget {
  const _DialAction({required this.action, required this.leadingButton, required this.onPressed});

  final FlFabAction action;
  final bool leadingButton;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final shape = _shapeOf(theme, BorderSide(color: flOverlayOutline(theme), width: theme.size.border));
    final color = action.destructive ? theme.colors.danger : theme.colors.onSurface;
    final chip = Flexible(
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onPressed,
          child: Opacity(
            opacity: onPressed == null ? theme.size.disabledOpacity : 1,
            child: FlShadow(
              layers: theme.shadows.overlay,
              shape: shape,
              child: DecoratedBox(
                decoration: ShapeDecoration(color: theme.colors.surfaceOverlay, shape: shape),
                child: Padding(
                  padding: EdgeInsetsDirectional.symmetric(horizontal: theme.space.md, vertical: theme.space.xs),
                  child: Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.resolve(FlTextRole.controlSm).copyWith(color: color),
                    strutStyle: theme.typography.strut(
                      FlTextRole.controlSm,
                      inheritedFamily: DefaultTextStyle.of(context).style.fontFamily,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final button = FlPressable(
      onPressed: onPressed,
      label: action.label,
      role: SemanticsRole.menuItem,
      borderRadius: _radiusOf(theme),
      builder: (context, states) => _Face(
        variant: action.destructive ? FlFabVariant.danger : FlFabVariant.surface,
        size: FlFabSize.sm,
        icon: action.icon,
        states: states,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: theme.space.md,
      children: leadingButton ? [button, chip] : [chip, button],
    );
  }
}

/// A menu's row: the label, then the glyph at the end.
class _MenuAction extends StatelessWidget {
  const _MenuAction({required this.action, required this.onPressed});

  final FlFabAction action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    final iconSize = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: theme.size.iconMaxScale)
        .scale(theme.size.buttonIconLg);
    return FlPressable(
      onPressed: onPressed,
      label: action.label,
      role: SemanticsRole.menuItem,
      borderRadius: BorderRadius.zero,
      scaleOnPress: false,
      overlay: FlPressOverlay.none,
      focusRing: FlFocusRingPlacement.inside,
      builder: (context, states) {
        final disabled = states.contains(WidgetState.disabled);
        final lit =
            !disabled &&
            (states.contains(WidgetState.pressed) || (theme.hovers && states.contains(WidgetState.hovered)));
        final fill = action.destructive ? colors.dangerFaint : colors.control;
        return Opacity(
          opacity: disabled ? theme.size.disabledOpacity : 1,
          child: ColoredBox(
            color: lit ? fill : fill.withValues(alpha: 0),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: theme.size.controlCompact),
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(horizontal: theme.space.lg, vertical: theme.space.sm),
                child: Row(
                  spacing: theme.space.lg,
                  children: [
                    Expanded(
                      child: Text(
                        action.label,
                        style: theme.typography
                            .resolve(FlTextRole.textBase)
                            .copyWith(color: action.destructive ? colors.danger : colors.onSurface),
                        strutStyle: theme.typography.strut(
                          FlTextRole.textBase,
                          inheritedFamily: DefaultTextStyle.of(context).style.fontFamily,
                        ),
                      ),
                    ),
                    IconTheme.merge(
                      data: IconThemeData(
                        color: action.destructive ? colors.danger : colors.onSurfaceMuted,
                        size: iconSize,
                      ),
                      child: action.icon,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
