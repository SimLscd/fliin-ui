// Modified from the AvatarGroup of HeroUI React v3, Copyright 2020 Next UI
// Inc., licensed under the MIT license below and under Apache 2.0:
// https://www.apache.org/licenses/LICENSE-2.0
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
//
// Also modified from the Avatar of HeroUI Native 1.0.10, Copyright 2025 NextUI
// Inc., licensed under Apache 2.0.
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/avatar/fl_avatar.dart';
import 'package:fliin_ui/core/fliin.dart';

/// How a [FlAvatarGroup] separates an avatar from the one it overlaps.
enum FlAvatarGroupOverlap {
  /// A transparent crescent cut out of the overlapped avatar: the
  /// background, whatever it is, shows through. The default.
  clip,

  /// A solid seam in the background color around each avatar, which
  /// overlaps the previous one by 8 rather than 12.
  ring,
}

/// Overlapping avatars: the participants
/// of a conversation or a project. Beyond [max], a neutral `+N` counter, at
/// the group's size, takes the place of the rest.
///
/// The screen reader reads the group as a single node: the name of each
/// displayed avatar, then [countLabel].
class FlAvatarGroup extends StatelessWidget {
  /// An `md` group of [avatars], cut as crescents.
  const FlAvatarGroup({
    super.key,
    required this.avatars,
    this.max,
    this.total,
    this.size = FlAvatarSize.md,
    this.overlap = FlAvatarGroupOverlap.clip,
    this.ringColor,
    this.countLabel,
    this.grid = false,
  }) : assert(max == null || max >= 0, 'max is non-negative');

  /// The avatars, from the first placed to the last. Their size yields to [size].
  final List<FlAvatar> avatars;

  /// The maximum number of avatars shown; when null, all.
  final int? max;

  /// The number of participants when [avatars] gives only some of them (the
  /// first of a half-loaded list): the counter shows the rest. When null:
  /// the length of [avatars].
  final int? total;

  /// The size of each avatar and of the counter.
  final FlAvatarSize size;

  /// The transparent crescent or the solid ring.
  final FlAvatarGroupOverlap overlap;

  /// The seam's color, that of the background under the group. When null:
  /// `surface`, the page background. No effect on the crescent.
  final Color? ringColor;

  /// What the screen reader reads for the counter ("and 2 others"). When
  /// null: the displayed text, `+2`.
  final String Function(int hidden)? countLabel;

  /// True: the avatars sit side by side without overlapping, `space.md`
  /// apart, and wrap onto the next line when the width runs out (the
  /// members of a team, the guests of an event). [overlap]
  /// and [ringColor] then have no effect.
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final max = this.max;
    final shown = max == null || max >= avatars.length ? avatars : avatars.sublist(0, max);
    final hidden = (total ?? avatars.length) - shown.length;
    final members = [
      for (final a in shown)
        FlAvatar(
          key: a.key,
          image: a.image,
          initials: a.initials,
          icon: a.icon,
          semanticLabel: a.semanticLabel,
          size: size,
          variant: a.variant,
          color: a.color,
          fallbackDelay: a.fallbackDelay,
        ),
      if (hidden > 0)
        FlAvatar(
          icon: _Count('+$hidden', size),
          semanticLabel: countLabel?.call(hidden) ?? '+$hidden',
          size: size,
          color: FlAvatarColor.neutral,
        ),
    ];
    if (grid) {
      final gap = FlScope.of(context).space.md;
      return MergeSemantics(
        child: Wrap(spacing: gap, runSpacing: gap, children: members),
      );
    }
    final ring = ringColor ?? FlScope.of(context).colors.surface;
    return MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, member) in members.indexed)
            _Seat(
              first: i == 0,
              cut: overlap == FlAvatarGroupOverlap.clip && i < members.length - 1,
              ring: overlap == FlAvatarGroupOverlap.ring ? ring : null,
              child: member,
            ),
        ],
      ),
    );
  }
}

/// The counter, in the style of [FlAvatar]'s initials (medium weight, text
/// capped at 1.4 times), shrunk to fit in the avatar when it is long
/// (`+128` at scale 2.0).
class _Count extends StatelessWidget {
  const _Count(this.text, this.size);

