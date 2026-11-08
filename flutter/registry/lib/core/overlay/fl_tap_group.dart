import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

/// Makes [child], the panel of an overlay in `TapRegion` group [id], count as
/// "inside" for every overlay opened beneath it: a menu opened from a popover
/// is placed in the `Overlay`, outside the popover's `TapRegion`, and a tap on
/// one of its actions would otherwise close the popover.
class FlTapGroup extends StatelessWidget {
  /// The panel of the overlay in group [id].
  const FlTapGroup({super.key, required this.id, required this.child});

  /// The `groupId` of the `TapRegion` of the overlay that places this panel,
  /// usually its `State`.
  final Object id;
  /// The panel's content. A tap on it counts as inside for every parent overlay
  /// of the group.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final outer = context.dependOnInheritedWidgetOfExactType<_Groups>()?.ids ?? const [];
    Widget result = _Groups(ids: [...outer, id], child: child);
    for (final group in outer) {
      result = TapRegion(groupId: group, child: result);
    }
    return result;
  }
}

class _Groups extends InheritedWidget {
  const _Groups({required this.ids, required super.child});

  final List<Object> ids;

  @override
  bool updateShouldNotify(_Groups oldWidget) => !listEquals(ids, oldWidget.ids);
}
