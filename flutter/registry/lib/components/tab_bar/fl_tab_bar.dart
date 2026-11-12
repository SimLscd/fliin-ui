// The sliding pill is modified from the Tabs indicator of HeroUI Native 1.0.10,
// Copyright 2025 NextUI Inc., licensed under Apache 2.0:
// https://www.apache.org/licenses/LICENSE-2.0
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';

/// A tab of an [FlBottomTabBar].
final class FlBottomTab {
  /// The [label] tab, drawn by [icon], or by [selectedIcon] once chosen,
  /// with a [badge].
  const FlBottomTab({required this.icon, this.selectedIcon, required this.label, this.badge});

  /// The icon, which reads its color and size from the `IconTheme`.
  final Widget icon;

  /// The icon of the chosen tab, which cross-fades with [icon] as the
  /// selection arrives: a filled glyph for an outlined one. When null,
  /// [icon] stays.
  final Widget? selectedIcon;

  /// The label under the icon, read by the screen reader even when the bar
  /// does not show it.
  final String label;

  /// A badge at the icon's corner (a count, a dot); its semantics are added
  /// to the tab's label.
  final Widget? badge;
}

/// Which tabs of an [FlBottomTabBar] show their label.
enum FlBottomTabLabels {
  /// Every tab, under its icon.
  always,

  /// The chosen tab only: its label rises under the icon, and the other
  /// icons sit in the middle of the bar.
  selected,

  /// None: icons only, the chosen one in a pill as tall as a touch target.
  /// The labels are still read.
  never,
}

/// What marks the chosen tab of an [FlBottomTabBar], besides its colors.
enum FlBottomTabIndicator {
  /// A pill under the icon (Izydesk's `.tab-pill`).
  pill,

  /// A shape behind the whole tab, icon and label.
  capsule,

  /// Nothing: the chosen tab only takes its colors.
  none,
}

/// The side of the tab icons, Izydesk's `.tab .i`.
const _iconSize = 22.0;

/// The pill of the selected tab, around the icon: Izydesk's `.tab-pill`.
const _pillWidth = 56.0;
const _pillHeight = 30.0;

/// The pill of a bar without labels: as tall as a touch target, and fully
/// rounded, so that the chosen icon sits in a button-sized capsule instead
/// of a thin band.
const _iconPillWidth = 72.0;
const _iconPillHeight = 44.0;

/// The pill around the chosen icon, larger when no label follows it.
Size _pillOf(FlBottomTabLabels labels) => labels == FlBottomTabLabels.never
    ? const Size(_iconPillWidth, _iconPillHeight)
    : const Size(_pillWidth, _pillHeight);

/// The widest a tab of a floating bar gets: past it, on a tablet or a
/// desktop, the bar stops growing and stays centered.
const _floatingTabWidth = 96.0;

/// The blur behind a translucent bar, and how opaque its background gets:
/// those of the raised `FlAppBar`.
const _glassBlur = 20.0;
const _glassOpacity = 0.85;

/// An app's bottom navigation: three to five [tabs] side by side, the icon
/// above its label, above the bottom safe area.
///
/// By default the bar is docked: a `surfaceRaised` band across the bottom,
/// under a separator. [floating] detaches it from the edges into a
/// `surfaceOverlay` shape lifted by the `overlay` shadow, whose corners
/// follow `shape.button` like those of a floating `FlToolbar` (a capsule by
/// default). [translucent] blurs what passes under either one, as the raised
/// `FlAppBar` does; in a `FlPage`, set `extendBody` so that the content runs
/// under the bar.
///
/// The chosen tab [index] takes its [FlBottomTab.selectedIcon] in `selected`
/// and an `onSurface` label; the others are muted. [labels] says which tabs
/// show their label, and [indicator] what lies under the chosen one: a
/// `controlPressed` pill under the icon, a capsule behind the whole tab, or
/// nothing. The indicator slides to the chosen tab with the `segment` spring
/// of the tabs' indicator; under reduced motion, it fades in in place.
///
/// The tabs follow one another by keyboard (tab and arrows) and activate
/// with Enter or Space; the screen reader reads a tab bar with exactly one
/// selected, each tab by its label, shown or not. The bar does not change
/// tabs by itself: [onSelected] receives the tapped index, even the one
/// already selected, which the app can use to scroll its list back to the
/// top.
class FlBottomTabBar extends StatefulWidget {
  /// A bar of [tabs], with tab [index] selected.
  const FlBottomTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onSelected,
    this.floating = false,
    this.translucent = false,
    this.labels = FlBottomTabLabels.always,
    this.indicator = FlBottomTabIndicator.pill,
  }) : assert(tabs.length >= 3 && tabs.length <= 5, 'three to five tabs'),
       assert(index >= 0 && index < tabs.length);

  /// The tabs, in reading order.
  final List<FlBottomTab> tabs;

  /// The selected tab.
  final int index;

  /// Called with the index of the tapped tab.
  final ValueChanged<int> onSelected;

  /// True: a shape detached from the screen's edges, lifted by a shadow;
  /// false: a band across the bottom.
  final bool floating;

  /// True: the background lets the content under it show, blurred.
  final bool translucent;

  /// Which tabs show their label.
  final FlBottomTabLabels labels;

  /// What lies under the chosen tab.
  final FlBottomTabIndicator indicator;

  @override
  State<FlBottomTabBar> createState() => _FlBottomTabBarState();
}

