import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/app_bar/fl_app_bar.dart';
import 'package:fliin_ui/components/scroll_shadow/fl_scroll_shadow.dart';
import 'package:fliin_ui/components/separator/fl_separator.dart';
import 'package:fliin_ui/components/spinner/fl_spinner.dart';
import 'package:fliin_ui/core/fliin.dart';

/// "Pull to refresh" on an [FlPage].
final class FlPageRefresh {
  /// A refresh named [label] ("Actualiser") that awaits [onRefresh].
  const FlPageRefresh({required this.label, required this.onRefresh});

  /// What the screen reader reads: the name of the indicator, and of the
  /// action that refreshes without a gesture.
  final String label;

  /// Reloads the content; the indicator spins until the future completes.
  final Future<void> Function() onRefresh;
}

/// The pull that triggers the refresh, and the height the indicator keeps
/// while it spins on iOS: those of the `UIRefreshControl` that
/// `CupertinoSliverRefreshControl` mirrors.
const _trigger = 100.0;
const _held = 60.0;

/// The indicator's disc on Android, and its travel: those of Material's
/// `RefreshIndicator`.
const _disc = 40.0;
const _discTravel = 50.0;

/// The refresh cycle. `done` waits for the gesture to end and the content
/// to settle back: a finger still pulling after the future completes
/// triggers nothing again, as with `UIRefreshControl`.
enum _Phase { idle, pulling, refreshing, done }

/// How the gesture shows: iOS pulls the content and reveals the indicator
/// above it; Android keeps the content and slides a disc down over it.
enum _Gesture { reveal, overlay }

/// The frame of a screen: the `surface` background, a pinned [appBar] that
/// follows the scroll, the content [slivers] in a `CustomScrollView`, a
/// [tabBar] at the bottom, and the safe area shared between them. The bottom
/// safe-area inset comes after the [slivers], which still read it from the
/// `MediaQuery`: no sliver adds it again.
///
/// Scrolling follows the theme's platform: it bounces on iOS and macOS, and
/// clamps elsewhere. The keyboard shrinks the content above it, without
/// lifting the [tabBar], which it covers: a focused field stays visible.
/// With [refresh], pulling the top of the content reloads the page, through
/// the platform's gesture, and the `FlSpinner` spins until it is done.
///
/// With [extendBody], the content runs under the [tabBar] to the bottom of
/// the page, where a floating or translucent bar lets it show; the slivers
/// still end above the bar.
///
/// Transitions, back navigation and Android's predictive back are left to
/// the app's router: the page sets up none of them.
class FlPage extends StatefulWidget {
  /// A page of [slivers].
  const FlPage({
    super.key,
    this.appBar,
    this.tabBar,
    this.extendBody = false,
    this.hideTabBarOnScroll = false,
    this.pinAppBar = true,
    this.floatAppBar = false,
    this.color,
    this.refresh,
    this.controller,
    required this.slivers,
  });

  /// The top bar, pinned at the head of the scroll; when null, the content
  /// starts below the safe area.
  final FlAppBar? appBar;

  /// The bottom navigation, usually an `FlBottomTabBar`, which carries the
  /// bottom safe area; when null, the content keeps it as padding.
  final Widget? tabBar;

  /// False: [appBar] scrolls away with the content, without the background
  /// a pinned bar raises: the screen is all content once scrolled, as a
  /// cart or a sheet-like page. True by default.
  final bool pinAppBar;

  /// True: [appBar] leaves with the content, and comes back as soon as it
  /// scrolls back down, on its glass over the content (`FlFloatingAppBar`):
  /// a feed's bar, out of the way and a flick away. Its title stays at rest.
  /// It wins over [pinAppBar].
  final bool floatAppBar;

  /// The page's color; when null, `surface`. `background`, the theme's base,
  /// sets white cards apart without a shadow, as a theme without shadows
  /// needs.
  final Color? color;

  /// True: the content passes under [tabBar], which must draw its own
  /// background over it (a floating or translucent `FlBottomTabBar`);
  /// false: the content stops at the bar.
  final bool extendBody;

