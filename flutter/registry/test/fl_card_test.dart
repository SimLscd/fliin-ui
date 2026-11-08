import 'package:fliin_ui/components/card/fl_card.dart';
import 'package:fliin_ui/components/surface/fl_surface.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: FlScope(
    child: Center(child: SizedBox(width: 300, child: child)),
  ),
);

const _dot = SizedBox(key: Key('dot'), width: 24, height: 24);

void main() {
  final tokens = FlTokens.defaults;

  testWidgets('devrait poser ses enfants sur la surface de sa variante, dans sa marge', (tester) async {
    await tester.pumpWidget(
      _app(
        const FlCard(
          variant: FlSurfaceVariant.secondary,
          children: [
            FlCardBody(children: [FlCardTitle('Sofa')]),
          ],
        ),
      ),
    );
    expect(tester.widget<FlSurface>(find.byType(FlSurface)).variant, FlSurfaceVariant.secondary);
    final padding = tokens.size.surfacePadding;
    expect(tester.getTopLeft(find.text('Sofa')) - tester.getTopLeft(find.byType(FlCard)), Offset(padding, padding));
  });

  testWidgets('devrait écrire le titre en textLg moyen onSurface et la description en textBase atténuée', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const FlCard(
          children: [
            FlCardBody(children: [FlCardTitle('Sofa'), FlCardDescription('Moderne')]),
          ],
        ),
      ),
    );
    final title = tester.widget<Text>(find.text('Sofa')).style!;
    expect(title.fontSize, tokens.typography.ios.textLg.size);
    expect(title.fontWeight, tokens.typography.weight.medium);
    expect(title.color, tokens.light.onSurface);
    final description = tester.widget<Text>(find.text('Moderne')).style!;
    expect(description.fontSize, tokens.typography.ios.textBase.size);
    expect(description.color, tokens.light.onSurfaceMuted);
    expect(tester.getSize(find.text('Sofa')).height, tokens.typography.ios.textLg.lineHeight);
  });

  testWidgets('devrait garder le contenu de l’en-tête au début de la ligne, à sa taille, et étirer le corps', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: FlScope(
            child: const Center(
              child: SizedBox(
                width: 300,
                child: FlCard(
                  children: [
                    FlCardHeader(children: [_dot]),
                    FlCardBody(children: [SizedBox(key: Key('body'), height: 10)]),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final card = tester.getRect(find.byType(FlCard));
      final dot = tester.getRect(find.byKey(const Key('dot')));
      final padding = tokens.size.surfacePadding;
      expect(dot.size, const Size(24, 24));
      expect(
        direction == TextDirection.ltr ? dot.left - card.left : card.right - dot.right,
        padding,
        reason: direction.name,
      );
      expect(tester.getSize(find.byKey(const Key('body'))).width, 300 - 2 * padding);
    }
  });

  testWidgets('devrait écarter les actions d’un pied horizontal jusqu’aux bords, dans le sens de lecture', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: const FlScope(
            child: Center(
              child: SizedBox(
                width: 300,
                child: FlCard(
                  children: [
                    FlCardFooter(
                      axis: Axis.horizontal,
                      spacing: 8,
                      children: [
                        SizedBox(key: Key('first'), width: 60, height: 40),
                        SizedBox(key: Key('last'), width: 60, height: 40),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final card = tester.getRect(find.byType(FlCard)).deflate(tokens.size.surfacePadding);
      final first = tester.getRect(find.byKey(const Key('first')));
      final last = tester.getRect(find.byKey(const Key('last')));
      expect(first.top, last.top, reason: direction.name);
      if (direction == TextDirection.ltr) {
        expect((first.left, last.right), (card.left, card.right));
      } else {
        expect((first.right, last.left), (card.right, card.left));
      }
    }
  });

  testWidgets('devrait passer à la ligne sans déborder quand les actions d’un pied horizontal ne tiennent pas', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const FlCard(
          children: [
            FlCardFooter(
              axis: Axis.horizontal,
              spacing: 8,
              children: [
                SizedBox(key: Key('first'), width: 160, height: 40),
                SizedBox(key: Key('last'), width: 160, height: 40),
              ],
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final first = tester.getRect(find.byKey(const Key('first')));
    final last = tester.getRect(find.byKey(const Key('last')));
    expect(last.top, first.bottom + 8);
    expect(last.left, first.left);
  });

  testWidgets('devrait poser le média au début et le contenu à côté, à space.md, dans le sens de lecture', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: const FlScope(
            child: Center(
              child: SizedBox(
                width: 300,
                child: FlCard(
                  axis: Axis.horizontal,
                  media: FlCardMedia(width: 80, height: 80, child: SizedBox(key: Key('media'))),
                  children: [SizedBox(key: Key('body'), height: 10)],
                ),
              ),
            ),
          ),
        ),
      );
      final card = tester.getRect(find.byType(FlCard)).deflate(tokens.size.surfacePadding);
      final media = tester.getRect(find.byKey(const Key('media')));
      final body = tester.getRect(find.byKey(const Key('body')));
      expect(media.size, const Size(80, 80), reason: direction.name);
      expect(body.top, card.top, reason: direction.name);
      expect(body.width, card.width - 80 - tokens.space.md, reason: direction.name);
      if (direction == TextDirection.ltr) {
        expect((media.left, body.left, body.right), (card.left, media.right + tokens.space.md, card.right));
      } else {
        expect((media.right, body.right, body.left), (card.right, media.left - tokens.space.md, card.left));
      }
    }
  });

  testWidgets('devrait étendre un média bleed jusqu’aux bords du haut et garder la marge du contenu', (tester) async {
    await tester.pumpWidget(
      _app(
        const FlCard(
          media: FlCardMedia(bleed: true, height: 100, child: SizedBox(key: Key('media'))),
          children: [SizedBox(key: Key('body'), height: 10)],
        ),
      ),
    );
    final card = tester.getRect(find.byType(FlCard));
    final media = tester.getRect(find.byKey(const Key('media')));
    final body = tester.getRect(find.byKey(const Key('body')));
    final padding = tokens.size.surfacePadding;
    expect(media, Rect.fromLTWH(card.left, card.top, card.width, 100));
    expect(body.top, media.bottom + padding);
    expect((body.left, body.right), (card.left + padding, card.right - padding));
  });

  testWidgets('devrait étendre un média bleed horizontal sur toute la hauteur, au début de la carte', (tester) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: const FlScope(
            child: Center(
              child: SizedBox(
                width: 300,
                child: FlCard(
                  axis: Axis.horizontal,
                  media: FlCardMedia(bleed: true, width: 90, height: 120, child: SizedBox.expand(key: Key('media'))),
                  children: [SizedBox(key: Key('body'), height: 10)],
                ),
              ),
            ),
          ),
        ),
      );
      final card = tester.getRect(find.byType(FlCard));
      final media = tester.getRect(find.byKey(const Key('media')));
      final body = tester.getRect(find.byKey(const Key('body')));
      final padding = tokens.size.surfacePadding;
      expect(card.height, 120, reason: direction.name);
      expect(media.height, 120, reason: direction.name);
      if (direction == TextDirection.ltr) {
        expect((media.left, media.right, body.left), (card.left, card.left + 90, card.left + 90 + padding));
      } else {
        expect((media.right, media.left, body.right), (card.right, card.right - 90, card.right - 90 - padding));
      }
    }
  });

  testWidgets('devrait arrondir un média non bleed et le garder à sa largeur, au début de la ligne', (tester) async {
    await tester.pumpWidget(
      _app(
        const FlCard(
          children: [FlCardMedia(width: 56, height: 56, child: SizedBox(key: Key('logo')))],
        ),
      ),
    );
    final card = tester.getRect(find.byType(FlCard)).deflate(tokens.size.surfacePadding);
    final logo = tester.getRect(find.byKey(const Key('logo')));
    expect(logo, Rect.fromLTWH(card.left, card.top, 56, 56));
    final clip = tester.widget<ClipPath>(
      find.ancestor(of: find.byKey(const Key('logo')), matching: find.byType(ClipPath)).first,
    );
    expect(((clip.clipper! as ShapeBorderClipper).shape as FlContinuousBorder).radius, tokens.shape.radiusXxl);
  });

  testWidgets('devrait poser trailing dans le coin haut de fin et en écarter le premier enfant seul', (tester) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: FlScope(
            child: Center(
              child: SizedBox(
                width: 300,
                child: FlCard(
                  trailing: SizedBox.square(key: const Key('close'), dimension: tokens.size.closeButton),
                  children: const [
                    SizedBox(key: Key('title'), height: 10),
                    SizedBox(key: Key('description'), height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final card = tester.getRect(find.byType(FlCard));
      final close = tester.getRect(find.byKey(const Key('close')));
      final title = tester.getRect(find.byKey(const Key('title')));
      final description = tester.getRect(find.byKey(const Key('description')));
      final padding = tokens.size.surfacePadding;
      expect(close.top - card.top, tokens.space.md, reason: direction.name);
      expect(
        direction == TextDirection.ltr ? card.right - close.right : close.left - card.left,
        tokens.space.md,
        reason: direction.name,
      );
      // HeroUI's `pe-8` on the title: clear of the button by space.xs.
      final gap = direction == TextDirection.ltr ? close.left - title.right : title.left - close.right;
      expect(gap, tokens.space.xs, reason: direction.name);
      expect(description.width, card.width - 2 * padding, reason: direction.name);
    }
  });

  testWidgets('devrait remplir toute la carte de son fond, sous le contenu', (tester) async {
    await tester.pumpWidget(
      _app(
        const FlCard(
          background: SizedBox.expand(key: Key('background')),
          children: [SizedBox(key: Key('body'), height: 10)],
        ),
      ),
    );
    expect(tester.getRect(find.byKey(const Key('background'))), tester.getRect(find.byType(FlCard)));
    expect(tester.getSize(find.byType(FlCard)).height, 10 + 2 * tokens.size.surfacePadding);
  });

  testWidgets('devrait espacer les enfants de spacing et garder ensemble ceux d’un pied aligné au début', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const FlCard(
          spacing: 8,
          children: [
            FlCardBody(
              spacing: 4,
              children: [
                SizedBox(key: Key('a'), height: 10),
                SizedBox(key: Key('b'), height: 10),
              ],
            ),
            FlCardFooter(
              axis: Axis.horizontal,
              alignment: WrapAlignment.start,
              spacing: 8,
              children: [
                SizedBox(key: Key('first'), width: 20, height: 20),
                SizedBox(key: Key('last'), width: 20, height: 20),
              ],
            ),
          ],
        ),
      ),
    );
    final a = tester.getRect(find.byKey(const Key('a')));
    final b = tester.getRect(find.byKey(const Key('b')));
    final first = tester.getRect(find.byKey(const Key('first')));
    final last = tester.getRect(find.byKey(const Key('last')));
    expect(b.top - a.bottom, 4);
    expect(first.top - b.bottom, 8);
    expect(last.left - first.right, 8);
  });
}
