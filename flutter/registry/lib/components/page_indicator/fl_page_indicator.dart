import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The look of an [FlPageIndicator].
enum FlPageIndicatorVariant {
  /// Izydesk's `.dots`: dots of 8, 8 apart, the current page a `selected`
  /// pill of 24, the others `onSurfaceMuted` at 40 %.
  dots,

  /// The header of Izydesk's onboarding: thin bars 6 high, 5 apart, the
  /// current page 40 long, all in `onSurface`, the others at 30 %.
  bars,

  /// Small round dots of 6, 4 apart, all the same size: the current page in
  /// `selected`, the others `onSurfaceMuted` at 40 %. Under a post's photos,
  /// where a pill would weigh more than the photos' count needs.
  circles,
}

/// The dots of a sequence of pages (onboarding, carousel): the current page
/// stretches into a pill, the others stay dots, or every dot stays round and
/// the current one takes the color ([variant]): solid capsules, gaps from the
/// `spacing` scale.
///
/// Bound to a `PageController` ([FlPageIndicator.controller]), it follows the
/// finger from one page to the next. On a given page ([FlPageIndicator]), the
/// pill slides there with the `motion.spring.indicator` spring, or jumps
/// there under reduced motion.
///
/// Touch follows the platform: on iOS, like `UIPageControl`, a tap before or
/// after the middle goes back or forward one page, and a drag scrubs through
/// the dots; elsewhere, a tap picks the nearest dot. The screen reader reads
/// a single adjustable node ("page 2 of 3"), and the keyboard arrows change
/// page.
class FlPageIndicator extends StatefulWidget {
  /// The dots of [count] pages, on page [index]. [onChanged] receives the
  /// page chosen by touch, keyboard or screen reader; when null, the dots
  /// cannot be chosen.
  const FlPageIndicator({
    super.key,
    required this.count,
    required int this.index,
    this.onChanged,
    required this.pageLabel,
    this.semanticLabel,
    this.variant = FlPageIndicatorVariant.dots,
    this.color,
    this.inactiveColor,
  }) : assert(count > 0, 'at least one page'),
       controller = null;

  /// The dots of [controller]'s pages, which they follow. Without
  /// [onChanged], a choice animates the page view there in `medium2`, or
  /// jumps there under reduced motion.
  const FlPageIndicator.controller({
    super.key,
    required this.count,
    required PageController this.controller,
    this.onChanged,
    required this.pageLabel,
    this.semanticLabel,
    this.variant = FlPageIndicatorVariant.dots,
    this.color,
    this.inactiveColor,
  }) : assert(count > 0, 'at least one page'),
       index = null;

  /// The number of pages.
  final int count;

  /// Receives the chosen page, from 0 to [count] - 1.
  final ValueChanged<int>? onChanged;

  /// The value read by the screen reader, the page counted from 1:
  /// `(page, count) => 'Page $page of $count'`.
  final String Function(int page, int count) pageLabel;

  /// What the dots stand for ("Introduction"); when null, the value alone.
  final String? semanticLabel;

  /// The current page, from 0 to [count] - 1; null with [controller].
  final int? index;

  /// The followed page view; null with [index].
  final PageController? controller;

  /// Round dots, or the thin bars of an onboarding's header.
  final FlPageIndicatorVariant variant;

  /// The current page's color: over a photo or a colored banner, the color
  /// written on it (`onAccent` on `accent`). When null: `selected` for the
  /// dots, `onSurface` for the bars.
  final Color? color;

  /// The other pages' color. When null: [color] at 40 % for the dots and 30 %
  /// for the bars, or, without [color], `onSurfaceMuted` at 40 % and
  /// `onSurface` at 30 %.
  final Color? inactiveColor;

  @override
  State<FlPageIndicator> createState() => _FlPageIndicatorState();
}

class _FlPageIndicatorState extends State<FlPageIndicator> with SingleTickerProviderStateMixin {
  /// The pill's position in pages, fractional during a movement.
  late final AnimationController _position = AnimationController.unbounded(vsync: this, value: _target.toDouble());

  bool _focused = false;

  PageController? get _controller => widget.controller;

  /// The page to reach: the given index, or the controller's rounded page.
  int get _target => (widget.index ?? _controllerPage(widget.controller!).round()).clamp(0, widget.count - 1);

  double _controllerPage(PageController controller) => controller.hasClients && controller.position.hasContentDimensions
      ? controller.page ?? controller.initialPage.toDouble()
      : controller.initialPage.toDouble();

  @override
  void initState() {
    super.initState();
    _controller?.addListener(_follow);
  }