  /// True: [tabBar] slides away as the content scrolls down, and comes back
  /// as soon as it scrolls up, or at either end, as Safari's bar. It stays
  /// put for a screen reader, which reaches the bar by moving to it.
  final bool hideTabBarOnScroll;

  /// "Pull to refresh"; when null, the top of the content reloads nothing.
  final FlPageRefresh? refresh;

  /// The scroll controller; when null, the page holds its own.
  final ScrollController? controller;

  /// The content, below the top bar.
  final List<Widget> slivers;

  @override
  State<FlPage> createState() => _FlPageState();
}

class _FlPageState extends State<FlPage> with SingleTickerProviderStateMixin {
  late final AnimationController _pull = AnimationController.unbounded(vsync: this);
  _Phase _phase = _Phase.idle;
  bool _dragging = false;
  bool _barHidden = false;
  ScrollController? _own;

  ScrollController get _scroll => widget.controller ?? (_own ??= ScrollController());

  _Gesture get _gesture => switch (FlScope.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => _Gesture.reveal,
    _ => _Gesture.overlay,
  };

  @override
  void dispose() {
    _pull.dispose();
    _own?.dispose();
    super.dispose();
  }

  /// Hands over to the next gesture, once the finger is lifted and the
  /// indicator is back to zero.
  void _rearm() {
    if (_phase == _Phase.done && !_dragging && _pull.value == 0) {
      _phase = _Phase.idle;
    }
  }

  /// Drives Android's disc to [target] with the `spatial` spring, or at once
  /// under reduced motion: its travel is a movement, not a fade.
  void _settle(double target) {
    final motion = FlMotion.of(context);
    if (motion.reduced) {
      _pull.value = target;
      _rearm();
    } else {
      unawaited(_pull.driveTo(target, FlSpringMotion(motion.tokens.spatial)).then((_) => _rearm()));
    }
  }

  /// Refreshes. Without a gesture (the screen reader's action), the scroll
  /// goes back to the top to reveal the indicator.
  Future<void> _start({bool gesture = true}) async {
    final refresh = widget.refresh;
    if (refresh == null || _phase == _Phase.refreshing) return;
    setState(() => _phase = _Phase.refreshing);
    switch (_gesture) {
      case _Gesture.reveal:
        if (gesture) unawaited(HapticFeedback.lightImpact());
      case _Gesture.overlay:
        _settle(_trigger);
    }
    if (!gesture) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
    try {
      await refresh.onRefresh();
    } finally {
      if (mounted) {
        setState(() => _phase = _Phase.done);
        if (_gesture == _Gesture.overlay) {
          _settle(0);
        } else {
          _rearm();
        }
      }
    }
  }