/// Where a bar's tabs and indicator sit: the margin of the [indicator]
/// capsule around a tab, the [padding] of the tab's content inside it, and
/// the radius of both shapes.
typedef _Geometry = ({double inset, double padding, double radius});

class _FlBottomTabBarState extends State<FlBottomTabBar> with TickerProviderStateMixin {
  late final AnimationController _position = AnimationController.unbounded(vsync: this, value: widget.index.toDouble());
  late final AnimationController _fade = AnimationController(vsync: this, value: 1);

  @override
  void didUpdateWidget(FlBottomTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    final motion = FlMotion.of(context);
    if (motion.reduced) {
      _position.value = widget.index.toDouble();
      _fade.value = 0;
      _fade.driveTo(1, FlFadeMotion(motion.tokens.short3));
    } else {
      _position.driveTo(widget.index.toDouble(), FlSpringMotion(motion.tokens.segment));
    }
  }

  @override
  void dispose() {
    _position.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final floating = widget.floating;
    final _Geometry geometry = floating
        // The bar's own padding is the capsule's margin: both shapes stay
        // concentric.
        ? (
            inset: 0,
            padding: theme.space.xs,
            radius: switch (theme.shape.button) {
              FlButtonShape.square => 0,
              FlButtonShape.rounded => theme.shape.radiusButton,
              FlButtonShape.pill => double.infinity,
            },
          )
        : (inset: theme.space.xs, padding: theme.space.sm - theme.space.xs, radius: theme.shape.radiusCard);

    final Widget tabs = FocusTraversalGroup(
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(TraversalDirection.left),
          SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(TraversalDirection.right),
        },
        child: Actions(
          actions: {DirectionalFocusIntent: DirectionalFocusAction()},
          child: CustomPaint(
            painter: _IndicatorPainter(
              position: _position,
              fade: _fade,
              count: widget.tabs.length,
              rtl: rtl,
              indicator: widget.indicator,
              rising: widget.labels == FlBottomTabLabels.selected,
              labels: widget.labels,
              pill: _pillOf(widget.labels),
              geometry: geometry,
              color: colors.controlPressed,
            ),
            child: Semantics(
              container: true,
              role: SemanticsRole.tabBar,
              explicitChildNodes: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, tab) in widget.tabs.indexed)
                    Expanded(
                      child: _Tab(
                        tab: tab,
                        selected: i == widget.index,
                        nearness: _position,
                        index: i,
                        labels: widget.labels,
                        indicator: widget.indicator,
                        geometry: geometry,
                        onPressed: () => widget.onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final media = MediaQuery.paddingOf(context);
    if (!floating) {
      return _Background(
        translucent: widget.translucent,
        color: colors.surfaceRaised,
        shape: const RoundedRectangleBorder(),
        shadow: const [],
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: colors.separator, width: theme.size.border),
            ),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              top: theme.size.border,
              bottom: media.bottom,
              start: theme.space.sm,
              end: theme.space.sm,
            ),
            child: SafeArea(top: false, bottom: false, child: tabs),
          ),
        ),
      );
    }

    final inset = theme.space.xs;
    final shape = geometry.radius == double.infinity
        ? const StadiumBorder()
        : FlContinuousBorder(radius: geometry.radius == 0 ? 0 : geometry.radius + inset);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: theme.space.lg,
        end: theme.space.lg,
        // Into the bottom safe area, above the home indicator, as iOS's own
        // floating bar sits.
        bottom: math.max(media.bottom - theme.space.sm, theme.space.lg),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.tabs.length * _floatingTabWidth + 2 * inset),
            child: _Background(
              translucent: widget.translucent,
              color: colors.surfaceOverlay,
              shape: shape,
              shadow: theme.shadows.overlay,
              child: Padding(padding: EdgeInsetsDirectional.all(inset), child: tabs),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar's [color] in [shape], over its [shadow]; when [translucent], see
/// through and blurring what lies under it.
class _Background extends StatelessWidget {
  const _Background({
    required this.translucent,
    required this.color,
    required this.shape,
    required this.shadow,
    required this.child,
  });

  final bool translucent;
  final Color color;
  final ShapeBorder shape;
  final List<FlShadowLayer> shadow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Widget filled = translucent
        ? ClipPath(
            clipper: ShapeBorderClipper(shape: shape, textDirection: Directionality.of(context)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: _glassBlur, sigmaY: _glassBlur),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: color.withValues(alpha: color.a * _glassOpacity),
                  shape: shape,
                ),
                child: child,
              ),
            ),
          )
        : DecoratedBox(
            decoration: ShapeDecoration(color: color, shape: shape),
            child: child,
          );
    return shadow.isEmpty ? filled : FlShadow(layers: shadow, shape: shape, child: filled);
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.tab,
    required this.selected,
    required this.nearness,
    required this.index,
    required this.labels,
    required this.indicator,
    required this.geometry,
    required this.onPressed,
  });

  final FlBottomTab tab;
  final bool selected;

  /// The indicator's position, from which the tab derives its colors.
  final Animation<double> nearness;
  final int index;
  final FlBottomTabLabels labels;
  final FlBottomTabIndicator indicator;
  final _Geometry geometry;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    final radius = geometry.radius;
    final pill = indicator == FlBottomTabIndicator.pill;
    return FlPressable(
      onPressed: onPressed,
      role: SemanticsRole.tab,
      // A capsule, when the radius is: the ring rounds down to the tab.
      borderRadius: BorderRadius.circular(math.min(radius, _floatingTabWidth)),
      scaleOnPress: false,
      overlay: FlPressOverlay.none,
      focusRing: FlFocusRingPlacement.inside,
      builder: (context, states) {
        // Hovered or pressed, a tab not chosen shows the indicator's shape in
        // `surfaceSecondary`, under the sliding one.
        final touched = !selected && (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed));
        return Semantics(
          selected: selected,
          // The label comes first, before the badge's semantics, whether the
          // bar shows it or not.
          label: tab.label,
          child: AnimatedBuilder(
            animation: nearness,
            builder: (context, _) {
              final t = (1 - (nearness.value - index).abs()).clamp(0.0, 1.0);
              final content = _Content(tab: tab, t: t, labels: labels, touched: touched && pill);
              return Padding(
                // The pill's tab keeps its whole width for the label.
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: pill ? 0 : geometry.inset,
                  vertical: geometry.inset,
                ),
                child: DecoratedBox(
                  decoration: touched && !pill
                      ? ShapeDecoration(
                          color: colors.surfaceSecondary,
                          shape: FlContinuousBorder(radius: radius),
                        )
                      : const BoxDecoration(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: geometry.padding),
                    child: content,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// The icon and the label of a tab, [t] of the way to chosen.
class _Content extends StatelessWidget {
  const _Content({required this.tab, required this.t, required this.labels, required this.touched});

  final FlBottomTab tab;
  final double t;
  final FlBottomTabLabels labels;

  /// Whether to show the pill under the icon in `surfaceSecondary`.
  final bool touched;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    final selectedIcon = tab.selectedIcon;
    final badge = tab.badge;
    final pill = _pillOf(labels);
    final icon = Container(
      height: pill.height,
      width: pill.width,
      decoration: touched
          ? ShapeDecoration(
              color: colors.surfaceSecondary,
              shape: FlContinuousBorder(radius: _pillRadius(labels, theme.shape.radiusCard, pill.height)),
            )
          : null,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IconTheme.merge(
              data: IconThemeData(
                size: _iconSize,
                // The chosen tab's icon in `selected`, the selection color;
                // its label stays in `onSurface`, which text contrast needs.
                color: Color.lerp(colors.onSurfaceMuted, colors.selected, t),
              ),
              child: SizedBox.square(
                dimension: _iconSize,
                child: selectedIcon == null
                    ? Center(child: tab.icon)
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(opacity: 1 - t, child: tab.icon),
                          Opacity(opacity: t, child: selectedIcon),
                        ],
                      ),
              ),
            ),
            if (badge != null)
              PositionedDirectional(top: -theme.space.xs, start: _iconSize - theme.space.sm, child: badge),
          ],
        ),
      ),
    );
    final gap = theme.space.xs / 2;
    switch (labels) {
      case FlBottomTabLabels.never:
        return Center(heightFactor: 1, child: icon);
      case FlBottomTabLabels.always:
        return Column(
          mainAxisSize: MainAxisSize.min,
          spacing: gap,
          children: [
            icon,
            _Label(tab.label, t: t),
          ],
        );
      case FlBottomTabLabels.selected:
        // The tab keeps the height of an icon and a label, so that the bar
        // does not move; the icon rises as its label unfolds under it.
        return Stack(
          alignment: Alignment.center,
          children: [
            Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: gap,
                children: [
                  const SizedBox(height: _pillHeight),
                  _Label(tab.label, t: 0),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                if (t > 0)
                  ClipRect(
                    child: Align(
                      alignment: AlignmentDirectional.topCenter,
                      heightFactor: t,
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(top: gap),
                        child: Opacity(
                          opacity: t,
                          child: _Label(tab.label, t: t),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
    }
  }
}

/// A tab's [label], [t] of the way from muted to `onSurface`; the tab's
/// semantics read it.
class _Label extends StatelessWidget {
  const _Label(this.label, {required this.t});

  final String label;
  final double t;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    const role = FlTextRole.caption;
    return ExcludeSemantics(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        textAlign: TextAlign.center,
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: theme.size.iconMaxScale),
        style: theme.typography
            .resolve(role)
            .copyWith(
              color: Color.lerp(colors.onSurfaceMuted, colors.onSurface, t),
              // Medium, not Izydesk's regular: at 12, regular Arabic labels
              // fail the measured contrast.
              fontWeight: theme.tokens.typography.weight.medium,
            ),
        strutStyle: theme.typography.strut(role, inheritedFamily: DefaultTextStyle.of(context).style.fontFamily),
      ),
    );
  }
}

/// [radius], a capsule at most on a side of [extent].
double _capped(double radius, double extent) => radius < extent / 2 ? radius : extent / 2;

/// The corners of the pill on a side of [extent]: a capsule around an icon
/// alone, [radius] at most otherwise.
double _pillRadius(FlBottomTabLabels labels, double radius, double extent) =>
    labels == FlBottomTabLabels.never ? extent / 2 : _capped(radius, extent);

/// The indicator under the tab that [position] designates, halfway between
/// two tabs during the spring.
class _IndicatorPainter extends CustomPainter {
  _IndicatorPainter({
    required this.position,
    required this.fade,
    required this.count,
    required this.rtl,
    required this.indicator,
    required this.rising,
    required this.labels,
    required this.pill,
    required this.geometry,
    required this.color,
  }) : super(repaint: Listenable.merge([position, fade]));

  final Animation<double> position;
  final Animation<double> fade;
  final int count;
  final bool rtl;
  final FlBottomTabIndicator indicator;

  /// Whether the chosen icon rises above its label ([FlBottomTabLabels.selected]),
  /// which the pill follows.
  final bool rising;

  /// The labels, which set the pill's size and its corners.
  final FlBottomTabLabels labels;

  /// The size of the pill, which follows the labels.
  final Size pill;
  final _Geometry geometry;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (indicator == FlBottomTabIndicator.none) return;
    final slot = size.width / count;
    final along = (position.value + 0.5) * slot;
    final x = rtl ? size.width - along : along;
    final Rect rect;
    final double radius;
    if (indicator == FlBottomTabIndicator.capsule) {
      final inset = geometry.inset;
      rect = Rect.fromLTRB(x - slot / 2 + inset, inset, x + slot / 2 - inset, size.height - inset);
      radius = _capped(geometry.radius, rect.shortestSide);
    } else {
      final top = geometry.inset + geometry.padding;
      // A tab is as tall as its icon and the room of a label; an icon not
      // chosen sits halfway down that room. Between two tabs, the pill
      // passes between their heights.
      final room = size.height - 2 * top - pill.height;
      final f = position.value - position.value.floorToDouble();
      final drop = rising ? room * f * (1 - f) : 0.0;
      rect = Rect.fromCenter(center: Offset(x, top + drop + pill.height / 2), width: pill.width, height: pill.height);
      radius = _pillRadius(labels, geometry.radius, pill.height);
    }
    canvas.drawPath(
      FlContinuousBorder.pathFor(rect, radius),
      Paint()..color = color.withValues(alpha: color.a * fade.value.clamp(0.0, 1.0)),
    );
  }

  @override
  bool shouldRepaint(_IndicatorPainter oldDelegate) =>
      count != oldDelegate.count ||
      rtl != oldDelegate.rtl ||
      indicator != oldDelegate.indicator ||
      rising != oldDelegate.rising ||
      labels != oldDelegate.labels ||
      pill != oldDelegate.pill ||
      geometry != oldDelegate.geometry ||
      color != oldDelegate.color;
}
