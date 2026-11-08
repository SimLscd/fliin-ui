import 'package:fliin_ui/components/avatar/fl_avatar.dart';
import 'package:fliin_ui/components/avatar_group/fl_avatar_group.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'torture/themes.dart';

Widget _app(Widget child, {TextDirection dir = TextDirection.ltr}) => Directionality(
  textDirection: dir,
  child: FlScope(
    platform: TargetPlatform.iOS,
    child: Center(child: child),
  ),
);

const _people = [
  FlAvatar(initials: 'JD', semanticLabel: 'Jane Doe'),
  FlAvatar(initials: 'KW', semanticLabel: 'Kate Wilson', size: FlAvatarSize.lg),
  FlAvatar(initials: 'EC', semanticLabel: 'Emily Chen'),
  FlAvatar(initials: 'MB', semanticLabel: 'Michael Brown'),
];

final _avatars = find.descendant(of: find.byType(FlAvatarGroup), matching: find.byType(FlAvatar));

void main() {
  testWidgets('devrait montrer tous les avatars sans compteur quand max est nul', (tester) async {
    await tester.pumpWidget(_app(const FlAvatarGroup(avatars: _people)));
    expect(_avatars, findsNWidgets(4));
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('devrait remplacer les avatars au-delà de max par un compteur neutre', (tester) async {
    await tester.pumpWidget(_app(const FlAvatarGroup(avatars: _people, max: 2)));
    expect(_avatars, findsNWidgets(3));
    expect(find.text('+2'), findsOneWidget);
    final count = tester.widgetList<FlAvatar>(_avatars).last;
    expect(count.color, FlAvatarColor.neutral);
    expect(count.variant, FlAvatarVariant.primary);
  });

  testWidgets('devrait compter le reste de total quand la liste n’en donne qu’une partie', (tester) async {
    await tester.pumpWidget(_app(const FlAvatarGroup(avatars: _people, total: 12, max: 3)));
    expect(find.text('+9'), findsOneWidget);
    await tester.pumpWidget(_app(const FlAvatarGroup(avatars: _people, total: 6)));
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('devrait poser chaque avatar à la taille du groupe', (tester) async {
    await tester.pumpWidget(_app(const FlAvatarGroup(avatars: _people, size: FlAvatarSize.sm, max: 3)));
    expect(tester.widgetList<FlAvatar>(_avatars).map((a) => a.size).toSet(), {FlAvatarSize.sm});
  });

  testWidgets('devrait faire reculer chaque avatar de 12 sous le précédent, vers le début en RTL', (tester) async {
    for (final dir in TextDirection.values) {
      await tester.pumpWidget(_app(const FlAvatarGroup(avatars: _people), dir: dir));
      final rects = tester.widgetList<FlAvatar>(_avatars).map((a) => tester.getRect(find.byWidget(a))).toList();
      expect(tester.getSize(find.byType(FlAvatarGroup)), const Size(4 * 48 - 3 * 12, 48), reason: '$dir');
      for (var i = 1; i < rects.length; i++) {
        final step = dir == TextDirection.ltr ? rects[i].left - rects[i - 1].left : rects[i - 1].right - rects[i].right;
        expect(step, 36, reason: '$dir $i');
      }
    }
  });

  testWidgets('devrait découper un croissant dans chaque avatar recouvert, pas dans le dernier', (tester) async {
    await tester.pumpWidget(_app(const FlAvatarGroup(avatars: _people)));
    expect(find.descendant(of: find.byType(FlAvatarGroup), matching: find.byType(ClipPath)), findsNWidgets(3));
    await tester.pumpWidget(_app(const FlAvatarGroup(avatars: _people, overlap: FlAvatarGroupOverlap.ring)));
    expect(find.descendant(of: find.byType(FlAvatarGroup), matching: find.byType(ClipPath)), findsNothing);
  });

  testWidgets('devrait lire le groupe en un seul nœud, chaque nom puis le compteur', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(FlAvatarGroup(avatars: _people, max: 2, countLabel: (n) => 'et $n autres')));
    expect(
      tester.getSemantics(find.byType(FlAvatarGroup)).getSemanticsData().label,
      'Jane Doe\nKate Wilson\net 2 autres',
    );
    handle.dispose();
  });

  testWidgets('devrait reculer de deux space.xs et cerner d’un seul joint de surface avec ring, comme HeroUI', (
    tester,
  ) async {
    for (final theme in flTestThemes) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FlScope(
            tokens: theme.tokens,
            platform: TargetPlatform.iOS,
            child: const Center(
              child: FlAvatarGroup(avatars: _people, overlap: FlAvatarGroupOverlap.ring),
            ),
          ),
        ),
      );
      final rects = tester.widgetList<FlAvatar>(_avatars).map((a) => tester.getRect(find.byWidget(a))).toList();
      final xs = theme.tokens.space.xs;
      expect(rects[1].left - rects[0].left, rects[0].width - xs * 2, reason: theme.id);
      final ring = find.descendant(of: find.byType(FlAvatarGroup), matching: find.byType(CustomPaint)).first;
      final border = theme.tokens.size.border;
      expect(
        tester.renderObject(ring),
        paints..path(
          color: theme.tokens.light.surface,
          includes: [Offset(-border, rects[0].height / 2)],
          excludes: [Offset(-border * 3, rects[0].height / 2)],
        ),
        reason: theme.id,
      );
    }
  });

  testWidgets('devrait faire tenir un long compteur dans l’avatar quand le texte grandit', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _app(
          const FlAvatarGroup(
            avatars: [
              FlAvatar(initials: 'JD'),
              FlAvatar(initials: 'KW'),
            ],
            max: 1,
            total: 129,
            size: FlAvatarSize.sm,
          ),
        ),
      ),
    );
    final text = find.text('+128');
    final count = tester.widgetList<FlAvatar>(_avatars).last;
    expect(tester.getRect(text).width, lessThanOrEqualTo(tester.getSize(find.byWidget(count)).width));
    expect(tester.renderObject<RenderParagraph>(text).didExceedMaxLines, isFalse);
  });

  testWidgets('devrait garder la clé de chaque avatar', (tester) async {
    await tester.pumpWidget(
      _app(
        const FlAvatarGroup(
          avatars: [
            FlAvatar(key: Key('jd'), initials: 'JD'),
            FlAvatar(initials: 'KW'),
          ],
        ),
      ),
    );
    expect(find.byKey(const Key('jd')), findsOneWidget);
  });

  testWidgets('devrait poser les avatars côte à côte, à space.md, sans croissant, et passer à la ligne avec grid', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const SizedBox(width: 120, child: FlAvatarGroup(avatars: _people, max: 3, grid: true))),
    );
    final rects = [for (var i = 0; i < 4; i++) tester.getRect(_avatars.at(i))];
    expect(rects[1].left - rects[0].right, FlTokens.defaults.space.md);
    expect(rects[2].top, greaterThan(rects[0].bottom), reason: 'la troisième passe à la ligne dans 120');
    expect(find.descendant(of: find.byType(FlAvatarGroup), matching: find.byType(ClipPath)), findsNothing);
    expect(find.text('+1'), findsOneWidget);
  });
}