  @override
  void didUpdateWidget(FlPageIndicator old) {
    super.didUpdateWidget(old);
    final previous = old.controller;
    if (previous != _controller) {
      previous?.removeListener(_follow);
      _controller?.addListener(_follow);
      _position.value = _target.toDouble();
      return;
    }
    final index = widget.index;
    if (index != null && index != old.index) {
      if (FlMotion.of(context).reduced) {
        _position.value = index.toDouble();
      } else {
        _position.driveTo(index.toDouble(), FlSpringMotion(FlScope.of(context).motion.indicator));
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_follow);
    _position.dispose();
    super.dispose();
  }

  /// A page view is followed with the finger, without a spring; the value
  /// read changes halfway.
  void _follow() {
    final before = _position.value.round();
    _position.value = _controllerPage(_controller!);
    if (_position.value.round() != before) setState(() {});
  }

  void _choose(int page) {
    final clamped = page.clamp(0, widget.count - 1);
    if (clamped == _target) return;
    final onChanged = widget.onChanged;
    if (onChanged != null) {
      onChanged(clamped);
      return;
    }
    final controller = _controller;
    if (controller == null || !controller.hasClients) return;
    if (FlMotion.of(context).reduced) {
      controller.jumpToPage(clamped);
    } else {
      final motion = FlScope.of(context).motion;
      controller.animateToPage(clamped, duration: motion.medium2, curve: motion.standard);
    }
  }

  /// The page the drag has reached: the parent or the page view has not
  /// rendered it yet, and each move only acts when it changes.
  int? _scrub;

  /// The iOS drag scrubs through the dots like `UIPageControl`: the page
  /// view jumps there, without animation.
  void _scrubTo(int page) {
    final clamped = page.clamp(0, widget.count - 1);
    if (clamped == (_scrub ?? _target)) return;
    _scrub = clamped;
    final onChanged = widget.onChanged;
    if (onChanged != null) {
      onChanged(clamped);
    } else if (_controller case final controller? when controller.hasClients) {
      controller.jumpToPage(clamped);
    }
  }

  bool get _interactive => widget.onChanged != null || _controller != null;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    final xs = theme.space.xs;
    final bars = widget.variant == FlPageIndicatorVariant.bars;
    final metrics = switch (widget.variant) {
      FlPageIndicatorVariant.bars => _Metrics(dot: xs * 1.5, pill: xs * 10, gap: xs * 1.25, count: widget.count),
      FlPageIndicatorVariant.dots => _Metrics(dot: xs * 2, pill: xs * 6, gap: xs * 2, count: widget.count),
      FlPageIndicatorVariant.circles => _Metrics(dot: xs * 1.5, pill: xs * 1.5, gap: xs, count: widget.count),
    };
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final ios = theme.platform == TargetPlatform.iOS;
    final target = _target;
    final interactive = _interactive;
    final forward = rtl ? -1 : 1;

    int pageAt(double x) {
      final along = rtl ? metrics.width - x : x;
      return metrics.nearest(along, target);
    }

    void tap(TapUpDetails details) {
      final x = details.localPosition.dx;
      if (!ios) return _choose(pageAt(x));
      final after = (x > metrics.width / 2) != rtl;
      _choose(target + (after ? 1 : -1));
    }

    final active = widget.color ?? (bars ? colors.onSurface : colors.selected);
    final faded = widget.color ?? (bars ? colors.onSurface : colors.onSurfaceMuted);
    final inactive = widget.inactiveColor ?? faded.withValues(alpha: faded.a * (bars ? _barOpacity : _inactiveOpacity));
    Widget dots = CustomPaint(
      size: Size(metrics.width, metrics.dot),
      painter: _Dots(position: _position, metrics: metrics, active: active, inactive: inactive, rtl: rtl),
    );
    if (interactive) {
      dots = GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapUp: tap,
        onHorizontalDragStart: ios ? (_) => _scrub = target : null,
        onHorizontalDragUpdate: ios ? (details) => _scrubTo(pageAt(details.localPosition.dx)) : null,
        onHorizontalDragEnd: ios ? (_) => _scrub = null : null,
        onHorizontalDragCancel: ios ? () => _scrub = null : null,
        child: dots,
      );
    }
    final canIncrease = interactive && target < widget.count - 1;
    final canDecrease = interactive && target > 0;
    return FocusableActionDetector(
      enabled: interactive,
      mouseCursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(forward),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(-forward),
        const SingleActivator(LogicalKeyboardKey.home): const _EdgeIntent(end: false),
        const SingleActivator(LogicalKeyboardKey.end): const _EdgeIntent(end: true),
      },
      // An arrow that would change nothing is not consumed: it bubbles up
      // to the page, which may use it.
      actions: {
        _StepIntent: _PageAction<_StepIntent>(
          interactive: interactive,
          count: widget.count,
          target: target,
          pageOf: (intent) => target + intent.pages,
          choose: _choose,
        ),
        _EdgeIntent: _PageAction<_EdgeIntent>(
          interactive: interactive,
          count: widget.count,
          target: target,
          pageOf: (intent) => intent.end ? widget.count - 1 : 0,
          choose: _choose,
        ),
      },
      onShowFocusHighlight: (visible) => setState(() => _focused = visible),
      child: FlFocusRing(
        visible: _focused,
        borderRadius: BorderRadius.circular(metrics.dot / 2),
        // The node sits under the target, which gives it its rectangle.
        child: FlHitTarget(
          child: Semantics(
            slider: true,
            label: widget.semanticLabel,
            value: widget.pageLabel(target + 1, widget.count),
            increasedValue: canIncrease ? widget.pageLabel(target + 2, widget.count) : null,
            decreasedValue: canDecrease ? widget.pageLabel(target, widget.count) : null,
            onIncrease: canIncrease ? () => _choose(target + 1) : null,
            onDecrease: canDecrease ? () => _choose(target - 1) : null,
            child: dots,
          ),
        ),
      ),
    );
  }
}