  final String text;
  final FlAvatarSize size;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final scale = theme.typography;
    final role = switch (size) {
      FlAvatarSize.sm => FlTextRole.textXs,
      FlAvatarSize.md => FlTextRole.textSm,
      FlAvatarSize.lg => FlTextRole.textBase,
      FlAvatarSize.xl => FlTextRole.heading2,
    };
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: scale
              .resolve(role)
              .copyWith(color: IconTheme.of(context).color, fontWeight: theme.tokens.typography.weight.medium),
          strutStyle: scale.strut(role, inheritedFamily: DefaultTextStyle.of(context).style.fontFamily),
        ),
      ),
    );
  }
}

/// The largest text scale the initials follow, that of [FlAvatar].
const double _maxTextScale = 1.4;

/// The group's overlap and seam, and the shape of an avatar.
typedef _Geometry = ({double side, double overlap, double seam, double radius});

_Geometry _geometry(BuildContext context, FlAvatarSize size, {required bool ringed}) {
  final theme = FlScope.of(context);
  final xs = theme.space.xs;
  return (
    // The sides of FlAvatar.
    side: switch (size) {
      FlAvatarSize.sm => xs * 10,
      FlAvatarSize.md => xs * 12,
      FlAvatarSize.lg => xs * 16,
      FlAvatarSize.xl => xs * 22,
    },
    // 12, the overlap of Izydesk's avatar group; 8 with the ring.
    overlap: ringed ? xs * 2 : xs * 3,
    // --avatar-group-seam: 2px, two strokes.
    seam: theme.size.border * 2,
    radius: theme.shape.radiusButtonLarge,
  );
}

/// The shape of [FlAvatar] on [rect], grown by [grow] all around.
Path _avatarShape(Rect rect, double radius, double grow) =>
    FlContinuousBorder(radius: radius + grow).getOuterPath(rect.inflate(grow));

/// The place of an avatar in the row: it tucks under the previous one,
/// except the first, is cut as a crescent where the next one overlaps it
/// ([cut]), or is circled by the seam and the ring of [ring].
class _Seat extends StatelessWidget {
  const _Seat({required this.first, required this.cut, required this.ring, required this.child});

  final bool first;
  final bool cut;
  final Color? ring;
  final FlAvatar child;

  @override
  Widget build(BuildContext context) {
    final ring = this.ring;
    final g = _geometry(context, child.size, ringed: ring != null);
    Widget seat = child;
    if (ring != null) {
      // box-shadow: 0 0 0 2px var(--background): the avatar's shape, solid,
      // under it, grown by the seam.
      seat = CustomPaint(painter: _Ring(ring, g), child: seat);
    }
    if (cut) {
      seat = ClipPath(clipper: _Crescent(Directionality.of(context), g), child: seat);
    }
    if (first) return seat;
    return SizedBox(
      width: g.side - g.overlap,
      height: g.side,
      child: OverflowBox(alignment: AlignmentDirectional.centerEnd, minWidth: g.side, maxWidth: g.side, child: seat),
    );
  }
}

/// `mask-image: radial-gradient(…)`: the shape of the next avatar, grown by
/// the seam, removed from this one, on the end side.
class _Crescent extends CustomClipper<Path> {
  _Crescent(this.direction, this.geometry);

  final TextDirection direction;
  final _Geometry geometry;

  @override
  Path getClip(Size size) {
    final reach = geometry.side - geometry.overlap;
    final next = (Offset.zero & size).shift(Offset(direction == TextDirection.rtl ? -reach : reach, 0));
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(_avatarShape(next, geometry.radius, geometry.seam), Offset.zero);
  }

  @override
  bool shouldReclip(_Crescent old) => old.direction != direction || old.geometry != geometry;
}

class _Ring extends CustomPainter {
  _Ring(this.color, this.geometry);

  final Color color;
  final _Geometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_avatarShape(Offset.zero & size, geometry.radius, geometry.seam), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Ring old) => old.color != color || old.geometry != geometry;
}
