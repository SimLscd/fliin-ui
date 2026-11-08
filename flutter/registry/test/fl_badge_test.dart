import 'package:fliin_ui/components/badge/fl_badge.dart';
import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {TextDirection dir = TextDirection.ltr}) => Directionality(
  textDirection: dir,
  child: FlScope(
    platform: TargetPlatform.iOS,
    child: Center(child: child),
  ),
);

const _anchor = SizedBox.square(key: Key('anchor'), dimension: 40);

final _pastille = find.descendant(
  of: find.byType(FlBadge),
  matching: find.byWidgetPredicate((widget) => widget is CustomPaint && '${widget.painter.runtimeType}' == '_Pastille'),
);

/// L'anneau, hors de la pastille, puis le fond par-dessus.
PaintPattern _painted(Color fill, Color ring) => paints
  ..path(color: ring)
  ..path(color: fill);

void main() {
  final light = FlTokens.defaults.light;

  testWidgets('devrait plafonner le compte à 99+ par défaut, et au plafond donné', (tester) async {
    await tester.pumpWidget(_app(const FlBadge.count(count: 120, child: _anchor)));
    expect(find.text('99+'), findsOneWidget);
    await tester.pumpWidget(_app(const FlBadge.count(count: 12, max: 9, child: _anchor)));
    await tester.pumpAndSettle();
    expect(find.text('9+'), findsOneWidget);
    await tester.pumpWidget(_app(const FlBadge.count(count: 99, child: _anchor)));
    await tester.pumpAndSettle();
    expect(find.text('99'), findsOneWidget);
  });

  testWidgets('devrait montrer zéro par défaut, et le cacher quand hideZero le demande', (tester) async {
    await tester.pumpWidget(_app(const FlBadge.count(count: 0, child: _anchor)));
    expect(find.text('0'), findsOneWidget);
    await tester.pumpWidget(_app(const FlBadge.count(count: 0, hideZero: true, child: _anchor)));
    await tester.pumpAndSettle();
    expect(_pastille, findsNothing);
    expect(find.byKey(const Key('anchor')), findsOneWidget);
  });

  testWidgets('devrait annoncer la pastille avec son enfant, en un seul nœud', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        FlBadge.count(
          count: 3,
          semanticLabel: '3 non lus',
          child: Semantics(button: true, label: 'Messages', onTap: () {}, child: _anchor),
        ),
      ),
    );
    final node = tester.getSemantics(find.byType(FlBadge));
    expect(node.label, 'Messages\n3 non lus');
    expect(node.flagsCollection.isButton, isTrue);
    expect(find.semantics.byLabel('3'), findsNothing);
    handle.dispose();
  });

  testWidgets('devrait lire le texte affiché quand aucun libellé n’est donné', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        FlBadge.count(
          count: 250,
          child: Semantics(label: 'Messages', child: _anchor),
        ),
      ),
    );
    expect(tester.getSemantics(find.byType(FlBadge)).label, 'Messages\n99+');
    await tester.pumpWidget(
      _app(
        FlBadge.count(
          count: 0,
          hideZero: true,
          child: Semantics(label: 'Messages', child: _anchor),
        ),
      ),
    );
    expect(tester.getSemantics(find.byType(FlBadge)).label, 'Messages');
    handle.dispose();
  });

  testWidgets('devrait centrer un point sur le coin de fin, retourné en RTL (canvas)', (tester) async {
    for (final (dir, placement, corner) in [
      (TextDirection.ltr, FlBadgePlacement.topEnd, (Rect r) => r.topRight),
      (TextDirection.rtl, FlBadgePlacement.topEnd, (Rect r) => r.topLeft),
      (TextDirection.ltr, FlBadgePlacement.bottomStart, (Rect r) => r.bottomLeft),
      (TextDirection.rtl, FlBadgePlacement.bottomStart, (Rect r) => r.bottomRight),
    ]) {
      await tester.pumpWidget(
        _app(
          FlBadge.dot(semanticLabel: 'En ligne', placement: placement, child: _anchor),
          dir: dir,
        ),
      );
      final anchor = tester.getRect(find.byKey(const Key('anchor')));
      final dot = tester.getRect(_pastille);
      expect(dot.size, const Size.square(12), reason: '$dir $placement');
      expect(dot.center, corner(anchor), reason: '$dir $placement');
    }
  });

  testWidgets(
    'devrait se poser seule, sans débord, son libellé dans le nœud qui la contient, quand elle n’a pas d’enfant',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          Semantics(
            container: true,
            label: 'Famille',
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _anchor,
                FlBadge.count(count: 3, semanticLabel: '3 non lus'),
              ],
            ),
          ),
        ),
      );
      final anchor = tester.getRect(find.byKey(const Key('anchor')));
      final badge = tester.getRect(find.byType(FlBadge));
      expect(tester.getRect(_pastille), badge, reason: 'ni coin ni débord');
      expect(badge.height, 20);
      expect(badge.width, greaterThanOrEqualTo(20));
      expect(
        _pastille,
        paintsExactlyCountTimes(#drawPath, 1),
        reason: 'seule, elle ne recouvre rien : le fond, sans anneau',
      );
      expect(badge.left, anchor.right, reason: 'à sa place dans la ligne');
      expect(tester.getSemantics(find.byType(Row)).label, 'Famille\n3 non lus');
      await tester.pumpWidget(_app(const FlBadge.count(count: 0, hideZero: true, semanticLabel: 'aucun non lu')));
      expect(tester.getSize(find.byType(FlBadge)), Size.zero);
      expect(find.semantics.byLabel('aucun non lu'), findsNothing);
      handle.dispose();
    },
  );

  testWidgets('devrait garder la taille de l’enfant dans la mise en page', (tester) async {
    await tester.pumpWidget(_app(const FlBadge.count(count: 120, size: FlBadgeSize.lg, child: _anchor)));
    expect(tester.getSize(find.byType(FlBadge)), const Size.square(40));
  });

  testWidgets('devrait faire un point de 12, 15 et 24, cerné d’un anneau à la couleur du fond', (tester) async {
    for (final (size, side) in [(FlBadgeSize.sm, 12.0), (FlBadgeSize.md, 15.0), (FlBadgeSize.lg, 24.0)]) {
      await tester.pumpWidget(_app(FlBadge.dot(semanticLabel: 'En ligne', size: size, child: _anchor)));
      expect(tester.getSize(_pastille), Size.square(side), reason: size.name);
      expect(tester.renderObject(_pastille), _painted(light.control, light.surface), reason: size.name);
    }
    await tester.pumpWidget(
      _app(FlBadge.dot(semanticLabel: 'En ligne', ringColor: light.surfaceRaised, child: _anchor)),
    );
    expect(tester.renderObject(_pastille), _painted(light.control, light.surfaceRaised));
  });

  testWidgets('devrait s’élargir avec son texte au-delà du côté minimal', (tester) async {
    await tester.pumpWidget(_app(const FlBadge.count(count: 120, size: FlBadgeSize.sm, child: _anchor)));
    expect(tester.getSize(_pastille).width, greaterThan(16));
    expect(tester.getSize(_pastille).height, 16);
  });

  testWidgets('devrait peindre le fond et le texte de chaque remplissage dans sa couleur', (tester) async {
    for (final (variant, color, fill, ink) in [
      (FlBadgeVariant.primary, FlBadgeColor.accent, light.selected, light.onSelected),
      (FlBadgeVariant.primary, FlBadgeColor.neutral, light.control, light.onControl),
      (FlBadgeVariant.primary, FlBadgeColor.danger, light.dangerFill, light.onDanger),
      (FlBadgeVariant.secondary, FlBadgeColor.success, light.control, light.onSuccessSoft),
      (FlBadgeVariant.soft, FlBadgeColor.warning, light.warningSoft, light.onWarningSoft),
      (FlBadgeVariant.secondary, FlBadgeColor.danger, light.control, light.danger),
      (FlBadgeVariant.soft, FlBadgeColor.neutral, light.controlPressed, light.onControl),
    ]) {
      await tester.pumpWidget(_app(FlBadge.count(count: 5, variant: variant, color: color, child: _anchor)));
      final reason = '${variant.name} ${color.name}';
      expect(tester.renderObject(_pastille), _painted(fill, light.surface), reason: reason);
      expect(tester.widget<Text>(find.text('5')).style!.color, ink, reason: reason);
    }
  });

  testWidgets('devrait borner son texte à iconMaxScale quand le texte grandit', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3)),
        child: _app(const FlBadge.count(count: 5, size: FlBadgeSize.lg, child: _anchor)),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(find.text('5'));
    expect(paragraph.textScaler, TextScaler.linear(FlTokens.defaults.size.iconMaxScale));
  });

  testWidgets('devrait transmettre à l’enfant les contraintes de son parent, sans les relâcher', (tester) async {
    const tile = DecoratedBox(
      key: Key('tile'),
      decoration: BoxDecoration(color: Color(0xFF000000)),
    );
    await tester.pumpWidget(_app(const SizedBox(width: 40, height: 40, child: FlBadge.count(count: 3, child: tile))));
    expect(tester.getSize(find.byKey(const Key('tile'))), const Size.square(40));
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 300,
          child: FlBadge.count(
            count: 3,
            child: FlButton(key: const Key('cart'), label: 'Panier', onPressed: () {}),
          ),
        ),
      ),
    );
    final button = tester.getRect(find.byKey(const Key('cart')));
    expect(button.width, 300);
    expect(tester.getRect(_pastille).center.dx, closeTo(button.right - tester.getSize(_pastille).width / 4, 0.5));
  });

  testWidgets('devrait faire apparaître la pastille en rebondissant quand le compte quitte zéro', (tester) async {
    await tester.pumpWidget(_app(const FlBadge.count(count: 0, hideZero: true, child: _anchor)));
    expect(_pastille, findsNothing);
    await tester.pumpWidget(_app(const FlBadge.count(count: 1, hideZero: true, child: _anchor)));
    await tester.pump(const Duration(milliseconds: 40));
    final pop = find.descendant(of: find.byType(FlBadge), matching: find.byType(FlPop));
    double scale() => tester
        .widget<Transform>(find.descendant(of: pop, matching: find.byType(Transform)).first)
        .transform
        .entry(0, 0);
    expect(scale(), inExclusiveRange(0, 1));
    expect(_pastille, findsOneWidget);
    await tester.pumpAndSettle();
    expect(scale(), 1);
    await tester.pumpWidget(_app(const FlBadge.count(count: 0, hideZero: true, child: _anchor)));
    await tester.pump(const Duration(milliseconds: 30));
    expect(find.text('1'), findsOneWidget, reason: 'it leaves with its last count');
    await tester.pumpAndSettle();
    expect(_pastille, findsNothing);
  });

  testWidgets('devrait faire défiler les chiffres du compte, puis seulement se fondre sous mouvement réduit', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const FlBadge.count(count: 8, child: _anchor)));
    await tester.pumpWidget(_app(const FlBadge.count(count: 9, child: _anchor)));
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('8'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('8'), findsNothing);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(const FlBadge.count(count: 9, child: _anchor)),
      ),
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(const FlBadge.count(count: 10, child: _anchor)),
      ),
    );
    expect(find.text('10'), findsOneWidget);
    expect(find.text('9'), findsNothing);
  });
}