  void _reveal() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    final theme = FlScope.of(context);
    if (FlMotion.of(context).reduced) {
      position.jumpTo(position.minScrollExtent);
    } else {
      unawaited(
        position.animateTo(position.minScrollExtent, duration: theme.motion.short4, curve: theme.motion.standard),
      );
    }
  }

  /// Hides the tab bar on a scroll down by the user, shows it on a scroll up
  /// or at an end, reached by a drag or by momentum; a scroll the code
  /// drives elsewhere leaves it as it is.
  void _followBar(ScrollNotification notification) {
    if (!widget.hideTabBarOnScroll || notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return;
    }
    if (notification is! ScrollUpdateNotification) return;
    final metrics = notification.metrics;
    final atEnd = metrics.pixels <= metrics.minScrollExtent || metrics.pixels >= metrics.maxScrollExtent;
    final delta = notification.scrollDelta ?? 0;
    final bool hidden;
    if (atEnd) {
      hidden = false;
    } else if (notification.dragDetails != null && delta != 0) {
      hidden = delta > 0;
    } else {
      return;
    }
    if (hidden != _barHidden) setState(() => _barHidden = hidden);
  }

  bool _onScroll(ScrollNotification notification) {
    _followBar(notification);
    if (widget.refresh == null || notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final metrics = notification.metrics;
    switch (notification) {
      case ScrollStartNotification(:final dragDetails) when dragDetails != null:
        _dragging = true;
      case ScrollEndNotification():
        _dragging = false;
      case _:
    }
    switch ((_gesture, notification)) {
      case (_Gesture.reveal, ScrollUpdateNotification(:final dragDetails)):
        _pull.value = math.max(0.0, metrics.minScrollExtent - metrics.pixels);
        if (_phase == _Phase.idle && dragDetails != null && _pull.value > 0) {
          _phase = _Phase.pulling;
        }
        if (_phase == _Phase.pulling && _pull.value >= _trigger) {
          unawaited(_start());
        }
        if (_phase == _Phase.pulling && dragDetails == null) {
          _phase = _Phase.idle;
        }
      case (_Gesture.overlay, OverscrollNotification(:final overscroll, :final dragDetails))
          when dragDetails != null && overscroll < 0 && (_phase == _Phase.idle || _phase == _Phase.pulling):
        _phase = _Phase.pulling;
        _pull.value -= overscroll;
      case (_Gesture.overlay, ScrollUpdateNotification(:final scrollDelta?)) when _phase == _Phase.pulling:
        _pull.value = math.max(0.0, _pull.value - scrollDelta);
      case (_Gesture.overlay, ScrollEndNotification()) when _phase == _Phase.pulling:
        if (_pull.value >= _trigger) {
          unawaited(_start());
        } else {
          _phase = _Phase.idle;
          _settle(0);
        }
      case _:
    }
    _rearm();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final media = MediaQuery.of(context);
    final appBar = widget.appBar;
    final refresh = widget.refresh;
    final tabBar = widget.tabBar;
    final gesture = _gesture;
    final reveal = gesture == _Gesture.reveal;
    final physics = reveal
        ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
        : const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
    Widget body = NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: (notification) {
          if (refresh != null && notification.leading) {
            notification.disallowIndicator();
          }
          return false;
        },
        child: CustomScrollView(
          controller: _scroll,
          physics: physics,
          slivers: [
            if (appBar != null && widget.floatAppBar)
              SliverPadding(padding: EdgeInsets.only(top: FlFloatingAppBar.restExtent(context, appBar)))
            else if (appBar != null)
              FlSliverAppBar(appBar: appBar, pinned: widget.pinAppBar)
            else
              SliverPadding(padding: EdgeInsets.only(top: media.padding.top)),
            if (refresh != null)
              _RefreshSliver(
                pull: _pull,
                held: reveal && _phase == _Phase.refreshing ? _held : 0,
                gesture: gesture,
                child: _Indicator(
                  pull: _pull,
                  gesture: gesture,
                  refreshing: _phase == _Phase.refreshing,
                  label: refresh.label,
                ),
              ),
            // The bottom inset stays readable by the slivers, so that an
            // empty state can derive its room: `SliverSafeArea` removed it.
            // Keyed: when the indicator or the end under the bar comes and
            // goes, the content keeps its elements, and a field its focus.
            SliverSafeArea(
              key: const ValueKey(_Slot.body),
              top: false,
              bottom: false,
              sliver: SliverMainAxisGroup(slivers: widget.slivers),
            ),
            // Under the bar, its height, which only the body's own
            // `MediaQuery` knows.
            if (widget.extendBody && tabBar != null)
              Builder(
                builder: (context) =>
                    SliverPadding(padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom)),
              )
            else
              SliverPadding(padding: EdgeInsets.only(bottom: media.padding.bottom)),
          ],
        ),
      ),
    );
    // Always there, even without [refresh]: a tree that changed shape when
    // refresh became null recreated the scroll view, and focus got lost.
    // Always a node too: on the web, a node that comes and goes moves the
    // field's input in the page, which takes the focus away from it.
    body = Semantics(
      container: true,
      explicitChildNodes: true,
      label: refresh?.label,
      customSemanticsActions: refresh == null
          ? null
          : {CustomSemanticsAction(label: refresh.label): () => _start(gesture: false)},
      child: body,
    );
    final color = widget.color ?? theme.colors.surface;
    return ColoredBox(
      color: color,
      child: CustomMultiChildLayout(
        delegate: _PageLayout(keyboard: media.viewInsets.bottom, extendBody: widget.extendBody),
        children: [
          LayoutId(
            id: _Slot.body,
            // The room under the bar only comes with the body's constraints,
            // once the bar is measured.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final room = constraints is _BodyConstraints ? constraints.room : 0.0;
                final data = media
                    .removeViewInsets(removeBottom: true)
                    .removePadding(removeBottom: tabBar != null)
                    .removeViewPadding(removeBottom: tabBar != null);
                return MediaQuery(
                  data: room == 0
                      ? data
                      : data.copyWith(
                          padding: data.padding.copyWith(bottom: room),
                          viewPadding: data.viewPadding.copyWith(bottom: room),
                        ),
                  // What passes under the bar is seen blurred, not read: the
                  // screen reader stops at the bar, as on iOS.
                  child: _SemanticsClip(bottom: room, child: body),
                );
              },
            ),
          ),
          if (tabBar != null)
            LayoutId(
              id: _Slot.tabBar,
              child: _PageColor(
                color: widget.color,
                child: widget.hideTabBarOnScroll
                    ? AnimatedSlide(
                        offset: Offset(0, _barHidden && !media.accessibleNavigation ? 1 : 0),
                        duration: FlMotion.of(context).reduced ? Duration.zero : theme.motion.medium2,
                        curve: theme.motion.standard,
                        child: tabBar,
                      )
                    : tabBar,
              ),
            ),
          // A bar that leaves with the content leaves the status bar over
          // it: a strip of the bar's glass keeps the time and the battery
          // readable, and shows nothing at rest, the page's own color.
          if (appBar != null && widget.floatAppBar)
            LayoutId(
              id: _Slot.appBar,
              child: FlFloatingAppBar(appBar: appBar, controller: _scroll),
            )
          else if (appBar != null && !widget.pinAppBar)
            LayoutId(
              id: _Slot.statusBar,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: _glassBlur, sigmaY: _glassBlur),
                  child: ColoredBox(
                    color: color.withValues(alpha: color.a * _glassOpacity),
                    child: SizedBox(height: media.padding.top),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _Slot { body, tabBar, statusBar, appBar }

/// Tells the semantics, not the painting, that [child] is cut [bottom] above
/// its lower edge: a node partly under the bar keeps its visible part, a
/// node wholly under it is hidden. The approximate paint clip is the one
/// Flutter carries down through the scroll view; the semantics clip stops
/// at the viewport.
class _SemanticsClip extends SingleChildRenderObjectWidget {
  const _SemanticsClip({required this.bottom, super.child});

  final double bottom;

  @override
  _RenderSemanticsClip createRenderObject(BuildContext context) => _RenderSemanticsClip(bottom);

  @override
  void updateRenderObject(BuildContext context, _RenderSemanticsClip renderObject) {
    renderObject.bottom = bottom;
  }
}

class _RenderSemanticsClip extends RenderProxyBox {
  _RenderSemanticsClip(this._bottom);

  double _bottom;

  set bottom(double value) {
    if (value == _bottom) return;
    _bottom = value;
    markNeedsSemanticsUpdate();
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _bottom == 0 ? null : Offset.zero & Size(size.width, math.max(0, size.height - _bottom));
}

/// The tab bar at the bottom, at its own height; the content above it, or
/// above the keyboard when it covers the bar. With [extendBody], the content
/// goes down to the bottom, the bar's height as its room.
class _PageLayout extends MultiChildLayoutDelegate {
  _PageLayout({required this.keyboard, required this.extendBody});

  final double keyboard;
  final bool extendBody;

  @override
  void performLayout(Size size) {
    var bar = 0.0;
    if (hasChild(_Slot.tabBar)) {
      bar = layoutChild(_Slot.tabBar, BoxConstraints.tightFor(width: size.width)).height;
      positionChild(_Slot.tabBar, Offset(0, size.height - bar));
    }
    // With the keyboard open, nothing passes under: a tab bar is covered by
    // the keyboard, and a page bar sits on it, the focused field above.
    final under = extendBody && keyboard == 0;
    final height = math.max(0.0, size.height - (under ? 0 : math.max(bar, keyboard)));
    layoutChild(_Slot.body, _BodyConstraints(width: size.width, height: height, room: under ? bar : 0));
    positionChild(_Slot.body, Offset.zero);
    for (final slot in [_Slot.statusBar, _Slot.appBar]) {
      if (!hasChild(slot)) continue;
      layoutChild(slot, BoxConstraints.tightFor(width: size.width));
      positionChild(slot, Offset.zero);
    }
  }

  @override
  bool shouldRelayout(_PageLayout oldDelegate) =>
      keyboard != oldDelegate.keyboard || extendBody != oldDelegate.extendBody;
}

/// The body's tight size, and the [room] the bar takes at its bottom: a
/// change of either builds the body again, as `Scaffold` does for its own.
class _BodyConstraints extends BoxConstraints {
  const _BodyConstraints({required double width, required double height, required this.room})
    : super(minWidth: width, maxWidth: width, minHeight: height, maxHeight: height);

  final double room;

  @override
  bool operator ==(Object other) => other is _BodyConstraints && super == other && room == other.room;

  @override
  int get hashCode => Object.hash(super.hashCode, room);
}

/// The refresh `FlSpinner`: centered in the revealed space on iOS, in a
/// disc that slides down on Android. It appears as the user pulls, and only
/// announces itself while spinning.
class _Indicator extends StatelessWidget {
  const _Indicator({required this.pull, required this.gesture, required this.refreshing, required this.label});

  final Animation<double> pull;
  final _Gesture gesture;
  final bool refreshing;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final spinner = FlSpinner(label: label, color: theme.colors.onSurfaceMuted);
    return AnimatedBuilder(
      animation: pull,
      child: ExcludeSemantics(excluding: !refreshing, child: spinner),
      builder: (context, spinner) {
        final shown = refreshing ? 1.0 : (pull.value / _trigger).clamp(0.0, 1.0);
        // When hidden, the spinner leaves the tree: it does not spin for nothing.
        if (shown == 0) return const SizedBox.shrink();
        return switch (gesture) {
          _Gesture.reveal => Opacity(
            opacity: shown,
            child: Center(child: spinner),
          ),
          _Gesture.overlay => Align(
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: Offset(0, math.min(pull.value / _trigger, 1.0) * _discTravel - _disc),
              child: Opacity(
                opacity: shown,
                child: FlShadow(
                  layers: theme.shadows.overlay,
                  shape: const CircleBorder(),
                  child: SizedBox.square(
                    dimension: _disc,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(color: theme.colors.surfaceRaised, shape: const CircleBorder()),
                      child: Center(child: spinner),
                    ),
                  ),
                ),
              ),
            ),
          ),
        };
      },
    );
  }
}