/// Goes to the page [pageOf] derives from the intent; enabled only when
/// that page exists and differs from [target].
class _PageAction<T extends Intent> extends Action<T> {
  _PageAction({
    required this.interactive,
    required this.count,
    required this.target,
    required this.pageOf,
    required this.choose,
  });

  final bool interactive;
  final int count;
  final int target;
  final int Function(T intent) pageOf;
  final ValueChanged<int> choose;

  @override
  bool isEnabled(T intent) {
    final page = pageOf(intent);
    return interactive && page >= 0 && page < count && page != target;
  }

  @override
  void invoke(T intent) => choose(pageOf(intent));
}

class _StepIntent extends Intent {
  const _StepIntent(this.pages);

  final int pages;
}

class _EdgeIntent extends Intent {
  const _EdgeIntent({required this.end});

  final bool end;
}

/// The opacity of the dots, and of the bars, of the other pages.
const double _inactiveOpacity = 0.4;
const double _barOpacity = 0.3;

/// The row's measurements: the pill takes the space of a dot plus
/// `pill - dot`, so the row keeps its width during the movement.
final class _Metrics {
  const _Metrics({required this.dot, required this.pill, required this.gap, required this.count});

  final double dot;
  final double pill;
  final double gap;
  final int count;

  double get width => count * dot + (pill - dot) + (count - 1) * gap;

  /// The pill share of dot [i] when the pill is at [position]: 1 on its
  /// page, 0 one page away or more.
  double share(int i, double position) => (1 - (position - i).abs()).clamp(0.0, 1.0);

  /// The dot whose center is nearest to [along], measured from the start,
  /// with the pill on [page].
  int nearest(double along, int page) {
    var start = 0.0;
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < count; i++) {
      final width = i == page ? pill : dot;
      final d = (start + width / 2 - along).abs();
      if (d < distance) (best, distance) = (i, d);
      start += width + gap;
    }
    return best;
  }
}

class _Dots extends CustomPainter {
  _Dots({
    required this.position,
    required this.metrics,
    required this.active,
    required this.inactive,
    required this.rtl,
  }) : super(repaint: position);

  final Animation<double> position;
  final _Metrics metrics;
  final Color active;
  final Color inactive;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(metrics.dot / 2);
    var start = 0.0;
    for (var i = 0; i < metrics.count; i++) {
      final share = metrics.share(i, position.value);
      final width = metrics.dot + (metrics.pill - metrics.dot) * share;
      final left = rtl ? size.width - start - width : start;
      canvas.drawRRect(
        RRect.fromLTRBR(left, 0, left + width, metrics.dot, radius),
        Paint()..color = Color.lerp(inactive, active, share)!,
      );
      start += width + metrics.gap;
    }
  }

  @override
  bool shouldRepaint(_Dots old) =>
      old.position != position ||
      old.metrics.dot != metrics.dot ||
      old.metrics.pill != metrics.pill ||
      old.metrics.gap != metrics.gap ||
      old.metrics.count != metrics.count ||
      old.active != active ||
      old.inactive != inactive ||
      old.rtl != rtl;
}
