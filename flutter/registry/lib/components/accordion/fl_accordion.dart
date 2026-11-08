// Modified from the Accordion of HeroUI Native 1.0.10, Copyright 2025 NextUI
// Inc., licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/separator/fl_separator.dart';
import 'package:fliin_ui/components/surface/fl_surface.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';

/// The container of a [FlAccordion].
enum FlAccordionVariant {
  /// No background: the sections and their rules on the page.
  plain,

  /// On a shadowed surface with continuous corners, wider margins.
  surface,
}

/// How many sections a [FlAccordion] opens at once.
enum FlAccordionSelection {
  /// Only one: opening one closes the other.
  single,

  /// As many as wanted.
  multiple,
}

/// A section of a [FlAccordion] (`Accordion.Item`): a pressable header and
/// content that unfolds.
final class FlAccordionItem<T> {
  /// The section [value], titled [title].
  const FlAccordionItem({
    required this.value,
    required this.title,
    required this.content,
    this.titleSpans,
    this.leading,
    this.indicator,
    this.enabled = true,
    this.subtitle,
    this.expandedIndicator,
  });

  /// The section's identifier among the open ones.
  final T value;

  /// The header's title, in `textBase` and `onSurface`, and its spoken name.
  final String title;

  /// The title in styled pieces (a word highlighted by a search), in the
  /// style of [title]; when null, [title] alone. Their text must be [title],
  /// so that the screen shows what is read.
  final List<InlineSpan>? titleSpans;

  /// The unfolded content, in muted `textBase` by default.
  final Widget content;

  /// An icon before the title, 12 away from it, in muted `onSurface` at
  /// `size.indicatorIcon` following the text up to `size.iconMaxScale`.
  final Widget? leading;

  /// An indicator in place of the rotating chevron (`Accordion.Indicator`
  /// and its children), with the icon theme of [leading]; it does not
  /// rotate.
  final Widget? indicator;

  /// False: the header is no longer pressable and fades to `disabledOpacity`.
  final bool enabled;

  /// A line under the title, in muted `textSm`: what the section holds.
  final String? subtitle;

  /// The indicator shown instead of [indicator] while the section is open,
  /// cross-faded over `short3`: a minus after a plus. It needs an
  /// [indicator]; when null, [indicator] stays.
  final Widget? expandedIndicator;
}

/// An accordion: sections whose header folds and
/// unfolds the content. The height follows the `motion.spring.layout`
/// spring, the content fades in and out over `short4` while it settles
/// `space.sm` down into the opening, and the chevron
/// turns half a turn on the `indicator` spring. Under reduced motion, the
/// height jumps and the content fades over `short3`.
///
/// The open sections are [expanded] when the app holds them, otherwise
/// [initialExpanded] then those the user opens; [onExpandedChanged]
/// receives each new set.
class FlAccordion<T> extends StatefulWidget {
  /// An accordion of [items], one section open at a time.
  const FlAccordion({
    super.key,
    required this.items,
    this.variant = FlAccordionVariant.plain,
    this.selection = FlAccordionSelection.single,
    this.collapsible = true,
    this.expanded,
    this.initialExpanded = const {},
    this.onExpandedChanged,
    this.enabled = true,
    this.separators = true,
  });

  /// The sections, top to bottom.
  final List<FlAccordionItem<T>> items;

  /// The container.
  final FlAccordionVariant variant;

  /// One section open at a time, or several.
  final FlAccordionSelection selection;

  /// False: an open section does not close through its header
  /// (`isCollapsible`).
  final bool collapsible;

  /// The open sections, held by the app; when null, the accordion holds them.
  final Set<T>? expanded;

  /// The sections open at creation, when [expanded] is null.
  final Set<T> initialExpanded;

  /// Called with the open sections after a press.
  final ValueChanged<Set<T>>? onExpandedChanged;

  /// False: no section is pressable (`isDisabled`).
  final bool enabled;

  /// False: no rule between the sections (`hideSeparator`).
  final bool separators;

  @override
  State<FlAccordion<T>> createState() => _FlAccordionState<T>();
}