/// The indicator's sliver, just below the top bar. On iOS, it paints in the
/// space the overscroll opens above it, and keeps [held] of height during
/// the refresh; a scroll offset correction absorbs each change of [held] so
/// the content does not jump. On Android, it takes no room and paints the
/// disc over the content.
class _RefreshSliver extends SingleChildRenderObjectWidget {
  const _RefreshSliver({required this.pull, required this.held, required this.gesture, required Widget super.child});

  final Animation<double> pull;
  final double held;
  final _Gesture gesture;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderRefresh(pull, held, gesture);

  @override
  void updateRenderObject(BuildContext context, _RenderRefresh renderObject) => renderObject
    ..pull = pull
    ..held = held
    ..gesture = gesture;
}

class _RenderRefresh extends RenderSliver with RenderObjectWithChildMixin<RenderBox> {
  _RenderRefresh(this._pull, this._held, this._gesture);

  Animation<double> _pull;
  set pull(Animation<double> value) {
    if (value == _pull) return;
    if (attached) _pull.removeListener(markNeedsLayout);
    _pull = value;
    if (attached) _pull.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  double _held;
  set held(double value) {
    if (value == _held) return;
    _held = value;
    markNeedsLayout();
  }

  _Gesture _gesture;
  set gesture(_Gesture value) {
    if (value == _gesture) return;
    _gesture = value;
    markNeedsLayout();
  }

  double _compensated = 0;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _pull.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _pull.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void performLayout() {
    final box = child!;
    if (_held != _compensated) {
      geometry = SliverGeometry(scrollOffsetCorrection: _held - _compensated);
      _compensated = _held;
      return;
    }
    final scrolled = constraints.scrollOffset;
    switch (_gesture) {
      case _Gesture.reveal:
        final gap = math.max(0.0, _pull.value);
        final total = gap + _held;
        box.layout(BoxConstraints.tightFor(width: constraints.crossAxisExtent, height: total));
        final paint = (total - scrolled).clamp(0.0, constraints.remainingPaintExtent);
        geometry = SliverGeometry(
          scrollExtent: _held,
          paintOrigin: -gap,
          paintExtent: paint,
          layoutExtent: (_held - scrolled).clamp(0.0, paint),
          maxPaintExtent: total,
          hasVisualOverflow: true,
        );
      case _Gesture.overlay:
        box.layout(BoxConstraints.tightFor(width: constraints.crossAxisExtent, height: _discTravel));
        final visible = _pull.value > 0 && scrolled == 0;
        geometry = SliverGeometry(
          paintExtent: visible ? math.min(_discTravel, constraints.remainingPaintExtent) : 0,
          layoutExtent: 0,
          maxPaintExtent: _discTravel,
          hasVisualOverflow: true,
        );
    }
  }

  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final geometry = this.geometry!;
    if (geometry.paintExtent <= 0) {
      _clip.layer = null;
      return;
    }
    switch (_gesture) {
      case _Gesture.reveal:
        _clip.layer = null;
        context.paintChild(child!, offset + Offset(0, -constraints.scrollOffset));
      case _Gesture.overlay:
        // The disc comes out of the sliver's top edge, below the top bar,
        // without passing over it when the bar is transparent.
        _clip.layer = context.pushClipRect(
          needsCompositing,
          offset,
          Offset.zero & Size(constraints.crossAxisExtent, geometry.paintExtent),
          (context, offset) => context.paintChild(child!, offset),
          oldLayer: _clip.layer,
        );
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (_gesture == _Gesture.reveal) {
      transform.translateByDouble(0, -constraints.scrollOffset, 0, 1);
    }
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) => false;
}

/// The blur behind a translucent page bar, and how opaque its background
/// gets: those of the raised `FlAppBar` and the translucent tab bar.
const _glassBlur = 20.0;
const _glassOpacity = 0.85;

/// The action bar at the bottom of a screen, to place in the `tabBar` slot of
/// an [FlPage]: a divider, what the screen says next to the action ([info]: a
/// notice, the billed amount), then the [action] ("Payer", "S'abonner"). The
/// background is `surfaceRaised`, and the bottom safe area is kept. With
/// [plain], neither background nor divider: the action seems to sit on the
/// page, and the content stops above it. With [translucent], the background
/// lets the content show through, blurred: give the page `extendBody` so the
/// content passes under the bar. With [floating], no band at all: the action
/// floats over the content, and [info] sits on a white card of its own, to
/// stay readable over what passes under it; give the page `extendBody` too.
///
/// It takes at most half of the screen's height, and with the keyboard open,
/// half of the room above it. Beyond that (a much enlarged text, a long
/// notice), [info] scrolls within its share, with an edge shadow where text
/// is hidden, and the [action] stays at the bottom, always on screen: without
/// this cap, the bar could push the content and the top bar off the screen.
/// An action taller than the whole bar (an extreme text size) scrolls in
/// turn, its bottom on screen. With the keyboard open, the bar sits on it,
/// unlike a tab bar, which the keyboard covers: the primary button stays
/// visible while typing. [info] keeps its focus order, and the screen reader
/// scrolls through it.
class FlPageBar extends StatelessWidget {
  /// The bar of the [action], below [info].
  const FlPageBar({
    super.key,
    this.info = const [],
    this.action,
    this.plain = false,
    this.translucent = false,
    this.floating = false,
  });

