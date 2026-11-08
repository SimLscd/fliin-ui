// Modified from the Toolbar of HeroUI React v3, Copyright 2025 NextUI Inc.,
// licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/separator/fl_separator.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The background of an [FlToolbar].
enum FlToolbarVariant {
  /// No background: the controls sit on the page.
  plain,

  /// A `surfaceOverlay` bar lifted by the `overlay` shadow, inset by
  /// `space.xs`: a floating bar over content, an
  /// editor's formatting bar.
  attached,
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.step, {this.edge = false});

  /// +1 toward the end, -1 toward the start; with [edge], all the way.
  final int step;
  final bool edge;
}

/// Tab order inside the bar: only the control last reached, so that the bar
/// is one stop, entered again where the user left it (a roving tab stop).
class _RovingPolicy extends ReadingOrderTraversalPolicy {
  _RovingPolicy(this._state);

  final _FlToolbarState _state;

  @override
  Iterable<FocusNode> sortDescendants(Iterable<FocusNode> descendants, FocusNode currentNode) {
    final sorted = super.sortDescendants(descendants, currentNode).toList();
    if (sorted.isEmpty) return sorted;
    final focused = sorted.where((node) => node.hasPrimaryFocus).firstOrNull;
    final kept = focused ?? (sorted.contains(_state._last) ? _state._last! : sorted.first);
    _state._last = kept;
    return [kept];
  }
}

/// A row of controls that act on the same thing:
/// buttons, toggle buttons, button groups, `space.sm` apart; an
/// `FlSeparator` among [children] becomes a line across the bar, at half
/// a control's height.
///
/// With a keyboard, the bar is a single Tab stop, as a toolbar should be:
/// the arrow keys move the focus from control to control in reading order
/// (reversed in RTL), Home and End to the first and the last, Tab leaves
/// the bar, and coming back lands on the control left last. Touch reaches
/// every control directly.
///
/// [spacing] tightens or loosens the controls, and [color] repaints the
/// bar of the `attached` variant.
///
/// The screen reader reads [semanticLabel], then each control.
///
/// ```dart
/// FlToolbar(semanticLabel: 'Formatting', children: [
///   FlButtonGroup(items: [/* bold, italic, underline */]),
///   const FlSeparator(),
///   FlButton.icon(label: 'Share', icon: FlIcon(FlIcons.arrowUpFromSquare), onPressed: share),
/// ])
/// ```
class FlToolbar extends StatefulWidget {
  /// A bar of [children].
  const FlToolbar({
    super.key,
    required this.children,
    this.axis = Axis.horizontal,
    this.variant = FlToolbarVariant.plain,
    this.semanticLabel,
    this.spacing,
    this.color,
  });

  /// The controls, in reading order.
  final List<Widget> children;

  /// A row, or a column aligned at the start.
  final Axis axis;

  /// No background, or a floating bar; `plain` by default.
  final FlToolbarVariant variant;

  /// The bar's name for the screen reader ("Formatting").
  final String? semanticLabel;

  /// The space between two controls; `space.sm` by default.
  final double? spacing;

  /// The fill of an `attached` bar, in place of `surfaceOverlay`.
  final Color? color;

  @override
  State<FlToolbar> createState() => _FlToolbarState();
}

class _FlToolbarState extends State<FlToolbar> {
  final FocusNode _scope = FocusNode(debugLabel: 'FlToolbar', skipTraversal: true, canRequestFocus: false);
  late final _RovingPolicy _policy = _RovingPolicy(this);

  /// The control the bar's Tab stop lands on.
  FocusNode? _last;

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  /// The controls that take focus, in the order of the tree.
  List<FocusNode> get _controls => _scope.traversalDescendants.toList();

  void _move(_MoveIntent intent) {
    final controls = _controls;
    if (controls.isEmpty) return;
    final at = controls.indexOf(FocusManager.instance.primaryFocus ?? _scope);
    final int next;
    if (intent.edge) {
      next = intent.step > 0 ? controls.length - 1 : 0;
    } else if (at < 0) {
      next = 0;
    } else {
      next = (at + intent.step).clamp(0, controls.length - 1);
    }
    _last = controls[next];
    controls[next].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final horizontal = widget.axis == Axis.horizontal;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final forward = rtl ? -1 : 1;
    final half = theme.controlHeight / 2;
    final children = [
      for (final child in widget.children)
        if (child is FlSeparator)
          // A square of half a control: the line across it, centered.
          SizedBox(
            width: horizontal ? null : half,
            height: horizontal ? half : null,
            child: FlSeparator(
              axis: horizontal ? Axis.vertical : Axis.horizontal,
              variant: child.variant,
              thickness: child.thickness,
            ),
          )
        else
          child,
    ];
    final gap = widget.spacing ?? theme.space.sm;
    Widget bar = horizontal
        ? Row(mainAxisSize: MainAxisSize.min, spacing: gap, children: children)
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: gap,
            children: [
              for (final (i, child) in children.indexed)
                widget.children[i] is FlSeparator
                    ? SizedBox(
                        width: theme.controlHeight,
                        child: Center(child: child),
                      )
                    : child,
            ],
          );
    if (widget.variant == FlToolbarVariant.attached) {
      final inset = theme.space.xs;
      final shape = switch (theme.shape.button) {
        FlButtonShape.square => const RoundedRectangleBorder(),
        // Concentric with the controls inside.
        FlButtonShape.rounded => RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.shape.radiusButton + inset),
        ),
        FlButtonShape.pill => const StadiumBorder(),
      };
      bar = FlShadow(
        layers: theme.shadows.overlay,
        shape: shape,
        child: DecoratedBox(
          decoration: ShapeDecoration(color: widget.color ?? theme.colors.surfaceOverlay, shape: shape),
          child: Padding(padding: EdgeInsetsDirectional.all(inset), child: bar),
        ),
      );
    }
    final next = horizontal ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowDown;
    final previous = horizontal ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowUp;
    return Shortcuts(
      shortcuts: {
        SingleActivator(next): _MoveIntent(horizontal ? forward : 1),
        SingleActivator(previous): _MoveIntent(horizontal ? -forward : -1),
        const SingleActivator(LogicalKeyboardKey.home): const _MoveIntent(-1, edge: true),
        const SingleActivator(LogicalKeyboardKey.end): const _MoveIntent(1, edge: true),
      },
      child: Actions(
        actions: {_MoveIntent: CallbackAction<_MoveIntent>(onInvoke: _move)},
        child: FocusTraversalGroup(
          policy: _policy,
          child: Focus(
            focusNode: _scope,
            child: Semantics(container: true, label: widget.semanticLabel, explicitChildNodes: true, child: bar),
          ),
        ),
      ),
    );
  }
}