class _FlAccordionState<T> extends State<FlAccordion<T>> {
  late Set<T> _expanded = widget.expanded ?? widget.initialExpanded;

  Set<T> get _current => widget.expanded ?? _expanded;

  void _toggle(T value) {
    final current = _current;
    final open = current.contains(value);
    if (open && !widget.collapsible) return;
    final next = switch (widget.selection) {
      FlAccordionSelection.single => open ? <T>{} : {value},
      FlAccordionSelection.multiple => open ? ({...current}..remove(value)) : {...current, value},
    };
    if (widget.expanded == null) setState(() => _expanded = next);
    widget.onExpandedChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final surface = widget.variant == FlAccordionVariant.surface;
    final xs = theme.space.xs;
    final current = _current;
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, item) in widget.items.indexed) ...[
          if (widget.separators && index > 0)
            Padding(
              // The surface's 12 of padding.
              padding: EdgeInsetsDirectional.symmetric(horizontal: surface ? xs * 3 : 0),
              child: const FlSeparator(),
            ),
          _Section<T>(
            key: ValueKey(item.value),
            item: item,
            expanded: current.contains(item.value),
            enabled: widget.enabled && item.enabled,
            // The canvas's `.acc-head`: 4 in, 16 on the surface (its 12 of
            // padding, then 4).
            inset: surface ? xs * 4 : xs,
            onPressed: () => _toggle(item.value),
          ),
        ],
      ],
    );
    if (!surface) return column;
    // The 1-wide border in the background color insets the content by as
    // much, and its antialiased stroke thickens the surface's edge.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(
        shape: FlContinuousBorder(
          radius: theme.shape.radiusCard,
          side: BorderSide(color: theme.colors.surfaceRaised, width: theme.size.border),
        ),
      ),
      child: FlSurface(padding: EdgeInsets.all(theme.size.border), child: column),
    );
  }
}

class _Section<T> extends StatefulWidget {
  const _Section({
    super.key,
    required this.item,
    required this.expanded,
    required this.enabled,
    required this.inset,
    required this.onPressed,
  });

  final FlAccordionItem<T> item;
  final bool expanded;
  final bool enabled;
  final double inset;
  final VoidCallback onPressed;

  @override
  State<_Section<T>> createState() => _SectionState<T>();
}

class _SectionState<T> extends State<_Section<T>> with TickerProviderStateMixin {
  late final AnimationController _height = AnimationController.unbounded(vsync: this, value: widget.expanded ? 1 : 0);
  late final AnimationController _turn = AnimationController.unbounded(vsync: this, value: widget.expanded ? 1 : 0);
  late final AnimationController _fade = AnimationController(vsync: this, value: widget.expanded ? 1 : 0);

  @override
  void didUpdateWidget(_Section<T> old) {
    super.didUpdateWidget(old);
    if (old.expanded == widget.expanded) return;
    final motion = FlMotion.of(context);
    final tokens = motion.tokens;
    final target = widget.expanded ? 1.0 : 0.0;
    if (motion.reduced) {
      _height.value = target;
      _turn.value = target;
      _fade.duration = tokens.short3;
    } else {
      _height.driveTo(target, FlSpringMotion(tokens.layout));
      _turn.driveTo(target, FlSpringMotion(tokens.indicator));
      _fade.duration = tokens.short4;
    }
    widget.expanded ? _fade.forward() : _fade.reverse();
  }