  /// What is said above the action, top to bottom; when empty, the action
  /// alone.
  final List<Widget> info;

  /// The primary action, an `FlButton` or a row of buttons; when null, the
  /// bar only says [info] (a removed line that can be restored, in a cart
  /// that became empty).
  final Widget? action;

  /// True: no background nor divider, on the page's color.
  final bool plain;

  /// True: the `surfaceRaised` background lets what passes under it show,
  /// blurred, as through iOS's bars. No effect with [plain].
  final bool translucent;

  /// True: neither background, blur nor divider; the action floats over the
  /// content, and [info] sits on a white card. Takes precedence over [plain]
  /// and [translucent].
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final space = theme.space;
    final colors = theme.colors;
    // With the keyboard open, the bar sits on it: the action stays visible,
    // and the content stops above it (`_PageLayout`). The cap includes the
    // bottom safe area: the bar never takes more than half of the room above
    // the keyboard.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final line = 1 / MediaQuery.devicePixelRatioOf(context);
    // The bottom safe area replaces the bar's last `space.md` instead of
    // adding to it, as in the canvas's frames.
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, space.md);
    final glass = translucent && !plain && !floating;
    // On a page of its own color, the bar is of that color, without a rule:
    // a white band would cut the page's base.
    final page = context.dependOnInheritedWidgetOfExactType<_PageColor>()?.color;
    final background = page ?? (plain ? colors.surface : colors.surfaceRaised);
    Widget bar = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: (MediaQuery.sizeOf(context).height - keyboard) / 2),
      child: SafeArea(
        top: false,
        bottom: false,
        // The action keeps its height as long as it fits; taller than the
        // whole bar (an extreme text size), it scrolls, its bottom on screen.
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!plain && !floating && page == null) FlSeparator(thickness: line),
              if (info.isNotEmpty && floating)
                Flexible(
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(space.lg, space.md, space.lg, action == null ? bottom : 0),
                    child: FlShadow(
                      layers: theme.shadows.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.shape.radiusCard)),
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: colors.surfaceRaised,
                          shape: FlContinuousBorder(radius: theme.shape.radiusCard),
                        ),
                        child: FlScrollShadow(
                          color: colors.surfaceRaised,
                          size: space.xl,
                          child: SingleChildScrollView(
                            padding: EdgeInsetsDirectional.all(space.md),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: space.sm,
                              children: info,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else if (info.isNotEmpty)
                Flexible(
                  child: FlScrollShadow(
                    color: background,
                    size: space.xl,
                    child: SingleChildScrollView(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        space.lg,
                        space.md,
                        space.lg,
                        action == null ? bottom : 0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        // gap-2 of Izydesk's page bar.
                        spacing: space.sm,
                        children: info,
                      ),
                    ),
                  ),
                ),
              if (action case final action?)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: constraints.maxHeight - (plain || floating ? 0 : line)),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        space.lg,
                        info.isEmpty ? space.md : space.sm,
                        space.lg,
                        bottom,
                      ),
                      child: action,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (!floating) {
      bar = ColoredBox(
        color: glass ? background.withValues(alpha: background.a * _glassOpacity) : background,
        child: bar,
      );
    }
    if (glass) {
      bar = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _glassBlur, sigmaY: _glassBlur),
          child: bar,
        ),
      );
    }
    return keyboard == 0
        ? bar
        : Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: bar,
          );
  }
}

/// The color [FlPage.color] gives the page, for its bottom bar; null, the
/// page keeps `surface`.
class _PageColor extends InheritedWidget {
  const _PageColor({required this.color, required super.child});

  final Color? color;

  @override
  bool updateShouldNotify(_PageColor oldWidget) => oldWidget.color != color;
}