  @override
  void dispose() {
    _height.dispose();
    _turn.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    final scale = theme.typography;
    final family = DefaultTextStyle.of(context).style.fontFamily;
    final item = widget.item;
    final xs = theme.space.xs;
    final leading = item.leading;
    final spans = item.titleSpans;
    assert(
      spans == null || TextSpan(children: spans).toPlainText() == item.title,
      'the text of titleSpans must be title',
    );
    final metrics = scale.style(FlTextRole.textBase);
    final subtitle = item.subtitle;
    final title = Text.rich(
      TextSpan(text: spans == null ? item.title : null, children: spans),
      style: scale.resolve(FlTextRole.textBase).copyWith(color: colors.onSurface),
      strutStyle: scale.strut(FlTextRole.textBase, inheritedFamily: family),
    );
    final indicator = switch ((item.indicator, item.expandedIndicator)) {
      (final closed?, final open?) => AnimatedCrossFade(
        firstChild: closed,
        secondChild: open,
        crossFadeState: widget.expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: FlMotion.of(context).reduced ? Duration.zero : theme.motion.short3,
      ),
      (final closed, _) => closed,
    };
    final icons = IconThemeData(
      color: colors.onSurfaceMuted,
      size: MediaQuery.textScalerOf(context)
          .clamp(maxScaleFactor: theme.size.iconMaxScale)
          .scale(theme.size.indicatorIcon),
    );
    final trigger = FlPressable(
      onPressed: widget.enabled ? widget.onPressed : null,
      borderRadius: BorderRadius.zero,
      scaleOnPress: false,
      // The trigger tints under the pointer or the finger, a hair of the
      // text color over the whole header.
      overlay: FlPressOverlay.highlight,
      focusRing: FlFocusRingPlacement.inside,
      expanded: widget.expanded,
      builder: (context, states) => Semantics(
        header: true,
        child: Opacity(
          opacity: widget.enabled ? 1 : theme.size.disabledOpacity,
          // At least the platform's target: the surface clips what
          // overflows, and the target of a shorter header would be cut off.
          // py-4 and gap-4; the title and its icon at gap-3.
          child: Container(
            constraints: BoxConstraints(minHeight: theme.hitTarget),
            alignment: AlignmentDirectional.centerStart,
            padding: EdgeInsetsDirectional.symmetric(horizontal: widget.inset, vertical: xs * 4),
            child: IconTheme.merge(
              data: icons,
              child: Row(
                spacing: xs * 4,
                children: [
                  Expanded(
                    child: Row(
                      spacing: xs * 3,
                      children: [
                        ?leading,
                        Expanded(
                          child: subtitle == null
                              ? title
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    title,
                                    Text(
                                      subtitle,
                                      style: scale.resolve(FlTextRole.textSm).copyWith(color: colors.onSurfaceMuted),
                                      strutStyle: scale.strut(FlTextRole.textSm, inheritedFamily: family),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  indicator ??
                      AnimatedBuilder(
                        animation: _turn,
                        builder: (context, child) => Transform.rotate(angle: -math.pi * _turn.value, child: child),
                        child: FlIcon(FlIcons.chevronDown),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final content = Padding(
      // pb-4.
      padding: EdgeInsetsDirectional.only(start: widget.inset, end: widget.inset, bottom: xs * 4),
      child: DefaultTextStyle.merge(
        style: scale
            .resolve(FlTextRole.textBase)
            .copyWith(
              color: colors.onSurfaceMuted,
              height: metrics.lineHeight / metrics.size,
              leadingDistribution: TextLeadingDistribution.even,
            ),
        child: item.content,
      ),
    );
    final curve = theme.motion.easeOut;
    final reduced = FlMotion.of(context).reduced;
    final opacity = CurvedAnimation(parent: _fade, curve: curve, reverseCurve: theme.motion.easeIn.flipped);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        trigger,
        AnimatedBuilder(
          animation: Listenable.merge([_height, _fade]),
          builder: (context, child) {
            if (!widget.expanded && _height.value <= 0 && _fade.value <= 0) {
              return const SizedBox.shrink();
            }
            return ClipRect(
              child: Align(
                alignment: AlignmentDirectional.topStart,
                heightFactor: math.max(0, _height.value),
                // The content settles down into the opening as it fades in,
                // and lifts as it fades out; it only fades under reduced
                // motion.
                child: Transform.translate(
                  offset: Offset(0, reduced ? 0 : -(1 - opacity.value) * theme.space.sm),
                  child: FadeTransition(opacity: opacity, child: child),
                ),
              ),
            );
          },
          child: content,
        ),
      ],
    );
  }
}
